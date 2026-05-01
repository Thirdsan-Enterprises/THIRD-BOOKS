// Local Backup Service — ThirdBooks Desktop
// Exports all locally-cached data to a .thirdbooks JSON file and restores it.
// Outlet revenue data is server-side and not included in local backups.

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'local_storage_service.dart';
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

  LocalBackupService(this._ls);

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<BackupResult?> exportBackup() async {
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
      },
    };

    final datePart = DateFormat('yyyyMMdd_HHmmss').format(now);
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
