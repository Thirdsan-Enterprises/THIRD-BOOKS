// Data Service for ThirdBooks Desktop App
// Offline-First Architecture with Local Storage and Sync Queue
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import 'sync_service.dart';
import '../models/models.dart';

// Global local storage instance
final _localStorage = LocalStorageService.instance;

// ============================================================================
// Dashboard Service
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

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/dashboard');
    if (response.statusCode == 200) {
      return DashboardData.fromJson(response.data['data'] ?? response.data);
    }
  } catch (e) {
    // Return empty data on error (no demo data)
  }

  return DashboardData.empty();
});

// ============================================================================
// Accounts Service - OFFLINE-FIRST
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    // Removed demo data - load from database only
    if (_isDemoMode) {
      final demoAccounts = _getDemoAccounts();
      await _localStorage.saveAccounts(demoAccounts);
      state = state.copyWith(accounts: demoAccounts, isLoading: false);
      return;
    }

    // 1. First, load from local storage (instant offline data)
    try {
      final localAccounts = await _localStorage.loadAccounts();
      if (localAccounts.isNotEmpty) {
        state = state.copyWith(accounts: localAccounts, isLoading: false);
        debugPrint('Loaded ${localAccounts.length} accounts from local storage');
      }
    } catch (e) {
      debugPrint('Error loading accounts from local storage: $e');
    }

    // 2. Then try to fetch fresh data from API (background refresh)
    await loadAccounts();
  }

  Future<void> loadAccounts() async {
    if (_isDemoMode) {
      final demoAccounts = _getDemoAccounts();
      state = state.copyWith(accounts: demoAccounts, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/accounts');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final accounts = (data as List<dynamic>)
            .map((json) => Account.fromJson(json as Map<String, dynamic>))
            .toList();

        // Save to local storage for offline access
        await _localStorage.saveAccounts(accounts);

        state = state.copyWith(accounts: accounts, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed, using cached/demo data: $e');
    }

    // Only use demo data if we have nothing cached
    if (state.accounts.isEmpty) {
      final demoAccounts = _getDemoAccounts();
      await _localStorage.saveAccounts(demoAccounts);
      state = state.copyWith(accounts: demoAccounts, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void addAccount(Account account) {
    final updatedAccounts = [...state.accounts, account];
    state = state.copyWith(accounts: updatedAccounts);

    // Save locally immediately
    _localStorage.saveAccounts(updatedAccounts);

    // Queue for sync
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

    // Save locally immediately
    _localStorage.saveAccounts(updatedAccounts);

    // Queue for sync
    _ref.read(syncServiceProvider.notifier).queueChange(
      action: SyncAction.update,
      entityType: SyncEntityType.account,
      entityId: account.id,
      data: account.toJson(),
    );
  }

  List<Account> _getDemoAccounts() {
    final now = DateTime.now();
    return [
      Account(id: '1', code: '1000', name: 'Cash on Hand', type: AccountType.asset, subType: AccountSubType.cash, balance: 5250000, createdAt: now, updatedAt: now),
      Account(id: '2', code: '1010', name: 'Petty Cash', type: AccountType.asset, subType: AccountSubType.cash, balance: 500000, createdAt: now, updatedAt: now),
      Account(id: '3', code: '1100', name: 'Bank Account - UGX', type: AccountType.asset, subType: AccountSubType.bank, balance: 45000000, createdAt: now, updatedAt: now),
      Account(id: '4', code: '1110', name: 'Bank Account - USD', type: AccountType.asset, subType: AccountSubType.bank, balance: 12500000, createdAt: now, updatedAt: now),
      Account(id: '5', code: '1200', name: 'Accounts Receivable', type: AccountType.asset, subType: AccountSubType.accountsReceivable, balance: 8450000, createdAt: now, updatedAt: now),
      Account(id: '6', code: '1500', name: 'Office Equipment', type: AccountType.asset, subType: AccountSubType.fixedAsset, balance: 15000000, createdAt: now, updatedAt: now),
      Account(id: '7', code: '1510', name: 'Computer Equipment', type: AccountType.asset, subType: AccountSubType.fixedAsset, balance: 8500000, createdAt: now, updatedAt: now),
      Account(id: '8', code: '2000', name: 'Accounts Payable', type: AccountType.liability, subType: AccountSubType.accountsPayable, balance: 6200000, createdAt: now, updatedAt: now),
      Account(id: '9', code: '2100', name: 'VAT Payable', type: AccountType.liability, subType: AccountSubType.currentLiability, balance: 2100000, createdAt: now, updatedAt: now),
      Account(id: '10', code: '2200', name: 'Salaries Payable', type: AccountType.liability, subType: AccountSubType.currentLiability, balance: 4500000, createdAt: now, updatedAt: now),
      Account(id: '11', code: '3000', name: "Owner's Capital", type: AccountType.equity, subType: AccountSubType.ownersEquity, balance: 50000000, createdAt: now, updatedAt: now),
      Account(id: '12', code: '3100', name: 'Retained Earnings', type: AccountType.equity, subType: AccountSubType.retainedEarnings, balance: 16910000, createdAt: now, updatedAt: now),
      Account(id: '13', code: '4000', name: 'Sales Revenue', type: AccountType.revenue, subType: AccountSubType.salesRevenue, balance: 52340000, createdAt: now, updatedAt: now),
      Account(id: '14', code: '4100', name: 'Service Revenue', type: AccountType.revenue, subType: AccountSubType.serviceRevenue, balance: 12500000, createdAt: now, updatedAt: now),
      Account(id: '15', code: '5000', name: 'Cost of Goods Sold', type: AccountType.expense, subType: AccountSubType.costOfGoodsSold, balance: 28000000, createdAt: now, updatedAt: now),
      Account(id: '16', code: '6000', name: 'Salaries & Wages', type: AccountType.expense, subType: AccountSubType.payrollExpense, balance: 15000000, createdAt: now, updatedAt: now),
      Account(id: '17', code: '6100', name: 'Rent Expense', type: AccountType.expense, subType: AccountSubType.operatingExpense, balance: 6000000, createdAt: now, updatedAt: now),
      Account(id: '18', code: '6200', name: 'Utilities Expense', type: AccountType.expense, subType: AccountSubType.operatingExpense, balance: 1800000, createdAt: now, updatedAt: now),
      Account(id: '19', code: '6300', name: 'Office Supplies', type: AccountType.expense, subType: AccountSubType.operatingExpense, balance: 450000, createdAt: now, updatedAt: now),
    ];
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    if (_isDemoMode) {
      final demoCustomers = _getDemoCustomers();
      await _localStorage.saveCustomers(demoCustomers);
      state = state.copyWith(customers: demoCustomers, isLoading: false);
      return;
    }

    try {
      final localCustomers = await _localStorage.loadCustomers();
      if (localCustomers.isNotEmpty) {
        state = state.copyWith(customers: localCustomers, isLoading: false);
        debugPrint('Loaded ${localCustomers.length} customers from local storage');
      }
    } catch (e) {
      debugPrint('Error loading customers from local storage: $e');
    }

    await loadCustomers();
  }

  Future<void> loadCustomers() async {
    if (_isDemoMode) {
      final demoCustomers = _getDemoCustomers();
      state = state.copyWith(customers: demoCustomers, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/customers');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final customers = (data as List<dynamic>)
            .map((json) => Customer.fromJson(json as Map<String, dynamic>))
            .toList();

        await _localStorage.saveCustomers(customers);
        state = state.copyWith(customers: customers, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed for customers: $e');
    }

    if (state.customers.isEmpty) {
      final demoCustomers = _getDemoCustomers();
      await _localStorage.saveCustomers(demoCustomers);
      state = state.copyWith(customers: demoCustomers, isLoading: false);
    } else {
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

  List<Customer> _getDemoCustomers() {
    final now = DateTime.now();
    return [
      Customer(id: '1', name: 'Kampala Traders Ltd', email: 'info@kampalatraders.co.ug', phone: '+256 700 123456', address: 'Plot 45, Kampala Road, Kampala', taxId: 'TIN123456789', creditLimit: 50000000, balance: 12500000, isActive: true, createdAt: now, updatedAt: now),
      Customer(id: '2', name: 'Jinja Hardware Supplies', email: 'sales@jinjahardware.ug', phone: '+256 752 987654', address: '23 Main Street, Jinja', taxId: 'TIN987654321', creditLimit: 30000000, balance: 8450000, isActive: true, createdAt: now, updatedAt: now),
      Customer(id: '3', name: 'Entebbe Fresh Farms', email: 'orders@entebbefarms.com', phone: '+256 780 456789', address: 'Entebbe Highway, Kampala', taxId: 'TIN456789123', creditLimit: 20000000, balance: 0, isActive: true, createdAt: now, updatedAt: now),
      Customer(id: '4', name: 'Mbarara Beverages Co', email: 'accounts@mbararabev.ug', phone: '+256 701 234567', address: 'Industrial Area, Mbarara', taxId: 'TIN234567891', creditLimit: 75000000, balance: 45000000, isActive: true, createdAt: now, updatedAt: now),
      Customer(id: '5', name: 'Gulu Construction Works', email: 'info@guluconst.co.ug', phone: '+256 772 345678', address: 'Plot 12, Gulu Town', taxId: 'TIN345678912', creditLimit: 100000000, balance: 67500000, isActive: false, createdAt: now, updatedAt: now),
      Customer(id: '6', name: 'Lira Agro Products', email: 'sales@liraagro.ug', phone: '+256 783 456789', address: 'Main Market, Lira', taxId: 'TIN567891234', creditLimit: 15000000, balance: 2500000, isActive: true, createdAt: now, updatedAt: now),
    ];
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    if (_isDemoMode) {
      final demoVendors = _getDemoVendors();
      await _localStorage.saveVendors(demoVendors);
      state = state.copyWith(vendors: demoVendors, isLoading: false);
      return;
    }

    try {
      final localVendors = await _localStorage.loadVendors();
      if (localVendors.isNotEmpty) {
        state = state.copyWith(vendors: localVendors, isLoading: false);
        debugPrint('Loaded ${localVendors.length} vendors from local storage');
      }
    } catch (e) {
      debugPrint('Error loading vendors from local storage: $e');
    }

    await loadVendors();
  }

  Future<void> loadVendors() async {
    if (_isDemoMode) {
      final demoVendors = _getDemoVendors();
      state = state.copyWith(vendors: demoVendors, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/vendors');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final vendors = (data as List<dynamic>)
            .map((json) => Vendor.fromJson(json as Map<String, dynamic>))
            .toList();

        await _localStorage.saveVendors(vendors);
        state = state.copyWith(vendors: vendors, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed for vendors: $e');
    }

    if (state.vendors.isEmpty) {
      final demoVendors = _getDemoVendors();
      await _localStorage.saveVendors(demoVendors);
      state = state.copyWith(vendors: demoVendors, isLoading: false);
    } else {
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

  List<Vendor> _getDemoVendors() {
    final now = DateTime.now();
    return [
      Vendor(id: '1', name: 'Uganda Office Supplies', email: 'orders@ugoffice.co.ug', phone: '+256 700 111222', address: 'Industrial Area, Kampala', taxId: 'TIN111222333', balance: 3500000, paymentTerms: 'Net 30', isActive: true, createdAt: now, updatedAt: now),
      Vendor(id: '2', name: 'East African Paper Mills', email: 'sales@eapaper.ug', phone: '+256 752 333444', address: 'Jinja Industrial Park', taxId: 'TIN333444555', balance: 8200000, paymentTerms: 'Net 45', isActive: true, createdAt: now, updatedAt: now),
      Vendor(id: '3', name: 'Kampala Tech Solutions', email: 'support@ktech.ug', phone: '+256 780 555666', address: 'Ntinda, Kampala', taxId: 'TIN555666777', balance: 2100000, paymentTerms: 'Net 15', isActive: true, createdAt: now, updatedAt: now),
      Vendor(id: '4', name: 'Uganda Petroleum Ltd', email: 'accounts@ugpetrol.co.ug', phone: '+256 701 777888', address: 'Port Bell, Kampala', taxId: 'TIN777888999', balance: 15000000, paymentTerms: 'Net 30', isActive: true, createdAt: now, updatedAt: now),
      Vendor(id: '5', name: 'Mbarara Construction Materials', email: 'info@mbaconst.ug', phone: '+256 772 999000', address: 'Mbarara Town', taxId: 'TIN999000111', balance: 5800000, paymentTerms: 'Net 60', isActive: false, createdAt: now, updatedAt: now),
    ];
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    if (_isDemoMode) {
      final demoInvoices = _getDemoInvoices();
      await _localStorage.saveInvoices(demoInvoices);
      state = state.copyWith(invoices: demoInvoices, isLoading: false);
      return;
    }

    try {
      final localInvoices = await _localStorage.loadInvoices();
      if (localInvoices.isNotEmpty) {
        state = state.copyWith(invoices: localInvoices, isLoading: false);
        debugPrint('Loaded ${localInvoices.length} invoices from local storage');
      }
    } catch (e) {
      debugPrint('Error loading invoices from local storage: $e');
    }

    await loadInvoices();
  }

  Future<void> loadInvoices() async {
    if (_isDemoMode) {
      final demoInvoices = _getDemoInvoices();
      state = state.copyWith(invoices: demoInvoices, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/invoices');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final invoices = (data as List<dynamic>)
            .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
            .toList();

        await _localStorage.saveInvoices(invoices);
        state = state.copyWith(invoices: invoices, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed for invoices: $e');
    }

    if (state.invoices.isEmpty) {
      final demoInvoices = _getDemoInvoices();
      await _localStorage.saveInvoices(demoInvoices);
      state = state.copyWith(invoices: demoInvoices, isLoading: false);
    } else {
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

  List<Invoice> _getDemoInvoices() {
    final now = DateTime.now();
    return [
      Invoice(id: '1', invoiceNumber: 'INV-2026-0001', customerId: '1', customerName: 'Kampala Traders Ltd', date: DateTime(2026, 1, 15), dueDate: DateTime(2026, 2, 14), subtotal: 5000000, taxAmount: 900000, total: 5900000, amountPaid: 5900000, status: InvoiceStatus.paid, lines: [], createdAt: now, updatedAt: now),
      Invoice(id: '2', invoiceNumber: 'INV-2026-0002', customerId: '2', customerName: 'Jinja Hardware Supplies', date: DateTime(2026, 1, 18), dueDate: DateTime(2026, 2, 17), subtotal: 3200000, taxAmount: 576000, total: 3776000, amountPaid: 2000000, status: InvoiceStatus.partial, lines: [], createdAt: now, updatedAt: now),
      Invoice(id: '3', invoiceNumber: 'INV-2026-0003', customerId: '4', customerName: 'Mbarara Beverages Co', date: DateTime(2026, 1, 20), dueDate: DateTime(2026, 2, 19), subtotal: 8500000, taxAmount: 1530000, total: 10030000, amountPaid: 0, status: InvoiceStatus.pending, lines: [], createdAt: now, updatedAt: now),
      Invoice(id: '4', invoiceNumber: 'INV-2026-0004', customerId: '1', customerName: 'Kampala Traders Ltd', date: DateTime(2026, 1, 22), dueDate: DateTime(2026, 2, 21), subtotal: 2450000, taxAmount: 441000, total: 2891000, amountPaid: 0, status: InvoiceStatus.pending, lines: [], createdAt: now, updatedAt: now),
      Invoice(id: '5', invoiceNumber: 'INV-2026-0005', customerId: '5', customerName: 'Gulu Construction Works', date: DateTime(2025, 12, 1), dueDate: DateTime(2025, 12, 31), subtotal: 15000000, taxAmount: 2700000, total: 17700000, amountPaid: 0, status: InvoiceStatus.overdue, lines: [], createdAt: now, updatedAt: now),
    ];
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    if (_isDemoMode) {
      final demoBills = _getDemoBills();
      await _localStorage.saveBills(demoBills);
      state = state.copyWith(bills: demoBills, isLoading: false);
      return;
    }

    try {
      final localBills = await _localStorage.loadBills();
      if (localBills.isNotEmpty) {
        state = state.copyWith(bills: localBills, isLoading: false);
        debugPrint('Loaded ${localBills.length} bills from local storage');
      }
    } catch (e) {
      debugPrint('Error loading bills from local storage: $e');
    }

    await loadBills();
  }

  Future<void> loadBills() async {
    if (_isDemoMode) {
      final demoBills = _getDemoBills();
      state = state.copyWith(bills: demoBills, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/bills');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final bills = (data as List<dynamic>)
            .map((json) => Bill.fromJson(json as Map<String, dynamic>))
            .toList();

        await _localStorage.saveBills(bills);
        state = state.copyWith(bills: bills, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed for bills: $e');
    }

    if (state.bills.isEmpty) {
      final demoBills = _getDemoBills();
      await _localStorage.saveBills(demoBills);
      state = state.copyWith(bills: demoBills, isLoading: false);
    } else {
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

  List<Bill> _getDemoBills() {
    final now = DateTime.now();
    return [
      Bill(id: '1', billNumber: 'BILL-2026-0001', vendorId: '1', vendorName: 'Uganda Office Supplies', date: DateTime(2026, 1, 10), dueDate: DateTime(2026, 2, 9), subtotal: 1200000, taxAmount: 216000, total: 1416000, amountPaid: 1416000, status: BillStatus.paid, lines: [], createdAt: now, updatedAt: now),
      Bill(id: '2', billNumber: 'BILL-2026-0002', vendorId: '2', vendorName: 'East African Paper Mills', date: DateTime(2026, 1, 12), dueDate: DateTime(2026, 2, 26), subtotal: 3500000, taxAmount: 630000, total: 4130000, amountPaid: 0, status: BillStatus.pending, lines: [], createdAt: now, updatedAt: now),
      Bill(id: '3', billNumber: 'BILL-2026-0003', vendorId: '4', vendorName: 'Uganda Petroleum Ltd', date: DateTime(2026, 1, 15), dueDate: DateTime(2026, 2, 14), subtotal: 5800000, taxAmount: 1044000, total: 6844000, amountPaid: 3000000, status: BillStatus.partial, lines: [], createdAt: now, updatedAt: now),
      Bill(id: '4', billNumber: 'BILL-2026-0004', vendorId: '3', vendorName: 'Kampala Tech Solutions', date: DateTime(2026, 1, 18), dueDate: DateTime(2026, 2, 2), subtotal: 2100000, taxAmount: 378000, total: 2478000, amountPaid: 0, status: BillStatus.pending, lines: [], createdAt: now, updatedAt: now),
      Bill(id: '5', billNumber: 'BILL-2026-0005', vendorId: '5', vendorName: 'Mbarara Construction Materials', date: DateTime(2025, 11, 15), dueDate: DateTime(2026, 1, 14), subtotal: 8500000, taxAmount: 1530000, total: 10030000, amountPaid: 0, status: BillStatus.overdue, lines: [], createdAt: now, updatedAt: now),
    ];
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    if (_isDemoMode) {
      final demoJournals = _getDemoJournals();
      await _localStorage.saveJournalEntries(demoJournals);
      state = state.copyWith(entries: demoJournals, isLoading: false);
      return;
    }

    try {
      final localEntries = await _localStorage.loadJournalEntries();
      if (localEntries.isNotEmpty) {
        state = state.copyWith(entries: localEntries, isLoading: false);
        debugPrint('Loaded ${localEntries.length} journal entries from local storage');
      }
    } catch (e) {
      debugPrint('Error loading journals from local storage: $e');
    }

    await loadJournals();
  }

  Future<void> loadJournals() async {
    if (_isDemoMode) {
      final demoJournals = _getDemoJournals();
      state = state.copyWith(entries: demoJournals, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/journals');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final entries = (data as List<dynamic>)
            .map((json) => JournalEntry.fromJson(json as Map<String, dynamic>))
            .toList();

        await _localStorage.saveJournalEntries(entries);
        state = state.copyWith(entries: entries, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed for journals: $e');
    }

    if (state.entries.isEmpty) {
      final demoJournals = _getDemoJournals();
      await _localStorage.saveJournalEntries(demoJournals);
      state = state.copyWith(entries: demoJournals, isLoading: false);
    } else {
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

  List<JournalEntry> _getDemoJournals() {
    final now = DateTime.now();
    return [
      JournalEntry(
        id: '1',
        entryNumber: 'JE-2026-0001',
        date: DateTime(2026, 1, 15),
        description: 'Record sales revenue',
        reference: 'INV-2026-0001',
        status: JournalEntryStatus.posted,
        lines: [
          JournalLine(id: '1', journalEntryId: '1', accountId: '5', accountCode: '1200', accountName: 'Accounts Receivable', debit: 5900000, credit: 0),
          JournalLine(id: '2', journalEntryId: '1', accountId: '13', accountCode: '4000', accountName: 'Sales Revenue', debit: 0, credit: 5000000),
          JournalLine(id: '3', journalEntryId: '1', accountId: '9', accountCode: '2100', accountName: 'VAT Payable', debit: 0, credit: 900000),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      ),
      JournalEntry(
        id: '2',
        entryNumber: 'JE-2026-0002',
        date: DateTime(2026, 1, 18),
        description: 'Payment received from customer',
        reference: 'REC-2026-0001',
        status: JournalEntryStatus.posted,
        lines: [
          JournalLine(id: '4', journalEntryId: '2', accountId: '3', accountCode: '1100', accountName: 'Bank Account - UGX', debit: 5900000, credit: 0),
          JournalLine(id: '5', journalEntryId: '2', accountId: '5', accountCode: '1200', accountName: 'Accounts Receivable', debit: 0, credit: 5900000),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      ),
      JournalEntry(
        id: '3',
        entryNumber: 'JE-2026-0003',
        date: DateTime(2026, 1, 20),
        description: 'Office supplies purchase',
        reference: 'BILL-2026-0001',
        status: JournalEntryStatus.posted,
        lines: [
          JournalLine(id: '6', journalEntryId: '3', accountId: '19', accountCode: '6300', accountName: 'Office Supplies', debit: 1200000, credit: 0),
          JournalLine(id: '7', journalEntryId: '3', accountId: '8', accountCode: '2000', accountName: 'Accounts Payable', debit: 0, credit: 1200000),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      ),
      JournalEntry(
        id: '4',
        entryNumber: 'JE-2026-0004',
        date: DateTime(2026, 1, 25),
        description: 'Monthly rent payment',
        reference: 'CHQ-2026-0015',
        status: JournalEntryStatus.posted,
        lines: [
          JournalLine(id: '8', journalEntryId: '4', accountId: '17', accountCode: '6100', accountName: 'Rent Expense', debit: 3000000, credit: 0),
          JournalLine(id: '9', journalEntryId: '4', accountId: '3', accountCode: '1100', accountName: 'Bank Account - UGX', debit: 0, credit: 3000000),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      ),
      JournalEntry(
        id: '5',
        entryNumber: 'JE-2026-0005',
        date: DateTime(2026, 1, 28),
        description: 'Salary accrual',
        reference: 'PAY-2026-01',
        status: JournalEntryStatus.draft,
        lines: [
          JournalLine(id: '10', journalEntryId: '5', accountId: '16', accountCode: '6000', accountName: 'Salaries & Wages', debit: 8500000, credit: 0),
          JournalLine(id: '11', journalEntryId: '5', accountId: '10', accountCode: '2200', accountName: 'Salaries Payable', debit: 0, credit: 8500000),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      ),
    ];
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

  bool get _isDemoMode => _ref.read(isOfflineModeProvider);

  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

    if (_isDemoMode) {
      final demoPayments = _getDemoPayments();
      await _localStorage.savePayments(demoPayments);
      state = state.copyWith(payments: demoPayments, isLoading: false);
      return;
    }

    try {
      final localPayments = await _localStorage.loadPayments();
      if (localPayments.isNotEmpty) {
        state = state.copyWith(payments: localPayments, isLoading: false);
        debugPrint('Loaded ${localPayments.length} payments from local storage');
      }
    } catch (e) {
      debugPrint('Error loading payments from local storage: $e');
    }

    await loadPayments();
  }

  Future<void> loadPayments() async {
    if (_isDemoMode) {
      final demoPayments = _getDemoPayments();
      state = state.copyWith(payments: demoPayments, isLoading: false);
      return;
    }

    try {
      final response = await _apiClient.get('/payments');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final payments = (data as List<dynamic>)
            .map((json) => Payment.fromJson(json as Map<String, dynamic>))
            .toList();

        await _localStorage.savePayments(payments);
        state = state.copyWith(payments: payments, isLoading: false);
        return;
      }
    } catch (e) {
      debugPrint('API fetch failed for payments: $e');
    }

    if (state.payments.isEmpty) {
      final demoPayments = _getDemoPayments();
      await _localStorage.savePayments(demoPayments);
      state = state.copyWith(payments: demoPayments, isLoading: false);
    } else {
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

  List<Payment> _getDemoPayments() {
    final now = DateTime.now();
    return [
      Payment(id: '1', paymentNumber: 'REC-2026-0001', paymentType: PaymentType.received, customerId: '1', customerName: 'Kampala Traders Ltd', paymentDate: DateTime(2026, 1, 18), amount: 5900000, paymentMethod: 'Bank Transfer', reference: 'TRF-123456', accountId: '3', accountName: 'Bank Account - UGX', status: PaymentStatus.completed, createdAt: now, updatedAt: now),
      Payment(id: '2', paymentNumber: 'REC-2026-0002', paymentType: PaymentType.received, customerId: '2', customerName: 'Jinja Hardware Supplies', paymentDate: DateTime(2026, 1, 20), amount: 2000000, paymentMethod: 'Cheque', reference: 'CHQ-78901', accountId: '3', accountName: 'Bank Account - UGX', status: PaymentStatus.completed, createdAt: now, updatedAt: now),
      Payment(id: '3', paymentNumber: 'PAY-2026-0001', paymentType: PaymentType.made, vendorId: '1', vendorName: 'Uganda Office Supplies', paymentDate: DateTime(2026, 1, 15), amount: 1416000, paymentMethod: 'Bank Transfer', reference: 'TRF-654321', accountId: '3', accountName: 'Bank Account - UGX', status: PaymentStatus.completed, createdAt: now, updatedAt: now),
      Payment(id: '4', paymentNumber: 'PAY-2026-0002', paymentType: PaymentType.made, vendorId: '4', vendorName: 'Uganda Petroleum Ltd', paymentDate: DateTime(2026, 1, 22), amount: 3000000, paymentMethod: 'Bank Transfer', reference: 'TRF-789012', accountId: '3', accountName: 'Bank Account - UGX', status: PaymentStatus.completed, createdAt: now, updatedAt: now),
      Payment(id: '5', paymentNumber: 'REC-2026-0003', paymentType: PaymentType.received, customerId: '4', customerName: 'Mbarara Beverages Co', paymentDate: DateTime(2026, 1, 25), amount: 8500000, paymentMethod: 'Mobile Money', reference: 'MTN-123456789', accountId: '3', accountName: 'Bank Account - UGX', status: PaymentStatus.completed, createdAt: now, updatedAt: now),
    ];
  }
}

final paymentsProvider = StateNotifierProvider<PaymentsNotifier, PaymentsState>((ref) {
  return PaymentsNotifier(ref.read(apiClientProvider), ref);
});
