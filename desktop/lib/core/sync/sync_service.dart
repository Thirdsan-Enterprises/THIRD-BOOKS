import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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
  String? _deviceId;

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

  /// Returns the persistent device ID, creating one on first run.
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final appDir = await getApplicationDocumentsDirectory();
    final idFile = File(p.join(appDir.path, 'thirdbooks', 'device_id.txt'));

    if (await idFile.exists()) {
      final saved = (await idFile.readAsString()).trim();
      if (saved.isNotEmpty) {
        _deviceId = saved;
        return _deviceId!;
      }
    }

    const uuid = Uuid();
    _deviceId = uuid.v4();
    await idFile.parent.create(recursive: true);
    await idFile.writeAsString(_deviceId!);
    return _deviceId!;
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
      final deviceId = await getDeviceId();
      final pendingEvents = await _db.getPendingSyncEvents();

      // Map local SyncEvents to the server event-sourcing format.
      final eventsToSync = pendingEvents.map((e) {
        final action = e.action;
        final suffix = switch (action) {
          'create' => 'created',
          'update' => 'updated',
          'delete' => 'deleted',
          _ => action,
        };
        return {
          'aggregate_type': e.entityType,
          'aggregate_id': e.entityId,
          'event_type': '${e.entityType}.$suffix',
          'event_data': jsonDecode(e.payload) as Map<String, dynamic>,
          'occurred_at': e.createdAt.toIso8601String(),
        };
      }).toList();

      // POST /api/sync — bidirectional
      final response = await _api.sync(
        deviceId: deviceId,
        afterSequence: state.lastSyncedSequence ?? 0,
        events: eventsToSync,
      );

      // Response shape: { success: true, data: { pushed: {...}, pulled: { events: [...], last_sequence: N } } }
      final responseData = response['data'] as Map<String, dynamic>? ?? {};
      final pulledData = responseData['pulled'] as Map<String, dynamic>? ?? {};
      final serverEvents = pulledData['events'] as List<dynamic>? ?? [];
      final newSequence =
          pulledData['last_sequence'] as int? ?? state.lastSyncedSequence ?? 0;

      // Apply each pulled event to the local SQLite database.
      for (final event in serverEvents) {
        try {
          await _applyServerEvent(event as Map<String, dynamic>);
        } catch (_) {
          // Skip bad events; don't abort the whole sync.
        }
      }

      // Mark local events as synced now that server has acknowledged them.
      if (pendingEvents.isNotEmpty) {
        await _db.markSyncEventsSynced(pendingEvents.map((e) => e.id).toList());
      }

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

  // ---------------------------------------------------------------------------
  // Event application — server → local SQLite
  // ---------------------------------------------------------------------------

  Future<void> _applyServerEvent(Map<String, dynamic> event) async {
    final aggregateType = event['aggregate_type'] as String? ?? '';
    final eventType = event['event_type'] as String? ?? '';
    final eventData = (event['event_data'] as Map<String, dynamic>? ?? {});
    final sequenceNumber = event['sequence_number'] as int?;

    // Inject sequence_number so downstream helpers can store it as syncSequence.
    final data = Map<String, dynamic>.from(eventData)
      ..['_seq'] = sequenceNumber;

    // Extract action suffix: "invoice.created" → "created"
    final action = eventType.contains('.')
        ? eventType.substring(eventType.lastIndexOf('.') + 1)
        : eventType;

    switch (aggregateType) {
      case 'account':
        await _applyAccountChange(action, data);
        break;
      case 'customer':
        await _applyCustomerChange(action, data);
        break;
      case 'vendor':
        await _applyVendorChange(action, data);
        break;
      case 'invoice':
        await _applyInvoiceChange(action, data);
        break;
      case 'bill':
        await _applyBillChange(action, data);
        break;
      case 'journal_entry':
        await _applyJournalEntryChange(action, data);
        break;
      case 'asset':
      case 'asset_register':
        await _applyAssetChange(action, data);
        break;
      case 'payment':
        await _applyPaymentChange(action, data);
        break;
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _applyAccountChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        await _db.into(_db.accounts).insertOnConflictUpdate(
              AccountsCompanion.insert(
                id: data['id'] as String,
                code: data['code'] as String? ?? '',
                name: data['name'] as String? ?? '',
                description: Value(data['description'] as String?),
                type: data['type'] as String? ?? 'asset',
                subType: Value(data['sub_type'] as String?),
                parentId: Value(data['parent_id'] as String?),
                currencyCode: Value(
                    data['currency_code'] as String? ??
                        (data['currency'] as Map?)?['code'] as String? ??
                        'UGX'),
                balance: Value(
                    (data['balance'] as num?)?.toDouble() ?? 0.0),
                isActive: Value(data['is_active'] as bool? ?? true),
                isSystemAccount:
                    Value(data['is_system_account'] as bool? ?? false),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );
        break;
      case 'deleted':
        await _db.deleteAccount(data['id'] as String);
        break;
    }
  }

  Future<void> _applyCustomerChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        await _db.into(_db.customers).insertOnConflictUpdate(
              CustomersCompanion.insert(
                id: data['id'] as String,
                name: data['name'] as String? ?? '',
                email: Value(data['email'] as String?),
                phone: Value(data['phone'] as String?),
                address: Value(data['address'] as String?),
                taxId: Value(data['tax_id'] as String?),
                creditLimit: Value(
                    (data['credit_limit'] as num?)?.toDouble() ?? 0.0),
                balance: Value(
                    (data['balance'] as num?)?.toDouble() ?? 0.0),
                currencyCode: Value(data['currency_code'] as String? ?? 'UGX'),
                paymentTerms: Value(data['payment_terms'] as String?),
                isActive: Value(data['is_active'] as bool? ?? true),
                notes: Value(data['notes'] as String?),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );
        break;
      case 'deleted':
        await (_db.delete(_db.customers)
              ..where((c) => c.id.equals(data['id'] as String)))
            .go();
        break;
    }
  }

  Future<void> _applyVendorChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        await _db.into(_db.vendors).insertOnConflictUpdate(
              VendorsCompanion.insert(
                id: data['id'] as String,
                name: data['name'] as String? ?? '',
                email: Value(data['email'] as String?),
                phone: Value(data['phone'] as String?),
                address: Value(data['address'] as String?),
                taxId: Value(data['tax_id'] as String?),
                balance: Value(
                    (data['balance'] as num?)?.toDouble() ?? 0.0),
                currencyCode: Value(data['currency_code'] as String? ?? 'UGX'),
                paymentTerms: Value(data['payment_terms'] as String?),
                isActive: Value(data['is_active'] as bool? ?? true),
                notes: Value(data['notes'] as String?),
                bankName: Value(data['bank_name'] as String?),
                bankAccountNumber:
                    Value(data['bank_account_number'] as String?),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );
        break;
      case 'deleted':
        await (_db.delete(_db.vendors)
              ..where((v) => v.id.equals(data['id'] as String)))
            .go();
        break;
    }
  }

  Future<void> _applyInvoiceChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        final customerId = data['customer_id'] as String? ?? '';
        // Ensure a customer stub exists so FK doesn't block the insert.
        if (customerId.isNotEmpty) {
          final existing = await _db.getCustomerById(customerId);
          if (existing == null) {
            final customerData =
                data['customer'] as Map<String, dynamic>? ?? {};
            await _db.into(_db.customers).insertOnConflictUpdate(
                  CustomersCompanion.insert(
                    id: customerId,
                    name: customerData['name'] as String? ?? 'Unknown',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
          }
        }

        await _db.into(_db.invoices).insertOnConflictUpdate(
              InvoicesCompanion.insert(
                id: data['id'] as String,
                invoiceNumber: data['invoice_number'] as String? ?? '',
                customerId: customerId,
                date: _parseDate(data['date']) ?? DateTime.now(),
                dueDate: _parseDate(data['due_date']) ??
                    (_parseDate(data['date']) ?? DateTime.now())
                        .add(const Duration(days: 30)),
                subtotal: Value(
                    (data['subtotal'] as num?)?.toDouble() ?? 0.0),
                taxAmount: Value(
                    (data['tax_amount'] as num?)?.toDouble() ?? 0.0),
                total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
                amountPaid: Value(
                    (data['paid_amount'] as num?)?.toDouble() ??
                        (data['amount_paid'] as num?)?.toDouble() ??
                        0.0),
                status: Value(data['status'] as String? ?? 'draft'),
                currencyCode: Value(
                    (data['currency'] as Map?)?['code'] as String? ??
                        data['currency_code'] as String? ??
                        'UGX'),
                notes: Value(data['notes'] as String?),
                terms: Value(data['terms'] as String?),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );

        // Upsert invoice lines.
        final lines = data['lines'] as List<dynamic>?;
        if (lines != null) {
          for (final line in lines) {
            final l = line as Map<String, dynamic>;
            await _db.into(_db.invoiceLines).insertOnConflictUpdate(
                  InvoiceLinesCompanion.insert(
                    id: l['id'] as String,
                    invoiceId: data['id'] as String,
                    description: l['description'] as String? ?? '',
                    quantity:
                        Value((l['quantity'] as num?)?.toDouble() ?? 1.0),
                    unitPrice:
                        Value((l['unit_price'] as num?)?.toDouble() ?? 0.0),
                    taxRate:
                        Value((l['tax_rate'] as num?)?.toDouble() ?? 0.0),
                    taxAmount:
                        Value((l['tax_amount'] as num?)?.toDouble() ?? 0.0),
                    amount: Value((l['amount'] as num?)?.toDouble() ?? 0.0),
                    accountId: Value(l['account_id'] as String?),
                  ),
                );
          }
        }
        break;

      case 'deleted':
        await (_db.delete(_db.invoiceLines)
              ..where((l) => l.invoiceId.equals(data['id'] as String)))
            .go();
        await (_db.delete(_db.invoices)
              ..where((i) => i.id.equals(data['id'] as String)))
            .go();
        break;
    }
  }

  Future<void> _applyBillChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        final vendorId = data['vendor_id'] as String? ?? '';
        // Ensure a vendor stub exists so FK doesn't block the insert.
        if (vendorId.isNotEmpty) {
          final existing = await _db.getVendorById(vendorId);
          if (existing == null) {
            final vendorData = data['vendor'] as Map<String, dynamic>? ?? {};
            await _db.into(_db.vendors).insertOnConflictUpdate(
                  VendorsCompanion.insert(
                    id: vendorId,
                    name: vendorData['name'] as String? ?? 'Unknown',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
          }
        }

        await _db.into(_db.bills).insertOnConflictUpdate(
              BillsCompanion.insert(
                id: data['id'] as String,
                billNumber: data['bill_number'] as String? ?? '',
                vendorId: vendorId,
                date: _parseDate(data['date']) ?? DateTime.now(),
                dueDate: _parseDate(data['due_date']) ??
                    (_parseDate(data['date']) ?? DateTime.now())
                        .add(const Duration(days: 30)),
                subtotal: Value(
                    (data['subtotal'] as num?)?.toDouble() ?? 0.0),
                taxAmount: Value(
                    (data['tax_amount'] as num?)?.toDouble() ?? 0.0),
                total: Value((data['total'] as num?)?.toDouble() ?? 0.0),
                amountPaid: Value(
                    (data['paid_amount'] as num?)?.toDouble() ??
                        (data['amount_paid'] as num?)?.toDouble() ??
                        0.0),
                status: Value(data['status'] as String? ?? 'draft'),
                currencyCode: Value(
                    (data['currency'] as Map?)?['code'] as String? ??
                        data['currency_code'] as String? ??
                        'UGX'),
                notes: Value(data['notes'] as String?),
                reference: Value(data['reference'] as String?),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );

        // Upsert bill lines.
        final lines = data['lines'] as List<dynamic>?;
        if (lines != null) {
          for (final line in lines) {
            final l = line as Map<String, dynamic>;
            final accountId = l['account_id'] as String?;
            if (accountId == null) continue;
            await _db.into(_db.billLines).insertOnConflictUpdate(
                  BillLinesCompanion.insert(
                    id: l['id'] as String,
                    billId: data['id'] as String,
                    accountId: accountId,
                    description: l['description'] as String? ?? '',
                    amount: Value((l['amount'] as num?)?.toDouble() ?? 0.0),
                    taxRate:
                        Value((l['tax_rate'] as num?)?.toDouble() ?? 0.0),
                    taxAmount:
                        Value((l['tax_amount'] as num?)?.toDouble() ?? 0.0),
                  ),
                );
          }
        }
        break;

      case 'deleted':
        await (_db.delete(_db.billLines)
              ..where((l) => l.billId.equals(data['id'] as String)))
            .go();
        await (_db.delete(_db.bills)
              ..where((b) => b.id.equals(data['id'] as String)))
            .go();
        break;
    }
  }

  Future<void> _applyJournalEntryChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        await _db.into(_db.journalEntries).insertOnConflictUpdate(
              JournalEntriesCompanion.insert(
                id: data['id'] as String,
                entryNumber: data['entry_number'] as String? ?? '',
                date: _parseDate(data['date']) ?? DateTime.now(),
                description: data['description'] as String? ?? '',
                reference: Value(data['reference'] as String?),
                status: Value(data['status'] as String? ?? 'draft'),
                notes: Value(data['notes'] as String?),
                createdBy: Value(data['created_by'] as String?),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );

        // Upsert journal lines.  When the server sends a lines array we treat
        // it as the authoritative set: delete any stale local lines first, then
        // insert the server-provided ones.  This mirrors the server's own
        // delete-then-recreate approach in materializeJournalEntry() and
        // prevents phantom lines from persisting after a sync.
        // Line IDs from the server may be integers (auto-increment) — always
        // call .toString() so they can be stored in the TEXT primary-key column.
        final lines = data['lines'] as List<dynamic>?;
        if (lines != null) {
          await (_db.delete(_db.journalLines)
                ..where((l) => l.journalEntryId.equals(data['id'] as String)))
              .go();
          for (final line in lines) {
            final l = line as Map<String, dynamic>;
            final accountId = l['account_id'] as String?;
            if (accountId == null) continue;
            final lineId = (l['id'] ?? '').toString();
            if (lineId.isEmpty) continue;
            await _db.into(_db.journalLines).insertOnConflictUpdate(
                  JournalLinesCompanion.insert(
                    id: lineId,
                    journalEntryId: data['id'] as String,
                    accountId: accountId,
                    debit: Value((l['debit'] as num?)?.toDouble() ?? 0.0),
                    credit: Value((l['credit'] as num?)?.toDouble() ?? 0.0),
                    description: Value(l['description'] as String?),
                  ),
                );
          }
        }
        break;

      case 'deleted':
        await (_db.delete(_db.journalLines)
              ..where((l) =>
                  l.journalEntryId.equals(data['id'] as String)))
            .go();
        await (_db.delete(_db.journalEntries)
              ..where((je) => je.id.equals(data['id'] as String)))
            .go();
        break;
    }
  }

  Future<void> _applyAssetChange(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'created':
      case 'updated':
        final cost = (data['cost'] as num?)?.toDouble() ?? 0.0;
        final bookValue =
            (data['current_book_value'] as num?)?.toDouble() ?? cost;
        final accumulated = (cost - bookValue).clamp(0.0, double.infinity);

        await _db.into(_db.assets).insertOnConflictUpdate(
              AssetsCompanion.insert(
                id: data['id'] as String,
                // Use id as fallback code — backend AssetRegister has no separate code field.
                assetCode: data['asset_code'] as String? ??
                    data['id'] as String,
                name: data['name'] as String? ?? 'Asset',
                description: Value(data['description'] as String?),
                category: data['category'] as String? ?? 'Equipment',
                purchasePrice: Value(cost),
                currentValue: Value(bookValue),
                accumulatedDepreciation: Value(accumulated),
                purchaseDate:
                    _parseDate(data['acquisition_date']) ?? DateTime.now(),
                supplier: Value(
                    (data['vendor'] as Map?)?['name'] as String?),
                isActive: Value(data['status'] as String? == 'active'),
                notes: Value(data['description'] as String?),
                createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
                updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
                syncSequence: Value(data['_seq'] as int?),
              ),
            );
        break;

      case 'deleted':
      case 'disposed':
        await (_db.delete(_db.assets)
              ..where((a) => a.id.equals(data['id'] as String)))
            .go();
        break;
    }
  }

  Future<void> _applyPaymentChange(
      String action, Map<String, dynamic> data) async {
    // Payments are reflected on the desktop by updating the parent invoice/bill
    // amountPaid and status. There is no standalone Payments table in the
    // desktop schema.
    if (action != 'created') return;

    final invoiceId = data['invoice_id'] as String?;
    final billId = data['bill_id'] as String?;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

    if (invoiceId != null) {
      final invoice = await (_db.select(_db.invoices)
            ..where((i) => i.id.equals(invoiceId)))
          .getSingleOrNull();
      if (invoice != null) {
        final newPaid = invoice.amountPaid + amount;
        final newStatus =
            newPaid >= invoice.total ? 'paid' : 'partial';
        await (_db.update(_db.invoices)
              ..where((i) => i.id.equals(invoiceId)))
            .write(InvoicesCompanion(
          amountPaid: Value(newPaid),
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }

    if (billId != null) {
      final bill = await (_db.select(_db.bills)
            ..where((b) => b.id.equals(billId)))
          .getSingleOrNull();
      if (bill != null) {
        final newPaid = bill.amountPaid + amount;
        final newStatus = newPaid >= bill.total ? 'paid' : 'partial';
        await (_db.update(_db.bills)
              ..where((b) => b.id.equals(billId)))
            .write(BillsCompanion(
          amountPaid: Value(newPaid),
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Local change recording (called by feature notifiers before/after API calls)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
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

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(apiClientProvider);
  return SyncService(db, api);
});
