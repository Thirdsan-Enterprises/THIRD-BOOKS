// Snapshot Service — ThirdBooks Desktop
// Creates named restore points so accountants can roll back to a known-good
// state after a mistake. Snapshots live in Documents/thirdbooks_snapshots/
// as individual JSON files (same schema as .thirdbooks backup files).
// Auto-purges oldest beyond the 20-snapshot cap.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'local_storage_service.dart';
import '../database/app_database.dart' show AppDatabase;
import '../models/account.dart';
import '../models/customer.dart';
import '../models/vendor.dart';
import '../models/invoice.dart';
import '../models/bill.dart';
import '../models/journal_entry.dart';
import '../models/payment.dart';
import '../models/bank_transaction.dart';
import '../models/credit_debit_note.dart';
import '../providers/asset_drafts_provider.dart' show AssetDraft;
import '../providers/local_bank_statements_provider.dart' show LocalBankStatement;
import '../providers/depreciation_schedules_provider.dart' show DepreciationSchedule;
import '../providers/local_attachments_provider.dart' show LocalAttachment;
import 'data_service.dart' show databaseProvider;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class SnapshotMeta {
  final String id;
  final String label;
  final DateTime createdAt;
  final Map<String, int> counts;

  const SnapshotMeta({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.counts,
  });

  int get totalRecords => counts.values.fold(0, (s, c) => s + c);

  factory SnapshotMeta.fromJson(Map<String, dynamic> j) => SnapshotMeta(
        id: j['snapshot_id'] as String,
        label: j['label'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        counts: (j['counts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class SnapshotService {
  static const _version = '1.0';
  static const _maxSnapshots = 20;
  static const _storage = FlutterSecureStorage();
  static const _lastAutoSnapshotKey = 'last_auto_snapshot_date';

  final LocalStorageService _ls;
  final AppDatabase _db;

  SnapshotService(this._ls, this._db);

  Future<Directory> _snapshotsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/thirdbooks_snapshots');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<SnapshotMeta> createSnapshot(String label) async {
    await _ls.initialize();

    final accounts       = await _ls.loadAccounts();
    final customers      = await _ls.loadCustomers();
    final vendors        = await _ls.loadVendors();
    final invoices       = await _ls.loadInvoices();
    final bills          = await _ls.loadBills();
    final journals       = await _ls.loadJournalEntries();
    final payments       = await _ls.loadPayments();
    final bankTxns       = await _ls.loadBankTransactions();
    final settlements    = await _ls.loadOutletSettlements();
    final creditNotes    = await _ls.loadCreditNotes();
    final debitNotes     = await _ls.loadDebitNotes();
    final bankStatements = await _ls.loadData('local_bank_statements', LocalBankStatement.fromJson);
    final assetDrafts    = await _ls.loadData('asset_drafts', AssetDraft.fromJson);
    final deprSchedules  = await _ls.loadData('depreciation_schedules', DepreciationSchedule.fromJson);
    final attachments    = await _ls.loadData('local_attachments', LocalAttachment.fromJson);

    final dbOutlets     = await _db.getAllOutlets();
    final dbRevenues    = await _db.getAllOutletRevenues();
    final dbExpend      = await _db.getAllOutletExpenditures();
    final dbCommissions = await _db.getAllCommissionPayments();
    final dbAssets      = await _db.getAllAssets();
    final dbAssetDepr   = await _db.getAllAssetDepreciationSchedules();
    final dbDeprEntries = await _db.getAllDepreciationEntries();

    final outletCodeMap = {for (final o in dbOutlets) o.id: o.outletCode};
    final now = DateTime.now();
    final id = DateFormat('yyyyMMdd_HHmmss').format(now);

    final counts = {
      'accounts':              accounts.length,
      'customers':             customers.length,
      'vendors':               vendors.length,
      'invoices':              invoices.length,
      'bills':                 bills.length,
      'journals':              journals.length,
      'payments':              payments.length,
      'bank_transactions':     bankTxns.length,
      'outlet_settlements':    settlements.length,
      'credit_notes':          creditNotes.length,
      'debit_notes':           debitNotes.length,
      'local_bank_statements': bankStatements.length,
      'asset_drafts':          assetDrafts.length,
      'depreciation_schedules': deprSchedules.length,
      'local_attachments':     attachments.length,
      'outlets':               dbOutlets.length,
      'outlet_revenues':       dbRevenues.length,
      'outlet_expenditures':   dbExpend.length,
      'commission_payments':   dbCommissions.length,
      'assets':                dbAssets.length,
      'asset_depreciation':    dbAssetDepr.length,
      'depreciation_entries':  dbDeprEntries.length,
    };

    final payload = {
      'version':     _version,
      'snapshot_id': id,
      'label':       label,
      'created_at':  now.toIso8601String(),
      'counts':      counts,
      'data': {
        'accounts':              accounts.map((e) => e.toJson()).toList(),
        'customers':             customers.map((e) => e.toJson()).toList(),
        'vendors':               vendors.map((e) => e.toJson()).toList(),
        'invoices':              invoices.map((e) => e.toJson()).toList(),
        'bills':                 bills.map((e) => e.toJson()).toList(),
        'journals':              journals.map((e) => e.toJson()).toList(),
        'payments':              payments.map((e) => e.toJson()).toList(),
        'bank_transactions':     bankTxns.map((e) => e.toJson()).toList(),
        'outlet_settlements':    settlements.map((e) => e.toJson()).toList(),
        'credit_notes':          creditNotes.map((e) => e.toJson()).toList(),
        'debit_notes':           debitNotes.map((e) => e.toJson()).toList(),
        'local_bank_statements': bankStatements.map((e) => e.toJson()).toList(),
        'asset_drafts':          assetDrafts.map((e) => e.toJson()).toList(),
        'depreciation_schedules': deprSchedules.map((e) => e.toJson()).toList(),
        'local_attachments':     attachments.map((e) => e.toJson()).toList(),
        'outlets': dbOutlets.map((o) => {
          'id':             o.id,
          'outlet_code':    o.outletCode,
          'name':           o.name,
          'address':        o.address,
          'city':           o.city,
          'postal_code':    o.postalCode,
          'region':         o.region,
          'venue_type':     o.venueType,
          'owner_name':     o.ownerName,
          'owner_contact':  o.ownerContact,
          'commission_rate': o.commissionRate,
          'is_active':      o.isActive,
          'notes':          o.notes,
          'created_at':     o.createdAt.toIso8601String(),
          'updated_at':     o.updatedAt.toIso8601String(),
        }).toList(),
        'outlet_revenues': dbRevenues.map((r) => {
          'id':                r.id,
          'outlet_id':         r.outletId,
          'outlet_code':       outletCodeMap[r.outletId] ?? '',
          'date':              r.date.toIso8601String(),
          'amount':            r.amount,
          'commission_amount': r.commissionAmount,
          'net_amount':        r.netAmount,
          'description':       r.description,
          'reference':         r.reference,
          'status':            r.status,
          'created_at':        r.createdAt.toIso8601String(),
          'updated_at':        r.updatedAt.toIso8601String(),
        }).toList(),
        'outlet_expenditures': dbExpend.map((e) => {
          'id':           e.id,
          'outlet_id':    e.outletId,
          'outlet_code':  outletCodeMap[e.outletId] ?? '',
          'date':         e.date.toIso8601String(),
          'expense_type': e.expenseType,
          'amount':       e.amount,
          'description':  e.description,
          'reference':    e.reference,
          'paid_to':      e.paidTo,
          'status':       e.status,
          'created_at':   e.createdAt.toIso8601String(),
          'updated_at':   e.updatedAt.toIso8601String(),
        }).toList(),
        'commission_payments': dbCommissions.map((c) => {
          'id':                c.id,
          'outlet_id':         c.outletId,
          'outlet_code':       outletCodeMap[c.outletId] ?? '',
          'period_start':      c.periodStart.toIso8601String(),
          'period_end':        c.periodEnd.toIso8601String(),
          'total_revenue':     c.totalRevenue,
          'commission_rate':   c.commissionRate,
          'commission_amount': c.commissionAmount,
          'status':            c.status,
          'paid_date':         c.paidDate?.toIso8601String(),
          'payment_method':    c.paymentMethod,
          'payment_reference': c.paymentReference,
          'notes':             c.notes,
          'created_at':        c.createdAt.toIso8601String(),
          'updated_at':        c.updatedAt.toIso8601String(),
        }).toList(),
        'assets': dbAssets.map((a) => {
          'id':                       a.id,
          'asset_code':               a.assetCode,
          'name':                     a.name,
          'description':              a.description,
          'category':                 a.category,
          'purchase_price':           a.purchasePrice,
          'current_value':            a.currentValue,
          'accumulated_depreciation': a.accumulatedDepreciation,
          'purchase_date':            a.purchaseDate.toIso8601String(),
          'supplier':                 a.supplier,
          'location':                 a.location,
          'outlet_id':                a.outletId,
          'is_active':                a.isActive,
          'notes':                    a.notes,
          'created_at':               a.createdAt.toIso8601String(),
          'updated_at':               a.updatedAt.toIso8601String(),
        }).toList(),
        'asset_depreciation': dbAssetDepr.map((d) => {
          'id':         d.id,
          'asset_id':   d.assetId,
          'method':     d.method,
          'rate':       d.rate,
          'period':     d.period,
          'start_date': d.startDate.toIso8601String(),
          'end_date':   d.endDate?.toIso8601String(),
          'is_active':  d.isActive,
          'notes':      d.notes,
          'created_at': d.createdAt.toIso8601String(),
          'updated_at': d.updatedAt.toIso8601String(),
        }).toList(),
        'depreciation_entries': dbDeprEntries.map((e) => {
          'id':                    e.id,
          'asset_id':              e.assetId,
          'asset_depreciation_id': e.assetDepreciationId,
          'journal_entry_id':      e.journalEntryId,
          'date':                  e.date.toIso8601String(),
          'depreciation_amount':   e.depreciationAmount,
          'book_value_before':     e.bookValueBefore,
          'book_value_after':      e.bookValueAfter,
          'status':                e.status,
          'notes':                 e.notes,
          'created_at':            e.createdAt.toIso8601String(),
        }).toList(),
      },
    };

    final dir = await _snapshotsDir();
    final safeLabel = label
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final filename = '${id}_$safeLabel.snapshot.json';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    await _autoPurge(dir);

    return SnapshotMeta(id: id, label: label, createdAt: now, counts: counts);
  }

  // ── List ─────────────────────────────────────────────────────────────────────

  Future<List<SnapshotMeta>> listSnapshots() async {
    final dir = await _snapshotsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.snapshot.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first

    final metas = <SnapshotMeta>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        metas.add(SnapshotMeta.fromJson(json));
      } catch (_) {
        // skip corrupt files
      }
    }
    return metas;
  }

  // ── Restore ──────────────────────────────────────────────────────────────────

  Future<void> restoreSnapshot(String snapshotId) async {
    final dir = await _snapshotsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(snapshotId) && f.path.endsWith('.snapshot.json'))
        .toList();

    if (files.isEmpty) throw Exception('Snapshot $snapshotId not found');

    final content = await files.first.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;

    Future<void> restore<T>(String key, T Function(Map<String, dynamic>) from,
        Future<void> Function(List<T>) save) async {
      final raw = data[key] as List? ?? [];
      final items = raw.map((e) => from(e as Map<String, dynamic>)).toList();
      await save(items);
    }

    await restore('accounts',    Account.fromJson,          _ls.saveAccounts);
    await restore('customers',   Customer.fromJson,         _ls.saveCustomers);
    await restore('vendors',     Vendor.fromJson,           _ls.saveVendors);
    await restore('invoices',    Invoice.fromJson,          _ls.saveInvoices);
    await restore('bills',       Bill.fromJson,             _ls.saveBills);
    await restore('journals',    JournalEntry.fromJson,     _ls.saveJournalEntries);
    await restore('payments',    Payment.fromJson,          _ls.savePayments);
    await restore('bank_transactions', BankTransaction.fromJson, _ls.saveBankTransactions);
    await restore('outlet_settlements', OutletSettlement.fromJson, _ls.saveOutletSettlements);
    await restore('credit_notes', CreditNote.fromJson,      _ls.saveCreditNotes);
    await restore('debit_notes',  DebitNote.fromJson,       _ls.saveDebitNotes);
    await restore('local_bank_statements', LocalBankStatement.fromJson,
        (items) => _ls.saveData('local_bank_statements', items, (s) => s.toJson()));
    await restore('asset_drafts', AssetDraft.fromJson,
        (items) => _ls.saveData('asset_drafts', items, (a) => a.toJson()));
    await restore('depreciation_schedules', DepreciationSchedule.fromJson,
        (items) => _ls.saveData('depreciation_schedules', items, (s) => s.toJson()));
    await restore('local_attachments', LocalAttachment.fromJson,
        (items) => _ls.saveData('local_attachments', items, (a) => a.toJson()));

    final rawRevenues = data['outlet_revenues'] as List? ?? [];
    for (final item in rawRevenues.whereType<Map<String, dynamic>>()) {
      await _db.upsertOutletRevenueFromMap(item);
    }

    final rawExpend = data['outlet_expenditures'] as List? ?? [];
    for (final item in rawExpend.whereType<Map<String, dynamic>>()) {
      await _db.upsertOutletExpenditureFromMap(item);
    }

    final rawCommissions = data['commission_payments'] as List? ?? [];
    for (final item in rawCommissions.whereType<Map<String, dynamic>>()) {
      await _db.upsertCommissionPaymentFromMap(item);
    }

    final rawAssets = data['assets'] as List? ?? [];
    for (final item in rawAssets.whereType<Map<String, dynamic>>()) {
      await _db.upsertAssetFromMap(item);
    }

    final rawAssetDepr = data['asset_depreciation'] as List? ?? [];
    for (final item in rawAssetDepr.whereType<Map<String, dynamic>>()) {
      await _db.upsertAssetDepreciationFromMap(item);
    }

    final rawDeprEntries = data['depreciation_entries'] as List? ?? [];
    for (final item in rawDeprEntries.whereType<Map<String, dynamic>>()) {
      await _db.upsertDepreciationEntryFromMap(item);
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────────

  Future<void> deleteSnapshot(String snapshotId) async {
    final dir = await _snapshotsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(snapshotId) && f.path.endsWith('.snapshot.json'))
        .toList();
    for (final f in files) {
      await f.delete();
    }
  }

  // ── Daily auto-snapshot ──────────────────────────────────────────────────────

  /// Called on every app launch / login. Creates one automatic snapshot per
  /// calendar day, labelled "Auto — DD MMM YYYY". Skips silently on failure
  /// so it never blocks startup.
  Future<void> maybeAutoSnapshot() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final last = await _storage.read(key: _lastAutoSnapshotKey);
      if (last == today) return;

      final label = 'Auto — ${DateFormat('dd MMM yyyy').format(DateTime.now())}';
      await createSnapshot(label);
      await _storage.write(key: _lastAutoSnapshotKey, value: today);
    } catch (_) {
      // auto-snapshot must never crash the app
    }
  }

  // ── Auto-purge ───────────────────────────────────────────────────────────────

  Future<void> _autoPurge(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.snapshot.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path)); // oldest first

    while (files.length > _maxSnapshots) {
      await files.removeAt(0).delete();
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  final db = ref.read(databaseProvider);
  return SnapshotService(LocalStorageService.instance, db);
});

// Holds the list loaded from disk; refreshed via invalidate.
final snapshotListProvider =
    FutureProvider<List<SnapshotMeta>>((ref) async {
  final svc = ref.read(snapshotServiceProvider);
  return svc.listSnapshots();
});
