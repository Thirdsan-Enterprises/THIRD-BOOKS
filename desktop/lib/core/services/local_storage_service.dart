import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/customer.dart';
import '../models/vendor.dart';
import '../models/invoice.dart';
import '../models/bill.dart';
import '../models/journal_entry.dart';
import '../models/payment.dart';
import '../models/bank_transaction.dart';
import '../models/credit_debit_note.dart';

// ============================================================================
// Local Storage Service - Persists data to local filesystem
// ============================================================================

class LocalStorageService {
  static LocalStorageService? _instance;
  late Directory _dataDir;
  bool _initialized = false;

  LocalStorageService._();

  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory('${appDir.path}/thirdbooks_data');

    if (!await _dataDir.exists()) {
      await _dataDir.create(recursive: true);
    }

    _initialized = true;
  }

  File _getFile(String name) {
    return File('${_dataDir.path}/$name.json');
  }

  // ============================================================================
  // Generic Save/Load Methods
  // ============================================================================

  Future<void> saveData<T>(String key, List<T> items, Map<String, dynamic> Function(T) toJson) async {
    await initialize();
    final file = _getFile(key);
    final jsonList = items.map((item) => toJson(item)).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<List<T>> loadData<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    await initialize();
    final file = _getFile(key);

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList.map((json) => fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading $key: $e');
      return [];
    }
  }

  // ============================================================================
  // Specific Entity Methods
  // ============================================================================

  Future<void> saveAccounts(List<Account> accounts) async {
    await saveData('accounts', accounts, (a) => a.toJson());
  }

  Future<List<Account>> loadAccounts() async {
    return loadData('accounts', Account.fromJson);
  }

  Future<void> saveCustomers(List<Customer> customers) async {
    await saveData('customers', customers, (c) => c.toJson());
  }

  Future<List<Customer>> loadCustomers() async {
    return loadData('customers', Customer.fromJson);
  }

  Future<void> saveVendors(List<Vendor> vendors) async {
    await saveData('vendors', vendors, (v) => v.toJson());
  }

  Future<List<Vendor>> loadVendors() async {
    return loadData('vendors', Vendor.fromJson);
  }

  Future<void> saveInvoices(List<Invoice> invoices) async {
    await saveData('invoices', invoices, (i) => i.toJson());
  }

  Future<List<Invoice>> loadInvoices() async {
    return loadData('invoices', Invoice.fromJson);
  }

  Future<void> saveBills(List<Bill> bills) async {
    await saveData('bills', bills, (b) => b.toJson());
  }

  Future<List<Bill>> loadBills() async {
    return loadData('bills', Bill.fromJson);
  }

  Future<void> saveJournalEntries(List<JournalEntry> entries) async {
    await saveData('journals', entries, (e) => e.toJson());
  }

  Future<List<JournalEntry>> loadJournalEntries() async {
    return loadData('journals', JournalEntry.fromJson);
  }

  Future<void> savePayments(List<Payment> payments) async {
    await saveData('payments', payments, (p) => p.toJson());
  }

  Future<List<Payment>> loadPayments() async {
    return loadData('payments', Payment.fromJson);
  }

  Future<void> saveBankTransactions(List<BankTransaction> txns) async {
    await saveData('bank_transactions', txns, (t) => t.toJson());
  }

  Future<List<BankTransaction>> loadBankTransactions() async {
    return loadData('bank_transactions', BankTransaction.fromJson);
  }

  Future<void> saveOutletSettlements(List<OutletSettlement> settlements) async {
    await saveData('outlet_settlements', settlements, (s) => s.toJson());
  }

  Future<List<OutletSettlement>> loadOutletSettlements() async {
    return loadData('outlet_settlements', OutletSettlement.fromJson);
  }

  Future<void> saveCreditNotes(List<CreditNote> notes) async {
    await saveData('credit_notes', notes, (n) => n.toJson());
  }

  Future<List<CreditNote>> loadCreditNotes() async {
    return loadData('credit_notes', CreditNote.fromJson);
  }

  Future<void> saveDebitNotes(List<DebitNote> notes) async {
    await saveData('debit_notes', notes, (n) => n.toJson());
  }

  Future<List<DebitNote>> loadDebitNotes() async {
    return loadData('debit_notes', DebitNote.fromJson);
  }

  // ============================================================================
  // Sync Queue Management
  // ============================================================================

  Future<void> addToSyncQueue(SyncQueueItem item) async {
    await initialize();
    final queue = await loadSyncQueue();
    queue.add(item);
    await _saveSyncQueue(queue);
  }

  Future<List<SyncQueueItem>> loadSyncQueue() async {
    await initialize();
    final file = _getFile('sync_queue');

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList.map((json) => SyncQueueItem.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
      return [];
    }
  }

  Future<void> _saveSyncQueue(List<SyncQueueItem> queue) async {
    final file = _getFile('sync_queue');
    final jsonList = queue.map((item) => item.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<void> removeFromSyncQueue(String itemId) async {
    final queue = await loadSyncQueue();
    queue.removeWhere((item) => item.id == itemId);
    await _saveSyncQueue(queue);
  }

  Future<void> clearSyncQueue() async {
    final file = _getFile('sync_queue');
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ============================================================================
  // Last Sync Timestamp
  // ============================================================================

  Future<void> setLastSyncTime(DateTime time) async {
    await initialize();
    final file = _getFile('last_sync');
    await file.writeAsString(time.toIso8601String());
  }

  Future<DateTime?> getLastSyncTime() async {
    await initialize();
    final file = _getFile('last_sync');

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      return DateTime.parse(content);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // Clear All Data
  // ============================================================================

  Future<void> clearAllData() async {
    await initialize();
    if (await _dataDir.exists()) {
      await _dataDir.delete(recursive: true);
      await _dataDir.create(recursive: true);
    }
  }
}

// ============================================================================
// Sync Queue Item Model
// ============================================================================

enum SyncAction { create, update, delete }
enum SyncEntityType { account, customer, vendor, invoice, bill, journalEntry, payment }

class SyncQueueItem {
  final String id;
  final SyncAction action;
  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final int retryCount;

  SyncQueueItem({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      action: SyncAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => SyncAction.create,
      ),
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == json['entity_type'],
        orElse: () => SyncEntityType.account,
      ),
      entityId: json['entity_id'] as String,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'entity_type': entityType.name,
      'entity_id': entityId,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  SyncQueueItem copyWith({
    String? id,
    SyncAction? action,
    SyncEntityType? entityType,
    String? entityId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

// ============================================================================
// Provider
// ============================================================================

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService.instance;
});
