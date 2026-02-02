// Data Service for ThirdBooks Desktop App
// Connects to the API and provides data to all screens
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import '../models/models.dart';

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

  // Default demo data for offline mode
  factory DashboardData.demo() {
    return DashboardData(
      totalRevenue: 45250000,
      totalExpenses: 28340000,
      netIncome: 16910000,
      outstandingInvoices: 8450000,
      invoiceCount: 12,
      revenueChange: 12.5,
      expenseChange: 5.2,
      incomeChange: 18.3,
      cashIn: 52340000,
      cashOut: 38120000,
      netCash: 14220000,
      revenueData: [
        {'month': 0, 'value': 35000000},
        {'month': 1, 'value': 42000000},
        {'month': 2, 'value': 38000000},
        {'month': 3, 'value': 45000000},
        {'month': 4, 'value': 48000000},
        {'month': 5, 'value': 52000000},
      ],
      expenseData: [
        {'month': 0, 'value': 25000000},
        {'month': 1, 'value': 28000000},
        {'month': 2, 'value': 24000000},
        {'month': 3, 'value': 30000000},
        {'month': 4, 'value': 32000000},
        {'month': 5, 'value': 35000000},
      ],
      receivableAging: [
        {'label': 'Current', 'amount': 4250000, 'percentage': 0.50},
        {'label': '1-30 Days', 'amount': 2100000, 'percentage': 0.25},
        {'label': '31-60 Days', 'amount': 1350000, 'percentage': 0.16},
        {'label': '60+ Days', 'amount': 750000, 'percentage': 0.09},
      ],
      recentTransactions: [
        {'title': 'Invoice #INV-2026-0042', 'subtitle': 'Customer: ABC Ltd', 'amount': 2450000, 'isIncome': true, 'icon': 'receipt_long'},
        {'title': 'Bill #BILL-2026-0018', 'subtitle': 'Vendor: XYZ Supplies', 'amount': 1250000, 'isIncome': false, 'icon': 'description'},
        {'title': 'Payment Received', 'subtitle': 'From: DEF Corp', 'amount': 3800000, 'isIncome': true, 'icon': 'payments'},
        {'title': 'Expense: Office Supplies', 'subtitle': 'Petty Cash', 'amount': 185000, 'isIncome': false, 'icon': 'shopping_bag'},
      ],
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
    // Return demo data on error (offline mode)
  }

  return DashboardData.demo();
});

// ============================================================================
// Accounts Service
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

  AccountsNotifier(this._apiClient) : super(AccountsState()) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/accounts');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final accounts = (data as List<dynamic>)
            .map((json) => Account.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(accounts: accounts, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    // Demo data for offline mode
    state = state.copyWith(
      accounts: _getDemoAccounts(),
      isLoading: false,
    );
  }

  Future<void> createAccount(Map<String, dynamic> accountData) async {
    try {
      await _apiClient.post('/accounts', data: accountData);
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateAccount(String id, Map<String, dynamic> accountData) async {
    try {
      await _apiClient.put('/accounts/$id', data: accountData);
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return AccountsNotifier(ref.read(apiClientProvider));
});

// ============================================================================
// Customers Service
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

  CustomersNotifier(this._apiClient) : super(CustomersState()) {
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/customers');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final customers = (data as List<dynamic>)
            .map((json) => Customer.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(customers: customers, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    state = state.copyWith(
      customers: _getDemoCustomers(),
      isLoading: false,
    );
  }

  Future<void> createCustomer(Map<String, dynamic> customerData) async {
    try {
      await _apiClient.post('/customers', data: customerData);
      await loadCustomers();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return CustomersNotifier(ref.read(apiClientProvider));
});

// ============================================================================
// Vendors Service
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

  VendorsNotifier(this._apiClient) : super(VendorsState()) {
    loadVendors();
  }

  Future<void> loadVendors() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/vendors');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final vendors = (data as List<dynamic>)
            .map((json) => Vendor.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(vendors: vendors, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    state = state.copyWith(
      vendors: _getDemoVendors(),
      isLoading: false,
    );
  }

  Future<void> createVendor(Map<String, dynamic> vendorData) async {
    try {
      await _apiClient.post('/vendors', data: vendorData);
      await loadVendors();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return VendorsNotifier(ref.read(apiClientProvider));
});

// ============================================================================
// Invoices Service
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

  InvoicesNotifier(this._apiClient) : super(InvoicesState()) {
    loadInvoices();
  }

  Future<void> loadInvoices() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/invoices');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final invoices = (data as List<dynamic>)
            .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(invoices: invoices, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    state = state.copyWith(
      invoices: _getDemoInvoices(),
      isLoading: false,
    );
  }

  Future<void> createInvoice(Map<String, dynamic> invoiceData) async {
    try {
      await _apiClient.post('/invoices', data: invoiceData);
      await loadInvoices();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return InvoicesNotifier(ref.read(apiClientProvider));
});

// ============================================================================
// Bills Service
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

  BillsNotifier(this._apiClient) : super(BillsState()) {
    loadBills();
  }

  Future<void> loadBills() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/bills');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final bills = (data as List<dynamic>)
            .map((json) => Bill.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(bills: bills, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    state = state.copyWith(
      bills: _getDemoBills(),
      isLoading: false,
    );
  }

  Future<void> createBill(Map<String, dynamic> billData) async {
    try {
      await _apiClient.post('/bills', data: billData);
      await loadBills();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return BillsNotifier(ref.read(apiClientProvider));
});

// ============================================================================
// Journal Entries Service
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

  JournalsNotifier(this._apiClient) : super(JournalsState()) {
    loadJournals();
  }

  Future<void> loadJournals() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/journals');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final entries = (data as List<dynamic>)
            .map((json) => JournalEntry.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(entries: entries, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    state = state.copyWith(
      entries: _getDemoJournals(),
      isLoading: false,
    );
  }

  Future<void> createJournalEntry(Map<String, dynamic> entryData) async {
    try {
      await _apiClient.post('/journals', data: entryData);
      await loadJournals();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return JournalsNotifier(ref.read(apiClientProvider));
});

// ============================================================================
// Payments Service
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

  PaymentsNotifier(this._apiClient) : super(PaymentsState()) {
    loadPayments();
  }

  Future<void> loadPayments() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('/payments');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final payments = (data as List<dynamic>)
            .map((json) => Payment.fromJson(json as Map<String, dynamic>))
            .toList();
        state = state.copyWith(payments: payments, isLoading: false);
        return;
      }
    } catch (e) {
      // Use demo data on error
    }

    state = state.copyWith(
      payments: _getDemoPayments(),
      isLoading: false,
    );
  }

  Future<void> createPayment(Map<String, dynamic> paymentData) async {
    try {
      await _apiClient.post('/payments', data: paymentData);
      await loadPayments();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
  return PaymentsNotifier(ref.read(apiClientProvider));
});
