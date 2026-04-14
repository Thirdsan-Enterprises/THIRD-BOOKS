import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'local_storage_service.dart';
import 'data_service.dart';
import '../models/models.dart';
import '../providers/local_bank_statements_provider.dart';
import '../providers/asset_drafts_provider.dart';
import '../providers/depreciation_schedules_provider.dart';
import '../providers/local_attachments_provider.dart';

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
      // Try to reach the server with a health check
      final response = await _apiClient.get('/health').timeout(
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
        lastError: 'Connection timed out',
      );
    } on DioException catch (e) {
      // Translate Dio errors into user-friendly messages
      final String friendlyError;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          friendlyError = 'Connection timed out';
          break;
        case DioExceptionType.connectionError:
          friendlyError = 'Unable to reach server';
          break;
        case DioExceptionType.badResponse:
          friendlyError = 'Server unavailable (${e.response?.statusCode ?? 'unknown'})';
          break;
        default:
          friendlyError = 'Unable to reach server';
      }
      debugPrint('Connectivity check failed: $e');
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        lastChecked: DateTime.now(),
        lastError: friendlyError,
      );
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        lastChecked: DateTime.now(),
        lastError: 'Unable to reach server',
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
        error: 'Sync failed. Changes will retry automatically.',
      );
    }
  }

  Future<void> _processSingleItem(SyncQueueItem item, {int maxAttempts = 3}) async {
    final endpoint = _getEndpoint(item.entityType);
    int attempt = 0;
    Duration delay = const Duration(seconds: 2);

    while (attempt < maxAttempts) {
      try {
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
        return; // success
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) {
          debugPrint('Failed to sync item ${item.id} after $maxAttempts attempts: $e');
          // Item stays in queue for the next auto-sync cycle
          return;
        }
        debugPrint('Sync attempt $attempt failed for ${item.id}, retrying in ${delay.inSeconds}s: $e');
        await Future.delayed(delay);
        delay *= 2; // exponential backoff
      }
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
      await Future.wait([
        _pullEntityFromServer<Account>(
          endpoint: '/accounts',
          fromJson: (j) => Account.fromJson(j),
          save: (items) => _localStorage.saveAccounts(items),
          reload: () => _ref.read(accountsProvider.notifier).loadAccounts(),
        ),
        _pullEntityFromServer<Customer>(
          endpoint: '/customers',
          fromJson: (j) => Customer.fromJson(j),
          save: (items) => _localStorage.saveCustomers(items),
          reload: () => _ref.read(customersProvider.notifier).loadCustomers(),
        ),
        _pullEntityFromServer<Vendor>(
          endpoint: '/vendors',
          fromJson: (j) => Vendor.fromJson(j),
          save: (items) => _localStorage.saveVendors(items),
          reload: () => _ref.read(vendorsProvider.notifier).loadVendors(),
        ),
        _pullEntityFromServer<Invoice>(
          endpoint: '/invoices',
          fromJson: (j) => Invoice.fromJson(j),
          save: (items) => _localStorage.saveInvoices(items),
          reload: () => _ref.read(invoicesProvider.notifier).loadInvoices(),
        ),
        _pullEntityFromServer<Bill>(
          endpoint: '/bills',
          fromJson: (j) => Bill.fromJson(j),
          save: (items) => _localStorage.saveBills(items),
          reload: () => _ref.read(billsProvider.notifier).loadBills(),
        ),
        _pullEntityFromServer<JournalEntry>(
          endpoint: '/journals',
          fromJson: (j) => JournalEntry.fromJson(j),
          save: (items) => _localStorage.saveJournalEntries(items),
          reload: () => _ref.read(journalsProvider.notifier).loadJournals(),
        ),
        _pullEntityFromServer<Payment>(
          endpoint: '/payments',
          fromJson: (j) => Payment.fromJson(j),
          save: (items) => _localStorage.savePayments(items),
          reload: () => _ref.read(paymentsProvider.notifier).loadPayments(),
        ),
      ]);
    } catch (e) {
      debugPrint('Error pulling data from server: $e');
    }
  }

  /// Fetches a collection from [endpoint], persists it to local storage via
  /// [save], then triggers a provider reload via [reload].
  Future<void> _pullEntityFromServer<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<void> Function(List<T>) save,
    required Future<void> Function() reload,
  }) async {
    try {
      final response = await _apiClient.get(endpoint);
      if (response.statusCode == 200) {
        final body = response.data;
        // Support both { data: [...] } and bare [...] response shapes
        final List<dynamic> rawList = body is Map && body.containsKey('data')
            ? (body['data'] as List<dynamic>)
            : (body as List<dynamic>);
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => fromJson(j))
            .toList();
        await save(items);
        await reload();
      }
    } catch (e) {
      debugPrint('Error pulling $endpoint from server: $e');
      // Fall back to local data — do not rethrow
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

  /// Populate all providers from local storage — called at app start when offline.
  Future<void> loadDataFromLocal() async {
    try {
      await Future.wait([
        _ref.read(accountsProvider.notifier).loadAccounts(),
        _ref.read(customersProvider.notifier).loadCustomers(),
        _ref.read(vendorsProvider.notifier).loadVendors(),
        _ref.read(invoicesProvider.notifier).loadInvoices(),
        _ref.read(billsProvider.notifier).loadBills(),
        _ref.read(journalsProvider.notifier).loadJournals(),
        _ref.read(paymentsProvider.notifier).loadPayments(),
      ]);
      debugPrint('Loaded all data from local storage.');
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
      // Clear JSON file cache — includes all local-only stores.
      await Future.wait([
        // Core synced entities
        _localStorage.saveAccounts([]),
        _localStorage.saveCustomers([]),
        _localStorage.saveVendors([]),
        _localStorage.saveInvoices([]),
        _localStorage.saveBills([]),
        _localStorage.saveJournalEntries([]),
        _localStorage.savePayments([]),
        _localStorage.clearSyncQueue(),
        // Local-only stores (not synced from cloud; user-generated on device)
        _localStorage.saveCreditNotes([]),
        _localStorage.saveDebitNotes([]),
        _localStorage.saveOutletSettlements([]),
        // Extended local stores (generic key-based)
        _localStorage.saveBankTransactions([]),
        _localStorage.saveData<Map<String, dynamic>>(
            'local_bank_statements', [], (s) => s),
        _localStorage.saveData<Map<String, dynamic>>(
            'asset_drafts', [], (s) => s),
        _localStorage.saveData<Map<String, dynamic>>(
            'depreciation_schedules', [], (s) => s),
        _localStorage.saveData<Map<String, dynamic>>(
            'local_attachments', [], (s) => s),
      ]);
      // Also wipe the SQLite/Drift database so outlet revenues, expenditures,
      // outlets, journals, assets etc. are fully gone — true blank slate.
      final db = _ref.read(databaseProvider);
      await db.clearAllData();

      // Invalidate cached FutureProviders so dashboard, analytics, expenditure,
      // and reports screens immediately reflect the cleared state without restart.
      _ref.invalidate(dashboardDataProvider);
      _ref.invalidate(outletAnalyticsProvider);
      _ref.invalidate(outletRevenueSummaryProvider);
      // Reset StateNotifier-based local stores so their in-memory state
      // matches the now-empty disk — no restart required.
      try {
        _ref.read(localBankStatementsProvider.notifier).clearAll();
        _ref.read(assetDraftsProvider.notifier).clearAll();
        _ref.read(depreciationSchedulesProvider.notifier).clearAll();
        _ref.read(localAttachmentsProvider.notifier).clearAll();
      } catch (_) {
        // Providers may not be initialised — the JSON files are already empty.
      }

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
