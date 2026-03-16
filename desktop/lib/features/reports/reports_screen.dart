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
    } else if (reportName == 'Trial Balance') {
      final cashIn = dashData?.cashIn ?? 0;
      final cashOut = dashData?.cashOut ?? 0;
      final ggr = dashData?.totalRevenue ?? 0;
      final commission = dashData?.totalExpenses ?? 0;

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
              data: [
                ['1200', 'Outlet Cash Collections', 'Asset', numFmt.format(ggr), '—'],
                ['4100', 'Total Stakes / Cash In', 'Revenue', '—', numFmt.format(cashIn)],
                ['5000', 'Customer Winnings (Payouts)', 'Expense', numFmt.format(cashOut), '—'],
                ['5100', 'Outlet Commission Expense', 'Expense', numFmt.format(commission), '—'],
                ['2300', 'Commission Payable', 'Liability', '—', numFmt.format(commission)],
                ['', 'TOTALS', '', numFmt.format(ggr + cashOut + commission), numFmt.format(cashIn + commission)],
              ],
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
      final taxDue = ggr * 0.15;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('GGR TAX REPORT — UGANDA REVENUE AUTHORITY'),
            pw.Text('GAMING REVENUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Total Stakes (Cash In)', 'UGX ${numFmt.format(dashData?.cashIn ?? 0)}'),
            _pdfRow('  Less: Customer Winnings', '(UGX ${numFmt.format(dashData?.cashOut ?? 0)})'),
            _pdfDivider(),
            _pdfRow('Gross Gaming Revenue (GGR)', 'UGX ${numFmt.format(ggr)}', bold: true),
            pw.SizedBox(height: 12),
            pw.Text('TAX COMPUTATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Gaming Tax @ 15% of GGR', 'UGX ${numFmt.format(taxDue)}'),
            _pdfDivider(),
            _pdfRow('GGR After Gaming Tax', 'UGX ${numFmt.format(ggr - taxDue)}', bold: true),
            _pdfRow('  Outlet Commission (40%)', '(UGX ${numFmt.format(dashData?.totalExpenses ?? 0)})'),
            _pdfDivider(),
            _pdfRow('NET INCOME AFTER TAX & COMMISSION', 'UGX ${numFmt.format((ggr - taxDue) - (dashData?.totalExpenses ?? 0))}', bold: true, size: 13),
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
    } else if (reportName == 'Trial Balance') {
      return _buildTrialBalancePreview(context);
    } else if (reportName == 'Cash Flow Statement') {
      return _buildCashFlowPreview(context);
    } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
      return _buildGGRTaxPreview(context);
    } else if (reportName == 'GGR by Outlet' || reportName == 'Top Performers' || reportName == 'Outlet Revenue Summary') {
      return _buildOutletPerformancePreview(context);
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

  // ── Trial Balance ──────────────────────────────────────────────────────────
  Widget _buildTrialBalancePreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    return dashboardAsync.when(
      data: (data) {
        final cashIn = data.cashIn;
        final cashOut = data.cashOut;
        final ggr = data.totalRevenue;
        final commission = data.totalExpenses;
        final totalDebits = ggr + cashOut + commission;
        final totalCredits = cashIn + commission;

        final rows = [
          {'code': '1200', 'account': 'Outlet Cash Collections', 'type': 'Asset',     'debit': ggr,        'credit': 0.0},
          {'code': '4100', 'account': 'Total Stakes / Cash In',  'type': 'Revenue',   'debit': 0.0,        'credit': cashIn},
          {'code': '5000', 'account': 'Customer Winnings (Payouts)', 'type': 'Expense','debit': cashOut,   'credit': 0.0},
          {'code': '5100', 'account': 'Outlet Commission Expense','type': 'Expense',  'debit': commission, 'credit': 0.0},
          {'code': '2300', 'account': 'Commission Payable',       'type': 'Liability', 'debit': 0.0,       'credit': commission},
        ];

        if (cashIn == 0) {
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Cash Flow Statement ────────────────────────────────────────────────────
  Widget _buildCashFlowPreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    return dashboardAsync.when(
      data: (data) {
        final cashIn = data.cashIn;
        final cashOut = data.cashOut;
        final ggr = data.totalRevenue;
        final commission = data.totalExpenses;
        final netCash = data.netIncome;

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
        // Uganda GGR tax rate: 15% per URA Gaming Act
        const taxRate = 0.15;
        final taxDue = ggr * taxRate;
        final ggrAfterTax = ggr - taxDue;

        if (ggr == 0) {
          return Center(child: Text('No data yet. Import CSV data to see the tax report.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — GGR TAX REPORT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Uganda Revenue Authority — Gaming Tax Computation',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 16),
              _ReportSection(title: 'Gross Gaming Revenue', items: [
                {'name': 'Total Stakes (Cash In)', 'amount': data.cashIn},
                {'name': 'Less: Customer Winnings (Payouts)', 'amount': -data.cashOut},
              ], total: ggr, isPositive: true),
              const Divider(height: 24),
              _ReportSection(title: 'Gaming Tax Computation (URA)', items: [
                {'name': 'GGR Subject to Tax', 'amount': ggr},
                {'name': 'Applicable Tax Rate', 'amount': 0.0},
              ], total: 0.0, isPositive: false),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('  Gaming Tax @ 15% of GGR'),
                    Text('UGX ${NumberFormat('#,##0').format(taxDue)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppColors.expense)),
                  ],
                ),
              ),
              const Divider(height: 24),
              _ReportTotalRow(label: 'GGR After Tax', amount: ggrAfterTax, isHighlight: true),
              const SizedBox(height: 8),
              _ReportTotalRow(label: 'Less: Outlet Commission (40% of GGR)', amount: -data.totalExpenses, isHighlight: false),
              const Divider(height: 16),
              _ReportTotalRow(label: 'NET INCOME AFTER TAX AND COMMISSION', amount: ggrAfterTax - data.totalExpenses, isHighlight: true, isFinal: true),
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
        final cashIn = dashData?.cashIn ?? 0;
        final cashOut = dashData?.cashOut ?? 0;
        final ggr = dashData?.totalRevenue ?? 0;
        final commission = dashData?.totalExpenses ?? 0;
        csvRows = [
          ['MAGIC BET LTD — TRIAL BALANCE'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Account Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)'],
          ['1200', 'Outlet Cash Collections', 'Asset', numFmt.format(ggr), ''],
          ['4100', 'Total Stakes / Cash In', 'Revenue', '', numFmt.format(cashIn)],
          ['5000', 'Customer Winnings (Payouts)', 'Expense', numFmt.format(cashOut), ''],
          ['5100', 'Outlet Commission Expense', 'Expense', numFmt.format(commission), ''],
          ['2300', 'Commission Payable', 'Liability', '', numFmt.format(commission)],
          [],
          ['', 'TOTALS', '', numFmt.format(ggr + cashOut + commission), numFmt.format(cashIn + commission)],
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
        final taxDue = ggr * 0.15;
        csvRows = [
          ['MAGIC BET LTD — GGR TAX REPORT'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Item', 'Amount (UGX)'],
          ['Total Stakes (Cash In)', numFmt.format(dashData?.cashIn ?? 0)],
          ['Less: Customer Winnings', '(${numFmt.format(dashData?.cashOut ?? 0)})'],
          ['Gross Gaming Revenue (GGR)', numFmt.format(ggr)],
          ['Gaming Tax @ 15%', numFmt.format(taxDue)],
          ['GGR After Tax', numFmt.format(ggr - taxDue)],
          ['Outlet Commission (40% of GGR)', '(${numFmt.format(dashData?.totalExpenses ?? 0)})'],
          ['Net Income After Tax & Commission', numFmt.format((ggr - taxDue) - (dashData?.totalExpenses ?? 0))],
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
        final cashIn = dashData?.cashIn ?? 0;
        final cashOut = dashData?.cashOut ?? 0;
        final ggr = dashData?.totalRevenue ?? 0;
        final commission = dashData?.totalExpenses ?? 0;
        addTitle('MAGIC BET LTD — TRIAL BALANCE');
        addHeader(['Account Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)']);
        final rows = [
          ['1200', 'Outlet Cash Collections', 'Asset', ggr, 0.0],
          ['4100', 'Total Stakes / Cash In', 'Revenue', 0.0, cashIn],
          ['5000', 'Customer Winnings (Payouts)', 'Expense', cashOut, 0.0],
          ['5100', 'Outlet Commission Expense', 'Expense', commission, 0.0],
          ['2300', 'Commission Payable', 'Liability', 0.0, commission],
        ];
        for (final r in rows) {
          sheet.appendRow([
            xl.TextCellValue(r[0] as String),
            xl.TextCellValue(r[1] as String),
            xl.TextCellValue(r[2] as String),
            (r[3] as double) > 0 ? xl.DoubleCellValue(r[3] as double) : xl.TextCellValue('—'),
            (r[4] as double) > 0 ? xl.DoubleCellValue(r[4] as double) : xl.TextCellValue('—'),
          ]);
        }
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('TOTALS'), xl.TextCellValue(''),
          xl.DoubleCellValue(ggr + cashOut + commission), xl.DoubleCellValue(cashIn + commission)]);
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
        final taxDue = ggr * 0.15;
        addTitle('MAGIC BET LTD — GGR TAX REPORT');
        addHeader(['Item', 'Amount (UGX)']);
        sheet.appendRow([xl.TextCellValue('Total Stakes (Cash In)'), xl.DoubleCellValue(dashData?.cashIn ?? 0)]);
        sheet.appendRow([xl.TextCellValue('Less: Customer Winnings'), xl.DoubleCellValue(-(dashData?.cashOut ?? 0))]);
        sheet.appendRow([xl.TextCellValue('Gross Gaming Revenue (GGR)'), xl.DoubleCellValue(ggr)]);
        sheet.appendRow([xl.TextCellValue('Gaming Tax @ 15%'), xl.DoubleCellValue(taxDue)]);
        sheet.appendRow([xl.TextCellValue('GGR After Tax'), xl.DoubleCellValue(ggr - taxDue)]);
        sheet.appendRow([xl.TextCellValue('Outlet Commission (40%)'), xl.DoubleCellValue(-(dashData?.totalExpenses ?? 0))]);
        sheet.appendRow([xl.TextCellValue('Net Income After Tax & Commission'), xl.DoubleCellValue((ggr - taxDue) - (dashData?.totalExpenses ?? 0))]);
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
