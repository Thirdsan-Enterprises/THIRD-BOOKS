import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../database/app_database.dart';

// Sync Status enum
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

// Sync State
class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSyncAt;
  final int? lastSyncedSequence;
  final int pendingEventsCount;
  final int conflictsCount;

  const SyncState({
    required this.status,
    this.errorMessage,
    this.lastSyncAt,
    this.lastSyncedSequence,
    this.pendingEventsCount = 0,
    this.conflictsCount = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? errorMessage,
    DateTime? lastSyncAt,
    int? lastSyncedSequence,
    int? pendingEventsCount,
    int? conflictsCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncedSequence: lastSyncedSequence ?? this.lastSyncedSequence,
      pendingEventsCount: pendingEventsCount ?? this.pendingEventsCount,
      conflictsCount: conflictsCount ?? this.conflictsCount,
    });
  }
}

// Sync Service
class SyncService extends StateNotifier<SyncState> {
  final ApiClient _apiClient;
  final AppDatabase _database;
  final FlutterSecureStorage _storage;
  final Logger _logger = Logger();

  Timer? _periodicSyncTimer;
  String? _deviceId;

  SyncService({
    required ApiClient apiClient,
    required AppDatabase database,
    required FlutterSecureStorage storage,
  })  : _apiClient = apiClient,
        _database = database,
        _storage = storage,
        super(const SyncState(status: SyncStatus.idle)) {
    _init();
  }

  Future<void> _init() async {
    // Get or create device ID
    _deviceId = await _storage.read(key: 'device_id');
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _storage.write(key: 'device_id', value: _deviceId);
    }

    // Get last sync info
    final lastSeq = await _storage.read(key: 'last_synced_sequence');
    final lastSyncTime = await _storage.read(key: 'last_sync_at');

    state = state.copyWith(
      lastSyncedSequence: lastSeq != null ? int.tryParse(lastSeq) : null,
      lastSyncAt: lastSyncTime != null ? DateTime.tryParse(lastSyncTime) : null,
    );

    // Load pending events and conflicts count
    await _updateCounts();

    // Start periodic sync (every 30 seconds)
    _startPeriodicSync();
  }

  Future<void> _updateCounts() async {
    try {
      final pendingEvents = await _database.getPendingEventsCount();
      final stats = await _apiClient.getConflictStatistics();
      final conflictsCount = stats['pending'] as int? ?? 0;

      state = state.copyWith(
        pendingEventsCount: pendingEvents,
        conflictsCount: conflictsCount,
      );
    } catch (e) {
      _logger.w('Failed to update counts: $e');
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => sync(),
    );
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
  }

  /// Perform full bi-directional sync
  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) {
      return; // Already syncing
    }

    try {
      state = state.copyWith(status: SyncStatus.syncing);

      // Get pending local events
      final pendingEvents = await _database.getPendingEvents();

      // Perform sync
      final result = await _apiClient.syncEvents(
        deviceId: _deviceId!,
        deviceName: 'Mobile Admin',
        deviceType: 'mobile',
        afterSequence: state.lastSyncedSequence,
        events: pendingEvents.map((e) => e.toJson()).toList(),
      );

      // Process pushed events
      final pushed = result['pushed'] as Map<String, dynamic>?;
      if (pushed != null) {
        final uploadedCount = pushed['uploaded_count'] as int;
        final conflictsCount = pushed['conflicts_count'] as int;

        _logger.i('Uploaded $uploadedCount events, $conflictsCount conflicts');

        // Mark uploaded events as synced
        for (final event in pendingEvents) {
          await _database.markEventAsSynced(event.id);
        }
      }

      // Process pulled events
      final pulled = result['pulled'] as Map<String, dynamic>?;
      if (pulled != null) {
        final events = pulled['events'] as List<dynamic>;
        final lastSequence = pulled['last_sequence'] as int;

        _logger.i('Downloaded ${events.length} events');

        // Save downloaded events to local database
        for (final eventJson in events) {
          await _database.insertDownloadedEvent(eventJson as Map<String, dynamic>);
        }

        // Update last synced sequence
        await _storage.write(key: 'last_synced_sequence', value: lastSequence.toString());
        await _storage.write(key: 'last_sync_at', value: DateTime.now().toIso8601String());

        state = state.copyWith(
          lastSyncedSequence: lastSequence,
          lastSyncAt: DateTime.now(),
        );
      }

      state = state.copyWith(status: SyncStatus.success);
      await _updateCounts();

    } catch (e, stackTrace) {
      _logger.e('Sync failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Push only - upload local events to server
  Future<void> push() async {
    try {
      state = state.copyWith(status: SyncStatus.syncing);

      final pendingEvents = await _database.getPendingEvents();

      if (pendingEvents.isEmpty) {
        state = state.copyWith(status: SyncStatus.success);
        return;
      }

      final result = await _apiClient.syncEvents(
        deviceId: _deviceId!,
        events: pendingEvents.map((e) => e.toJson()).toList(),
      );

      final pushed = result['pushed'] as Map<String, dynamic>?;
      if (pushed != null) {
        for (final event in pendingEvents) {
          await _database.markEventAsSynced(event.id);
        }
      }

      state = state.copyWith(status: SyncStatus.success);
      await _updateCounts();

    } catch (e) {
      _logger.e('Push failed', error: e);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pull only - download events from server
  Future<void> pull() async {
    try {
      state = state.copyWith(status: SyncStatus.syncing);

      final result = await _apiClient.syncEvents(
        deviceId: _deviceId!,
        afterSequence: state.lastSyncedSequence,
      );

      final pulled = result['pulled'] as Map<String, dynamic>?;
      if (pulled != null) {
        final events = pulled['events'] as List<dynamic>;
        final lastSequence = pulled['last_sequence'] as int;

        for (final eventJson in events) {
          await _database.insertDownloadedEvent(eventJson as Map<String, dynamic>);
        }

        await _storage.write(key: 'last_synced_sequence', value: lastSequence.toString());
        await _storage.write(key: 'last_sync_at', value: DateTime.now().toIso8601String());

        state = state.copyWith(
          lastSyncedSequence: lastSequence,
          lastSyncAt: DateTime.now(),
        );
      }

      state = state.copyWith(status: SyncStatus.success);
      await _updateCounts();

    } catch (e) {
      _logger.e('Pull failed', error: e);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get sync status from server
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _apiClient.getSyncStatus(_deviceId!);
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}

// Sync Service Provider
final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final database = ref.watch(appDatabaseProvider);
  final storage = ref.watch(secureStorageProvider);

  return SyncService(
    apiClient: apiClient,
    database: database,
    storage: storage,
  );
});
