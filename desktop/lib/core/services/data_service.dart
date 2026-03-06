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


  Future<void> _initializeData() async {
    state = state.copyWith(isLoading: true);

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

    state = state.copyWith(isLoading: false);
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
