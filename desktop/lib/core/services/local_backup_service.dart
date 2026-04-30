// Local Backup Service — ThirdBooks Desktop
// Exports all local data to a single .thirdbooks JSON file and restores it.
// Works fully offline — no cloud required.

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'local_storage_service.dart';
import '../database/app_database.dart';
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
  static const _backupVersion = '1.2';
  static const _appTag = 'ThirdBooks';
  final LocalStorageService _ls;
  final AppDatabase _db;

  LocalBackupService(this._ls, this._db);

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<BackupResult?> exportBackup() async {
    await _ls.initialize();

    // JSON-store entities
    final accounts     = await _ls.loadAccounts();
    final customers    = await _ls.loadCustomers();
    final vendors      = await _ls.loadVendors();
    final invoices     = await _ls.loadInvoices();
    final bills        = await _ls.loadBills();
    final journals     = await _ls.loadJournalEntries();
    final payments     = await _ls.loadPayments();
    final bankTxns     = await _ls.loadBankTransactions();
    final settlements  = await _ls.loadOutletSettlements();
    final creditNotes  = await _ls.loadCreditNotes();
    final debitNotes   = await _ls.loadDebitNotes();

    // SQLite/Drift entities
    final dbOutlets       = await _db.getAllOutlets();
    final dbRevenues      = await _db.getAllOutletRevenues();
    final dbExpenditures  = await _db.getAllOutletExpenditures();
    final dbCommissions   = await _db.getAllCommissionPayments();

    // Build outlet code map for FK resolution on import
    final outletCodeMap = {for (final o in dbOutlets) o.id: o.outletCode};

    final now = DateTime.now();
    final counts = {
      'accounts':            accounts.length,
      'customers':           customers.length,
      'vendors':             vendors.length,
      'invoices':            invoices.length,
      'bills':               bills.length,
      'journals':            journals.length,
      'payments':            payments.length,
      'bank_transactions':   bankTxns.length,
      'outlet_settlements':  settlements.length,
      'credit_notes':        creditNotes.length,
      'debit_notes':         debitNotes.length,
      'outlets':             dbOutlets.length,
      'outlet_revenues':     dbRevenues.length,
      'outlet_expenditures': dbExpenditures.length,
      'commission_payments': dbCommissions.length,
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
        'outlet_expenditures': dbExpenditures.map((e) => {
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
          'id':                 c.id,
          'outlet_id':          c.outletId,
          'outlet_code':        outletCodeMap[c.outletId] ?? '',
          'period_start':       c.periodStart.toIso8601String(),
          'period_end':         c.periodEnd.toIso8601String(),
          'total_revenue':      c.totalRevenue,
          'commission_rate':    c.commissionRate,
          'commission_amount':  c.commissionAmount,
          'status':             c.status,
          'paid_date':          c.paidDate?.toIso8601String(),
          'payment_method':     c.paymentMethod,
          'payment_reference':  c.paymentReference,
          'notes':              c.notes,
          'created_at':         c.createdAt.toIso8601String(),
          'updated_at':         c.updatedAt.toIso8601String(),
        }).toList(),
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
    return _parse(content, filePath: filePath) ??
        RestoreResult(counts: {}, exportedAt: '', success: false, error: 'Could not parse file');
  }

  Future<RestoreResult> restoreFromFile(String filePath) async {
    final content = await File(filePath).readAsString();
    final parsed = _parse(content, filePath: filePath);
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

    // Restore SQLite/Drift entities using outlet_code for FK resolution.
    // Outlets are pre-seeded so we skip re-inserting them.
    final rawRevenues = data['outlet_revenues'] as List? ?? [];
    for (final item in rawRevenues.whereType<Map<String, dynamic>>()) {
      await _db.upsertOutletRevenueFromMap(item);
    }
    counts['outlet_revenues'] = rawRevenues.length;

    final rawExpenditures = data['outlet_expenditures'] as List? ?? [];
    for (final item in rawExpenditures.whereType<Map<String, dynamic>>()) {
      await _db.upsertOutletExpenditureFromMap(item);
    }
    counts['outlet_expenditures'] = rawExpenditures.length;

    final rawCommissions = data['commission_payments'] as List? ?? [];
    for (final item in rawCommissions.whereType<Map<String, dynamic>>()) {
      await _db.upsertCommissionPaymentFromMap(item);
    }
    counts['commission_payments'] = rawCommissions.length;

    return RestoreResult(counts: counts, exportedAt: json['exported_at'] ?? '');
  }

  RestoreResult? _parse(String content, {required String filePath}) {
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
