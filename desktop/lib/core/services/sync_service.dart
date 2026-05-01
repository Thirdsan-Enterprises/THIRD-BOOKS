import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart' show Dio, DioException, DioExceptionType, MultipartFile, FormData, DioMediaType, Response;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';
import 'local_storage_service.dart';
import 'data_service.dart';
import '../models/models.dart';
import '../models/bank_transaction.dart';
import '../providers/local_bank_statements_provider.dart';
import '../providers/asset_drafts_provider.dart';
import '../providers/depreciation_schedules_provider.dart';
import '../providers/local_attachments_provider.dart';
import '../providers/notes_providers.dart';

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
    // No periodic check — auto-sync removed. Connectivity state is not needed.
  }

  void _startPeriodicCheck() {
    // No-op: periodic connectivity check removed.
  }

  Future<void> checkConnectivity() async {
    try {
      // Check actual device internet connectivity via DNS lookup.
      // This is fast (<1 s) and does NOT depend on our server's response time,
      // which prevents false "offline" when the server is slow but the device
      // has a working internet connection.
      final results = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (results.isNotEmpty && results[0].rawAddress.isNotEmpty) {
        state = state.copyWith(
          status: ConnectivityStatus.online,
          lastChecked: DateTime.now(),
          lastError: null,
        );
      } else {
        state = state.copyWith(
          status: ConnectivityStatus.offline,
          lastChecked: DateTime.now(),
          lastError: 'No internet connection',
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
        lastError: 'Connection check timed out',
      );
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        lastChecked: DateTime.now(),
        lastError: 'No internet connection',
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
  String? _cachedDeviceId;

  SyncServiceNotifier(this._ref, this._apiClient, this._localStorage)
      : super(SyncState()) {
    _initialize();
  }

  // Returns a stable UUID for this installation, creating one on first run.
  Future<String> _getOrCreateDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final appDir = await getApplicationDocumentsDirectory();
    final idFile = File(p.join(appDir.path, 'thirdbooks', 'device_id.txt'));
    if (await idFile.exists()) {
      final saved = (await idFile.readAsString()).trim();
      if (saved.isNotEmpty) {
        _cachedDeviceId = saved;
        return _cachedDeviceId!;
      }
    }
    _cachedDeviceId = const Uuid().v4();
    await idFile.parent.create(recursive: true);
    await idFile.writeAsString(_cachedDeviceId!);
    return _cachedDeviceId!;
  }

  // Registers this device in the server's device_sync_state table.
  // Idempotent — safe to call on every sync.
  Future<void> _registerDevice() async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      await _apiClient.post('/sync/device', data: {
        'device_id': deviceId,
        'device_name': 'ThirdBooks Desktop',
        'device_type': 'desktop',
        'last_sequence': 0,
      });
    } catch (e) {
      debugPrint('Device registration failed (non-fatal): $e');
    }
  }

  Future<void> _initialize() async {
    await _localStorage.initialize();
    await _loadPendingChanges();
    // Auto-sync disabled — data sharing is done via Export/Import file transfer.
  }

  void _startAutoSync() {
    // No-op: auto-sync removed. Use Export Backup / Import Backup instead.
  }

  Future<void> _attemptAutoSync() async {
    final connectivity = _ref.read(connectivityProvider);
    // Always pull from server when online — not just when there are pending
    // local changes. Without this, a device with no local edits never fetches
    // data entered by another device.
    if (connectivity.isOnline && !state.isSyncing) {
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

    // Register this device on the server so it appears in device_sync_state
    // immediately on first login without waiting for a full event-sourcing sync.
    unawaited(_registerDevice());

    try {
      final queue = await _localStorage.loadSyncQueue();
      final total = queue.length;

      for (var i = 0; i < queue.length; i++) {
        final item = queue[i];
        await _processSingleItem(item);
        state = state.copyWith(progress: (i + 1) / total);
      }

      // Upload any locally-stored attachments that haven't reached the server yet
      await _uploadPendingAttachments();

      // After syncing queue, pull fresh data from server
      await _pullFromServer();

      // Push+pull client-managed entities (blob store via /client-data/{type})
      await _syncClientDataEntities();

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
        return '/journal-entries';
      case SyncEntityType.payment:
        return '/payments';
      case SyncEntityType.creditNote:
        return '/credit-notes';
      case SyncEntityType.debitNote:
        return '/debit-notes';
    }
  }

  // ============================================================================
  // Attachment Upload
  // Uploads any LocalAttachment still in 'local' status to POST /attachments.
  // Marks each one 'synced' or 'error' and persists the result.
  // ============================================================================

  Future<void> _uploadPendingAttachments() async {
    final notifier = _ref.read(localAttachmentsProvider.notifier);
    final pending = _ref
        .read(localAttachmentsProvider)
        .where((a) => a.isLocal)
        .toList();

    for (final att in pending) {
      try {
        final file = File(att.localPath);
        if (!await file.exists()) {
          await notifier.markError(att.id);
          continue;
        }

        final ext = p.extension(att.fileName).toLowerCase();
        final mimeType = att.mimeType ?? _mimeFromExt(ext);

        final formData = FormData.fromMap({
          'attachable_type': att.attachableType,
          'attachable_id':   att.localRecordId,
          'file': await MultipartFile.fromFile(
            att.localPath,
            filename: att.fileName,
            contentType: mimeType != null
                ? DioMediaType.parse(mimeType)
                : null,
          ),
        });

        final response = await _apiClient.post('/attachments', data: formData);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = response.data;
          final serverData = body['attachment'] ?? body['data'] ?? body;
          await notifier.markSynced(
            att.id,
            serverData['id'] as int? ?? 0,
            serverData['url'] as String? ?? '',
          );
        } else {
          await notifier.markError(att.id);
        }
      } catch (e) {
        debugPrint('Attachment upload failed for ${att.id}: $e');
        await notifier.markError(att.id);
      }
    }
  }

  /// Minimal MIME inference from file extension — avoids adding a mime package.
  String? _mimeFromExt(String ext) {
    const map = {
      '.pdf':  'application/pdf',
      '.jpg':  'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png':  'image/png',
      '.gif':  'image/gif',
      '.webp': 'image/webp',
      '.doc':  'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls':  'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.txt':  'text/plain',
      '.csv':  'text/csv',
    };
    return map[ext];
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
          loadLocal: () => _localStorage.loadInvoices(),
          getId: (i) => i.id,
        ),
        // Bills and JournalEntries are synced exclusively via the blob-store
        // path (_syncBillsBlob / _syncJournalEntriesBlob) which runs in
        // _syncClientDataEntities().  Pulling them here from the REST endpoint
        // caused two problems:
        //   1. JournalLine / BillLine decimal fields come back as strings
        //      ("500.0000") from Laravel's decimal:4 cast, causing TypeError
        //      in fromJson and silently emptying journals.json / bills.json.
        //   2. Server assigns integer IDs; local uses UUIDs — ID mismatches
        //      created duplicate records that confused the merge logic.
        // The blob store is the single source of truth for these entities.

        _pullEntityFromServer<Payment>(
          endpoint: '/payments',
          fromJson: (j) => Payment.fromJson(j),
          save: (items) => _localStorage.savePayments(items),
          reload: () => _ref.read(paymentsProvider.notifier).loadPayments(),
        ),
        _pullEntityFromServer<CreditNote>(
          endpoint: '/credit-notes',
          fromJson: (j) => CreditNote.fromJson(j),
          save: (items) => _localStorage.saveCreditNotes(items),
          reload: () => _ref.read(creditNotesProvider.notifier).reload(),
          responseKey: 'credit_notes',
          loadLocal: () => _localStorage.loadCreditNotes(),
          getId: (n) => n.id,
        ),
        _pullEntityFromServer<DebitNote>(
          endpoint: '/debit-notes',
          fromJson: (j) => DebitNote.fromJson(j),
          save: (items) => _localStorage.saveDebitNotes(items),
          reload: () => _ref.read(debitNotesProvider.notifier).reload(),
          responseKey: 'debit_notes',
          loadLocal: () => _localStorage.loadDebitNotes(),
          getId: (n) => n.id,
        ),
      ]);
    } catch (e) {
      debugPrint('Error pulling data from server: $e');
    }
  }

  /// Fetches a collection from [endpoint], persists it to local storage via
  /// [save], then triggers a provider reload via [reload].
  ///
  /// When [loadLocal] and [getId] are supplied the pull uses a MERGE strategy:
  /// server items (authoritative) are kept as-is, while local items whose IDs
  /// are absent from the server response are preserved — they are pending push
  /// and must not be destroyed by a pull before the push succeeds.
  ///
  /// Without those parameters the pull does a full replace (safe for
  /// reference-data entities like Accounts, Customers, Vendors).
  Future<void> _pullEntityFromServer<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<void> Function(List<T>) save,
    required Future<void> Function() reload,
    String? responseKey,
    Future<List<T>> Function()? loadLocal,
    String Function(T)? getId,
  }) async {
    try {
      final response = await _apiClient.get(
        endpoint,
        queryParameters: {'per_page': 10000},
      );
      if (response.statusCode == 200) {
        final body = response.data;
        List<dynamic> rawList;
        if (responseKey != null && body is Map && body.containsKey(responseKey)) {
          rawList = body[responseKey] as List<dynamic>;
        } else if (body is Map && body.containsKey('data')) {
          rawList = body['data'] as List<dynamic>;
        } else {
          rawList = body as List<dynamic>;
        }
        final serverItems = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => fromJson(j))
            .toList();

        List<T> itemsToSave = serverItems;

        if (loadLocal != null && getId != null) {
          // Merge: keep local items whose IDs are not yet on the server.
          final local = await loadLocal();
          final serverIds = {for (final item in serverItems) getId(item)};
          final localOnly = local.where((item) => !serverIds.contains(getId(item))).toList();
          if (localOnly.isNotEmpty) {
            itemsToSave = [...serverItems, ...localOnly];
          }
        }

        await save(itemsToSave);
        await reload();
      }
    } catch (e) {
      debugPrint('Error pulling $endpoint from server: $e');
      // Fall back to local data — do not rethrow
    }
  }

  // ============================================================================
  // Client-Data Blob Store Sync (bank tx, asset drafts, outlet revenues, etc.)
  // ============================================================================

  /// Push+pull all entities that use the generic /client-data/{type} endpoint.
  Future<void> _syncClientDataEntities() async {
    try {
      await Future.wait([
        _syncBankTransactions(),
        _syncBankStatements(),
        _syncAssetDrafts(),
        _syncDepreciationSchedules(),
        _syncOutletSettlements(),
        _syncOutletRevenues(),
        _syncOutletExpenditures(),
        _syncCommissionPayments(),
        // Accounting entities — blob store guarantees delivery regardless of
        // REST validation state. Data also flows through the REST queue path
        // so proper DB tables get populated when the server accepts the push.
        _syncVendorsBlob(),
        _syncCustomersBlob(),
        _syncInvoicesBlob(),
        _syncBillsBlob(),
        _syncJournalEntriesBlob(),
        _syncCreditNotesBlob(),
        _syncDebitNotesBlob(),
      ]);
    } catch (e) {
      debugPrint('Error in _syncClientDataEntities: $e');
    }
  }

  Future<void> _syncBankTransactions() async {
    const type = 'bank-transactions';
    try {
      // Push
      final local = await _localStorage.loadBankTransactions();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((t) => t.toJson()).toList()},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(BankTransaction.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          await _localStorage.saveBankTransactions(pulled);
        }
      }
    } catch (e) {
      debugPrint('Bank transaction sync error: $e');
    }
  }

  Future<void> _syncBankStatements() async {
    const type = 'bank-statements';
    try {
      // Push
      final local = _ref.read(localBankStatementsProvider);
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((s) => s.toJson()).toList()},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(LocalBankStatement.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          _ref.read(localBankStatementsProvider.notifier).replaceAll(pulled);
        }
      }
    } catch (e) {
      debugPrint('Bank statement sync error: $e');
    }
  }

  Future<void> _syncAssetDrafts() async {
    const type = 'asset-drafts';
    try {
      // Push
      final local = _ref.read(assetDraftsProvider);
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((a) => a.toJson()).toList()},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(AssetDraft.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          await _ref.read(assetDraftsProvider.notifier).replaceAll(pulled);
        }
      }
    } catch (e) {
      debugPrint('Asset drafts sync error: $e');
    }
  }

  Future<void> _syncDepreciationSchedules() async {
    const type = 'depreciation-schedules';
    try {
      // Push
      final local = _ref.read(depreciationSchedulesProvider);
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((s) => s.toJson()).toList()},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(DepreciationSchedule.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          _ref.read(depreciationSchedulesProvider.notifier).replaceAll(pulled);
        }
      }
    } catch (e) {
      debugPrint('Depreciation schedules sync error: $e');
    }
  }

  Future<void> _syncOutletSettlements() async {
    const type = 'outlet-settlements';
    try {
      // Push
      final local = await _localStorage.loadOutletSettlements();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((s) => s.toJson()).toList()},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(OutletSettlement.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          await _localStorage.saveOutletSettlements(pulled);
        }
      }
    } catch (e) {
      debugPrint('Outlet settlements sync error: $e');
    }
  }

  Future<void> _syncOutletRevenues() async {
    const type = 'outlet-revenues';
    try {
      final db = _ref.read(databaseProvider);
      // Push — include outlet_code so the receiving device can resolve the FK
      final allOutlets = await db.getAllOutlets();
      final outletCodeMap = {for (final o in allOutlets) o.id: o.outletCode};
      final revenues = await db.getAllOutletRevenues();
      if (revenues.isNotEmpty) {
        final records = revenues.map((r) => {
          'id': r.id,
          'outlet_id': r.outletId,
          'outlet_code': outletCodeMap[r.outletId] ?? '',
          'date': r.date.toIso8601String(),
          'amount': r.amount,
          'commission_amount': r.commissionAmount,
          'net_amount': r.netAmount,
          'description': r.description,
          'reference': r.reference,
          'status': r.status,
          'created_at': r.createdAt.toIso8601String(),
          'updated_at': r.updatedAt.toIso8601String(),
        }).toList();
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': records},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        for (final item in raw.whereType<Map<String, dynamic>>()) {
          await db.upsertOutletRevenueFromMap(item);
        }
        if (raw.isNotEmpty) {
          _ref.invalidate(dashboardDataProvider);
          _ref.invalidate(outletRevenueSummaryProvider);
          _ref.invalidate(outletAnalyticsProvider);
        }
      }
    } catch (e) {
      debugPrint('Outlet revenues sync error: $e');
    }
  }

  Future<void> _syncOutletExpenditures() async {
    const type = 'outlet-expenditures';
    try {
      final db = _ref.read(databaseProvider);
      final allOutlets = await db.getAllOutlets();
      final outletCodeMap = {for (final o in allOutlets) o.id: o.outletCode};
      final expenditures = await db.getAllOutletExpenditures();
      if (expenditures.isNotEmpty) {
        final records = expenditures.map((e) => {
          'id': e.id,
          'outlet_id': e.outletId,
          'outlet_code': outletCodeMap[e.outletId] ?? '',
          'date': e.date.toIso8601String(),
          'expense_type': e.expenseType,
          'amount': e.amount,
          'description': e.description,
          'reference': e.reference,
          'paid_to': e.paidTo,
          'status': e.status,
          'created_at': e.createdAt.toIso8601String(),
          'updated_at': e.updatedAt.toIso8601String(),
        }).toList();
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': records},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        for (final item in raw.whereType<Map<String, dynamic>>()) {
          await db.upsertOutletExpenditureFromMap(item);
        }
        if (raw.isNotEmpty) {
          _ref.invalidate(dashboardDataProvider);
          _ref.invalidate(outletRevenueSummaryProvider);
          _ref.invalidate(outletAnalyticsProvider);
        }
      }
    } catch (e) {
      debugPrint('Outlet expenditures sync error: $e');
    }
  }

  Future<void> _syncCommissionPayments() async {
    const type = 'commission-payments';
    try {
      final db = _ref.read(databaseProvider);
      final allOutlets = await db.getAllOutlets();
      final outletCodeMap = {for (final o in allOutlets) o.id: o.outletCode};
      final payments = await db.getAllCommissionPayments();
      if (payments.isNotEmpty) {
        final records = payments.map((c) => {
          'id': c.id,
          'outlet_id': c.outletId,
          'outlet_code': outletCodeMap[c.outletId] ?? '',
          'period_start': c.periodStart.toIso8601String(),
          'period_end': c.periodEnd.toIso8601String(),
          'total_revenue': c.totalRevenue,
          'commission_rate': c.commissionRate,
          'commission_amount': c.commissionAmount,
          'status': c.status,
          'paid_date': c.paidDate?.toIso8601String(),
          'payment_method': c.paymentMethod,
          'payment_reference': c.paymentReference,
          'notes': c.notes,
          'created_at': c.createdAt.toIso8601String(),
          'updated_at': c.updatedAt.toIso8601String(),
        }).toList();
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': records},
        );
      }
      // Pull
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        for (final item in raw.whereType<Map<String, dynamic>>()) {
          await db.upsertCommissionPaymentFromMap(item);
        }
        if (raw.isNotEmpty) {
          _ref.invalidate(dashboardDataProvider);
          _ref.invalidate(outletRevenueSummaryProvider);
          _ref.invalidate(outletAnalyticsProvider);
        }
      }
    } catch (e) {
      debugPrint('Commission payments sync error: $e');
    }
  }

  // ============================================================================
  // Accounting Entity Blob-Store Sync
  // These mirror the outlet-revenues pattern: push ALL local records to the
  // /client-data/{type} blob store on every sync cycle, then pull the server's
  // authoritative set back.  This guarantees data reaches the server even when
  // the REST queue push (→ proper DB tables) has not yet succeeded.
  // ============================================================================

  Future<void> _syncVendorsBlob() async {
    const type = 'vendors';
    try {
      final local = await _localStorage.loadVendors();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((v) => v.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(Vendor.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          await _localStorage.saveVendors(pulled);
          await _ref.read(vendorsProvider.notifier).loadVendors();
        }
      }
    } catch (e) {
      debugPrint('Vendors blob sync error: $e');
    }
  }

  Future<void> _syncCustomersBlob() async {
    const type = 'customers';
    try {
      final local = await _localStorage.loadCustomers();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((c) => c.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final pulled = raw
            .whereType<Map<String, dynamic>>()
            .map(Customer.fromJson)
            .toList();
        if (pulled.isNotEmpty) {
          await _localStorage.saveCustomers(pulled);
          await _ref.read(customersProvider.notifier).loadCustomers();
        }
      }
    } catch (e) {
      debugPrint('Customers blob sync error: $e');
    }
  }

  Future<void> _syncInvoicesBlob() async {
    const type = 'invoices';
    try {
      final local = await _localStorage.loadInvoices();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((i) => i.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final serverItems = raw
            .whereType<Map<String, dynamic>>()
            .map(Invoice.fromJson)
            .toList();
        final merged = _mergeById<Invoice>(
          local: local,
          server: serverItems,
          getId: (i) => i.id,
        );
        await _localStorage.saveInvoices(merged);
        await _ref.read(invoicesProvider.notifier).loadInvoices();
      }
    } catch (e) {
      debugPrint('Invoices blob sync error: $e');
    }
  }

  Future<void> _syncBillsBlob() async {
    const type = 'bills';
    try {
      final local = await _localStorage.loadBills();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((b) => b.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final serverItems = raw
            .whereType<Map<String, dynamic>>()
            .map(Bill.fromJson)
            .toList();
        final merged = _mergeById<Bill>(
          local: local,
          server: serverItems,
          getId: (b) => b.id,
        );
        await _localStorage.saveBills(merged);
        await _ref.read(billsProvider.notifier).loadBills();
      }
    } catch (e) {
      debugPrint('Bills blob sync error: $e');
    }
  }

  Future<void> _syncJournalEntriesBlob() async {
    const type = 'journal-entries';
    try {
      final local = await _localStorage.loadJournalEntries();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((j) => j.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final serverItems = raw
            .whereType<Map<String, dynamic>>()
            .map(JournalEntry.fromJson)
            .toList();
        // Map-based merge: start with all local journals, then overlay server
        // versions for matching IDs.  This guarantees the set never shrinks —
        // a local journal that was skipped by the server (e.g. empty id) or
        // that is not yet in the blob store is always preserved.
        final merged = _mergeById<JournalEntry>(
          local: local,
          server: serverItems,
          getId: (j) => j.id,
        );
        await _localStorage.saveJournalEntries(merged);
        await _ref.read(journalsProvider.notifier).loadJournals();
      }
    } catch (e) {
      debugPrint('Journal entries blob sync error: $e');
    }
  }

  Future<void> _syncCreditNotesBlob() async {
    const type = 'credit-notes';
    try {
      final local = await _localStorage.loadCreditNotes();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((n) => n.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final serverItems = raw
            .whereType<Map<String, dynamic>>()
            .map(CreditNote.fromJson)
            .toList();
        final merged = _mergeById<CreditNote>(
          local: local,
          server: serverItems,
          getId: (n) => n.id,
        );
        await _localStorage.saveCreditNotes(merged);
        _ref.read(creditNotesProvider.notifier).replaceAll(merged);
      }
    } catch (e) {
      debugPrint('Credit notes blob sync error: $e');
    }
  }

  Future<void> _syncDebitNotesBlob() async {
    const type = 'debit-notes';
    try {
      final local = await _localStorage.loadDebitNotes();
      if (local.isNotEmpty) {
        await _apiClient.post(
          '/client-data/$type',
          data: {'records': local.map((n) => n.toJson()).toList()},
        );
      }
      final resp = await _apiClient.get('/client-data/$type');
      if (resp.statusCode == 200) {
        final raw = (resp.data['data'] as List<dynamic>?) ?? [];
        final serverItems = raw
            .whereType<Map<String, dynamic>>()
            .map(DebitNote.fromJson)
            .toList();
        final merged = _mergeById<DebitNote>(
          local: local,
          server: serverItems,
          getId: (n) => n.id,
        );
        await _localStorage.saveDebitNotes(merged);
        _ref.read(debitNotesProvider.notifier).replaceAll(merged);
      }
    } catch (e) {
      debugPrint('Debit notes blob sync error: $e');
    }
  }

  // ============================================================================
  // Merge Helper
  // ============================================================================

  /// Merges [local] and [server] lists by ID, ensuring the result never
  /// shrinks below [local].  Server items overwrite local items for the same
  /// ID (server is authoritative for updates), while local-only items are
  /// always preserved (they may be pending push to the server).
  List<T> _mergeById<T>({
    required List<T> local,
    required List<T> server,
    required String Function(T) getId,
  }) {
    final map = {for (final item in local) getId(item): item};
    for (final item in server) {
      map[getId(item)] = item;
    }
    return map.values.toList();
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

      // Invalidate cached FutureProviders and StreamProviders so all screens
      // immediately reflect the cleared state without needing a restart.
      _ref.invalidate(dashboardDataProvider);
      _ref.invalidate(outletAnalyticsProvider);
      _ref.invalidate(outletRevenueSummaryProvider);
      _ref.invalidate(allOutletRevenuesProvider);
      _ref.invalidate(allOutletExpendituresProvider);
      // Reload core accounting StateNotifiers from now-empty JSON stores.
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
      } catch (_) {}
      // Reset StateNotifier-based local stores so their in-memory state
      // matches the now-empty disk — no restart required.
      try {
        _ref.read(localBankStatementsProvider.notifier).clearAll();
        _ref.read(assetDraftsProvider.notifier).clearAll();
        _ref.read(depreciationSchedulesProvider.notifier).clearAll();
        _ref.read(localAttachmentsProvider.notifier).clearAll();
        _ref.read(creditNotesProvider.notifier).clearAll();
        _ref.read(debitNotesProvider.notifier).clearAll();
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

      // Ask backend to wipe the tenant's data.
      // The controller requires confirmation: DELETE_ALL_MY_DATA to guard
      // against accidental calls.
      final response = await _apiClient.delete(
        '/me/data',
        data: {'confirmation': 'DELETE_ALL_MY_DATA'},
      );
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
