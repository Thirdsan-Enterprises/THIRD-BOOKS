import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../database/app_database.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

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
  }) =>
      SyncState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastSyncedSequence: lastSyncedSequence ?? this.lastSyncedSequence,
        pendingEventsCount: pendingEventsCount ?? this.pendingEventsCount,
        conflictsCount: conflictsCount ?? this.conflictsCount,
      );

  static const initial = SyncState(status: SyncStatus.idle);
}

class SyncService extends StateNotifier<SyncState> {
  final AppDatabase _db;
  final ApiClient _api;
  Timer? _autoSyncTimer;

  SyncService(this._db, this._api) : super(SyncState.initial) {
    _loadSyncState();
  }

  Future<void> _loadSyncState() async {
    final dbState = await _db.getSyncState();
    final pendingEvents = await _db.getPendingSyncEvents();

    state = state.copyWith(
      lastSyncAt: dbState?.lastSyncAt,
      lastSyncedSequence: dbState?.lastSyncedSequence,
      pendingEventsCount: pendingEvents.length,
      status: _parseStatus(dbState?.syncStatus ?? 'idle'),
    );
  }

  SyncStatus _parseStatus(String status) {
    switch (status) {
      case 'syncing':
        return SyncStatus.syncing;
      case 'success':
        return SyncStatus.success;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.idle;
    }
  }

  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) => sync());
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);
    await _db.updateSyncState(syncStatus: 'syncing');

    try {
      // Get pending local changes
      final pendingEvents = await _db.getPendingSyncEvents();

      // Prepare events for sync
      final eventsToSync = pendingEvents.map((e) {
        return {
          'id': e.id,
          'entity_type': e.entityType,
          'entity_id': e.entityId,
          'action': e.action,
          'payload': jsonDecode(e.payload),
          'created_at': e.createdAt.toIso8601String(),
        };
      }).toList();

      // Send sync request
      final response = await _api.sync(
        lastSequence: state.lastSyncedSequence ?? 0,
        events: eventsToSync,
      );

      // Process server changes
      final serverChanges = response['changes'] as List<dynamic>? ?? [];
      final newSequence = response['sequence'] as int? ?? state.lastSyncedSequence ?? 0;

      for (final change in serverChanges) {
        await _applyServerChange(change as Map<String, dynamic>);
      }

      // Mark local events as synced
      if (pendingEvents.isNotEmpty) {
        await _db.markSyncEventsSynced(pendingEvents.map((e) => e.id).toList());
      }

      // Update sync state
      final now = DateTime.now();
      await _db.updateSyncState(
        lastSyncedSequence: newSequence,
        lastSyncAt: now,
        syncStatus: 'success',
        lastError: null,
      );

      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncAt: now,
        lastSyncedSequence: newSequence,
        pendingEventsCount: 0,
        errorMessage: null,
      );
    } catch (e) {
      final errorMessage = e.toString();
      await _db.updateSyncState(syncStatus: 'error', lastError: errorMessage);

      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: errorMessage,
      );

      rethrow;
    }
  }

  Future<void> _applyServerChange(Map<String, dynamic> change) async {
    final entityType = change['entity_type'] as String;
    final action = change['action'] as String;
    final payload = change['payload'] as Map<String, dynamic>;

    switch (entityType) {
      case 'account':
        await _applyAccountChange(action, payload);
        break;
      case 'customer':
        await _applyCustomerChange(action, payload);
        break;
      case 'vendor':
        await _applyVendorChange(action, payload);
        break;
      case 'invoice':
        await _applyInvoiceChange(action, payload);
        break;
      case 'bill':
        await _applyBillChange(action, payload);
        break;
      case 'journal_entry':
        await _applyJournalEntryChange(action, payload);
        break;
    }
  }

  Future<void> _applyAccountChange(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _db.into(_db.accounts).insertOnConflictUpdate(
              AccountsCompanion.insert(
                id: data['id'] as String,
                code: data['code'] as String,
                name: data['name'] as String,
                description: Value(data['description'] as String?),
                type: data['type'] as String,
                subType: Value(data['sub_type'] as String?),
                parentId: Value(data['parent_id'] as String?),
                currencyCode: Value(data['currency_code'] as String? ?? 'UGX'),
                balance: Value((data['balance'] as num?)?.toDouble() ?? 0.0),
                isActive: Value(data['is_active'] as bool? ?? true),
                isSystemAccount: Value(data['is_system_account'] as bool? ?? false),
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: DateTime.parse(data['updated_at'] as String),
                syncSequence: Value(data['sync_sequence'] as int?),
              ),
            );
        break;
      case 'delete':
        await _db.deleteAccount(data['id'] as String);
        break;
    }
  }

  Future<void> _applyCustomerChange(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _db.into(_db.customers).insertOnConflictUpdate(
              CustomersCompanion.insert(
                id: data['id'] as String,
                name: data['name'] as String,
                email: Value(data['email'] as String?),
                phone: Value(data['phone'] as String?),
                address: Value(data['address'] as String?),
                taxId: Value(data['tax_id'] as String?),
                creditLimit: Value((data['credit_limit'] as num?)?.toDouble() ?? 0.0),
                balance: Value((data['balance'] as num?)?.toDouble() ?? 0.0),
                currencyCode: Value(data['currency_code'] as String? ?? 'UGX'),
                paymentTerms: Value(data['payment_terms'] as String?),
                isActive: Value(data['is_active'] as bool? ?? true),
                notes: Value(data['notes'] as String?),
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: DateTime.parse(data['updated_at'] as String),
                syncSequence: Value(data['sync_sequence'] as int?),
              ),
            );
        break;
      case 'delete':
        await (_db.delete(_db.customers)..where((c) => c.id.equals(data['id'] as String))).go();
        break;
    }
  }

  Future<void> _applyVendorChange(String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'create':
      case 'update':
        await _db.into(_db.vendors).insertOnConflictUpdate(
              VendorsCompanion.insert(
                id: data['id'] as String,
                name: data['name'] as String,
                email: Value(data['email'] as String?),
                phone: Value(data['phone'] as String?),
                address: Value(data['address'] as String?),
                taxId: Value(data['tax_id'] as String?),
                balance: Value((data['balance'] as num?)?.toDouble() ?? 0.0),
                currencyCode: Value(data['currency_code'] as String? ?? 'UGX'),
                paymentTerms: Value(data['payment_terms'] as String?),
                isActive: Value(data['is_active'] as bool? ?? true),
                notes: Value(data['notes'] as String?),
                bankName: Value(data['bank_name'] as String?),
                bankAccountNumber: Value(data['bank_account_number'] as String?),
                createdAt: DateTime.parse(data['created_at'] as String),
                updatedAt: DateTime.parse(data['updated_at'] as String),
                syncSequence: Value(data['sync_sequence'] as int?),
              ),
            );
        break;
      case 'delete':
        await (_db.delete(_db.vendors)..where((v) => v.id.equals(data['id'] as String))).go();
        break;
    }
  }

  Future<void> _applyInvoiceChange(String action, Map<String, dynamic> data) async {
    // Implementation for invoice sync
  }

  Future<void> _applyBillChange(String action, Map<String, dynamic> data) async {
    // Implementation for bill sync
  }

  Future<void> _applyJournalEntryChange(String action, Map<String, dynamic> data) async {
    // Implementation for journal entry sync
  }

  Future<void> recordLocalChange({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    await _db.insertSyncEvent(
      SyncEventsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        action: action,
        payload: jsonEncode(payload),
        createdAt: DateTime.now(),
      ),
    );

    final pendingEvents = await _db.getPendingSyncEvents();
    state = state.copyWith(pendingEventsCount: pendingEvents.length);
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}

// Riverpod providers
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(apiClientProvider);
  return SyncService(db, api);
});
