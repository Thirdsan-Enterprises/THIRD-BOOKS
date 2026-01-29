import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// Trial balance report data
class TrialBalanceReport {
  final DateTime asOfDate;
  final List<TrialBalanceRow> rows;
  final double totalDebits;
  final double totalCredits;
  final bool isBalanced;

  TrialBalanceReport({
    required this.asOfDate,
    required this.rows,
    required this.totalDebits,
    required this.totalCredits,
  }) : isBalanced = (totalDebits - totalCredits).abs() < 0.01;
}

class TrialBalanceRow {
  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final double debitBalance;
  final double creditBalance;

  TrialBalanceRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debitBalance,
    required this.creditBalance,
  });
}

/// Income statement report data
class IncomeStatementReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<IncomeStatementSection> revenueSections;
  final List<IncomeStatementSection> expenseSections;
  final double totalRevenue;
  final double totalExpenses;
  final double netIncome;

  IncomeStatementReport({
    required this.startDate,
    required this.endDate,
    required this.revenueSections,
    required this.expenseSections,
    required this.totalRevenue,
    required this.totalExpenses,
  }) : netIncome = totalRevenue - totalExpenses;

  double get grossProfitMargin =>
      totalRevenue > 0 ? (netIncome / totalRevenue) * 100 : 0;
}

class IncomeStatementSection {
  final String accountCode;
  final String accountName;
  final double amount;

  IncomeStatementSection({
    required this.accountCode,
    required this.accountName,
    required this.amount,
  });
}

/// Balance sheet report data
class BalanceSheetReport {
  final DateTime asOfDate;
  final List<BalanceSheetSection> assets;
  final List<BalanceSheetSection> liabilities;
  final List<BalanceSheetSection> equity;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final bool isBalanced;

  BalanceSheetReport({
    required this.asOfDate,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
  }) : isBalanced = (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;
}

class BalanceSheetSection {
  final String accountCode;
  final String accountName;
  final double balance;

  BalanceSheetSection({
    required this.accountCode,
    required this.accountName,
    required this.balance,
  });
}

/// Cash flow summary
class CashFlowSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double openingBalance;
  final double totalInflows;
  final double totalOutflows;
  final double closingBalance;
  final List<CashFlowItem> inflows;
  final List<CashFlowItem> outflows;

  CashFlowSummary({
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.totalInflows,
    required this.totalOutflows,
    required this.inflows,
    required this.outflows,
  }) : closingBalance = openingBalance + totalInflows - totalOutflows;
}

class CashFlowItem {
  final String description;
  final double amount;
  final DateTime date;

  CashFlowItem({
    required this.description,
    required this.amount,
    required this.date,
  });
}

/// Accounts receivable aging
class ARAgingReport {
  final DateTime asOfDate;
  final List<ARAgingRow> rows;
  final double totalCurrent;
  final double total1to30;
  final double total31to60;
  final double total61to90;
  final double totalOver90;
  final double grandTotal;

  ARAgingReport({
    required this.asOfDate,
    required this.rows,
    required this.totalCurrent,
    required this.total1to30,
    required this.total31to60,
    required this.total61to90,
    required this.totalOver90,
  }) : grandTotal = totalCurrent + total1to30 + total31to60 + total61to90 + totalOver90;
}

class ARAgingRow {
  final String customerId;
  final String customerName;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double over90;
  final double total;

  ARAgingRow({
    required this.customerId,
    required this.customerName,
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.over90,
  }) : total = current + days1to30 + days31to60 + days61to90 + over90;
}

/// Accounts payable aging
class APAgingReport {
  final DateTime asOfDate;
  final List<APAgingRow> rows;
  final double totalCurrent;
  final double total1to30;
  final double total31to60;
  final double total61to90;
  final double totalOver90;
  final double grandTotal;

  APAgingReport({
    required this.asOfDate,
    required this.rows,
    required this.totalCurrent,
    required this.total1to30,
    required this.total31to60,
    required this.total61to90,
    required this.totalOver90,
  }) : grandTotal = totalCurrent + total1to30 + total31to60 + total61to90 + totalOver90;
}

class APAgingRow {
  final String vendorId;
  final String vendorName;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double over90;
  final double total;

  APAgingRow({
    required this.vendorId,
    required this.vendorName,
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.over90,
  }) : total = current + days1to30 + days31to60 + days61to90 + over90;
}

/// Reports state
class ReportsState {
  final bool isLoading;
  final String? error;
  final TrialBalanceReport? trialBalance;
  final IncomeStatementReport? incomeStatement;
  final BalanceSheetReport? balanceSheet;
  final ARAgingReport? arAging;
  final APAgingReport? apAging;

  const ReportsState({
    this.isLoading = false,
    this.error,
    this.trialBalance,
    this.incomeStatement,
    this.balanceSheet,
    this.arAging,
    this.apAging,
  });

  ReportsState copyWith({
    bool? isLoading,
    String? error,
    TrialBalanceReport? trialBalance,
    IncomeStatementReport? incomeStatement,
    BalanceSheetReport? balanceSheet,
    ARAgingReport? arAging,
    APAgingReport? apAging,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      trialBalance: trialBalance ?? this.trialBalance,
      incomeStatement: incomeStatement ?? this.incomeStatement,
      balanceSheet: balanceSheet ?? this.balanceSheet,
      arAging: arAging ?? this.arAging,
      apAging: apAging ?? this.apAging,
    );
  }
}

/// Reports provider
class ReportsNotifier extends StateNotifier<ReportsState> {
  final AppDatabase _db;

  ReportsNotifier(this._db) : super(const ReportsState());

  Future<TrialBalanceReport> generateTrialBalance({DateTime? asOfDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final date = asOfDate ?? DateTime.now();
      final data = await _db.getTrialBalance();

      final rows = data.map((d) => TrialBalanceRow(
        accountId: d['account_id'] as String,
        accountCode: d['account_code'] as String,
        accountName: d['account_name'] as String,
        accountType: d['account_type'] as String,
        debitBalance: (d['debit_balance'] as num).toDouble(),
        creditBalance: (d['credit_balance'] as num).toDouble(),
      )).toList();

      double totalDebits = 0;
      double totalCredits = 0;
      for (final row in rows) {
        totalDebits += row.debitBalance;
        totalCredits += row.creditBalance;
      }

      final report = TrialBalanceReport(
        asOfDate: date,
        rows: rows,
        totalDebits: totalDebits,
        totalCredits: totalCredits,
      );

      state = state.copyWith(isLoading: false, trialBalance: report);
      return report;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<IncomeStatementReport> generateIncomeStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _db.getIncomeStatement(startDate, endDate);

      final revenueList = (data['revenue_accounts'] as List<dynamic>).map((a) =>
        IncomeStatementSection(
          accountCode: a['code'] as String,
          accountName: a['name'] as String,
          amount: (a['balance'] as num).toDouble(),
        )).toList();

      final expenseList = (data['expense_accounts'] as List<dynamic>).map((a) =>
        IncomeStatementSection(
          accountCode: a['code'] as String,
          accountName: a['name'] as String,
          amount: (a['balance'] as num).toDouble(),
        )).toList();

      final report = IncomeStatementReport(
        startDate: startDate,
        endDate: endDate,
        revenueSections: revenueList,
        expenseSections: expenseList,
        totalRevenue: (data['total_revenue'] as num).toDouble(),
        totalExpenses: (data['total_expenses'] as num).toDouble(),
      );

      state = state.copyWith(isLoading: false, incomeStatement: report);
      return report;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<BalanceSheetReport> generateBalanceSheet({DateTime? asOfDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final date = asOfDate ?? DateTime.now();
      final data = await _db.getBalanceSheet();

      final assetsList = (data['assets'] as List<dynamic>).map((a) =>
        BalanceSheetSection(
          accountCode: a['code'] as String,
          accountName: a['name'] as String,
          balance: (a['balance'] as num).toDouble(),
        )).toList();

      final liabilitiesList = (data['liabilities'] as List<dynamic>).map((a) =>
        BalanceSheetSection(
          accountCode: a['code'] as String,
          accountName: a['name'] as String,
          balance: (a['balance'] as num).toDouble(),
        )).toList();

      final equityList = (data['equity'] as List<dynamic>).map((a) =>
        BalanceSheetSection(
          accountCode: a['code'] as String,
          accountName: a['name'] as String,
          balance: (a['balance'] as num).toDouble(),
        )).toList();

      final report = BalanceSheetReport(
        asOfDate: date,
        assets: assetsList,
        liabilities: liabilitiesList,
        equity: equityList,
        totalAssets: (data['total_assets'] as num).toDouble(),
        totalLiabilities: (data['total_liabilities'] as num).toDouble(),
        totalEquity: (data['total_equity'] as num).toDouble(),
      );

      state = state.copyWith(isLoading: false, balanceSheet: report);
      return report;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<ARAgingReport> generateARAgingReport({DateTime? asOfDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final date = asOfDate ?? DateTime.now();
      final invoices = await _db.getAllInvoices();
      final customers = await _db.getAllCustomers();
      final customerMap = {for (var c in customers) c.id: c};

      // Group unpaid invoices by customer
      final Map<String, ARAgingRow> agingByCustomer = {};

      for (final invoice in invoices) {
        if (invoice.balanceDue <= 0) continue;

        final customerId = invoice.customerId;
        final customerName = customerMap[customerId]?.name ?? 'Unknown';
        final daysPastDue = date.difference(invoice.dueDate).inDays;

        agingByCustomer.putIfAbsent(customerId, () => ARAgingRow(
          customerId: customerId,
          customerName: customerName,
          current: 0,
          days1to30: 0,
          days31to60: 0,
          days61to90: 0,
          over90: 0,
        ));

        final existing = agingByCustomer[customerId]!;
        if (daysPastDue <= 0) {
          agingByCustomer[customerId] = ARAgingRow(
            customerId: existing.customerId,
            customerName: existing.customerName,
            current: existing.current + invoice.balanceDue,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90,
            over90: existing.over90,
          );
        } else if (daysPastDue <= 30) {
          agingByCustomer[customerId] = ARAgingRow(
            customerId: existing.customerId,
            customerName: existing.customerName,
            current: existing.current,
            days1to30: existing.days1to30 + invoice.balanceDue,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90,
            over90: existing.over90,
          );
        } else if (daysPastDue <= 60) {
          agingByCustomer[customerId] = ARAgingRow(
            customerId: existing.customerId,
            customerName: existing.customerName,
            current: existing.current,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60 + invoice.balanceDue,
            days61to90: existing.days61to90,
            over90: existing.over90,
          );
        } else if (daysPastDue <= 90) {
          agingByCustomer[customerId] = ARAgingRow(
            customerId: existing.customerId,
            customerName: existing.customerName,
            current: existing.current,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90 + invoice.balanceDue,
            over90: existing.over90,
          );
        } else {
          agingByCustomer[customerId] = ARAgingRow(
            customerId: existing.customerId,
            customerName: existing.customerName,
            current: existing.current,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90,
            over90: existing.over90 + invoice.balanceDue,
          );
        }
      }

      final rows = agingByCustomer.values.toList();
      double totalCurrent = 0, total1to30 = 0, total31to60 = 0, total61to90 = 0, totalOver90 = 0;
      for (final row in rows) {
        totalCurrent += row.current;
        total1to30 += row.days1to30;
        total31to60 += row.days31to60;
        total61to90 += row.days61to90;
        totalOver90 += row.over90;
      }

      final report = ARAgingReport(
        asOfDate: date,
        rows: rows,
        totalCurrent: totalCurrent,
        total1to30: total1to30,
        total31to60: total31to60,
        total61to90: total61to90,
        totalOver90: totalOver90,
      );

      state = state.copyWith(isLoading: false, arAging: report);
      return report;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<APAgingReport> generateAPAgingReport({DateTime? asOfDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final date = asOfDate ?? DateTime.now();
      final bills = await _db.getAllBills();
      final vendors = await _db.getAllVendors();
      final vendorMap = {for (var v in vendors) v.id: v};

      // Group unpaid bills by vendor
      final Map<String, APAgingRow> agingByVendor = {};

      for (final bill in bills) {
        if (bill.balanceDue <= 0) continue;

        final vendorId = bill.vendorId;
        final vendorName = vendorMap[vendorId]?.name ?? 'Unknown';
        final daysPastDue = date.difference(bill.dueDate).inDays;

        agingByVendor.putIfAbsent(vendorId, () => APAgingRow(
          vendorId: vendorId,
          vendorName: vendorName,
          current: 0,
          days1to30: 0,
          days31to60: 0,
          days61to90: 0,
          over90: 0,
        ));

        final existing = agingByVendor[vendorId]!;
        if (daysPastDue <= 0) {
          agingByVendor[vendorId] = APAgingRow(
            vendorId: existing.vendorId,
            vendorName: existing.vendorName,
            current: existing.current + bill.balanceDue,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90,
            over90: existing.over90,
          );
        } else if (daysPastDue <= 30) {
          agingByVendor[vendorId] = APAgingRow(
            vendorId: existing.vendorId,
            vendorName: existing.vendorName,
            current: existing.current,
            days1to30: existing.days1to30 + bill.balanceDue,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90,
            over90: existing.over90,
          );
        } else if (daysPastDue <= 60) {
          agingByVendor[vendorId] = APAgingRow(
            vendorId: existing.vendorId,
            vendorName: existing.vendorName,
            current: existing.current,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60 + bill.balanceDue,
            days61to90: existing.days61to90,
            over90: existing.over90,
          );
        } else if (daysPastDue <= 90) {
          agingByVendor[vendorId] = APAgingRow(
            vendorId: existing.vendorId,
            vendorName: existing.vendorName,
            current: existing.current,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90 + bill.balanceDue,
            over90: existing.over90,
          );
        } else {
          agingByVendor[vendorId] = APAgingRow(
            vendorId: existing.vendorId,
            vendorName: existing.vendorName,
            current: existing.current,
            days1to30: existing.days1to30,
            days31to60: existing.days31to60,
            days61to90: existing.days61to90,
            over90: existing.over90 + bill.balanceDue,
          );
        }
      }

      final rows = agingByVendor.values.toList();
      double totalCurrent = 0, total1to30 = 0, total31to60 = 0, total61to90 = 0, totalOver90 = 0;
      for (final row in rows) {
        totalCurrent += row.current;
        total1to30 += row.days1to30;
        total31to60 += row.days31to60;
        total61to90 += row.days61to90;
        totalOver90 += row.over90;
      }

      final report = APAgingReport(
        asOfDate: date,
        rows: rows,
        totalCurrent: totalCurrent,
        total1to30: total1to30,
        total31to60: total31to60,
        total61to90: total61to90,
        totalOver90: totalOver90,
      );

      state = state.copyWith(isLoading: false, apAging: report);
      return report;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

/// Provider instance
final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReportsNotifier(db);
});

/// Convenience providers for individual reports
final trialBalanceProvider = FutureProvider.family<TrialBalanceReport, DateTime?>((ref, asOfDate) async {
  final notifier = ref.watch(reportsProvider.notifier);
  return notifier.generateTrialBalance(asOfDate: asOfDate);
});

final balanceSheetProvider = FutureProvider.family<BalanceSheetReport, DateTime?>((ref, asOfDate) async {
  final notifier = ref.watch(reportsProvider.notifier);
  return notifier.generateBalanceSheet(asOfDate: asOfDate);
});
