import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
// Local Storage Service — SharedPreferences backed (web + native compatible)
// ============================================================================

class LocalStorageService {
  static LocalStorageService? _instance;

  LocalStorageService._();

  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  Future<void> initialize() async {
    // No-op — SharedPreferences initialises lazily.
  }

  // ============================================================================
  // Generic Save/Load
  // ============================================================================

  Future<void> saveData<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map(toJson).toList());
      await prefs.setString('ls_$key', encoded);
    } catch (e) {
      debugPrint('LocalStorage saveData($key): $e');
    }
  }

  Future<List<T>> loadData<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ls_$key');
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('LocalStorage loadData($key): $e');
      return [];
    }
  }

  // ============================================================================
  // Entity helpers
  // ============================================================================

  Future<void> saveAccounts(List<Account> items) =>
      saveData('accounts', items, (a) => a.toJson());
  Future<List<Account>> loadAccounts() =>
      loadData('accounts', Account.fromJson);

  Future<void> saveCustomers(List<Customer> items) =>
      saveData('customers', items, (c) => c.toJson());
  Future<List<Customer>> loadCustomers() =>
      loadData('customers', Customer.fromJson);

  Future<void> saveVendors(List<Vendor> items) =>
      saveData('vendors', items, (v) => v.toJson());
  Future<List<Vendor>> loadVendors() =>
      loadData('vendors', Vendor.fromJson);

  Future<void> saveInvoices(List<Invoice> items) =>
      saveData('invoices', items, (i) => i.toJson());
  Future<List<Invoice>> loadInvoices() =>
      loadData('invoices', Invoice.fromJson);

  Future<void> saveBills(List<Bill> items) =>
      saveData('bills', items, (b) => b.toJson());
  Future<List<Bill>> loadBills() =>
      loadData('bills', Bill.fromJson);

  Future<void> saveJournalEntries(List<JournalEntry> items) =>
      saveData('journals', items, (e) => e.toJson());
  Future<List<JournalEntry>> loadJournalEntries() =>
      loadData('journals', JournalEntry.fromJson);

  Future<void> savePayments(List<Payment> items) =>
      saveData('payments', items, (p) => p.toJson());
  Future<List<Payment>> loadPayments() =>
      loadData('payments', Payment.fromJson);

  Future<void> saveBankTransactions(List<BankTransaction> items) =>
      saveData('bank_transactions', items, (t) => t.toJson());
  Future<List<BankTransaction>> loadBankTransactions() =>
      loadData('bank_transactions', BankTransaction.fromJson);

  Future<void> saveOutletSettlements(List<OutletSettlement> items) =>
      saveData('outlet_settlements', items, (s) => s.toJson());
  Future<List<OutletSettlement>> loadOutletSettlements() =>
      loadData('outlet_settlements', OutletSettlement.fromJson);

  Future<void> saveCreditNotes(List<CreditNote> items) =>
      saveData('credit_notes', items, (n) => n.toJson());
  Future<List<CreditNote>> loadCreditNotes() =>
      loadData('credit_notes', CreditNote.fromJson);

  Future<void> saveDebitNotes(List<DebitNote> items) =>
      saveData('debit_notes', items, (n) => n.toJson());
  Future<List<DebitNote>> loadDebitNotes() =>
      loadData('debit_notes', DebitNote.fromJson);

  // ============================================================================
  // Clear all
  // ============================================================================

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('ls_')).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('LocalStorage clearAllData: $e');
    }
  }
}

// ============================================================================
// Provider
// ============================================================================

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService.instance;
});
