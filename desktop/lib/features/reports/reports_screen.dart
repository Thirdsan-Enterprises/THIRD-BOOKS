import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
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
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportPdf(report['name'] as String);
            },
            icon: const Icon(Icons.download, size: 18),
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
      final cashIn = dashData?.cashIn ?? 0;
      final cashOut = dashData?.cashOut ?? 0;
      final ggr = dashData?.totalRevenue ?? 0;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('BALANCE SHEET'),
            pw.Text('ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            pw.Text('Current Assets', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            _pdfRow('  Outlet Cash Collections', 'UGX ${numFmt.format(cashIn)}'),
            _pdfDivider(),
            _pdfRow('TOTAL ASSETS', 'UGX ${numFmt.format(cashIn)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            pw.Text('Current Liabilities', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            _pdfRow('  Customer Payouts', 'UGX ${numFmt.format(cashOut)}'),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES', 'UGX ${numFmt.format(cashOut)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            pw.Text("Owner's Equity", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            _pdfRow('  Retained Earnings (GGR)', 'UGX ${numFmt.format(ggr)}'),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES & EQUITY', 'UGX ${numFmt.format(cashOut + ggr)}', bold: true, size: 13),
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

      // Page 2: Balance Sheet
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('BALANCE SHEET'),
            pw.Text('ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Outlet Cash Collections', 'UGX ${numFmt.format(totalIn)}'),
            _pdfDivider(),
            _pdfRow('TOTAL ASSETS', 'UGX ${numFmt.format(totalIn)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Customer Payouts', 'UGX ${numFmt.format(totalOut)}'),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES', 'UGX ${numFmt.format(totalOut)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Retained Earnings (GGR)', 'UGX ${numFmt.format(ggr)}'),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES & EQUITY', 'UGX ${numFmt.format(totalOut + ggr)}', bold: true, size: 13),
          ],
        ),
      ));

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
    } else if (reportName == 'GGR by Outlet' || reportName == 'Top Performers' || reportName == 'Outlet Revenue Summary') {
      return _buildOutletPerformancePreview(context);
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
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (data) {
        final totalIn = data.cashIn;
        final totalOut = data.cashOut;
        final ggr = data.totalRevenue;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD - INCOME STATEMENT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _ReportSection(
                title: 'Revenue',
                items: [
                  {'name': 'Total Stakes (Cash In)', 'amount': totalIn},
                ],
                total: totalIn,
                isPositive: true,
              ),
              const SizedBox(height: 16),
              _ReportSection(
                title: 'Cost of Revenue',
                items: [
                  {'name': 'Customer Winnings (Payouts)', 'amount': totalOut},
                ],
                total: totalOut,
                isPositive: false,
              ),
              const Divider(),
              _ReportTotalRow(label: 'Gross Gaming Revenue (GGR)', amount: ggr, isHighlight: true),
              if (ggr == 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No data yet. Import CSV data to see revenue.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
                  ),
                ),
              const Divider(height: 32),
              _ReportTotalRow(label: 'Net Income', amount: ggr, isHighlight: true, isFinal: true),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  Widget _buildBalanceSheetPreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (data) {
        final cashCollections = data.cashIn;
        final payoutsPayable = data.cashOut;
        final ggr = data.totalRevenue;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD - BALANCE SHEET',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('ASSETS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _ReportSection(
                title: 'Current Assets',
                items: [
                  {'name': 'Outlet Cash Collections', 'amount': cashCollections},
                ],
                total: cashCollections,
                isPositive: true,
              ),
              _ReportTotalRow(label: 'Total Assets', amount: cashCollections, isHighlight: true),
              const Divider(height: 32),
              Text('LIABILITIES', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _ReportSection(
                title: 'Current Liabilities',
                items: [
                  {'name': 'Customer Payouts', 'amount': payoutsPayable},
                ],
                total: payoutsPayable,
                isPositive: false,
              ),
              _ReportTotalRow(label: 'Total Liabilities', amount: payoutsPayable, isHighlight: true),
              const Divider(height: 32),
              Text('EQUITY', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _ReportSection(
                title: "Owner's Equity",
                items: [
                  {'name': 'Retained Earnings (GGR)', 'amount': ggr},
                ],
                total: ggr,
                isPositive: true,
              ),
              const Divider(),
              _ReportTotalRow(label: 'Total Liabilities & Equity', amount: payoutsPayable + ggr, isHighlight: true, isFinal: true),
              if (data.cashIn == 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No data yet. Import CSV data to see balances.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
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

  const _ReportSection({
    required this.title,
    required this.items,
    required this.total,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('  ${item['name']}'),
                  Text(
                    'UGX ${NumberFormat('#,###').format(item['amount'])}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            )),
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
