import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'local_storage_service.dart';
import 'data_service.dart';

// ============================================================================
// Connectivity State
// ============================================================================

enum ConnectivityStatus { online, offline, checking }

class ConnectivityState {
  final ConnectivityStatus status;
  final DateTime? lastChecked;
  final String? lastError;

  ConnectivityState({
    this.status = ConnectivityStatus.checking,
    this.lastChecked,
    this.lastError,
  });

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    DateTime? lastChecked,
    String? lastError,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      lastChecked: lastChecked ?? this.lastChecked,
      lastError: lastError,
    );
  }

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;
}

// ============================================================================
// Sync State
// ============================================================================

class SyncState {
  final bool isSyncing;
  final int pendingChanges;
  final DateTime? lastSyncTime;
  final String? error;
  final double progress;

  SyncState({
    this.isSyncing = false,
    this.pendingChanges = 0,
    this.lastSyncTime,
    this.error,
    this.progress = 0,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? pendingChanges,
    DateTime? lastSyncTime,
    String? error,
    double? progress,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

// ============================================================================
// Connectivity Notifier
// ============================================================================

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final ApiClient _apiClient;
  Timer? _checkTimer;

  ConnectivityNotifier(this._apiClient) : super(ConnectivityState()) {
    _startPeriodicCheck();
    checkConnectivity();
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnectivity();
    });
  }

  Future<void> checkConnectivity() async {
    try {
      // Try to reach the server with a simple ping
      final response = await _apiClient.get('/ping').timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(
          status: ConnectivityStatus.online,
          lastChecked: DateTime.now(),
          lastError: null,
        );
      } else {
        state = state.copyWith(
          status: ConnectivityStatus.offline,
          lastChecked: DateTime.now(),
          lastError: 'Server returned ${response.statusCode}',
        );
      }
    } on SocketException {
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        lastChecked: DateTime.now(),
        lastError: 'No network connection',
      );
    } on TimeoutException {
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        lastChecked: DateTime.now(),
        lastError: 'Connection timeout',
      );
    } catch (e) {
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        lastChecked: DateTime.now(),
        lastError: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// Sync Service Notifier
// ============================================================================

class SyncServiceNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  final ApiClient _apiClient;
  final LocalStorageService _localStorage;
  Timer? _autoSyncTimer;

  SyncServiceNotifier(this._ref, this._apiClient, this._localStorage)
      : super(SyncState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _localStorage.initialize();
    await _loadPendingChanges();
    _startAutoSync();
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _attemptAutoSync();
    });
  }

  Future<void> _attemptAutoSync() async {
    final connectivity = _ref.read(connectivityProvider);
    if (connectivity.isOnline && state.pendingChanges > 0 && !state.isSyncing) {
      await syncAll();
    }
  }

  Future<void> _loadPendingChanges() async {
    final queue = await _localStorage.loadSyncQueue();
    state = state.copyWith(pendingChanges: queue.length);

    final lastSync = await _localStorage.getLastSyncTime();
    if (lastSync != null) {
      state = state.copyWith(lastSyncTime: lastSync);
    }
  }

  // ============================================================================
  // Queue Management
  // ============================================================================

  Future<void> queueChange({
    required SyncAction action,
    required SyncEntityType entityType,
    required String entityId,
    Map<String, dynamic>? data,
  }) async {
    final item = SyncQueueItem(
      id: const Uuid().v4(),
      action: action,
      entityType: entityType,
      entityId: entityId,
      data: data,
      createdAt: DateTime.now(),
    );

    await _localStorage.addToSyncQueue(item);
    await _loadPendingChanges();

    // Try to sync immediately if online
    final connectivity = _ref.read(connectivityProvider);
    if (connectivity.isOnline) {
      _processSingleItem(item);
    }
  }

  // ============================================================================
  // Sync Operations
  // ============================================================================

  Future<void> syncAll() async {
    if (state.isSyncing) return;

    final connectivity = _ref.read(connectivityProvider);
    if (!connectivity.isOnline) {
      state = state.copyWith(error: 'Cannot sync while offline');
      return;
    }

    state = state.copyWith(isSyncing: true, error: null, progress: 0);

    try {
      final queue = await _localStorage.loadSyncQueue();
      final total = queue.length;

      for (var i = 0; i < queue.length; i++) {
        final item = queue[i];
        await _processSingleItem(item);
        state = state.copyWith(progress: (i + 1) / total);
      }

      // After syncing queue, pull fresh data from server
      await _pullFromServer();

      await _localStorage.setLastSyncTime(DateTime.now());
      await _loadPendingChanges();

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        progress: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: 'Sync failed: ${e.toString()}',
      );
    }
  }

  Future<void> _processSingleItem(SyncQueueItem item) async {
    try {
      final endpoint = _getEndpoint(item.entityType);

      switch (item.action) {
        case SyncAction.create:
          await _apiClient.post(endpoint, data: item.data);
          break;
        case SyncAction.update:
          await _apiClient.put('$endpoint/${item.entityId}', data: item.data);
          break;
        case SyncAction.delete:
          await _apiClient.delete('$endpoint/${item.entityId}');
          break;
      }

      await _localStorage.removeFromSyncQueue(item.id);
    } catch (e) {
      debugPrint('Failed to sync item ${item.id}: $e');
      // Item stays in queue for retry
    }
  }

  String _getEndpoint(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.account:
        return '/accounts';
      case SyncEntityType.customer:
        return '/customers';
      case SyncEntityType.vendor:
        return '/vendors';
      case SyncEntityType.invoice:
        return '/invoices';
      case SyncEntityType.bill:
        return '/bills';
      case SyncEntityType.journalEntry:
        return '/journals';
      case SyncEntityType.payment:
        return '/payments';
    }
  }

  Future<void> _pullFromServer() async {
    try {
      // Refresh all data from server
      await Future.wait([
        _ref.read(accountsProvider.notifier).loadAccounts(),
        _ref.read(customersProvider.notifier).loadCustomers(),
        _ref.read(vendorsProvider.notifier).loadVendors(),
        _ref.read(invoicesProvider.notifier).loadInvoices(),
        _ref.read(billsProvider.notifier).loadBills(),
        _ref.read(journalsProvider.notifier).loadJournals(),
        _ref.read(paymentsProvider.notifier).loadPayments(),
      ]);
    } catch (e) {
      debugPrint('Error pulling data from server: $e');
    }
  }

  // ============================================================================
  // Save Local Data
  // ============================================================================

  Future<void> saveDataLocally() async {
    try {
      final accounts = _ref.read(accountsProvider).accounts;
      final customers = _ref.read(customersProvider).customers;
      final vendors = _ref.read(vendorsProvider).vendors;
      final invoices = _ref.read(invoicesProvider).invoices;
      final bills = _ref.read(billsProvider).bills;
      final journals = _ref.read(journalsProvider).entries;
      final payments = _ref.read(paymentsProvider).payments;

      await Future.wait([
        _localStorage.saveAccounts(accounts),
        _localStorage.saveCustomers(customers),
        _localStorage.saveVendors(vendors),
        _localStorage.saveInvoices(invoices),
        _localStorage.saveBills(bills),
        _localStorage.saveJournalEntries(journals),
        _localStorage.savePayments(payments),
      ]);
    } catch (e) {
      debugPrint('Error saving data locally: $e');
    }
  }

  // ============================================================================
  // Load Local Data
  // ============================================================================

  Future<void> loadDataFromLocal() async {
    try {
      // This would be used to populate providers from local storage
      // when app starts and is offline
      debugPrint('Loading data from local storage...');
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  // ============================================================================
  // Clear Local Cache
  // Wipes all locally-stored JSON files and the sync queue.
  // Cloud data is untouched. The next sync will re-populate local storage.
  // ============================================================================

  Future<void> clearLocalCache() async {
    try {
      await _localStorage.initialize();
      // Clear JSON file cache
      await Future.wait([
        _localStorage.saveAccounts([]),
        _localStorage.saveCustomers([]),
        _localStorage.saveVendors([]),
        _localStorage.saveInvoices([]),
        _localStorage.saveBills([]),
        _localStorage.saveJournalEntries([]),
        _localStorage.savePayments([]),
        _localStorage.clearSyncQueue(),
      ]);
      // Also wipe the SQLite/Drift database so outlet revenues, expenditures,
      // outlets, journals, assets etc. are fully gone — true blank slate.
      final db = _ref.read(databaseProvider);
      await db.clearAllData();

      state = state.copyWith(pendingChanges: 0);
      debugPrint('Local cache and database cleared.');
    } catch (e) {
      debugPrint('Error clearing local cache: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Delete All Cloud Data
  // Calls DELETE /api/me/data on the backend (irrecoverable) then clears local.
  // ============================================================================

  Future<void> deleteAllCloudData() async {
    try {
      final connectivity = _ref.read(connectivityProvider);
      if (!connectivity.isOnline) {
        throw Exception('Must be online to delete cloud data');
      }

      state = state.copyWith(isSyncing: true, error: null);

      // Ask backend to wipe the tenant's data
      final response = await _apiClient.delete('/me/data');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Server returned ${response.statusCode}');
      }

      // Then wipe local cache too
      await clearLocalCache();

      state = state.copyWith(isSyncing: false);
      debugPrint('All cloud and local data deleted.');
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: 'Delete failed: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// Providers
// ============================================================================

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier(ref.read(apiClientProvider));
});

final syncServiceProvider = StateNotifierProvider<SyncServiceNotifier, SyncState>((ref) {
  return SyncServiceNotifier(
    ref,
    ref.read(apiClientProvider),
    ref.read(localStorageServiceProvider),
  );
});
