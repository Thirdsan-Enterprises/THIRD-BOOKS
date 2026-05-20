// Local Backup Service — ThirdBooks Desktop
// Exports all local data to a single .thirdbooks JSON file and restores it.
// Works fully offline — no cloud required.

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

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

class BackupResult {
  final String filePath;
  final Map<String, int> counts;
  final DateTime exportedAt;

  BackupResult({required this.filePath, required this.counts, required this.exportedAt});

  int get totalRecords => counts.values.fold(0, (s, c) => s + c);
}

class RestoreResult {
  final Map<String, int> counts;
  final String exportedAt;
  final bool success;
  final String? error;

  RestoreResult({required this.counts, required this.exportedAt, this.success = true, this.error});

  int get totalRecords => counts.values.fold(0, (s, c) => s + c);
}

class LocalBackupService {
  static const _backupVersion = '2.0';
  static const _appTag = 'ThirdBooks';
  final LocalStorageService _ls;
  final AppDatabase _db;

  LocalBackupService(this._ls, this._db);

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<BackupResult?> exportBackup() async {
    await _ls.initialize();
    final payload = await _buildPayloadInternal();
    final now     = DateTime.parse(payload['exported_at'] as String);
    final counts  = (payload['counts'] as Map).cast<String, int>();

    final datePart      = DateFormat('yyyy-MM-dd').format(now);
    final suggestedName = 'thirdbooks_backup_$datePart.thirdbooks';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ThirdBooks Backup',
      fileName: suggestedName,
      type: FileType.any,
    );
    if (savePath == null) return null;

    final finalPath = savePath.endsWith('.thirdbooks') ? savePath : '$savePath.thirdbooks';
    await File(finalPath).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    return BackupResult(filePath: finalPath, counts: counts, exportedAt: now);
  }

  Future<Map<String, dynamic>> _buildPayloadInternal() async {
    // JSON-store entities
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

    // SQLite/Drift entities
    final dbOutlets     = await _db.getAllOutlets();
    final dbRevenues    = await _db.getAllOutletRevenues();
    final dbExpend      = await _db.getAllOutletExpenditures();
    final dbCommissions = await _db.getAllCommissionPayments();
    final dbAssets      = await _db.getAllAssets();
    final dbAssetDepr   = await _db.getAllAssetDepreciationSchedules();
    final dbDeprEntries = await _db.getAllDepreciationEntries();

    final outletCodeMap = {for (final o in dbOutlets) o.id: o.outletCode};

    final now = DateTime.now();
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
      'version':     _backupVersion,
      'app':         _appTag,
      'exported_at': now.toIso8601String(),
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

    return payload;
  }

  /// Exports the full backup as a JSON string without prompting for a file path.
  /// Used by ServerSyncService to push the backup to the sync server.
  Future<String> exportAsJson() async {
    await _ls.initialize();
    final payload = await _buildPayloadInternal();
    return jsonEncode(payload);
  }

  // ── Import / Restore ────────────────────────────────────────────────────────

  Future<RestoreResult> previewRestoreFromPath(String filePath) async {
    final content = await File(filePath).readAsString();
    return _parse(content) ??
        RestoreResult(counts: {}, exportedAt: '', success: false, error: 'Could not parse file');
  }

  Future<RestoreResult> restoreFromFile(String filePath) async {
    final content = await File(filePath).readAsString();
    final parsed = _parse(content);
    if (parsed == null) throw Exception('Could not read backup file');
    if (parsed.error != null) throw Exception(parsed.error);

    final json = jsonDecode(content) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;

    Future<int> restore<T>(String key, T Function(Map<String, dynamic>) from,
        Future<void> Function(List<T>) save) async {
      final raw = data[key] as List? ?? [];
      final items = raw.map((e) => from(e as Map<String, dynamic>)).toList();
      if (items.isNotEmpty) await save(items);
      return items.length;
    }

    final counts = <String, int>{};
    counts['accounts']           = await restore('accounts',           Account.fromJson,         _ls.saveAccounts);
    counts['customers']          = await restore('customers',          Customer.fromJson,         _ls.saveCustomers);
    counts['vendors']            = await restore('vendors',            Vendor.fromJson,           _ls.saveVendors);
    counts['invoices']           = await restore('invoices',           Invoice.fromJson,          _ls.saveInvoices);
    counts['bills']              = await restore('bills',              Bill.fromJson,             _ls.saveBills);
    counts['journals']           = await restore('journals',           JournalEntry.fromJson,     _ls.saveJournalEntries);
    counts['payments']           = await restore('payments',           Payment.fromJson,          _ls.savePayments);
    counts['bank_transactions']  = await restore('bank_transactions',  BankTransaction.fromJson,  _ls.saveBankTransactions);
    counts['outlet_settlements'] = await restore('outlet_settlements', OutletSettlement.fromJson, _ls.saveOutletSettlements);
    counts['credit_notes']       = await restore('credit_notes',       CreditNote.fromJson,       _ls.saveCreditNotes);
    counts['debit_notes']        = await restore('debit_notes',        DebitNote.fromJson,        _ls.saveDebitNotes);
    counts['local_bank_statements'] = await restore('local_bank_statements', LocalBankStatement.fromJson,
        (items) => _ls.saveData('local_bank_statements', items, (s) => s.toJson()));
    counts['asset_drafts']       = await restore('asset_drafts',       AssetDraft.fromJson,
        (items) => _ls.saveData('asset_drafts', items, (a) => a.toJson()));
    counts['depreciation_schedules'] = await restore('depreciation_schedules', DepreciationSchedule.fromJson,
        (items) => _ls.saveData('depreciation_schedules', items, (s) => s.toJson()));
    counts['local_attachments']  = await restore('local_attachments',  LocalAttachment.fromJson,
        (items) => _ls.saveData('local_attachments', items, (a) => a.toJson()));

    // Outlets are pre-seeded — skip re-inserting them.
    final rawRevenues = data['outlet_revenues'] as List? ?? [];
    for (final item in rawRevenues.whereType<Map<String, dynamic>>()) {
      await _db.upsertOutletRevenueFromMap(item);
    }
    counts['outlet_revenues'] = rawRevenues.length;

    final rawExpend = data['outlet_expenditures'] as List? ?? [];
    for (final item in rawExpend.whereType<Map<String, dynamic>>()) {
      await _db.upsertOutletExpenditureFromMap(item);
    }
    counts['outlet_expenditures'] = rawExpend.length;

    final rawCommissions = data['commission_payments'] as List? ?? [];
    for (final item in rawCommissions.whereType<Map<String, dynamic>>()) {
      await _db.upsertCommissionPaymentFromMap(item);
    }
    counts['commission_payments'] = rawCommissions.length;

    // Assets before depreciation schedules and entries (FK order).
    final rawAssets = data['assets'] as List? ?? [];
    for (final item in rawAssets.whereType<Map<String, dynamic>>()) {
      await _db.upsertAssetFromMap(item);
    }
    counts['assets'] = rawAssets.length;

    final rawAssetDepr = data['asset_depreciation'] as List? ?? [];
    for (final item in rawAssetDepr.whereType<Map<String, dynamic>>()) {
      await _db.upsertAssetDepreciationFromMap(item);
    }
    counts['asset_depreciation'] = rawAssetDepr.length;

    final rawDeprEntries = data['depreciation_entries'] as List? ?? [];
    for (final item in rawDeprEntries.whereType<Map<String, dynamic>>()) {
      await _db.upsertDepreciationEntryFromMap(item);
    }
    counts['depreciation_entries'] = rawDeprEntries.length;

    return RestoreResult(counts: counts, exportedAt: json['exported_at'] ?? '');
  }

  RestoreResult? _parse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      if (json['app'] != _appTag) {
        return RestoreResult(
          counts: {},
          exportedAt: '',
          success: false,
          error: 'Not a valid ThirdBooks backup file.',
        );
      }
      final counts = (json['counts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt()));
      return RestoreResult(counts: counts, exportedAt: json['exported_at'] ?? '');
    } catch (e) {
      return RestoreResult(
        counts: {},
        exportedAt: '',
        success: false,
        error: 'Failed to parse backup: $e',
      );
    }
  }
}
