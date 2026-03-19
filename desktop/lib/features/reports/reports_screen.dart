import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/models.dart';
import '../../core/database/app_database.dart' hide Account, Customer, Vendor, Invoice, Bill, JournalEntry, JournalLine;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedPeriod = 'This Month';
  String _selectedReportType = 'all';
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  final List<Map<String, dynamic>> _reportCategories = [
    {
      'category': 'Financial Statements',
      'icon': Icons.account_balance,
      'color': AppColors.primary,
      'reports': [
        {'name': 'Balance Sheet', 'description': 'Assets, liabilities and equity at a point in time', 'icon': Icons.balance},
        {'name': 'Income Statement', 'description': 'Revenue and expenses over a period', 'icon': Icons.trending_up},
        {'name': 'Cash Flow Statement', 'description': 'Cash inflows and outflows', 'icon': Icons.water_drop},
        {'name': 'Trial Balance', 'description': 'All account balances', 'icon': Icons.list_alt},
      ],
    },
    {
      'category': 'Outlet Performance',
      'icon': Icons.store,
      'color': AppColors.debit,
      'reports': [
        {'name': 'GGR by Outlet', 'description': 'Gross Gaming Revenue per outlet', 'icon': Icons.bar_chart},
        {'name': 'Outlet Revenue Summary', 'description': 'Total In / Out / GGR summary', 'icon': Icons.summarize},
        {'name': 'Daily Performance', 'description': 'Day-by-day outlet performance', 'icon': Icons.calendar_month},
        {'name': 'Top Performers', 'description': 'Highest revenue outlets', 'icon': Icons.emoji_events},
      ],
    },
    {
      'category': 'Tax Reports',
      'icon': Icons.calculate,
      'color': AppColors.warning,
      'reports': [
        {'name': 'GGR Tax Report', 'description': 'Gaming revenue tax summary', 'icon': Icons.receipt},
        {'name': 'Tax Summary', 'description': 'Tax obligations summary', 'icon': Icons.summarize},
        {'name': 'Withholding Tax', 'description': 'WHT deducted and remitted', 'icon': Icons.remove_circle_outline},
      ],
    },
    {
      'category': 'Management Reports',
      'icon': Icons.insights,
      'color': AppColors.secondary,
      'reports': [
        {'name': 'GGR by Month', 'description': 'Monthly GGR comparison', 'icon': Icons.calendar_month},
        {'name': 'Payout Ratio Analysis', 'description': 'Total Out vs Total In ratio', 'icon': Icons.pie_chart},
        {'name': 'Revenue Trend', 'description': 'Revenue trend over time', 'icon': Icons.show_chart},
      ],
    },
  ];

  // ---------------------------------------------------------------------------
  // Ledger helpers — compute real account balances from posted journal entries
  // ---------------------------------------------------------------------------

  /// Returns {accountId → (totalDebits − totalCredits)} for every posted JE.
  Map<String, double> _computeLedgerBalances(List<JournalEntry> entries) {
    final raw = <String, double>{};
    for (final entry in entries) {
      if (entry.status != JournalEntryStatus.posted) continue;
      for (final line in entry.lines) {
        raw[line.accountId] = (raw[line.accountId] ?? 0) + line.debit - line.credit;
      }
    }
    return raw;
  }

  /// Presentational balance for [account] — positive means normal direction.
  double _acctBal(Account account, Map<String, double> raw) {
    final r = raw['acct-${account.code}'] ?? 0.0;
    return account.isDebitNormal ? r : -r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildQuickStats(context),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(child: _buildReportsGrid(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Reports',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate and analyze financial reports',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  items: ['Today', 'This Week', 'This Month', 'This Quarter', 'This Year', 'Last Month', 'Last Quarter', 'Last Year', 'Custom']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedPeriod = value!),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(journalsProvider);
                ref.invalidate(accountsProvider);
                ref.invalidate(dashboardDataProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports refreshed'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _exportAllReports,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export All'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (data) => Row(
        children: [
          Expanded(
            child: _QuickStatCard(
              title: 'Gross Gaming Revenue',
              value: _currencyFormat.format(data.totalRevenue),
              change: 'Total GGR',
              isPositive: true,
              icon: Icons.trending_up,
              color: AppColors.income,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _QuickStatCard(
              title: 'Total Cash In (Stakes)',
              value: _currencyFormat.format(data.cashIn),
              change: 'All outlets',
              isPositive: true,
              icon: Icons.attach_money,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _QuickStatCard(
              title: 'Total Payouts',
              value: _currencyFormat.format(data.cashOut),
              change: 'Customer winnings',
              isPositive: false,
              icon: Icons.money_off,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _QuickStatCard(
              title: 'Payout Ratio',
              value: data.cashIn > 0
                  ? '${(data.cashOut / data.cashIn * 100).toStringAsFixed(1)}%'
                  : '0%',
              change: 'Out/In ratio',
              isPositive: data.cashIn > 0 && (data.cashOut / data.cashIn) < 0.85,
              icon: Icons.pie_chart,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 100, child: Center(child: Text('Error loading data'))),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        FilterChip(
          label: const Text('All Reports'),
          selected: _selectedReportType == 'all',
          onSelected: (selected) => setState(() => _selectedReportType = 'all'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Financial'),
          selected: _selectedReportType == 'financial',
          onSelected: (selected) => setState(() => _selectedReportType = 'financial'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Outlet Performance'),
          selected: _selectedReportType == 'outlets',
          onSelected: (selected) => setState(() => _selectedReportType = 'outlets'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Tax'),
          selected: _selectedReportType == 'tax',
          onSelected: (selected) => setState(() => _selectedReportType = 'tax'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Management'),
          selected: _selectedReportType == 'management',
          onSelected: (selected) => setState(() => _selectedReportType = 'management'),
        ),
      ],
    );
  }

  Widget _buildReportsGrid(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _reportCategories.map((category) {
          return _ReportCategorySection(
            category: category['category'],
            icon: category['icon'],
            color: category['color'],
            reports: List<Map<String, dynamic>>.from(category['reports']),
            onReportTap: (report) => _showReportPreview(context, report, category['category']),
          );
        }).toList(),
      ),
    );
  }

  void _showReportPreview(BuildContext context, Map<String, dynamic> report, String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(report['icon'], color: AppColors.primary),
            const SizedBox(width: 12),
            Text(report['name']),
          ],
        ),
        content: SizedBox(
          width: 800,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report['description'],
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Period: $_selectedPeriod', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: _buildReportContent(context, report['name']),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _printReport(report['name'] as String);
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportCsv(report['name'] as String);
            },
            icon: const Icon(Icons.table_chart, size: 18),
            label: const Text('Export CSV'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportExcel(report['name'] as String);
            },
            icon: const Icon(Icons.grid_on, size: 18),
            label: const Text('Export Excel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportPdf(report['name'] as String);
            },
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }

  // ── PDF Generation Helpers ─────────────────────────────────────────────────

  static pw.Widget _pdfRow(String label, String value, {bool bold = false, double size = 11}) {
    final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: size);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
      ),
    );
  }

  static pw.Widget _pdfDivider() => pw.Divider(thickness: 0.5, color: PdfColors.grey400);

  Future<pw.Document> _buildPdfDocument(String reportName) async {
    final numFmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('MMM d, yyyy HH:mm');
    final pdf = pw.Document();

    final dashData = ref.read(dashboardDataProvider).valueOrNull;
    final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
    final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

    pw.Widget buildHeader(String title) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MAGIC BET LTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
            pw.SizedBox(height: 4),
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
            pw.SizedBox(height: 4),
            pw.Text('Period: $_selectedPeriod   |   Generated: ${dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            _pdfDivider(),
            pw.SizedBox(height: 8),
          ],
        );

    if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
      final totalIn = dashData?.cashIn ?? 0;
      final totalOut = dashData?.cashOut ?? 0;
      final ggr = dashData?.totalRevenue ?? 0;
      final commission = dashData?.totalExpenses ?? 0;
      final netRevenue = dashData?.netIncome ?? 0;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('INCOME STATEMENT'),
            pw.Text('REVENUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('Total Stakes (Cash In)', 'UGX ${numFmt.format(totalIn)}'),
            _pdfRow('Customer Winnings (Payouts)', '(UGX ${numFmt.format(totalOut)})'),
            _pdfDivider(),
            _pdfRow('Gross Gaming Revenue (GGR)', 'UGX ${numFmt.format(ggr)}', bold: true),
            pw.SizedBox(height: 12),
            pw.Text('OPERATING EXPENSES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('Outlet Commission (40% of GGR)', '(UGX ${numFmt.format(commission)})'),
            _pdfDivider(),
            _pdfRow('Net Revenue (after commission)', 'UGX ${numFmt.format(netRevenue)}', bold: true, size: 13),
          ],
        ),
      ));
    } else if (reportName == 'Balance Sheet') {
      final bsAccounts = ref.read(accountsProvider).accounts;
      final bsEntries = ref.read(journalsProvider).entries;
      final bsRaw = _computeLedgerBalances(bsEntries);

      final bsAssets = bsAccounts.where((a) => a.type == AccountType.asset).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final bsLiabilities = bsAccounts.where((a) => a.type == AccountType.liability).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final bsEquity = bsAccounts.where((a) => a.type == AccountType.equity).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final bsRevenue = bsAccounts.where((a) => a.type == AccountType.revenue).toList();
      final bsExpenses = bsAccounts.where((a) => a.type == AccountType.expense).toList();

      final bsTotalAssets = bsAssets.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsTotalLiabilities = bsLiabilities.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsPermEquity = bsEquity.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsCYE = bsRevenue.fold(0.0, (s, a) => s + _acctBal(a, bsRaw))
          - bsExpenses.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsTotalEquity = bsPermEquity + bsCYE;

      final bsAssetRows = bsAssets.where((a) => _acctBal(a, bsRaw) != 0).toList();
      final bsLiabRows = bsLiabilities.where((a) => _acctBal(a, bsRaw) != 0).toList();
      final bsEquityRows = bsEquity.where((a) => _acctBal(a, bsRaw) != 0).toList();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('BALANCE SHEET'),
            pw.Text('ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...bsAssetRows.map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw))}'))
                .toList(),
            _pdfDivider(),
            _pdfRow('TOTAL ASSETS', 'UGX ${numFmt.format(bsTotalAssets)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...bsLiabRows.map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw))}'))
                .toList(),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES', 'UGX ${numFmt.format(bsTotalLiabilities)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...bsEquityRows.map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw))}'))
                .toList(),
            _pdfRow('  Current Year Earnings', 'UGX ${numFmt.format(bsCYE)}'),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES & EQUITY', 'UGX ${numFmt.format(bsTotalLiabilities + bsTotalEquity)}',
                bold: true, size: 13),
          ],
        ),
      ));
    } else if (reportName == 'Trial Balance') {
      final tbAccounts = ref.read(accountsProvider).accounts;
      final tbEntries = ref.read(journalsProvider).entries;
      final tbRaw = _computeLedgerBalances(tbEntries);

      final tbRows = <List<String>>[];
      double tbTotalDr = 0;
      double tbTotalCr = 0;
      final tbSorted = List<Account>.from(tbAccounts)..sort((a, b) => a.code.compareTo(b.code));
      for (final acct in tbSorted) {
        final net = tbRaw['acct-${acct.code}'] ?? 0.0;
        if (net == 0.0) continue;
        final typeName = acct.type.name[0].toUpperCase() + acct.type.name.substring(1);
        if (net > 0) {
          tbRows.add([acct.code, acct.name, typeName, numFmt.format(net), '—']);
          tbTotalDr += net;
        } else {
          tbRows.add([acct.code, acct.name, typeName, '—', numFmt.format(-net)]);
          tbTotalCr += -net;
        }
      }
      tbRows.add(['', 'TOTALS', '', numFmt.format(tbTotalDr), numFmt.format(tbTotalCr)]);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('TRIAL BALANCE'),
            pw.TableHelper.fromTextArray(
              headers: ['Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              data: tbRows,
            ),
          ],
        ),
      ));
    } else if (reportName == 'Cash Flow Statement') {
      final cashIn = dashData?.cashIn ?? 0;
      final cashOut = dashData?.cashOut ?? 0;
      final commission = dashData?.totalExpenses ?? 0;
      final netCash = dashData?.netIncome ?? 0;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('STATEMENT OF CASH FLOWS'),
            pw.Text('OPERATING ACTIVITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            _pdfRow('  Cash received from betting customers', 'UGX ${numFmt.format(cashIn)}'),
            _pdfRow('  Cash paid to winning customers (Payouts)', '(UGX ${numFmt.format(cashOut)})'),
            _pdfDivider(),
            _pdfRow('  Net cash from betting operations', 'UGX ${numFmt.format(cashIn - cashOut)}', bold: true),
            _pdfRow('  Commission paid to outlet owners', '(UGX ${numFmt.format(commission)})'),
            _pdfDivider(),
            _pdfRow('NET CASH FROM OPERATING ACTIVITIES', 'UGX ${numFmt.format(netCash)}', bold: true, size: 12),
            pw.SizedBox(height: 12),
            pw.Text('INVESTING ACTIVITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            _pdfRow('  No capital expenditure transactions', '—'),
            _pdfDivider(),
            _pdfRow('NET CASH FROM INVESTING ACTIVITIES', 'UGX 0', bold: true),
            pw.SizedBox(height: 12),
            pw.Text('FINANCING ACTIVITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            _pdfRow('  No financing transactions', '—'),
            _pdfDivider(),
            _pdfRow('NET CASH FROM FINANCING ACTIVITIES', 'UGX 0', bold: true),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Column(children: [
                _pdfRow('Opening Cash Balance', 'UGX 0'),
                _pdfRow('Net Increase in Cash', 'UGX ${numFmt.format(netCash)}'),
                _pdfDivider(),
                _pdfRow('CLOSING CASH BALANCE', 'UGX ${numFmt.format(netCash)}', bold: true, size: 13),
              ]),
            ),
          ],
        ),
      ));
    } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
      final ggr = dashData?.totalRevenue ?? 0;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('GGR REVENUE REPORT'),
            pw.Text('GAMING REVENUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Total Stakes (Cash In)', 'UGX ${numFmt.format(dashData?.cashIn ?? 0)}'),
            _pdfRow('  Less: Customer Winnings', '(UGX ${numFmt.format(dashData?.cashOut ?? 0)})'),
            _pdfDivider(),
            _pdfRow('Gross Gaming Revenue (GGR)', 'UGX ${numFmt.format(ggr)}', bold: true),
            pw.SizedBox(height: 12),
            pw.Text('REVENUE DISTRIBUTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Outlet Commission (40%)', '(UGX ${numFmt.format(dashData?.totalExpenses ?? 0)})'),
            _pdfDivider(),
            _pdfRow('NET REVENUE AFTER COMMISSION', 'UGX ${numFmt.format(ggr - (dashData?.totalExpenses ?? 0))}', bold: true, size: 13),
          ],
        ),
      ));
    } else if (reportName == 'GGR by Outlet' || reportName == 'Top Performers' || reportName == 'Outlet Revenue Summary') {
      final sortedEntries = (summary?.entries.toList() ?? [])
        ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('OUTLET PERFORMANCE REPORT'),
            pw.TableHelper.fromTextArray(
              headers: ['Outlet', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              data: sortedEntries.map((entry) {
                final outlet = outlets.where((o) => o.outletCode == entry.key).firstOrNull;
                final d = entry.value;
                return [
                  outlet?.name ?? 'Outlet ${entry.key}',
                  numFmt.format(d['totalIn'] ?? 0),
                  numFmt.format(d['totalOut'] ?? 0),
                  numFmt.format(d['totalGGR'] ?? 0),
                  '${(d['days'] ?? 0).toInt()}',
                ];
              }).toList(),
            ),
          ],
        ),
      ));
    } else {
      // Generic placeholder page for reports without detailed preview
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader(reportName.toUpperCase()),
            pw.Center(
              child: pw.Text(
                'Report data will be available once CSV data has been imported.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      ));
    }

    return pdf;
  }

  Future<void> _printReport(String reportName) async {
    try {
      final pdf = await _buildPdfDocument(reportName);
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportReportPdf(String reportName) async {
    try {
      final pdf = await _buildPdfDocument(reportName);
      final bytes = await pdf.save();
      final filename = '${reportName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportAllReports() async {
    try {
      final numFmt = NumberFormat('#,##0', 'en_US');
      final dateFmt = DateFormat('MMM d, yyyy HH:mm');
      final dashData = ref.read(dashboardDataProvider).valueOrNull;
      final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
      final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

      final pdf = pw.Document();

      pw.Widget buildHeader(String title) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MAGIC BET LTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 4),
              pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
              pw.SizedBox(height: 4),
              pw.Text('Period: $_selectedPeriod   |   Generated: ${dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              _pdfDivider(),
              pw.SizedBox(height: 8),
            ],
          );

      final totalIn = dashData?.cashIn ?? 0;
      final totalOut = dashData?.cashOut ?? 0;
      final ggr = dashData?.totalRevenue ?? 0;
      final commission = dashData?.totalExpenses ?? 0;
      final netRevenue = dashData?.netIncome ?? 0;

      // Page 1: Income Statement
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('INCOME STATEMENT'),
            _pdfRow('Total Stakes (Cash In)', 'UGX ${numFmt.format(totalIn)}'),
            _pdfRow('Customer Winnings (Payouts)', '(UGX ${numFmt.format(totalOut)})'),
            _pdfDivider(),
            _pdfRow('Gross Gaming Revenue (GGR)', 'UGX ${numFmt.format(ggr)}', bold: true),
            pw.SizedBox(height: 12),
            _pdfRow('Outlet Commission (40% of GGR)', '(UGX ${numFmt.format(commission)})'),
            _pdfDivider(),
            _pdfRow('Net Revenue', 'UGX ${numFmt.format(netRevenue)}', bold: true, size: 13),
          ],
        ),
      ));

      // Page 2: Balance Sheet (ledger-driven)
      {
        final bsAccounts2 = ref.read(accountsProvider).accounts;
        final bsEntries2 = ref.read(journalsProvider).entries;
        final bsRaw2 = _computeLedgerBalances(bsEntries2);

        final bsAssets2 = bsAccounts2.where((a) => a.type == AccountType.asset).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsLiabs2 = bsAccounts2.where((a) => a.type == AccountType.liability).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsEq2 = bsAccounts2.where((a) => a.type == AccountType.equity).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsRev2 = bsAccounts2.where((a) => a.type == AccountType.revenue).toList();
        final bsExp2 = bsAccounts2.where((a) => a.type == AccountType.expense).toList();

        final bsTotalA2 = bsAssets2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsTotalL2 = bsLiabs2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsPermEq2 = bsEq2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsCYE2 = bsRev2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2))
            - bsExp2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsTotalEq2 = bsPermEq2 + bsCYE2;

        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader('BALANCE SHEET'),
              pw.Text('ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...bsAssets2.where((a) => _acctBal(a, bsRaw2) != 0)
                  .map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw2))}')),
              _pdfDivider(),
              _pdfRow('TOTAL ASSETS', 'UGX ${numFmt.format(bsTotalA2)}', bold: true),
              pw.SizedBox(height: 16),
              pw.Text('LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...bsLiabs2.where((a) => _acctBal(a, bsRaw2) != 0)
                  .map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw2))}')),
              _pdfDivider(),
              _pdfRow('TOTAL LIABILITIES', 'UGX ${numFmt.format(bsTotalL2)}', bold: true),
              pw.SizedBox(height: 16),
              pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...bsEq2.where((a) => _acctBal(a, bsRaw2) != 0)
                  .map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw2))}')),
              _pdfRow('  Current Year Earnings', 'UGX ${numFmt.format(bsCYE2)}'),
              _pdfDivider(),
              _pdfRow('TOTAL LIABILITIES & EQUITY', 'UGX ${numFmt.format(bsTotalL2 + bsTotalEq2)}',
                  bold: true, size: 13),
            ],
          ),
        ));
      }

      // Page 3: Outlet Performance
      final sortedEntries = (summary?.entries.toList() ?? [])
        ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('OUTLET PERFORMANCE REPORT'),
            if (sortedEntries.isEmpty)
              pw.Text('No outlet data yet. Import CSV data to see outlet performance.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Outlet', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                data: sortedEntries.map((entry) {
                  final outlet = outlets.where((o) => o.outletCode == entry.key).firstOrNull;
                  final d = entry.value;
                  return [
                    outlet?.name ?? 'Outlet ${entry.key}',
                    numFmt.format(d['totalIn'] ?? 0),
                    numFmt.format(d['totalOut'] ?? 0),
                    numFmt.format(d['totalGGR'] ?? 0),
                    '${(d['days'] ?? 0).toInt()}',
                  ];
                }).toList(),
              ),
          ],
        ),
      ));

      final bytes = await pdf.save();
      final filename = 'MagicBet_All_Reports_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildReportContent(BuildContext context, String reportName) {
    if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
      return _buildIncomeStatementPreview(context);
    } else if (reportName == 'Balance Sheet') {
      return _buildBalanceSheetPreview(context);
    } else if (reportName == 'Trial Balance') {
      return _buildTrialBalancePreview(context);
    } else if (reportName == 'Cash Flow Statement') {
      return _buildCashFlowPreview(context);
    } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
      return _buildGGRTaxPreview(context);
    } else if (reportName == 'GGR by Outlet' || reportName == 'Outlet Revenue Summary') {
      return _buildOutletPerformancePreview(context);
    } else if (reportName == 'Top Performers') {
      return _buildTopPerformersPreview(context);
    } else if (reportName == 'Daily Performance') {
      return _buildDailyPerformancePreview(context);
    } else if (reportName == 'Payout Ratio Analysis') {
      return _buildPayoutRatioPreview(context);
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Report Preview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Click Export to generate the full report',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }
  }

  Widget _buildIncomeStatementPreview(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final accountsState = ref.watch(accountsProvider);

    final entries = journalsState.entries;
    final accounts = accountsState.accounts;
    final raw = _computeLedgerBalances(entries);

    // Group accounts by type
    final revenueAccts = accounts.where((a) => a.type == AccountType.revenue).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final expenseAccts = accounts.where((a) => a.type == AccountType.expense).toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    // Identify specific expense sub-groups by account code
    const corCodes = {'107', '178'}; // Customer Winnings/Payouts + Outlet Commission Expense
    const directTaxCodes = {'108'}; // Gaming Tax Expense

    final corAccts = expenseAccts.where((a) => corCodes.contains(a.code)).toList();
    final directTaxAccts = expenseAccts.where((a) => directTaxCodes.contains(a.code)).toList();
    final opexAccts = expenseAccts
        .where((a) => !corCodes.contains(a.code) && !directTaxCodes.contains(a.code))
        .toList();

    double _sum(List<Account> list) => list.fold(0.0, (s, a) => s + _acctBal(a, raw));

    final totalRevenue = _sum(revenueAccts);
    final totalCoR = _sum(corAccts);
    final ggr = totalRevenue - totalCoR;
    final totalDirectTax = _sum(directTaxAccts);
    final netGamingRevenue = ggr - totalDirectTax;
    final totalOpex = _sum(opexAccts);
    final netIncome = netGamingRevenue - totalOpex;

    if (raw.isEmpty) {
      return Center(
        child: Text(
          'No data yet. Import CSV data to see the income statement.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAGIC BET LTD — INCOME STATEMENT',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('For the period ended ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
          const SizedBox(height: 16),

          // Revenue
          _ReportSection(
            title: 'Revenue',
            items: revenueAccts
                .where((a) => _acctBal(a, raw) != 0)
                .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                .toList(),
            total: totalRevenue,
            isPositive: true,
            onItemTap: (item) => _showLedgerDrillDown(context, item),
          ),
          const SizedBox(height: 8),

          // Cost of Revenue — Payouts (107) + Outlet Commission Expense (178)
          _ReportSection(
            title: 'Cost of Revenue',
            items: corAccts
                .where((a) => _acctBal(a, raw) != 0)
                .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                .toList(),
            total: totalCoR,
            isPositive: false,
            onItemTap: (item) => _showLedgerDrillDown(context, item),
          ),
          const Divider(),
          _ReportTotalRow(label: 'Gross Gaming Revenue (GGR)', amount: ggr, isHighlight: true),
          const SizedBox(height: 12),

          // Direct Taxes (Gaming Tax)
          if (directTaxAccts.any((a) => _acctBal(a, raw) != 0)) ...[
            _ReportSection(
              title: 'Direct Taxes',
              items: directTaxAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalDirectTax,
              isPositive: false,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
            const Divider(),
            _ReportTotalRow(label: 'Net Gaming Revenue', amount: netGamingRevenue, isHighlight: true),
            const SizedBox(height: 12),
          ],

          // Operating Expenses
          if (opexAccts.any((a) => _acctBal(a, raw) != 0)) ...[
            _ReportSection(
              title: 'Operating Expenses',
              items: opexAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalOpex,
              isPositive: false,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
          ],

          const Divider(height: 32),
          _ReportTotalRow(
            label: 'Net Income',
            amount: netIncome,
            isHighlight: true,
            isFinal: true,
          ),
        ],
      ),
    );
  }

  /// Shows a modal ledger drill-down: all journal entry lines for [item]'s account.
  void _showLedgerDrillDown(BuildContext context, Map<String, dynamic> item) {
    final accountId = item['accountId'] as String?;
    if (accountId == null) return;
    final accountName = item['name'] as String? ?? accountId;
    final entries = ref.read(journalsProvider).entries;
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('dd MMM yyyy');

    // Collect all journal lines for this account
    final lines = <Map<String, dynamic>>[];
    for (final entry in entries) {
      if (entry.status != JournalEntryStatus.posted) continue;
      for (final line in entry.lines) {
        if (line.accountId == accountId) {
          lines.add({
            'date': entry.date,
            'entryNumber': entry.entryNumber,
            'description': entry.description,
            'reference': entry.reference,
            'debit': line.debit,
            'credit': line.credit,
          });
        }
      }
    }
    lines.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final totalDebit = lines.fold<double>(0, (s, l) => s + (l['debit'] as double));
    final totalCredit = lines.fold<double>(0, (s, l) => s + (l['credit'] as double));
    final netBalance = totalDebit - totalCredit;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ledger: $accountName',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const Divider(),
                // Summary row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _drillChip('Total Debits', fmt.format(totalDebit), Colors.red.shade700),
                      const SizedBox(width: 16),
                      _drillChip('Total Credits', fmt.format(totalCredit), Colors.green.shade700),
                      const SizedBox(width: 16),
                      _drillChip('Net Balance', fmt.format(netBalance.abs()), Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        netBalance >= 0 ? '(Dr)' : '(Cr)',
                        style: TextStyle(
                          fontSize: 12,
                          color: netBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (lines.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No posted journal entries for this account.'),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(90),
                          1: FixedColumnWidth(130),
                          2: FlexColumnWidth(),
                          3: FixedColumnWidth(110),
                          4: FixedColumnWidth(110),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.all(6), child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Entry #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Debit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                              Padding(padding: EdgeInsets.all(6), child: Text('Credit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                            ],
                          ),
                          ...lines.map((l) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(dateFmt.format(l['date'] as DateTime), style: const TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(l['entryNumber'] as String, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(
                                      l['description'] as String,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(
                                      (l['debit'] as double) > 0 ? fmt.format(l['debit']) : '',
                                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (l['debit'] as double) > 0 ? Colors.red.shade700 : null),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(
                                      (l['credit'] as double) > 0 ? fmt.format(l['credit']) : '',
                                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (l['credit'] as double) > 0 ? Colors.green.shade700 : null),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drillChip(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey.shade600)),
          TextSpan(text: 'UGX $value', style: TextStyle(fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetPreview(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final accountsState = ref.watch(accountsProvider);

    final entries = journalsState.entries;
    final accounts = accountsState.accounts;
    final raw = _computeLedgerBalances(entries);

    final assetAccts = accounts.where((a) => a.type == AccountType.asset).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final liabilityAccts = accounts.where((a) => a.type == AccountType.liability).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final equityAccts = accounts.where((a) => a.type == AccountType.equity).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final revenueAccts = accounts.where((a) => a.type == AccountType.revenue).toList();
    final expenseAccts = accounts.where((a) => a.type == AccountType.expense).toList();

    final totalAssets = assetAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalLiabilities = liabilityAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalPermEquity = equityAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalRevenue = revenueAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalExpenses = expenseAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final currentYearEarnings = totalRevenue - totalExpenses;
    final totalEquity = totalPermEquity + currentYearEarnings;
    final balanced = (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAGIC BET LTD - BALANCE SHEET',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('As at ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
          const SizedBox(height: 16),
          if (raw.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No posted journal entries yet. Import CSV data to see balances.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
              ),
            )
          else ...[
            Text('ASSETS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ReportSection(
              title: 'Current & Non-Current Assets',
              items: assetAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw)})
                  .toList(),
              total: totalAssets,
              isPositive: true,
            ),
            _ReportTotalRow(label: 'Total Assets', amount: totalAssets, isHighlight: true),
            const Divider(height: 32),
            Text('LIABILITIES', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ReportSection(
              title: 'Current & Non-Current Liabilities',
              items: liabilityAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw)})
                  .toList(),
              total: totalLiabilities,
              isPositive: false,
            ),
            _ReportTotalRow(label: 'Total Liabilities', amount: totalLiabilities, isHighlight: true),
            const Divider(height: 32),
            Text('EQUITY', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ReportSection(
              title: "Owner's Equity",
              items: [
                ...equityAccts
                    .where((a) => _acctBal(a, raw) != 0)
                    .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw)}),
                {'name': 'Current Year Earnings', 'amount': currentYearEarnings},
              ],
              total: totalEquity,
              isPositive: true,
            ),
            const Divider(),
            _ReportTotalRow(
                label: 'Total Liabilities & Equity',
                amount: totalLiabilities + totalEquity,
                isHighlight: true,
                isFinal: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(balanced ? Icons.check_circle : Icons.warning,
                    color: balanced ? AppColors.success : AppColors.warning, size: 16),
                const SizedBox(width: 6),
                Text(
                  balanced ? 'Balance sheet is balanced ✓' : 'Warning: balance sheet does not balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: balanced ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutletPerformancePreview(BuildContext context) {
    final summaryAsync = ref.watch(outletRevenueSummaryProvider);
    final outletsAsync = ref.watch(outletsStreamProvider);

    return summaryAsync.when(
      data: (summary) => outletsAsync.when(
        data: (outlets) {
          if (summary.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No outlet data yet', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Import CSV data to see outlet performance',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            );
          }

          // Sort by GGR descending
          final sortedEntries = summary.entries.toList()
            ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Total In', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    Expanded(child: Text('Total Out', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    Expanded(child: Text('GGR', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    Expanded(child: Text('Days', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = sortedEntries[index];
                    final outlet = outlets.where((o) => o.outletCode == entry.key).firstOrNull;
                    final data = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(outlet?.name ?? 'Outlet ${entry.key}')),
                          Expanded(child: Text(_currencyFormat.format(data['totalIn']), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace'))),
                          Expanded(child: Text(_currencyFormat.format(data['totalOut']), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace'))),
                          Expanded(child: Text(
                            _currencyFormat.format(data['totalGGR']),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: (data['totalGGR'] ?? 0) >= 0 ? AppColors.income : AppColors.expense,
                            ),
                          )),
                          Expanded(child: Text('${(data['days'] ?? 0).toInt()}', textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading outlets')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Top Performers ─────────────────────────────────────────────────────────
  Widget _buildTopPerformersPreview(BuildContext context) {
    final analyticsAsync = ref.watch(outletAnalyticsProvider);

    return analyticsAsync.when(
      data: (analytics) {
        final ranked = List<OutletLifetime>.from(analytics.lifetimeTotals)
          ..sort((a, b) => b.netRevenue.compareTo(a.netRevenue));

        if (ranked.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text('No outlet data yet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Import CSV data to see top performers',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          );
        }

        final maxNetRev = ranked.first.netRevenue.abs().clamp(1.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('MAGIC BET LTD — TOP PERFORMERS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(child: Text('GGR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Commission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Net Revenue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  SizedBox(width: 120, child: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ranked.length,
                itemBuilder: (context, index) {
                  final ol = ranked[index];
                  final rank = index + 1;
                  final barFraction = (ol.netRevenue / maxNetRev).clamp(0.0, 1.0);
                  final isPositive = ol.netRevenue >= 0;

                  Color rankColor;
                  IconData rankIcon;
                  if (rank == 1) { rankColor = const Color(0xFFFFD700); rankIcon = Icons.looks_one; }
                  else if (rank == 2) { rankColor = const Color(0xFFC0C0C0); rankIcon = Icons.looks_two; }
                  else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankIcon = Icons.looks_3; }
                  else { rankColor = Theme.of(context).colorScheme.outline; rankIcon = Icons.circle; }

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4))),
                      color: rank <= 3 ? rankColor.withOpacity(0.04) : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Icon(rankIcon, size: 18, color: rankColor),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ol.outletName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(ol.outletCode, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormat('#,##0').format(ol.totalGGR),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormat('#,##0').format(ol.totalOutletExpense),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormat('#,##0').format(ol.netRevenue),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPositive ? AppColors.income : AppColors.expense,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: barFraction,
                                minHeight: 10,
                                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isPositive ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading analytics')),
    );
  }

  // ── Trial Balance ──────────────────────────────────────────────────────────
  Widget _buildTrialBalancePreview(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final accountsState = ref.watch(accountsProvider);

    final entries = journalsState.entries;
    final accounts = accountsState.accounts;
    final raw = _computeLedgerBalances(entries);

    final sortedAccounts = List<Account>.from(accounts)
      ..sort((a, b) => a.code.compareTo(b.code));

    final rows = <Map<String, dynamic>>[];
    double totalDebits = 0;
    double totalCredits = 0;

    for (final account in sortedAccounts) {
      final netRaw = raw['acct-${account.code}'] ?? 0.0;
      if (netRaw == 0.0) continue;
      double debit = 0;
      double credit = 0;
      if (netRaw > 0) {
        debit = netRaw;
        totalDebits += netRaw;
      } else {
        credit = -netRaw;
        totalCredits += -netRaw;
      }
      rows.add({
        'code': account.code,
        'account': account.name,
        'type': account.type.name[0].toUpperCase() + account.type.name.substring(1),
        'debit': debit,
        'credit': credit,
      });
    }

    if (rows.isEmpty) {
      return Center(child: Text('No data yet. Import CSV data to see the trial balance.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
    }

    return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — TRIAL BALANCE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('As at ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FixedColumnWidth(56),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant),
                    children: const [
                      Padding(padding: EdgeInsets.all(8), child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Debit (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                      Padding(padding: EdgeInsets.all(8), child: Text('Credit (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    ],
                  ),
                  ...rows.map((row) => TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4))),
                    ),
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(row['code'] as String, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(row['account'] as String, style: const TextStyle(fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(row['type'] as String, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(
                        (row['debit'] as double) > 0 ? NumberFormat('#,##0').format(row['debit']) : '—',
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (row['debit'] as double) > 0 ? AppColors.debit : Theme.of(context).colorScheme.outline),
                        textAlign: TextAlign.right,
                      )),
                      Padding(padding: const EdgeInsets.all(8), child: Text(
                        (row['credit'] as double) > 0 ? NumberFormat('#,##0').format(row['credit']) : '—',
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (row['credit'] as double) > 0 ? AppColors.income : Theme.of(context).colorScheme.outline),
                        textAlign: TextAlign.right,
                      )),
                    ],
                  )),
                  TableRow(
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08)),
                    children: [
                      const Padding(padding: EdgeInsets.all(8), child: SizedBox.shrink()),
                      const Padding(padding: EdgeInsets.all(8), child: Text('TOTALS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      const Padding(padding: EdgeInsets.all(8), child: SizedBox.shrink()),
                      Padding(padding: const EdgeInsets.all(8), child: Text(
                        NumberFormat('#,##0').format(totalDebits),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace', color: AppColors.primary),
                        textAlign: TextAlign.right,
                      )),
                      Padding(padding: const EdgeInsets.all(8), child: Text(
                        NumberFormat('#,##0').format(totalCredits),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace', color: AppColors.primary),
                        textAlign: TextAlign.right,
                      )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(totalDebits == totalCredits ? Icons.check_circle : Icons.warning,
                      color: totalDebits == totalCredits ? AppColors.success : AppColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    totalDebits == totalCredits ? 'Trial balance is balanced ✓' : 'Warning: trial balance does not balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: totalDebits == totalCredits ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  // ── Cash Flow Statement ────────────────────────────────────────────────────
  Widget _buildCashFlowPreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final analyticsAsync = ref.watch(outletAnalyticsProvider);
    return dashboardAsync.when(
      data: (data) {
        final cashIn = data.cashIn;
        final cashOut = data.cashOut;
        final ggr = data.totalRevenue;
        final commission = data.totalExpenses;
        final netCash = data.netIncome;

        // Per-outlet breakdown from analytics provider (carry-forward engine)
        final outletTotals = analyticsAsync.valueOrNull?.lifetimeTotals ?? [];
        final sortedOutlets = List<OutletLifetime>.from(outletTotals)
          ..sort((a, b) => b.totalGGR.compareTo(a.totalGGR));

        if (cashIn == 0) {
          return Center(child: Text('No data yet. Import CSV data to see the cash flow statement.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }

        Widget cfRow(String label, double amount, {bool bold = false, bool isFinal = false, bool isSubtotal = false, String? indent}) {
          final isNegative = amount < 0;
          final display = amount == 0 ? '—' : '${isNegative ? '(' : ''}UGX ${NumberFormat('#,##0').format(amount.abs())}${isNegative ? ')' : ''}';
          return Padding(
            padding: EdgeInsets.symmetric(vertical: isFinal ? 6 : 3, horizontal: 0),
            child: Row(
              children: [
                Expanded(child: Text(
                  indent != null ? '$indent$label' : label,
                  style: TextStyle(
                    fontWeight: bold || isFinal ? FontWeight.bold : FontWeight.normal,
                    fontSize: isFinal ? 14 : 13,
                  ),
                )),
                Text(
                  display,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: bold || isFinal ? FontWeight.bold : FontWeight.normal,
                    fontSize: isFinal ? 14 : 13,
                    color: isNegative ? AppColors.expense : (isFinal || bold ? AppColors.primary : null),
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — STATEMENT OF CASH FLOWS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Period: $_selectedPeriod  |  Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 16),

              // Operating Activities
              Text('OPERATING ACTIVITIES', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const Divider(height: 8),
              cfRow('Cash received from betting customers (Total Stakes)', cashIn, indent: '  '),
              cfRow('Cash paid to winning customers (Payouts)', -cashOut, indent: '  '),
              const Divider(height: 8),
              cfRow('Net cash from betting operations', ggr, bold: true),
              const SizedBox(height: 4),
              cfRow('Commission paid to outlet owners (40% of GGR)', -commission, indent: '  '),
              const Divider(height: 8),
              cfRow('NET CASH FROM OPERATING ACTIVITIES', netCash, isFinal: true),

              // Outlet aggregate — single summary line (detail in Outlet Performance report)
              if (sortedOutlets.isNotEmpty)
                cfRow(
                  '  Net revenue across ${sortedOutlets.length} outlets (see Outlet Performance for details)',
                  netCash,
                  indent: '    ',
                ),

              const SizedBox(height: 16),
              // Investing
              Text('INVESTING ACTIVITIES', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const Divider(height: 8),
              cfRow('No capital expenditure transactions recorded', 0.0, indent: '  '),
              const Divider(height: 8),
              cfRow('NET CASH FROM INVESTING ACTIVITIES', 0.0, isFinal: true),

              const SizedBox(height: 16),
              // Financing
              Text('FINANCING ACTIVITIES', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const Divider(height: 8),
              cfRow('No financing transactions recorded', 0.0, indent: '  '),
              const Divider(height: 8),
              cfRow('NET CASH FROM FINANCING ACTIVITIES', 0.0, isFinal: true),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    cfRow('Opening Cash Balance', 0.0),
                    cfRow('Net Increase in Cash', netCash, bold: true),
                    const Divider(height: 8),
                    cfRow('CLOSING CASH BALANCE', netCash, isFinal: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── GGR Tax Report ─────────────────────────────────────────────────────────
  Widget _buildGGRTaxPreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    return dashboardAsync.when(
      data: (data) {
        final ggr = data.totalRevenue;

        if (ggr == 0) {
          return Center(child: Text('No data yet. Import CSV data to see the revenue report.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — GGR REVENUE REPORT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Gross Gaming Revenue and Distribution Summary',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 16),
              _ReportSection(title: 'Gross Gaming Revenue', items: [
                {'name': 'Total Stakes (Cash In)', 'amount': data.cashIn},
                {'name': 'Less: Customer Winnings (Payouts)', 'amount': -data.cashOut},
              ], total: ggr, isPositive: true),
              const Divider(height: 24),
              _ReportTotalRow(label: 'Gross Gaming Revenue (GGR)', amount: ggr, isHighlight: true),
              const SizedBox(height: 8),
              _ReportTotalRow(label: 'Less: Outlet Commission (40% of GGR)', amount: -data.totalExpenses, isHighlight: false),
              const Divider(height: 16),
              _ReportTotalRow(label: 'NET REVENUE AFTER COMMISSION', amount: ggr - data.totalExpenses, isHighlight: true, isFinal: true),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Daily Performance ──────────────────────────────────────────────────────
  Widget _buildDailyPerformancePreview(BuildContext context) {
    final analyticsAsync = ref.watch(outletAnalyticsProvider);
    return analyticsAsync.when(
      data: (analytics) {
        if (analytics.allWeeks.isEmpty) {
          return Center(child: Text('No data yet. Import CSV data to see daily performance.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }
        // Aggregate weekly data as proxy for period performance
        final weeks = analytics.allWeeks;
        final grouped = <String, Map<String, double>>{};
        for (final w in weeks) {
          final key = '${w.year}-W${w.weekNumber.toString().padLeft(2, '0')}';
          grouped[key] = (grouped[key] ?? {});
          grouped[key]!['ggr'] = (grouped[key]!['ggr'] ?? 0) + w.adjustedGGR;
          grouped[key]!['commission'] = (grouped[key]!['commission'] ?? 0) + w.outletExpense;
          grouped[key]!['net'] = (grouped[key]!['net'] ?? 0) + w.netRevenue;
        }
        final sortedWeeks = grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(child: Text('Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(child: Text('GGR (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Commission (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Net Revenue (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sortedWeeks.length,
                itemBuilder: (context, i) {
                  final e = sortedWeeks[i];
                  final net = e.value['net'] ?? 0.0;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)))),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text(NumberFormat('#,##0').format(e.value['ggr'] ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text(NumberFormat('#,##0').format(e.value['commission'] ?? 0), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.warning))),
                        Expanded(child: Text(NumberFormat('#,##0').format(net), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: net >= 0 ? AppColors.income : AppColors.error))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Payout Ratio Analysis ──────────────────────────────────────────────────
  Widget _buildPayoutRatioPreview(BuildContext context) {
    final summaryAsync = ref.watch(outletRevenueSummaryProvider);
    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) {
          return Center(child: Text('No data yet. Import CSV data to see payout ratios.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }
        final sorted = summary.entries.toList()
          ..sort((a, b) {
            final ratioA = (a.value['totalIn'] ?? 0) > 0 ? (a.value['totalOut'] ?? 0) / (a.value['totalIn'] ?? 1) : 0.0;
            final ratioB = (b.value['totalIn'] ?? 0) > 0 ? (b.value['totalOut'] ?? 0) / (b.value['totalIn'] ?? 1) : 0.0;
            return ratioB.compareTo(ratioA);
          });
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(child: Text('Total In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Total Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Payout %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final e = sorted[i];
                  final totalIn = e.value['totalIn'] ?? 0.0;
                  final totalOut = e.value['totalOut'] ?? 0.0;
                  final ratio = totalIn > 0 ? totalOut / totalIn * 100 : 0.0;
                  final ratioColor = ratio > 90 ? AppColors.error : ratio > 80 ? AppColors.warning : AppColors.success;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)))),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(e.key, style: const TextStyle(fontSize: 12))),
                        Expanded(child: Text(NumberFormat('#,##0').format(totalIn), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text(NumberFormat('#,##0').format(totalOut), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text('${ratio.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ratioColor))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────
  Future<void> _exportReportCsv(String reportName) async {
    try {
      final numFmt = NumberFormat('#,##0', 'en_US');
      final dashData = ref.read(dashboardDataProvider).valueOrNull;
      final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
      final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

      List<List<dynamic>> csvRows = [];

      if (reportName == 'Trial Balance') {
        final tbAccounts2 = ref.read(accountsProvider).accounts;
        final tbEntries2 = ref.read(journalsProvider).entries;
        final tbRaw2 = _computeLedgerBalances(tbEntries2);
        final tbSorted2 = List<Account>.from(tbAccounts2)..sort((a, b) => a.code.compareTo(b.code));
        double tbDr2 = 0;
        double tbCr2 = 0;
        final tbDataRows = <List<dynamic>>[];
        for (final acct in tbSorted2) {
          final net = tbRaw2['acct-${acct.code}'] ?? 0.0;
          if (net == 0.0) continue;
          final typeName = acct.type.name[0].toUpperCase() + acct.type.name.substring(1);
          if (net > 0) {
            tbDataRows.add([acct.code, acct.name, typeName, numFmt.format(net), '']);
            tbDr2 += net;
          } else {
            tbDataRows.add([acct.code, acct.name, typeName, '', numFmt.format(-net)]);
            tbCr2 += -net;
          }
        }
        csvRows = [
          ['MAGIC BET LTD — TRIAL BALANCE'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Account Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)'],
          ...tbDataRows,
          [],
          ['', 'TOTALS', '', numFmt.format(tbDr2), numFmt.format(tbCr2)],
        ];
      } else if (reportName == 'Cash Flow Statement') {
        final cashIn = dashData?.cashIn ?? 0;
        final cashOut = dashData?.cashOut ?? 0;
        final commission = dashData?.totalExpenses ?? 0;
        final netCash = dashData?.netIncome ?? 0;
        csvRows = [
          ['MAGIC BET LTD — STATEMENT OF CASH FLOWS'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Section', 'Description', 'Amount (UGX)'],
          ['Operating', 'Cash received from betting customers', numFmt.format(cashIn)],
          ['Operating', 'Cash paid to winning customers', '(${numFmt.format(cashOut)})'],
          ['Operating', 'Net cash from betting operations', numFmt.format(cashIn - cashOut)],
          ['Operating', 'Commission paid to outlet owners', '(${numFmt.format(commission)})'],
          ['Operating', 'NET CASH FROM OPERATING ACTIVITIES', numFmt.format(netCash)],
          ['Investing', 'No investing activities', '—'],
          ['Financing', 'No financing activities', '—'],
          [],
          ['Summary', 'Opening Cash Balance', '0'],
          ['Summary', 'Net Increase in Cash', numFmt.format(netCash)],
          ['Summary', 'CLOSING CASH BALANCE', numFmt.format(netCash)],
        ];
      } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
        final ggr = dashData?.totalRevenue ?? 0;
        csvRows = [
          ['MAGIC BET LTD — GGR REVENUE REPORT'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Item', 'Amount (UGX)'],
          ['Total Stakes (Cash In)', numFmt.format(dashData?.cashIn ?? 0)],
          ['Less: Customer Winnings', '(${numFmt.format(dashData?.cashOut ?? 0)})'],
          ['Gross Gaming Revenue (GGR)', numFmt.format(ggr)],
          ['Outlet Commission (40% of GGR)', '(${numFmt.format(dashData?.totalExpenses ?? 0)})'],
          ['Net Revenue After Commission', numFmt.format(ggr - (dashData?.totalExpenses ?? 0))],
        ];
      } else if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
        final cashIn = dashData?.cashIn ?? 0;
        final cashOut = dashData?.cashOut ?? 0;
        final ggr = dashData?.totalRevenue ?? 0;
        final commission = dashData?.totalExpenses ?? 0;
        csvRows = [
          ['MAGIC BET LTD — INCOME STATEMENT'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Category', 'Item', 'Amount (UGX)'],
          ['Revenue', 'Total Stakes (Cash In)', numFmt.format(cashIn)],
          ['Cost of Revenue', 'Customer Winnings (Payouts)', '(${numFmt.format(cashOut)})'],
          ['', 'GROSS GAMING REVENUE (GGR)', numFmt.format(ggr)],
          ['Expenses', 'Outlet Commission (40%)', '(${numFmt.format(commission)})'],
          ['', 'NET REVENUE', numFmt.format(dashData?.netIncome ?? 0)],
        ];
      } else {
        // Outlet performance for all other reports
        final sortedEntries = (summary?.entries.toList() ?? [])
          ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));
        csvRows = [
          ['MAGIC BET LTD — ${reportName.toUpperCase()}'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Outlet Code', 'Outlet Name', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days'],
          ...sortedEntries.map((e) {
            final outlet = outlets.where((o) => o.outletCode == e.key).firstOrNull;
            return [
              e.key,
              outlet?.name ?? 'Outlet ${e.key}',
              numFmt.format(e.value['totalIn'] ?? 0),
              numFmt.format(e.value['totalOut'] ?? 0),
              numFmt.format(e.value['totalGGR'] ?? 0),
              '${(e.value['days'] ?? 0).toInt()}',
            ];
          }),
        ];
      }

      final csv = const ListToCsvConverter().convert(csvRows);
      final filename = '${reportName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export $reportName as CSV',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (path != null) {
        await File(path).writeAsString(csv);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSV exported: $path'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Excel Export ───────────────────────────────────────────────────────────
  Future<void> _exportReportExcel(String reportName) async {
    try {
      final numFmt = NumberFormat('#,##0', 'en_US');
      final dashData = ref.read(dashboardDataProvider).valueOrNull;
      final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
      final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

      final excel = xl.Excel.createExcel();
      final sheetName = reportName.length > 31 ? reportName.substring(0, 31) : reportName;
      final sheet = excel[sheetName];
      // Remove default Sheet1 if it exists and is different
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      void addHeader(List<String> headers) {
        final row = headers.map((h) => xl.TextCellValue(h)).toList();
        sheet.appendRow(row);
        // Bold the header row
        for (int c = 0; c < headers.length; c++) {
          final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sheet.maxRows - 1));
          cell.cellStyle = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'), fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'));
        }
      }

      void addTitle(String title) {
        sheet.appendRow([xl.TextCellValue(title)]);
        sheet.appendRow([xl.TextCellValue('Generated: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}')]);
        sheet.appendRow([xl.TextCellValue('')]);
      }

      if (reportName == 'Trial Balance') {
        final tbAcc3 = ref.read(accountsProvider).accounts;
        final tbEnt3 = ref.read(journalsProvider).entries;
        final tbRaw3 = _computeLedgerBalances(tbEnt3);
        final tbSorted3 = List<Account>.from(tbAcc3)..sort((a, b) => a.code.compareTo(b.code));
        double tbDr3 = 0;
        double tbCr3 = 0;
        addTitle('MAGIC BET LTD — TRIAL BALANCE');
        addHeader(['Account Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)']);
        for (final acct in tbSorted3) {
          final net = tbRaw3['acct-${acct.code}'] ?? 0.0;
          if (net == 0.0) continue;
          final typeName = acct.type.name[0].toUpperCase() + acct.type.name.substring(1);
          if (net > 0) {
            sheet.appendRow([xl.TextCellValue(acct.code), xl.TextCellValue(acct.name), xl.TextCellValue(typeName),
              xl.DoubleCellValue(net), xl.TextCellValue('—')]);
            tbDr3 += net;
          } else {
            sheet.appendRow([xl.TextCellValue(acct.code), xl.TextCellValue(acct.name), xl.TextCellValue(typeName),
              xl.TextCellValue('—'), xl.DoubleCellValue(-net)]);
            tbCr3 += -net;
          }
        }
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('TOTALS'), xl.TextCellValue(''),
          xl.DoubleCellValue(tbDr3), xl.DoubleCellValue(tbCr3)]);
      } else if (reportName == 'Cash Flow Statement') {
        final cashIn = dashData?.cashIn ?? 0;
        final cashOut = dashData?.cashOut ?? 0;
        final commission = dashData?.totalExpenses ?? 0;
        final netCash = dashData?.netIncome ?? 0;
        addTitle('MAGIC BET LTD — STATEMENT OF CASH FLOWS');
        addHeader(['Section', 'Description', 'Amount (UGX)']);
        sheet.appendRow([xl.TextCellValue('Operating'), xl.TextCellValue('Cash received from betting customers'), xl.DoubleCellValue(cashIn)]);
        sheet.appendRow([xl.TextCellValue('Operating'), xl.TextCellValue('Cash paid to winning customers'), xl.DoubleCellValue(-cashOut)]);
        sheet.appendRow([xl.TextCellValue('Operating'), xl.TextCellValue('Net cash from betting operations'), xl.DoubleCellValue(cashIn - cashOut)]);
        sheet.appendRow([xl.TextCellValue('Operating'), xl.TextCellValue('Commission paid to outlet owners'), xl.DoubleCellValue(-commission)]);
        sheet.appendRow([xl.TextCellValue('Operating'), xl.TextCellValue('NET CASH FROM OPERATING ACTIVITIES'), xl.DoubleCellValue(netCash)]);
        sheet.appendRow([xl.TextCellValue('Summary'), xl.TextCellValue('CLOSING CASH BALANCE'), xl.DoubleCellValue(netCash)]);
      } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
        final ggr = dashData?.totalRevenue ?? 0;
        addTitle('MAGIC BET LTD — GGR REVENUE REPORT');
        addHeader(['Item', 'Amount (UGX)']);
        sheet.appendRow([xl.TextCellValue('Total Stakes (Cash In)'), xl.DoubleCellValue(dashData?.cashIn ?? 0)]);
        sheet.appendRow([xl.TextCellValue('Less: Customer Winnings'), xl.DoubleCellValue(-(dashData?.cashOut ?? 0))]);
        sheet.appendRow([xl.TextCellValue('Gross Gaming Revenue (GGR)'), xl.DoubleCellValue(ggr)]);
        sheet.appendRow([xl.TextCellValue('Outlet Commission (40%)'), xl.DoubleCellValue(-(dashData?.totalExpenses ?? 0))]);
        sheet.appendRow([xl.TextCellValue('Net Revenue After Commission'), xl.DoubleCellValue(ggr - (dashData?.totalExpenses ?? 0))]);
      } else if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
        addTitle('MAGIC BET LTD — INCOME STATEMENT');
        addHeader(['Category', 'Item', 'Amount (UGX)']);
        sheet.appendRow([xl.TextCellValue('Revenue'), xl.TextCellValue('Total Stakes (Cash In)'), xl.DoubleCellValue(dashData?.cashIn ?? 0)]);
        sheet.appendRow([xl.TextCellValue('Cost of Revenue'), xl.TextCellValue('Customer Winnings (Payouts)'), xl.DoubleCellValue(-(dashData?.cashOut ?? 0))]);
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('GROSS GAMING REVENUE'), xl.DoubleCellValue(dashData?.totalRevenue ?? 0)]);
        sheet.appendRow([xl.TextCellValue('Expenses'), xl.TextCellValue('Outlet Commission (40%)'), xl.DoubleCellValue(-(dashData?.totalExpenses ?? 0))]);
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('NET REVENUE'), xl.DoubleCellValue(dashData?.netIncome ?? 0)]);
      } else {
        // Outlet performance
        final sortedEntries = (summary?.entries.toList() ?? [])
          ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));
        addTitle('MAGIC BET LTD — ${reportName.toUpperCase()}');
        addHeader(['Outlet Code', 'Outlet Name', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days']);
        for (final e in sortedEntries) {
          final outlet = outlets.where((o) => o.outletCode == e.key).firstOrNull;
          sheet.appendRow([
            xl.TextCellValue(e.key),
            xl.TextCellValue(outlet?.name ?? 'Outlet ${e.key}'),
            xl.DoubleCellValue((e.value['totalIn'] ?? 0).toDouble()),
            xl.DoubleCellValue((e.value['totalOut'] ?? 0).toDouble()),
            xl.DoubleCellValue((e.value['totalGGR'] ?? 0).toDouble()),
            xl.IntCellValue((e.value['days'] ?? 0).toInt()),
          ]);
        }
      }

      // Auto-size first two columns
      sheet.setColumnWidth(0, 16);
      sheet.setColumnWidth(1, 36);
      sheet.setColumnWidth(2, 28);
      sheet.setColumnWidth(3, 20);
      sheet.setColumnWidth(4, 20);

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final filename = '${reportName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export $reportName as Excel',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (path != null) {
        await File(path).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel exported: $path'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;

  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              change,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCategorySection extends StatelessWidget {
  final String category;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> reports;
  final Function(Map<String, dynamic>) onReportTap;

  const _ReportCategorySection({
    required this.category,
    required this.icon,
    required this.color,
    required this.reports,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              category,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: reports.map((report) {
            return SizedBox(
              width: 280,
              child: Card(
                child: InkWell(
                  onTap: () => onReportTap(report),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(report['icon'], color: color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report['name'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report['description'],
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final double total;
  final bool isPositive;
  /// Optional — if supplied, each line becomes tappable for ledger drill-down.
  final void Function(Map<String, dynamic> item)? onItemTap;

  const _ReportSection({
    required this.title,
    required this.items,
    required this.total,
    required this.isPositive,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final canDrill = onItemTap != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline)),
            if (canDrill) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Tap any line to view journal entries',
                child: Icon(Icons.receipt_long_outlined, size: 13, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final rowContent = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('  ${item['name']}'),
                    if (canDrill)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.open_in_new, size: 11, color: Colors.blueGrey),
                      ),
                  ],
                ),
                Text(
                  'UGX ${NumberFormat('#,###').format(item['amount'])}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          );
          if (!canDrill) return rowContent;
          return InkWell(
            onTap: () => onItemTap!(item),
            borderRadius: BorderRadius.circular(4),
            hoverColor: Colors.blueGrey.withOpacity(0.06),
            child: rowContent,
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('  Total $title', style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              'UGX ${NumberFormat('#,###').format(total)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportTotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isHighlight;
  final bool isFinal;

  const _ReportTotalRow({
    required this.label,
    required this.amount,
    this.isHighlight = false,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isFinal ? FontWeight.bold : FontWeight.w600,
              fontSize: isFinal ? 16 : 14,
            ),
          ),
          Text(
            'UGX ${NumberFormat('#,###').format(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: isFinal ? 16 : 14,
              color: isHighlight ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
