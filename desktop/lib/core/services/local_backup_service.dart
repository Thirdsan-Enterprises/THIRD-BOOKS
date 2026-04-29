// Local Backup Service — Web Edition
// Exports all cached data to a downloadable JSON file via the browser.

import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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

class BackupResult {
  final String fileName;
  final Map<String, int> counts;
  final DateTime exportedAt;

  BackupResult({
    required this.fileName,
    required this.counts,
    required this.exportedAt,
  });

  int get totalRecords => counts.values.fold(0, (s, c) => s + c);
}

class BackupPreview {
  final String? error;
  final String exportedAt;
  final Map<String, int> counts;

  BackupPreview({this.error, required this.exportedAt, required this.counts});

  int get totalRecords => counts.values.fold(0, (s, c) => s + c);
}

class LocalBackupService {
  static const _backupVersion = '2.0';
  static const _appTag = 'ThirdBooks';
  final LocalStorageService _ls;

  LocalBackupService(this._ls);

  /// Gathers all locally cached data, serialises to JSON, and triggers a
  /// browser download. Returns [BackupResult] with filename + counts.
  Future<BackupResult> exportBackup() async {
    final accounts    = await _ls.loadAccounts();
    final customers   = await _ls.loadCustomers();
    final vendors     = await _ls.loadVendors();
    final invoices    = await _ls.loadInvoices();
    final bills       = await _ls.loadBills();
    final journals    = await _ls.loadJournalEntries();
    final payments    = await _ls.loadPayments();
    final bankTxns    = await _ls.loadBankTransactions();
    final settlements = await _ls.loadOutletSettlements();
    final creditNotes = await _ls.loadCreditNotes();
    final debitNotes  = await _ls.loadDebitNotes();

    final now = DateTime.now();
    final counts = {
      'accounts':           accounts.length,
      'customers':          customers.length,
      'vendors':            vendors.length,
      'invoices':           invoices.length,
      'bills':              bills.length,
      'journals':           journals.length,
      'payments':           payments.length,
      'bank_transactions':  bankTxns.length,
      'outlet_settlements': settlements.length,
      'credit_notes':       creditNotes.length,
      'debit_notes':        debitNotes.length,
    };

    final payload = {
      'version':     _backupVersion,
      'app':         _appTag,
      'exported_at': now.toIso8601String(),
      'counts':      counts,
      'data': {
        'accounts':           accounts.map((e) => e.toJson()).toList(),
        'customers':          customers.map((e) => e.toJson()).toList(),
        'vendors':            vendors.map((e) => e.toJson()).toList(),
        'invoices':           invoices.map((e) => e.toJson()).toList(),
        'bills':              bills.map((e) => e.toJson()).toList(),
        'journals':           journals.map((e) => e.toJson()).toList(),
        'payments':           payments.map((e) => e.toJson()).toList(),
        'bank_transactions':  bankTxns.map((e) => e.toJson()).toList(),
        'outlet_settlements': settlements.map((e) => e.toJson()).toList(),
        'credit_notes':       creditNotes.map((e) => e.toJson()).toList(),
        'debit_notes':        debitNotes.map((e) => e.toJson()).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final datePart = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'thirdbooks_backup_$datePart.json';

    // Trigger browser download
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);

    return BackupResult(fileName: fileName, counts: counts, exportedAt: now);
  }

  /// Parse backup bytes and return a preview without writing anything.
  Future<BackupPreview> previewRestoreFromBytes(Uint8List bytes) async {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json['app'] != _appTag) {
        return BackupPreview(
          error: 'Not a valid ThirdBooks backup file.',
          exportedAt: '',
          counts: {},
        );
      }
      final counts = (json['counts'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
      return BackupPreview(
        exportedAt: json['exported_at'] as String? ?? '',
        counts: counts,
      );
    } catch (e) {
      return BackupPreview(
        error: 'Could not read backup file: $e',
        exportedAt: '',
        counts: {},
      );
    }
  }

  /// Restore all data from backup bytes, overwriting local cache.
  Future<BackupResult> restoreFromBytes(Uint8List bytes) async {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final counts = (json['counts'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));

    Future<void> saveList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
      Future<void> Function(List<T>) saver,
    ) async {
      final raw = (data[key] as List? ?? []).cast<Map<String, dynamic>>();
      await saver(raw.map(fromJson).toList());
    }

    await saveList('accounts',    Account.fromJson,       _ls.saveAccounts);
    await saveList('customers',   Customer.fromJson,      _ls.saveCustomers);
    await saveList('vendors',     Vendor.fromJson,        _ls.saveVendors);
    await saveList('invoices',    Invoice.fromJson,       _ls.saveInvoices);
    await saveList('bills',       Bill.fromJson,          _ls.saveBills);
    await saveList('journals',    JournalEntry.fromJson,  _ls.saveJournalEntries);
    await saveList('payments',    Payment.fromJson,       _ls.savePayments);

    final now = DateTime.now();
    return BackupResult(
      fileName: json['exported_at'] as String? ?? now.toIso8601String(),
      counts: counts,
      exportedAt: now,
    );
  }
}
