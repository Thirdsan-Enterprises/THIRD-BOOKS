// Data Service for MagicBet Accounting Desktop App
// Offline-First Architecture with Local Storage and Sync Queue
// © 2026 Magic Bet Ltd. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;

import 'api_client.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import 'sync_service.dart';
import '../models/models.dart';
import '../database/app_database.dart' hide Account, Customer, Vendor, Invoice, Bill, JournalEntry, JournalLine;

// Global local storage instance
final _localStorage = LocalStorageService.instance;
const _uuid = Uuid();

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// ============================================================================
// MagicBet Default Chart of Accounts
// ============================================================================

List<Account> _magicBetDefaultAccounts() {
  final now = DateTime.now();
  return [
    // Assets
    Account(id: 'acct-1000', code: '1000', name: 'Cash on Hand', type: AccountType.asset, subType: AccountSubType.cash, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-1100', code: '1100', name: 'Bank Account - UGX', type: AccountType.asset, subType: AccountSubType.bank, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-1200', code: '1200', name: 'Outlet Cash Collections', description: 'Total cash collected from all outlets (Total In)', type: AccountType.asset, subType: AccountSubType.cash, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-1300', code: '1300', name: 'Accounts Receivable', type: AccountType.asset, subType: AccountSubType.accountsReceivable, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-1500', code: '1500', name: 'Betting Equipment', description: 'Machines, terminals, and betting equipment', type: AccountType.asset, subType: AccountSubType.fixedAsset, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-1600', code: '1600', name: 'Office Equipment', type: AccountType.asset, subType: AccountSubType.fixedAsset, isSystemAccount: true, createdAt: now, updatedAt: now),
    // Liabilities
    Account(id: 'acct-2000', code: '2000', name: 'Customer Payouts Payable', description: 'Winnings owed to customers (Total Out)', type: AccountType.liability, subType: AccountSubType.currentLiability, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-2100', code: '2100', name: 'Betting Tax Payable', description: 'Tax on GGR per URA regulations', type: AccountType.liability, subType: AccountSubType.currentLiability, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-2200', code: '2200', name: 'VAT Payable', type: AccountType.liability, subType: AccountSubType.currentLiability, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-2300', code: '2300', name: 'Commission Payable', description: 'Commission owed to outlet owners', type: AccountType.liability, subType: AccountSubType.currentLiability, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-2400', code: '2400', name: 'Accounts Payable', type: AccountType.liability, subType: AccountSubType.accountsPayable, isSystemAccount: true, createdAt: now, updatedAt: now),
    // Equity
    Account(id: 'acct-3000', code: '3000', name: "Owner's Equity", type: AccountType.equity, subType: AccountSubType.ownersEquity, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-3100', code: '3100', name: 'Retained Earnings', type: AccountType.equity, subType: AccountSubType.retainedEarnings, isSystemAccount: true, createdAt: now, updatedAt: now),
    // Revenue
    Account(id: 'acct-4000', code: '4000', name: 'Gross Gaming Revenue (GGR)', description: 'Total In minus Total Out from all outlets', type: AccountType.revenue, subType: AccountSubType.salesRevenue, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-4100', code: '4100', name: 'Total Stakes (Cash In)', description: 'Total money wagered by customers', type: AccountType.revenue, subType: AccountSubType.salesRevenue, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-4200', code: '4200', name: 'Other Income', type: AccountType.revenue, subType: AccountSubType.otherIncome, isSystemAccount: true, createdAt: now, updatedAt: now),
    // Expenses
    Account(id: 'acct-5000', code: '5000', name: 'Customer Winnings (Payouts)', description: 'Total paid out to winning customers', type: AccountType.expense, subType: AccountSubType.costOfGoodsSold, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-5100', code: '5100', name: 'Outlet Commission Expense', description: '40% commission to location owners', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6000', code: '6000', name: 'Salaries & Wages', type: AccountType.expense, subType: AccountSubType.payrollExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6100', code: '6100', name: 'Rent Expense', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6200', code: '6200', name: 'Utilities Expense', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6300', code: '6300', name: 'Betting Tax Expense', description: 'Tax paid on GGR', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6400', code: '6400', name: 'Equipment Maintenance', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6500', code: '6500', name: 'Office Supplies', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6600', code: '6600', name: 'Security Expense', type: AccountType.expense, subType: AccountSubType.operatingExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
    Account(id: 'acct-6900', code: '6900', name: 'Other Operating Expenses', type: AccountType.expense, subType: AccountSubType.otherExpense, isSystemAccount: true, createdAt: now, updatedAt: now),
  ];
}

// ============================================================================
// Dashboard Service - Computed from real database data
// ============================================================================

class DashboardData {
  final double totalRevenue;
  final double totalExpenses;
  final double netIncome;
  final double outstandingInvoices;
  final int invoiceCount;
  final double revenueChange;
  final double expenseChange;
  final double incomeChange;
  final double cashIn;
  final double cashOut;
  final double netCash;
  final List<Map<String, double>> revenueData;
  final List<Map<String, double>> expenseData;
  final List<Map<String, dynamic>> receivableAging;
  final List<Map<String, dynamic>> recentTransactions;

  DashboardData({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netIncome,
    required this.outstandingInvoices,
    required this.invoiceCount,
    required this.revenueChange,
    required this.expenseChange,
    required this.incomeChange,
    required this.cashIn,
    required this.cashOut,
    required this.netCash,
    required this.revenueData,
    required this.expenseData,
    required this.receivableAging,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      netIncome: (json['net_income'] as num?)?.toDouble() ?? 0.0,
      outstandingInvoices: (json['outstanding_invoices'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: json['invoice_count'] as int? ?? 0,
      revenueChange: (json['revenue_change'] as num?)?.toDouble() ?? 0.0,
      expenseChange: (json['expense_change'] as num?)?.toDouble() ?? 0.0,
      incomeChange: (json['income_change'] as num?)?.toDouble() ?? 0.0,
      cashIn: (json['cash_in'] as num?)?.toDouble() ?? 0.0,
      cashOut: (json['cash_out'] as num?)?.toDouble() ?? 0.0,
      netCash: (json['net_cash'] as num?)?.toDouble() ?? 0.0,
      revenueData: ((json['revenue_data'] as List<dynamic>?) ?? [])
          .map((e) => {'month': (e['month'] as num).toDouble(), 'value': (e['value'] as num).toDouble()})
          .toList(),
      expenseData: ((json['expense_data'] as List<dynamic>?) ?? [])
          .map((e) => {'month': (e['month'] as num).toDouble(), 'value': (e['value'] as num).toDouble()})
          .toList(),
      receivableAging: ((json['receivable_aging'] as List<dynamic>?) ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      recentTransactions: ((json['recent_transactions'] as List<dynamic>?) ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  factory DashboardData.empty() {
    return DashboardData(
      totalRevenue: 0,
      totalExpenses: 0,
      netIncome: 0,
      outstandingInvoices: 0,
      invoiceCount: 0,
      revenueChange: 0,
      expenseChange: 0,
      incomeChange: 0,
      cashIn: 0,
      cashOut: 0,
      netCash: 0,
      revenueData: [],
      expenseData: [],
      receivableAging: [],
      recentTransactions: [],
    );
  }
}

/// Dashboard data computed from real outlet revenue data in the database
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final db = ref.read(databaseProvider);

  try {
    final allRevenues = await db.getAllOutletRevenues();
    final outlets = await db.getAllOutlets();

    if (allRevenues.isEmpty) {
      return DashboardData.empty();
    }

    // Run carry-forward commission engine per outlet to get accurate Net Revenue.
    // This is the real money MagicBet has available after paying 40% to outlet owners.
    double totalCashIn = 0;
    double totalCashOut = 0;   // raw payouts (Total Out column)
    double totalGGR = 0;       // Gross Gaming Revenue = Cash In - Cash Out
    double totalOutletExpense = 0;  // 40% commission (carry-forward adjusted)
    double totalNetRevenue = 0;    // what MagicBet actually keeps

    final revenuesByOutlet = <String, List<OutletRevenue>>{};
    for (final rev in allRevenues) {
      revenuesByOutlet.putIfAbsent(rev.outletId, () => []).add(rev);
      totalCashIn += rev.amount;
      totalCashOut += rev.commissionAmount;
      totalGGR += rev.netAmount;
    }

    // Monthly GGR and Net Revenue for charts
    final Map<int, double> monthlyGGR = {};
    final Map<int, double> monthlyNet = {};

    // Per-outlet net for top-outlets panel
    final Map<String, double> outletNet = {};

    for (final outlet in outlets) {
      final revs = revenuesByOutlet[outlet.id] ?? [];
      final weeks = _computeWeeksForOutlet(outlet, revs);
      final outletNetTotal = weeks.fold(0.0, (s, w) => s + w.netRevenue);
      final outletExpTotal = weeks.fold(0.0, (s, w) => s + w.outletExpense);
      totalOutletExpense += outletExpTotal;
      totalNetRevenue += outletNetTotal;
      outletNet[outlet.id] = outletNetTotal;

      // Monthly aggregation from weekly data
      for (final w in weeks) {
        final mo = w.weekStart.month;
        monthlyGGR[mo] = (monthlyGGR[mo] ?? 0) + w.rawGGR;
        monthlyNet[mo] = (monthlyNet[mo] ?? 0) + w.netRevenue;
      }
    }

    // Recent transactions (last 10 entries, sorted DESC)
    final sortedRevenues = List<OutletRevenue>.from(allRevenues)
      ..sort((a, b) => b.date.compareTo(a.date));

    final recentTx = <Map<String, dynamic>>[];
    for (var i = 0; i < sortedRevenues.length && i < 10; i++) {
      final rev = sortedRevenues[i];
      final outlet = outlets.where((o) => o.id == rev.outletId).firstOrNull;
      recentTx.add({
        'title': outlet?.name ?? 'Outlet',
        'subtitle': DateFormat('MMM d, yyyy').format(rev.date),
        'amount': rev.netAmount,
        'isIncome': rev.netAmount >= 0,
        'icon': 'payments',
      });
    }

    // Chart data: GGR line (light) and Net line (bold)
    final revenueData = monthlyGGR.entries
        .map((e) => {'month': e.key.toDouble(), 'value': e.value})
        .toList()
      ..sort((a, b) => a['month']!.compareTo(b['month']!));

    final expenseData = monthlyNet.entries
        .map((e) => {'month': e.key.toDouble(), 'value': e.value})
        .toList()
      ..sort((a, b) => a['month']!.compareTo(b['month']!));

    // Top outlets by net revenue for the panel
    final sortedByNet = outletNet.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topNet = sortedByNet.take(5).toList();
    final maxNet = topNet.isNotEmpty ? topNet.first.value.abs().clamp(1.0, double.infinity) : 1.0;

    final receivableAging = topNet.map((e) {
      final outlet = outlets.where((o) => o.id == e.key).firstOrNull;
      return {
        'label': outlet?.name ?? 'Unknown',
        'amount': e.value,
        'percentage': e.value / maxNet,
      };
    }).toList();

    return DashboardData(
      totalRevenue: totalGGR,
      totalExpenses: totalOutletExpense, // actual 40% commission expense
      netIncome: totalNetRevenue,        // real money MagicBet keeps
      outstandingInvoices: 0,
      invoiceCount: outlets.where((o) => o.isActive).length,
      revenueChange: 0,
      expenseChange: 0,
      incomeChange: 0,
      cashIn: totalCashIn,
      cashOut: totalCashOut,
      netCash: totalNetRevenue,
      revenueData: revenueData,
      expenseData: expenseData,
      receivableAging: receivableAging,
      recentTransactions: recentTx,
    );
  } catch (e) {
    debugPrint('Error computing dashboard data: $e');
    return DashboardData.empty();
  }
});

// ============================================================================
// Accounts Service - OFFLINE-FIRST with MagicBet defaults
// ============================================================================

class AccountsState {
  final List<Account> accounts;
  final bool isLoading;
  final String? error;

  AccountsState({
    this.accounts = const [],
    this.isLoading = false,
    this.error,
  });

  AccountsState copyWith({
    List<Account>? accounts,
    bool? isLoading,
    String? error,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AccountsNotifier extends StateNotifier<AccountsState> {
  final ApiClient _apiClient;
  final Ref _ref;

  AccountsNotifier(this._apiClient, this._ref) : super(AccountsState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API - MagicBet is offline-first)
    try {
      final localAccounts = await _localStorage.loadAccounts();
      if (localAccounts.isNotEmpty) {
        state = state.copyWith(accounts: localAccounts, isLoading: false);
        debugPrint('Loaded ${localAccounts.length} accounts from local storage');
        return;
      }
    } catch (e) {
      debugPrint('Error loading accounts from local storage: $e');
    }

    // Start with empty chart of accounts - user adds accounts manually
    state = state.copyWith(accounts: [], isLoading: false);
    debugPrint('No accounts found. Use "New Account" to add accounts.');
  }

  Future<void> loadAccounts() async {
    // Reload from local storage
    try {
      final localAccounts = await _localStorage.loadAccounts();
      state = state.copyWith(accounts: localAccounts, isLoading: false);
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addAccount(Account account) {
    final updatedAccounts = [...state.accounts, account];
    state = state.copyWith(accounts: updatedAccounts);

    _localStorage.saveAccounts(updatedAccounts);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.account,
      entityId: account.id,
      data: account.toJson(),
    );
  }

  void updateAccount(Account account) {
    final updatedAccounts = state.accounts.map((a) {
      return a.id == account.id ? account : a;
    }).toList();
    state = state.copyWith(accounts: updatedAccounts);

    _localStorage.saveAccounts(updatedAccounts);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.account,
      entityId: account.id,
      data: account.toJson(),
    );
  }
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, AccountsState>((ref) {
  return AccountsNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Customers Service - OFFLINE-FIRST
// ============================================================================

class CustomersState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;

  CustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  final ApiClient _apiClient;
  final Ref _ref;

  CustomersNotifier(this._apiClient, this._ref) : super(CustomersState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API)
    try {
      final localCustomers = await _localStorage.loadCustomers();
      state = state.copyWith(customers: localCustomers, isLoading: false);
      debugPrint('Loaded ${localCustomers.length} customers from local storage');
    } catch (e) {
      debugPrint('Error loading customers from local storage: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadCustomers() async {
    try {
      final localCustomers = await _localStorage.loadCustomers();
      state = state.copyWith(customers: localCustomers, isLoading: false);
    } catch (e) {
      debugPrint('Error loading customers: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addCustomer(Customer customer) {
    final updatedCustomers = [...state.customers, customer];
    state = state.copyWith(customers: updatedCustomers);

    _localStorage.saveCustomers(updatedCustomers);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.customer,
      entityId: customer.id,
      data: customer.toJson(),
    );
  }

  void updateCustomer(Customer customer) {
    final updatedCustomers = state.customers.map((c) {
      return c.id == customer.id ? customer : c;
    }).toList();
    state = state.copyWith(customers: updatedCustomers);

    _localStorage.saveCustomers(updatedCustomers);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.customer,
      entityId: customer.id,
      data: customer.toJson(),
    );
  }
}

final customersProvider = StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  return CustomersNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Vendors Service - OFFLINE-FIRST
// ============================================================================

class VendorsState {
  final List<Vendor> vendors;
  final bool isLoading;
  final String? error;

  VendorsState({
    this.vendors = const [],
    this.isLoading = false,
    this.error,
  });

  VendorsState copyWith({
    List<Vendor>? vendors,
    bool? isLoading,
    String? error,
  }) {
    return VendorsState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class VendorsNotifier extends StateNotifier<VendorsState> {
  final ApiClient _apiClient;
  final Ref _ref;

  VendorsNotifier(this._apiClient, this._ref) : super(VendorsState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API)
    try {
      final localVendors = await _localStorage.loadVendors();
      state = state.copyWith(vendors: localVendors, isLoading: false);
      debugPrint('Loaded ${localVendors.length} vendors from local storage');
    } catch (e) {
      debugPrint('Error loading vendors from local storage: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadVendors() async {
    try {
      final localVendors = await _localStorage.loadVendors();
      state = state.copyWith(vendors: localVendors, isLoading: false);
    } catch (e) {
      debugPrint('Error loading vendors: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addVendor(Vendor vendor) {
    final updatedVendors = [...state.vendors, vendor];
    state = state.copyWith(vendors: updatedVendors);

    _localStorage.saveVendors(updatedVendors);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.vendor,
      entityId: vendor.id,
      data: vendor.toJson(),
    );
  }

  void updateVendor(Vendor vendor) {
    final updatedVendors = state.vendors.map((v) {
      return v.id == vendor.id ? vendor : v;
    }).toList();
    state = state.copyWith(vendors: updatedVendors);

    _localStorage.saveVendors(updatedVendors);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.vendor,
      entityId: vendor.id,
      data: vendor.toJson(),
    );
  }
}

final vendorsProvider = StateNotifierProvider<VendorsNotifier, VendorsState>((ref) {
  return VendorsNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Invoices Service - OFFLINE-FIRST
// ============================================================================

class InvoicesState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;

  InvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
  });

  InvoicesState copyWith({
    List<Invoice>? invoices,
    bool? isLoading,
    String? error,
  }) {
    return InvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InvoicesNotifier extends StateNotifier<InvoicesState> {
  final ApiClient _apiClient;
  final Ref _ref;

  InvoicesNotifier(this._apiClient, this._ref) : super(InvoicesState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API)
    try {
      final localInvoices = await _localStorage.loadInvoices();
      state = state.copyWith(invoices: localInvoices, isLoading: false);
      debugPrint('Loaded ${localInvoices.length} invoices from local storage');
    } catch (e) {
      debugPrint('Error loading invoices from local storage: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadInvoices() async {
    try {
      final localInvoices = await _localStorage.loadInvoices();
      state = state.copyWith(invoices: localInvoices, isLoading: false);
    } catch (e) {
      debugPrint('Error loading invoices: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addInvoice(Invoice invoice) {
    final updatedInvoices = [...state.invoices, invoice];
    state = state.copyWith(invoices: updatedInvoices);

    _localStorage.saveInvoices(updatedInvoices);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.invoice,
      entityId: invoice.id,
      data: invoice.toJson(),
    );
  }

  void updateInvoice(Invoice invoice) {
    final updatedInvoices = state.invoices.map((i) {
      return i.id == invoice.id ? invoice : i;
    }).toList();
    state = state.copyWith(invoices: updatedInvoices);

    _localStorage.saveInvoices(updatedInvoices);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.invoice,
      entityId: invoice.id,
      data: invoice.toJson(),
    );
  }

  void recordPayment(String invoiceId, double amount) {
    final updatedInvoices = state.invoices.map((invoice) {
      if (invoice.id == invoiceId) {
        final newAmountPaid = invoice.amountPaid + amount;
        final newStatus = newAmountPaid >= invoice.total
            ? InvoiceStatus.paid
            : InvoiceStatus.partial;
        return invoice.copyWith(
          amountPaid: newAmountPaid,
          status: newStatus,
          updatedAt: DateTime.now(),
        );
      }
      return invoice;
    }).toList();
    state = state.copyWith(invoices: updatedInvoices);

    _localStorage.saveInvoices(updatedInvoices);

    final invoice = updatedInvoices.firstWhere((i) => i.id == invoiceId);
    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.invoice,
      entityId: invoiceId,
      data: invoice.toJson(),
    );
  }
}

final invoicesProvider = StateNotifierProvider<InvoicesNotifier, InvoicesState>((ref) {
  return InvoicesNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Bills Service - OFFLINE-FIRST
// ============================================================================

class BillsState {
  final List<Bill> bills;
  final bool isLoading;
  final String? error;

  BillsState({
    this.bills = const [],
    this.isLoading = false,
    this.error,
  });

  BillsState copyWith({
    List<Bill>? bills,
    bool? isLoading,
    String? error,
  }) {
    return BillsState(
      bills: bills ?? this.bills,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BillsNotifier extends StateNotifier<BillsState> {
  final ApiClient _apiClient;
  final Ref _ref;

  BillsNotifier(this._apiClient, this._ref) : super(BillsState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API)
    try {
      final localBills = await _localStorage.loadBills();
      state = state.copyWith(bills: localBills, isLoading: false);
      debugPrint('Loaded ${localBills.length} bills from local storage');
    } catch (e) {
      debugPrint('Error loading bills from local storage: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadBills() async {
    try {
      final localBills = await _localStorage.loadBills();
      state = state.copyWith(bills: localBills, isLoading: false);
    } catch (e) {
      debugPrint('Error loading bills: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addBill(Bill bill) {
    final updatedBills = [...state.bills, bill];
    state = state.copyWith(bills: updatedBills);

    _localStorage.saveBills(updatedBills);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.bill,
      entityId: bill.id,
      data: bill.toJson(),
    );
  }

  void updateBill(Bill bill) {
    final updatedBills = state.bills.map((b) {
      return b.id == bill.id ? bill : b;
    }).toList();
    state = state.copyWith(bills: updatedBills);

    _localStorage.saveBills(updatedBills);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.bill,
      entityId: bill.id,
      data: bill.toJson(),
    );
  }

  void recordPayment(String billId, double amount) {
    final updatedBills = state.bills.map((bill) {
      if (bill.id == billId) {
        final newAmountPaid = bill.amountPaid + amount;
        final newStatus = newAmountPaid >= bill.total
            ? BillStatus.paid
            : BillStatus.partial;
        return bill.copyWith(
          amountPaid: newAmountPaid,
          status: newStatus,
          updatedAt: DateTime.now(),
        );
      }
      return bill;
    }).toList();
    state = state.copyWith(bills: updatedBills);

    _localStorage.saveBills(updatedBills);

    final bill = updatedBills.firstWhere((b) => b.id == billId);
    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.bill,
      entityId: billId,
      data: bill.toJson(),
    );
  }
}

final billsProvider = StateNotifierProvider<BillsNotifier, BillsState>((ref) {
  return BillsNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Journal Entries Service - OFFLINE-FIRST
// ============================================================================

class JournalsState {
  final List<JournalEntry> entries;
  final bool isLoading;
  final String? error;

  JournalsState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  JournalsState copyWith({
    List<JournalEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return JournalsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class JournalsNotifier extends StateNotifier<JournalsState> {
  final ApiClient _apiClient;
  final Ref _ref;

  JournalsNotifier(this._apiClient, this._ref) : super(JournalsState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API)
    try {
      final localEntries = await _localStorage.loadJournalEntries();
      state = state.copyWith(entries: localEntries, isLoading: false);
      debugPrint('Loaded ${localEntries.length} journal entries from local storage');
    } catch (e) {
      debugPrint('Error loading journals from local storage: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadJournals() async {
    try {
      final localEntries = await _localStorage.loadJournalEntries();
      state = state.copyWith(entries: localEntries, isLoading: false);
    } catch (e) {
      debugPrint('Error loading journals: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addEntry(JournalEntry entry) {
    final updatedEntries = [...state.entries, entry];
    state = state.copyWith(entries: updatedEntries);

    _localStorage.saveJournalEntries(updatedEntries);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.journalEntry,
      entityId: entry.id,
      data: entry.toJson(),
    );
  }

  void postEntry(String entryId) {
    final updatedEntries = state.entries.map((e) {
      if (e.id == entryId) {
        return e.copyWith(
          status: JournalEntryStatus.posted,
          updatedAt: DateTime.now(),
        );
      }
      return e;
    }).toList();
    state = state.copyWith(entries: updatedEntries);

    _localStorage.saveJournalEntries(updatedEntries);

    final entry = updatedEntries.firstWhere((e) => e.id == entryId);
    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.journalEntry,
      entityId: entryId,
      data: entry.toJson(),
    );
  }
}

final journalsProvider = StateNotifierProvider<JournalsNotifier, JournalsState>((ref) {
  return JournalsNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Payments Service - OFFLINE-FIRST
// ============================================================================

class PaymentsState {
  final List<Payment> payments;
  final bool isLoading;
  final String? error;

  PaymentsState({
    this.payments = const [],
    this.isLoading = false,
    this.error,
  });

  PaymentsState copyWith({
    List<Payment>? payments,
    bool? isLoading,
    String? error,
  }) {
    return PaymentsState(
      payments: payments ?? this.payments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PaymentsNotifier extends StateNotifier<PaymentsState> {
  final ApiClient _apiClient;
  final Ref _ref;

  PaymentsNotifier(this._apiClient, this._ref) : super(PaymentsState()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Load from local storage only (no API)
    try {
      final localPayments = await _localStorage.loadPayments();
      state = state.copyWith(payments: localPayments, isLoading: false);
      debugPrint('Loaded ${localPayments.length} payments from local storage');
    } catch (e) {
      debugPrint('Error loading payments from local storage: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadPayments() async {
    try {
      final localPayments = await _localStorage.loadPayments();
      state = state.copyWith(payments: localPayments, isLoading: false);
    } catch (e) {
      debugPrint('Error loading payments: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void addPayment(Payment payment) {
    final updatedPayments = [...state.payments, payment];
    state = state.copyWith(payments: updatedPayments);

    _localStorage.savePayments(updatedPayments);

    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.create,
      entityType: SyncEntityType.payment,
      entityId: payment.id,
      data: payment.toJson(),
    );
  }
}

final paymentsProvider = StateNotifierProvider<PaymentsNotifier, PaymentsState>((ref) {
  return PaymentsNotifier(ref.read(apiClientProvider), ref);
});

// ============================================================================
// Outlets Service - Database Stream
// ============================================================================

/// Stream provider that watches outlets from database in real-time
final outletsStreamProvider = StreamProvider<List<Outlet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllOutlets();
});

/// Get active outlets count
final activeOutletsCountProvider = Provider<int>((ref) {
  final outletsAsync = ref.watch(outletsStreamProvider);
  return outletsAsync.when(
    data: (outlets) => outlets.where((o) => o.isActive).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Get outlets by region
final outletsByRegionProvider = Provider.family<List<Outlet>, String>((ref, region) {
  final outletsAsync = ref.watch(outletsStreamProvider);
  return outletsAsync.when(
    data: (outlets) {
      if (region == 'All') return outlets;
      return outlets.where((o) => o.region == region).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Sorted outlets stream (by outlet code/ID)
final sortedOutletsStreamProvider = Provider<Stream<List<Outlet>>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllOutlets().map((outlets) {
    outlets.sort((a, b) => a.outletCode.compareTo(b.outletCode));
    return outlets;
  });
});

// ============================================================================
// CSV Import Service - Import AccountingTotalsInOut.csv
// ============================================================================

class CsvImportResult {
  final int totalRows;
  final int importedRows;
  final int skippedRows;
  final int journalEntriesCreated;
  final List<String> errors;

  CsvImportResult({
    required this.totalRows,
    required this.importedRows,
    required this.skippedRows,
    required this.journalEntriesCreated,
    required this.errors,
  });
}

/// CSV Import state
class CsvImportState {
  final bool isImporting;
  final CsvImportResult? lastResult;
  final String? error;
  final double progress;

  CsvImportState({
    this.isImporting = false,
    this.lastResult,
    this.error,
    this.progress = 0,
  });

  CsvImportState copyWith({
    bool? isImporting,
    CsvImportResult? lastResult,
    String? error,
    double? progress,
  }) {
    return CsvImportState(
      isImporting: isImporting ?? this.isImporting,
      lastResult: lastResult ?? this.lastResult,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

class CsvImportNotifier extends StateNotifier<CsvImportState> {
  final AppDatabase _db;
  final Ref _ref;

  CsvImportNotifier(this._db, this._ref) : super(CsvImportState());

  /// Parse a number string like " 746,000 " or " 1,585,000 " to double
  double _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse date in m/d/yyyy format
  DateTime? _parseDate(String raw) {
    try {
      final trimmed = raw.trim();
      final parts = trimmed.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  /// Normalize CSV outlet code for DB lookup
  /// DB stores full codes like "23103000", CSV has same format
  String _mapOutletCode(String csvCode) {
    return csvCode.trim();
  }

  /// Import CSV file and create outlet revenue entries + journal entries
  Future<CsvImportResult> importCsvFile(String filePath) async {
    state = state.copyWith(isImporting: true, progress: 0, error: null);

    int totalRows = 0;
    int importedRows = 0;
    int skippedRows = 0;
    int journalEntriesCreated = 0;
    final errors = <String>[];

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        throw Exception('CSV file is empty');
      }

      // Skip header row
      totalRows = lines.length - 1;

      // Get all outlets for mapping
      final outlets = await _db.getAllOutlets();
      final outletMap = <String, Outlet>{};
      for (final outlet in outlets) {
        outletMap[outlet.outletCode] = outlet;
      }

      // Track journal entries to create
      final journalEntries = <JournalEntry>[];
      int jeCounter = 0;

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) {
          skippedRows++;
          continue;
        }

        try {
          // Parse CSV line (handle quoted fields with commas)
          final fields = _parseCsvLine(line);
          if (fields.length < 5) {
            errors.add('Row ${i + 1}: Not enough columns (${fields.length})');
            skippedRows++;
            continue;
          }

          final csvOutletCode = fields[0].trim();
          final dateStr = fields[1].trim();
          final totalIn = _parseAmount(fields[2]);
          final totalOut = _parseAmount(fields[3]);
          final totalGGR = _parseAmount(fields[4]);

          // Map outlet code
          final outletCode = _mapOutletCode(csvOutletCode);
          final outlet = outletMap[outletCode];

          if (outlet == null) {
            errors.add('Row ${i + 1}: Outlet $outletCode not found');
            skippedRows++;
            continue;
          }

          // Parse date
          final date = _parseDate(dateStr);
          if (date == null) {
            errors.add('Row ${i + 1}: Invalid date "$dateStr"');
            skippedRows++;
            continue;
          }

          // Create OutletRevenue entry
          // amount = Total In, commissionAmount = Total Out, netAmount = GGR
          final revenueId = _uuid.v4();
          final revenue = OutletRevenuesCompanion.insert(
            id: revenueId,
            outletId: outlet.id,
            date: date,
            amount: Value(totalIn),
            commissionAmount: Value(totalOut),
            netAmount: Value(totalGGR),
            description: Value('CSV Import: ${outlet.name} - ${DateFormat('MMM d, yyyy').format(date)}'),
            reference: Value('CSV-$csvOutletCode-${DateFormat('yyyyMMdd').format(date)}'),
            status: const Value('recorded'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _db.insertOutletRevenue(revenue);
          importedRows++;

          // Create journal entry for this revenue record
          jeCounter++;
          final jeId = _uuid.v4();
          final jeNumber = 'JE-CSV-${DateFormat('yyyyMMdd').format(date)}-${jeCounter.toString().padLeft(4, '0')}';

          journalEntries.add(JournalEntry(
            id: jeId,
            entryNumber: jeNumber,
            date: date,
            description: '${outlet.name} (${outlet.outletCode}) - Daily GGR',
            reference: 'CSV-$csvOutletCode-${DateFormat('yyyyMMdd').format(date)}',
            status: JournalEntryStatus.posted,
            lines: [
              // Debit: Outlet Cash Collections (Total In)
              JournalLine(id: '${jeId}-1', journalEntryId: jeId, accountId: 'acct-1200', accountCode: '1200', accountName: 'Outlet Cash Collections', debit: totalIn, credit: 0),
              // Credit: Customer Winnings / Payouts (Total Out)
              JournalLine(id: '${jeId}-2', journalEntryId: jeId, accountId: 'acct-5000', accountCode: '5000', accountName: 'Customer Winnings (Payouts)', debit: 0, credit: totalOut),
              // Credit: Gross Gaming Revenue (GGR)
              JournalLine(id: '${jeId}-3', journalEntryId: jeId, accountId: 'acct-4000', accountCode: '4000', accountName: 'Gross Gaming Revenue (GGR)', debit: 0, credit: totalGGR),
            ],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: 'CSV Import',
          ));

          // Update progress
          state = state.copyWith(progress: i / totalRows);

        } catch (e) {
          errors.add('Row ${i + 1}: $e');
          skippedRows++;
        }
      }

      // Save journal entries to local storage
      if (journalEntries.isNotEmpty) {
        try {
          final existingEntries = await _localStorage.loadJournalEntries();
          final allEntries = [...existingEntries, ...journalEntries];
          await _localStorage.saveJournalEntries(allEntries);
          journalEntriesCreated = journalEntries.length;

          // Update the journals provider state
          _ref.read(journalsProvider.notifier).state = JournalsState(
            entries: allEntries,
            isLoading: false,
          );
        } catch (e) {
          errors.add('Failed to save journal entries: $e');
        }
      }

      // Refresh dashboard data
      _ref.invalidate(dashboardDataProvider);

    } catch (e) {
      state = state.copyWith(isImporting: false, error: e.toString());
      return CsvImportResult(
        totalRows: totalRows,
        importedRows: importedRows,
        skippedRows: skippedRows,
        journalEntriesCreated: journalEntriesCreated,
        errors: [e.toString()],
      );
    }

    final result = CsvImportResult(
      totalRows: totalRows,
      importedRows: importedRows,
      skippedRows: skippedRows,
      journalEntriesCreated: journalEntriesCreated,
      errors: errors,
    );

    state = state.copyWith(
      isImporting: false,
      lastResult: result,
      progress: 1.0,
    );

    return result;
  }

  /// Parse a CSV line handling quoted fields with commas
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    fields.add(current.toString());

    return fields;
  }
}

final csvImportProvider = StateNotifierProvider<CsvImportNotifier, CsvImportState>((ref) {
  final db = ref.read(databaseProvider);
  return CsvImportNotifier(db, ref);
});

// ============================================================================
// Outlet Revenue Aggregation Providers
// ============================================================================

/// All outlet revenues stream
final allOutletRevenuesProvider = StreamProvider<List<OutletRevenue>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.outletRevenues).watch();
});

/// Stream provider for all outlet expenditures
final allOutletExpendituresProvider = StreamProvider<List<OutletExpenditure>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.outletExpenditures).watch();
});

/// Revenue summary per outlet
final outletRevenueSummaryProvider = FutureProvider<Map<String, Map<String, double>>>((ref) async {
  final db = ref.read(databaseProvider);
  final revenues = await db.getAllOutletRevenues();
  final outlets = await db.getAllOutlets();

  final summary = <String, Map<String, double>>{};

  for (final outlet in outlets) {
    final outletRevs = revenues.where((r) => r.outletId == outlet.id);
    double totalIn = 0, totalOut = 0, totalGGR = 0;
    for (final rev in outletRevs) {
      totalIn += rev.amount;
      totalOut += rev.commissionAmount;
      totalGGR += rev.netAmount;
    }
    summary[outlet.outletCode] = {
      'totalIn': totalIn,
      'totalOut': totalOut,
      'totalGGR': totalGGR,
      'days': outletRevs.length.toDouble(),
    };
  }

  return summary;
});

// ============================================================================
// Outlet Analytics — Carry-Forward Commission Engine
// ============================================================================
//
// Business Rules (MagicBet):
//  • Revenue data arrives weekly per outlet.
//  • 40% of GGR is the outlet expense (commission to location owner).
//  • If a week's adjusted GGR ≤ 0  → NO 40% deducted; full negative carried forward.
//  • If a week's adjusted GGR  > 0  → 40% deducted on the adjusted GGR.
//  • "Adjusted GGR" = raw week GGR + carriedForward (negative from prior week).
//  • Net Revenue = adjusted GGR × 60% (what MagicBet actually keeps).
//
// Example:
//   Week 1: rawGGR = -20 000 → adjustedGGR = -20 000 → no expense → carry -20 000
//   Week 2: rawGGR = 80 000  → adjustedGGR = 60 000  → expense = 24 000 → net = 36 000

class OutletWeekSummary {
  final String outletId;
  final String outletName;
  final String outletCode;
  final DateTime weekStart;   // Monday of the week
  final DateTime weekEnd;     // Sunday of the week
  final int weekNumber;
  final int year;
  final double rawGGR;
  final double carriedForward; // negative from previous week (≤ 0)
  final double adjustedGGR;
  final double outletExpense;  // 40% if adjustedGGR > 0, else 0
  final double netRevenue;     // what MagicBet keeps

  const OutletWeekSummary({
    required this.outletId,
    required this.outletName,
    required this.outletCode,
    required this.weekStart,
    required this.weekEnd,
    required this.weekNumber,
    required this.year,
    required this.rawGGR,
    required this.carriedForward,
    required this.adjustedGGR,
    required this.outletExpense,
    required this.netRevenue,
  });
}

class OutletMonthSummary {
  final String outletId;
  final String outletName;
  final String outletCode;
  final int year;
  final int month;
  final double totalGGR;
  final double totalOutletExpense;
  final double netRevenue;

  const OutletMonthSummary({
    required this.outletId,
    required this.outletName,
    required this.outletCode,
    required this.year,
    required this.month,
    required this.totalGGR,
    required this.totalOutletExpense,
    required this.netRevenue,
  });
}

class OutletAnalyticsData {
  final double totalGGR;
  final double totalOutletExpense;
  final double totalNetRevenue;
  final int totalActiveOutlets;
  final List<OutletWeekSummary> allWeeks;   // all outlets × all weeks
  final List<OutletMonthSummary> allMonths; // all outlets × all months
  // Per-outlet lifetime totals
  final List<OutletLifetime> lifetimeTotals;

  const OutletAnalyticsData({
    required this.totalGGR,
    required this.totalOutletExpense,
    required this.totalNetRevenue,
    required this.totalActiveOutlets,
    required this.allWeeks,
    required this.allMonths,
    required this.lifetimeTotals,
  });

  static const empty = OutletAnalyticsData(
    totalGGR: 0,
    totalOutletExpense: 0,
    totalNetRevenue: 0,
    totalActiveOutlets: 0,
    allWeeks: [],
    allMonths: [],
    lifetimeTotals: [],
  );
}

class OutletLifetime {
  final String outletId;
  final String outletName;
  final String outletCode;
  final double totalGGR;
  final double totalOutletExpense;
  final double netRevenue;

  const OutletLifetime({
    required this.outletId,
    required this.outletName,
    required this.outletCode,
    required this.totalGGR,
    required this.totalOutletExpense,
    required this.netRevenue,
  });
}

// Returns the Monday (start) of the ISO week containing [date].
DateTime _weekStart(DateTime date) {
  final diff = date.weekday - DateTime.monday;
  return DateTime(date.year, date.month, date.day - diff);
}

// Key for grouping: "yyyy-Www" e.g. "2025-W12"
String _weekKey(DateTime date) {
  final start = _weekStart(date);
  // ISO week number: days from Jan 4 of year (first week always contains Jan 4)
  final jan4 = DateTime(start.year, 1, 4);
  final weekNum = ((start.difference(jan4).inDays + jan4.weekday) / 7).ceil();
  return '${start.year}-W${weekNum.toString().padLeft(2, '0')}';
}

int _isoWeekNumber(DateTime date) {
  final start = _weekStart(date);
  final jan4 = DateTime(start.year, 1, 4);
  return ((start.difference(jan4).inDays + jan4.weekday) / 7).ceil();
}

List<OutletWeekSummary> _computeWeeksForOutlet(
  Outlet outlet,
  List<OutletRevenue> revenues,
) {
  if (revenues.isEmpty) return [];

  // Group raw GGR by ISO week
  final weekRaw = <String, double>{};
  final weekStartDates = <String, DateTime>{};

  for (final rev in revenues) {
    final key = _weekKey(rev.date);
    weekRaw[key] = (weekRaw[key] ?? 0) + rev.netAmount;
    final ws = _weekStart(rev.date);
    if (!weekStartDates.containsKey(key) || ws.isBefore(weekStartDates[key]!)) {
      weekStartDates[key] = ws;
    }
  }

  // Sort weeks chronologically
  final sortedKeys = weekRaw.keys.toList()..sort();

  final summaries = <OutletWeekSummary>[];
  double carriedForward = 0; // negative balance carried from previous week

  for (final key in sortedKeys) {
    final rawGGR = weekRaw[key]!;
    final ws = weekStartDates[key]!;
    final incomingCarry = carriedForward; // capture before update
    final adjustedGGR = rawGGR + incomingCarry;
    final double outletExpense;
    final double netRevenue;

    if (adjustedGGR > 0) {
      outletExpense = adjustedGGR * 0.40;
      netRevenue = adjustedGGR * 0.60;
      carriedForward = 0;
    } else {
      outletExpense = 0;
      netRevenue = adjustedGGR;
      carriedForward = adjustedGGR;
    }

    summaries.add(OutletWeekSummary(
      outletId: outlet.id,
      outletName: outlet.name,
      outletCode: outlet.outletCode,
      weekStart: ws,
      weekEnd: ws.add(const Duration(days: 6)),
      weekNumber: _isoWeekNumber(ws),
      year: ws.year,
      rawGGR: rawGGR,
      carriedForward: incomingCarry, // what came in from previous week
      adjustedGGR: adjustedGGR,
      outletExpense: outletExpense,
      netRevenue: netRevenue,
    ));
  }

  return summaries;
}

final outletAnalyticsProvider = FutureProvider<OutletAnalyticsData>((ref) async {
  final db = ref.read(databaseProvider);
  final outlets = await db.getAllOutlets();
  final allRevenues = await db.getAllOutletRevenues();

  if (outlets.isEmpty || allRevenues.isEmpty) return OutletAnalyticsData.empty;

  final revenuesByOutlet = <String, List<OutletRevenue>>{};
  for (final rev in allRevenues) {
    revenuesByOutlet.putIfAbsent(rev.outletId, () => []).add(rev);
  }

  final allWeeks = <OutletWeekSummary>[];
  final allMonths = <OutletMonthSummary>[];
  final lifetimes = <OutletLifetime>[];

  for (final outlet in outlets) {
    final revs = revenuesByOutlet[outlet.id] ?? [];
    final weeks = _computeWeeksForOutlet(outlet, revs);
    allWeeks.addAll(weeks);

    // Aggregate months from weekly summaries (use adjustedGGR and outletExpense)
    // Group weeks into months by weekStart month
    final monthMap = <String, _MonthAccum>{};
    for (final w in weeks) {
      final mk = '${w.year}-${w.weekStart.month.toString().padLeft(2, '0')}';
      monthMap.putIfAbsent(mk, () => _MonthAccum(w.weekStart.year, w.weekStart.month));
      monthMap[mk]!.addWeek(w);
    }
    for (final accum in monthMap.values) {
      allMonths.add(OutletMonthSummary(
        outletId: outlet.id,
        outletName: outlet.name,
        outletCode: outlet.outletCode,
        year: accum.year,
        month: accum.month,
        totalGGR: accum.totalGGR,
        totalOutletExpense: accum.totalOutletExpense,
        netRevenue: accum.netRevenue,
      ));
    }

    // Lifetime totals per outlet
    final lifetimeGGR = weeks.fold(0.0, (s, w) => s + w.rawGGR);
    final lifetimeExpense = weeks.fold(0.0, (s, w) => s + w.outletExpense);
    final lifetimeNet = weeks.fold(0.0, (s, w) => s + w.netRevenue);
    lifetimes.add(OutletLifetime(
      outletId: outlet.id,
      outletName: outlet.name,
      outletCode: outlet.outletCode,
      totalGGR: lifetimeGGR,
      totalOutletExpense: lifetimeExpense,
      netRevenue: lifetimeNet,
    ));
  }

  final grandGGR = lifetimes.fold(0.0, (s, o) => s + o.totalGGR);
  final grandExpense = lifetimes.fold(0.0, (s, o) => s + o.totalOutletExpense);
  final grandNet = lifetimes.fold(0.0, (s, o) => s + o.netRevenue);

  return OutletAnalyticsData(
    totalGGR: grandGGR,
    totalOutletExpense: grandExpense,
    totalNetRevenue: grandNet,
    totalActiveOutlets: outlets.where((o) => o.isActive).length,
    allWeeks: allWeeks,
    allMonths: allMonths,
    lifetimeTotals: lifetimes,
  );
});

class _MonthAccum {
  final int year;
  final int month;
  double totalGGR = 0;
  double totalOutletExpense = 0;
  double netRevenue = 0;
  _MonthAccum(this.year, this.month);
  void addWeek(OutletWeekSummary w) {
    totalGGR += w.rawGGR;
    totalOutletExpense += w.outletExpense;
    netRevenue += w.netRevenue;
  }
}
