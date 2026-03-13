import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Outlet Analytics Screen
// Full weekly/monthly/per-outlet view with carry-forward commission engine.
// ─────────────────────────────────────────────────────────────────────────────

class OutletAnalyticsScreen extends ConsumerStatefulWidget {
  const OutletAnalyticsScreen({super.key});

  @override
  ConsumerState<OutletAnalyticsScreen> createState() => _OutletAnalyticsScreenState();
}

class _OutletAnalyticsScreenState extends ConsumerState<OutletAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Weekly filter
  int? _filterYear;
  int? _filterWeek;
  // Monthly filter
  int? _filterMonth;
  int? _filterMonthYear;
  // Per-outlet filter
  String? _selectedOutletId;

  final _fmt = NumberFormat('#,###');

  String _fc(double v) => 'UGX ${_fmt.format(v.round())}';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(outletAnalyticsProvider);

    return Scaffold(
      body: analyticsAsync.when(
        data: (data) => _buildBody(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error loading analytics: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(outletAnalyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, OutletAnalyticsData data) {
    return Column(
      children: [
        _buildHeader(context, data),
        _buildKPIs(context, data),
        _buildTabBar(context),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _OverviewTab(data: data, fc: _fc),
              _WeeklyTab(data: data, fc: _fc, onExport: _exportWeeklyCSV, onExportPDF: _exportWeeklyPDF),
              _MonthlyTab(data: data, fc: _fc, onExport: _exportMonthlyCSV, onExportPDF: _exportMonthlyPDF),
              _PerOutletTab(data: data, fc: _fc, onExport: _exportOutletCSV, onExportPDF: _exportOutletPDF),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, OutletAnalyticsData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outlet Analytics',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Revenue · Commission · Net — with carry-forward loss adjustment',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _exportAllCSV(data),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('Export CSV'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _exportAllPDF(data),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs(BuildContext context, OutletAnalyticsData data) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _KPI(
              label: 'Total GGR',
              value: _fc(data.totalGGR),
              sub: 'Gross Gaming Revenue',
              icon: Icons.bar_chart,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _KPI(
              label: 'Outlet Expense (40%)',
              value: _fc(data.totalOutletExpense),
              sub: 'Commission to location owners',
              icon: Icons.handshake_outlined,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _KPI(
              label: 'Net Revenue',
              value: _fc(data.totalNetRevenue),
              sub: 'Real money available to spend',
              icon: Icons.account_balance_wallet,
              color: AppColors.income,
              highlight: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _KPI(
              label: 'Active Outlets',
              value: data.totalActiveOutlets.toString(),
              sub: 'Contributing outlets',
              icon: Icons.store_mall_directory,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Weekly'),
          Tab(text: 'Monthly'),
          Tab(text: 'Per Outlet'),
        ],
      ),
    );
  }

  // ── Exports ──────────────────────────────────────────────────────────────

  Future<void> _exportAllCSV(OutletAnalyticsData data) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export All Analytics',
      fileName: 'outlet_analytics_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    final buf = StringBuffer();
    buf.writeln('MagicBet Outlet Analytics — ${DateFormat('MMMM d, yyyy').format(DateTime.now())}');
    buf.writeln('');
    buf.writeln('SUMMARY');
    buf.writeln('Total GGR,${data.totalGGR}');
    buf.writeln('Total Outlet Expense (40%),${data.totalOutletExpense}');
    buf.writeln('Total Net Revenue,${data.totalNetRevenue}');
    buf.writeln('');
    buf.writeln('WEEKLY BREAKDOWN');
    buf.writeln('Outlet,Code,Week Start,Week End,Week#,Raw GGR,Adj. GGR,40% Expense,Net Revenue');
    for (final w in data.allWeeks) {
      buf.writeln(
        '"${w.outletName}","${w.outletCode}",'
        '"${DateFormat('yyyy-MM-dd').format(w.weekStart)}",'
        '"${DateFormat('yyyy-MM-dd').format(w.weekEnd)}",'
        '${w.weekNumber},${w.rawGGR},${w.adjustedGGR},${w.outletExpense},${w.netRevenue}',
      );
    }
    buf.writeln('');
    buf.writeln('MONTHLY BREAKDOWN');
    buf.writeln('Outlet,Code,Year,Month,Total GGR,Outlet Expense,Net Revenue');
    for (final m in data.allMonths) {
      buf.writeln(
        '"${m.outletName}","${m.outletCode}",'
        '${m.year},${DateFormat('MMMM').format(DateTime(m.year, m.month))},'
        '${m.totalGGR},${m.totalOutletExpense},${m.netRevenue}',
      );
    }
    await File(path).writeAsString(buf.toString());
    _snack('Exported to $path');
  }

  Future<void> _exportWeeklyCSV(List<OutletWeekSummary> weeks) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Weekly Data',
      fileName: 'outlet_weekly_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    final buf = StringBuffer();
    buf.writeln('Outlet,Code,Week Start,Week End,Week#,Raw GGR,Adj. GGR,40% Expense,Net Revenue');
    for (final w in weeks) {
      buf.writeln(
        '"${w.outletName}","${w.outletCode}",'
        '"${DateFormat('yyyy-MM-dd').format(w.weekStart)}",'
        '"${DateFormat('yyyy-MM-dd').format(w.weekEnd)}",'
        '${w.weekNumber},${w.rawGGR},${w.adjustedGGR},${w.outletExpense},${w.netRevenue}',
      );
    }
    await File(path).writeAsString(buf.toString());
    _snack('Exported to $path');
  }

  Future<void> _exportMonthlyCSV(List<OutletMonthSummary> months) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Monthly Data',
      fileName: 'outlet_monthly_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    final buf = StringBuffer();
    buf.writeln('Outlet,Code,Year,Month,Total GGR,Outlet Expense,Net Revenue');
    for (final m in months) {
      buf.writeln(
        '"${m.outletName}","${m.outletCode}",'
        '${m.year},"${DateFormat('MMMM').format(DateTime(m.year, m.month))}",'
        '${m.totalGGR},${m.totalOutletExpense},${m.netRevenue}',
      );
    }
    await File(path).writeAsString(buf.toString());
    _snack('Exported to $path');
  }

  Future<void> _exportOutletCSV(List<OutletWeekSummary> weeks, String outletName) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Outlet Report',
      fileName: '${outletName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    final buf = StringBuffer();
    buf.writeln('Outlet Report — $outletName');
    buf.writeln('Week Start,Week End,Week#,Raw GGR,Carry Fwd,Adj. GGR,40% Expense,Net Revenue');
    for (final w in weeks) {
      buf.writeln(
        '"${DateFormat('yyyy-MM-dd').format(w.weekStart)}",'
        '"${DateFormat('yyyy-MM-dd').format(w.weekEnd)}",'
        '${w.weekNumber},${w.rawGGR},${w.carriedForward},'
        '${w.adjustedGGR},${w.outletExpense},${w.netRevenue}',
      );
    }
    await File(path).writeAsString(buf.toString());
    _snack('Exported to $path');
  }

  Future<void> _exportWeeklyPDF(List<OutletWeekSummary> weeks) async =>
      _exportPDF(_buildWeeklyPDF(weeks));
  Future<void> _exportMonthlyPDF(List<OutletMonthSummary> months) async =>
      _exportPDF(_buildMonthlyPDF(months));
  Future<void> _exportOutletPDF(List<OutletWeekSummary> weeks, String outletName) async =>
      _exportPDF(_buildOutletPDF(weeks, outletName));
  Future<void> _exportAllPDF(OutletAnalyticsData data) async =>
      _exportPDF(_buildFullPDF(data));

  Future<void> _exportPDF(Future<pw.Document> docFuture) async {
    try {
      final doc = await docFuture;
      await Printing.layoutPdf(onLayout: (fmt) => doc.save());
    } catch (e) {
      _snack('PDF export failed: $e');
    }
  }

  Future<pw.Document> _buildWeeklyPDF(List<OutletWeekSummary> weeks) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Header(level: 0, child: pw.Text('MagicBet Weekly Outlet Report — ${DateFormat('MMMM d, yyyy').format(DateTime.now())}')),
        pw.TableHelper.fromTextArray(
          headers: ['Outlet', 'Week', 'Raw GGR', 'Adj. GGR', '40% Expense', 'Net Revenue'],
          data: weeks.map((w) => [
            '${w.outletName} (${w.outletCode})',
            'Wk ${w.weekNumber} ${w.year}\n${DateFormat('d MMM').format(w.weekStart)}–${DateFormat('d MMM').format(w.weekEnd)}',
            _fc(w.rawGGR),
            _fc(w.adjustedGGR),
            _fc(w.outletExpense),
            _fc(w.netRevenue),
          ]).toList(),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerLeft,
          cellStyle: pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(2)},
        ),
      ],
    ));
    return doc;
  }

  Future<pw.Document> _buildMonthlyPDF(List<OutletMonthSummary> months) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Header(level: 0, child: pw.Text('MagicBet Monthly Outlet Report — ${DateFormat('MMMM d, yyyy').format(DateTime.now())}')),
        pw.TableHelper.fromTextArray(
          headers: ['Outlet', 'Month', 'Total GGR', 'Outlet Expense', 'Net Revenue'],
          data: months.map((m) => [
            '${m.outletName} (${m.outletCode})',
            '${DateFormat('MMMM').format(DateTime(m.year, m.month))} ${m.year}',
            _fc(m.totalGGR),
            _fc(m.totalOutletExpense),
            _fc(m.netRevenue),
          ]).toList(),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerLeft,
          cellStyle: pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ));
    return doc;
  }

  Future<pw.Document> _buildOutletPDF(List<OutletWeekSummary> weeks, String outletName) async {
    final doc = pw.Document();
    final totalGGR = weeks.fold(0.0, (s, w) => s + w.rawGGR);
    final totalExp = weeks.fold(0.0, (s, w) => s + w.outletExpense);
    final totalNet = weeks.fold(0.0, (s, w) => s + w.netRevenue);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Header(level: 0, child: pw.Text('Outlet Report: $outletName — ${DateFormat('MMMM d, yyyy').format(DateTime.now())}')),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('Total GGR: ${_fc(totalGGR)}')),
          pw.Expanded(child: pw.Text('Total Expense: ${_fc(totalExp)}')),
          pw.Expanded(child: pw.Text('Net Revenue: ${_fc(totalNet)}')),
        ]),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Week Start', 'Week End', 'Wk#', 'Raw GGR', 'Carry Fwd', 'Adj. GGR', '40% Exp', 'Net'],
          data: weeks.map((w) => [
            DateFormat('d MMM yyyy').format(w.weekStart),
            DateFormat('d MMM yyyy').format(w.weekEnd),
            w.weekNumber.toString(),
            _fc(w.rawGGR),
            w.carriedForward != 0 ? _fc(w.carriedForward) : '—',
            _fc(w.adjustedGGR),
            _fc(w.outletExpense),
            _fc(w.netRevenue),
          ]).toList(),
          cellAlignment: pw.Alignment.centerRight,
          cellStyle: pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ));
    return doc;
  }

  Future<pw.Document> _buildFullPDF(OutletAnalyticsData data) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('MagicBet Outlet Analytics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(DateFormat('MMMM d, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 16),
          pw.Row(children: [
            pw.Expanded(child: pw.Text('Total GGR: ${_fc(data.totalGGR)}')),
            pw.Expanded(child: pw.Text('Outlet Expense: ${_fc(data.totalOutletExpense)}')),
            pw.Expanded(child: pw.Text('Net Revenue: ${_fc(data.totalNetRevenue)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ]),
          pw.SizedBox(height: 24),
          pw.Text('Outlet Lifetime Totals', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Outlet', 'Code', 'Total GGR', 'Expense (40%)', 'Net Revenue'],
            data: data.lifetimeTotals.map((o) => [
              o.outletName,
              o.outletCode,
              _fc(o.totalGGR),
              _fc(o.totalOutletExpense),
              _fc(o.netRevenue),
            ]).toList(),
            cellStyle: pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ));
    return doc;
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Overview
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final OutletAnalyticsData data;
  final String Function(double) fc;

  const _OverviewTab({required this.data, required this.fc});

  @override
  Widget build(BuildContext context) {
    if (data.lifetimeTotals.isEmpty) {
      return _EmptyState(msg: 'No outlet revenue data yet.\nAdd revenue records to see analytics.');
    }

    final sorted = [...data.lifetimeTotals]..sort((a, b) => b.netRevenue.compareTo(a.netRevenue));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildBarChart(context, sorted)),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildDonutChart(context, sorted)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryTable(context, sorted),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<OutletLifetime> outlets) {
    final maxVal = outlets.fold(0.0, (m, o) => o.totalGGR > m ? o.totalGGR : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GGR vs Net Revenue per Outlet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Outlet expense (40%) is the gap between bars',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.15,
                  barGroups: outlets.asMap().entries.map((e) {
                    final i = e.key;
                    final o = e.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: o.totalGGR,
                          color: AppColors.info.withOpacity(0.6),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: o.netRevenue,
                          color: AppColors.income,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  }).toList(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx >= outlets.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              outlets[idx].outletCode,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (v, _) => Text(
                          '${(v / 1000000).toStringAsFixed(1)}M',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend('GGR', AppColors.info.withOpacity(0.6)),
                const SizedBox(width: 20),
                _Legend('Net Revenue', AppColors.income),
                const SizedBox(width: 20),
                _Legend('Outlet Expense (gap)', AppColors.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(BuildContext context, List<OutletLifetime> outlets) {
    final total = outlets.fold(0.0, (s, o) => s + o.netRevenue.clamp(0, double.infinity));
    final colors = [
      AppColors.primary, AppColors.secondary, AppColors.income,
      AppColors.info, AppColors.warning, Colors.purple,
      Colors.teal, Colors.orange, Colors.pink, Colors.cyan,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Revenue Share', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('By outlet contribution', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: total <= 0
                  ? const Center(child: Text('No positive net revenue yet'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: outlets.asMap().entries.where((e) => e.value.netRevenue > 0).map((e) {
                          final pct = total > 0 ? e.value.netRevenue / total * 100 : 0;
                          return PieChartSectionData(
                            value: e.value.netRevenue,
                            title: '${pct.toStringAsFixed(0)}%',
                            color: colors[e.key % colors.length],
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            ...outlets.take(6).asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: colors[e.key % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.outletName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text(fc(e.value.netRevenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTable(BuildContext context, List<OutletLifetime> outlets) {
    final grandGGR = outlets.fold(0.0, (s, o) => s + o.totalGGR);
    final grandExp = outlets.fold(0.0, (s, o) => s + o.totalOutletExpense);
    final grandNet = outlets.fold(0.0, (s, o) => s + o.netRevenue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lifetime Summary by Outlet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
              },
              children: [
                _tableHeader(context, ['Outlet', 'Code', 'Total GGR', 'Outlet Exp (40%)', 'Net Revenue']),
                ...outlets.map((o) => _tableRow(context, [
                  o.outletName,
                  o.outletCode,
                  fc(o.totalGGR),
                  fc(o.totalOutletExpense),
                  fc(o.netRevenue),
                ], netPositive: o.netRevenue >= 0)),
                _tableTotalRow(context, [
                  'TOTAL', '', fc(grandGGR), fc(grandExp), fc(grandNet),
                ], netPositive: grandNet >= 0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Weekly
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyTab extends StatefulWidget {
  final OutletAnalyticsData data;
  final String Function(double) fc;
  final Future<void> Function(List<OutletWeekSummary>) onExport;
  final Future<void> Function(List<OutletWeekSummary>) onExportPDF;

  const _WeeklyTab({
    required this.data,
    required this.fc,
    required this.onExport,
    required this.onExportPDF,
  });

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  int? _yearFilter;
  int? _weekFilter;
  String? _outletFilter; // outletId or null for all

  List<OutletWeekSummary> get _filtered {
    return widget.data.allWeeks.where((w) {
      if (_yearFilter != null && w.year != _yearFilter) return false;
      if (_weekFilter != null && w.weekNumber != _weekFilter) return false;
      if (_outletFilter != null && w.outletId != _outletFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final d = a.weekStart.compareTo(b.weekStart);
        return d != 0 ? d : a.outletCode.compareTo(b.outletCode);
      });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final years = widget.data.allWeeks.map((w) => w.year).toSet().toList()..sort();
    final outlets = <String, String>{}; // id → name
    for (final w in widget.data.allWeeks) {
      outlets[w.outletId] = '${w.outletName} (${w.outletCode})';
    }

    final totalGGR = rows.fold(0.0, (s, w) => s + w.rawGGR);
    final totalExp = rows.fold(0.0, (s, w) => s + w.outletExpense);
    final totalNet = rows.fold(0.0, (s, w) => s + w.netRevenue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Filter:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  // Year
                  DropdownButton<int?>(
                    value: _yearFilter,
                    hint: const Text('All Years'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years')),
                      ...years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))),
                    ],
                    onChanged: (v) => setState(() => _yearFilter = v),
                  ),
                  const SizedBox(width: 16),
                  // Outlet
                  DropdownButton<String?>(
                    value: _outletFilter,
                    hint: const Text('All Outlets'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Outlets')),
                      ...outlets.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) => setState(() => _outletFilter = v),
                  ),
                  const Spacer(),
                  Text('${rows.length} weeks', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => widget.onExport(rows),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => widget.onExportPDF(rows),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Summary KPIs for filter
          Row(
            children: [
              Expanded(child: _MiniKPI(label: 'Filtered GGR', value: widget.fc(totalGGR), color: AppColors.info)),
              const SizedBox(width: 12),
              Expanded(child: _MiniKPI(label: 'Outlet Expense', value: widget.fc(totalExp), color: AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _MiniKPI(label: 'Net Revenue', value: widget.fc(totalNet), color: totalNet >= 0 ? AppColors.income : AppColors.expense)),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly bar chart
          if (rows.isNotEmpty) _buildWeeklyChart(context, rows),
          const SizedBox(height: 16),
          // Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Breakdown', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Negative GGR weeks carry forward to next week before applying 40% expense',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No data for selected filters')),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.5),
                        6: FlexColumnWidth(1.5),
                      },
                      children: [
                        _tableHeader(context, ['Outlet', 'Week', 'Raw GGR', 'Adj. GGR', '40% Exp', 'Net Revenue', 'Status']),
                        ...rows.map((w) => _weekRow(context, w)),
                        _tableTotalRow(context, ['TOTAL', '', widget.fc(totalGGR), '', widget.fc(totalExp), widget.fc(totalNet), ''],
                            netPositive: totalNet >= 0),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, List<OutletWeekSummary> rows) {
    // Group by week key for chart
    final weekKeys = <String>{};
    final weekLabels = <String, String>{};
    final ggrByWeek = <String, double>{};
    final netByWeek = <String, double>{};

    for (final w in rows) {
      final key = 'Wk${w.weekNumber}\n${w.year}';
      weekKeys.add(key);
      weekLabels[key] = key;
      ggrByWeek[key] = (ggrByWeek[key] ?? 0) + w.rawGGR;
      netByWeek[key] = (netByWeek[key] ?? 0) + w.netRevenue;
    }
    final sortedKeys = weekKeys.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly GGR vs Net Revenue', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: sortedKeys.asMap().entries.map((e) {
                    final k = e.value;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: ggrByWeek[k]!,
                          color: AppColors.info.withOpacity(0.5),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: netByWeek[k]!,
                          color: (netByWeek[k]! >= 0) ? AppColors.income : AppColors.expense,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                      barsSpace: 3,
                    );
                  }).toList(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx >= sortedKeys.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(sortedKeys[idx], style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (v, _) => Text('${(v / 1000000).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 9)),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _weekRow(BuildContext context, OutletWeekSummary w) {
    final hasCarry = w.adjustedGGR < w.rawGGR && w.rawGGR >= 0;
    final netColor = w.netRevenue >= 0 ? AppColors.income : AppColors.expense;
    return TableRow(
      decoration: BoxDecoration(
        color: w.rawGGR < 0 ? AppColors.warning.withOpacity(0.06) : null,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      children: [
        _cell(w.outletName, context),
        _cell('Wk ${w.weekNumber}\n${DateFormat('d MMM').format(w.weekStart)}–${DateFormat('d MMM').format(w.weekEnd)}', context, size: 10),
        _cell(widget.fc(w.rawGGR), context, color: w.rawGGR < 0 ? AppColors.expense : null),
        _cell(widget.fc(w.adjustedGGR), context, color: w.adjustedGGR < 0 ? AppColors.expense : null),
        _cell(w.outletExpense > 0 ? widget.fc(w.outletExpense) : '—', context, color: AppColors.warning),
        _cell(widget.fc(w.netRevenue), context, color: netColor, bold: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: w.rawGGR < 0
              ? _StatusChip('Carried Fwd', AppColors.warning)
              : _StatusChip('Settled', AppColors.income),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Monthly
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyTab extends StatefulWidget {
  final OutletAnalyticsData data;
  final String Function(double) fc;
  final Future<void> Function(List<OutletMonthSummary>) onExport;
  final Future<void> Function(List<OutletMonthSummary>) onExportPDF;

  const _MonthlyTab({
    required this.data,
    required this.fc,
    required this.onExport,
    required this.onExportPDF,
  });

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  int? _yearFilter;
  String? _outletFilter;

  List<OutletMonthSummary> get _filtered {
    return widget.data.allMonths.where((m) {
      if (_yearFilter != null && m.year != _yearFilter) return false;
      if (_outletFilter != null && m.outletId != _outletFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        if (a.month != b.month) return a.month.compareTo(b.month);
        return a.outletCode.compareTo(b.outletCode);
      });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final years = widget.data.allMonths.map((m) => m.year).toSet().toList()..sort();
    final outlets = <String, String>{};
    for (final m in widget.data.allMonths) {
      outlets[m.outletId] = '${m.outletName} (${m.outletCode})';
    }

    final totalGGR = rows.fold(0.0, (s, m) => s + m.totalGGR);
    final totalExp = rows.fold(0.0, (s, m) => s + m.totalOutletExpense);
    final totalNet = rows.fold(0.0, (s, m) => s + m.netRevenue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Filter:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  DropdownButton<int?>(
                    value: _yearFilter,
                    hint: const Text('All Years'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years')),
                      ...years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))),
                    ],
                    onChanged: (v) => setState(() => _yearFilter = v),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String?>(
                    value: _outletFilter,
                    hint: const Text('All Outlets'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Outlets')),
                      ...outlets.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) => setState(() => _outletFilter = v),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => widget.onExport(rows),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => widget.onExportPDF(rows),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniKPI(label: 'Total GGR', value: widget.fc(totalGGR), color: AppColors.info)),
              const SizedBox(width: 12),
              Expanded(child: _MiniKPI(label: 'Total Expense', value: widget.fc(totalExp), color: AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _MiniKPI(label: 'Net Revenue', value: widget.fc(totalNet), color: totalNet >= 0 ? AppColors.income : AppColors.expense)),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isNotEmpty) _buildMonthlyLineChart(context, rows),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No data for selected filters')))
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.8),
                        3: FlexColumnWidth(1.8),
                        4: FlexColumnWidth(1.8),
                      },
                      children: [
                        _tableHeader(context, ['Outlet', 'Month', 'Total GGR', 'Outlet Expense', 'Net Revenue']),
                        ...rows.map((m) => _monthRow(context, m)),
                        _tableTotalRow(context, ['TOTAL', '', widget.fc(totalGGR), widget.fc(totalExp), widget.fc(totalNet)], netPositive: totalNet >= 0),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyLineChart(BuildContext context, List<OutletMonthSummary> rows) {
    // Aggregate by month across all outlets
    final monthAgg = <int, Map<String, double>>{};
    for (final m in rows) {
      final key = m.year * 100 + m.month;
      monthAgg.putIfAbsent(key, () => {'ggr': 0, 'net': 0});
      monthAgg[key]!['ggr'] = (monthAgg[key]!['ggr'] ?? 0) + m.totalGGR;
      monthAgg[key]!['net'] = (monthAgg[key]!['net'] ?? 0) + m.netRevenue;
    }
    final sortedKeys = monthAgg.keys.toList()..sort();
    final ggrSpots = sortedKeys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), monthAgg[e.value]!['ggr']!)).toList();
    final netSpots = sortedKeys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), monthAgg[e.value]!['net']!)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Revenue Trend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= sortedKeys.length) return const SizedBox();
                        final key = sortedKeys[idx];
                        final mo = key % 100;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('MMM').format(DateTime(key ~/ 100, mo)), style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 70,
                      getTitlesWidget: (v, _) => Text('${(v / 1000000).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: ggrSpots,
                    isCurved: true,
                    color: AppColors.info,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.info.withOpacity(0.08)),
                  ),
                  LineChartBarData(
                    spots: netSpots,
                    isCurved: true,
                    color: AppColors.income,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: AppColors.income),
                    ),
                    belowBarData: BarAreaData(show: true, color: AppColors.income.withOpacity(0.1)),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend('GGR', AppColors.info),
                const SizedBox(width: 20),
                _Legend('Net Revenue', AppColors.income),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _monthRow(BuildContext context, OutletMonthSummary m) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      children: [
        _cell(m.outletName, context),
        _cell('${DateFormat('MMM').format(DateTime(m.year, m.month))} ${m.year}', context),
        _cell(widget.fc(m.totalGGR), context, color: m.totalGGR < 0 ? AppColors.expense : null),
        _cell(widget.fc(m.totalOutletExpense), context, color: AppColors.warning),
        _cell(widget.fc(m.netRevenue), context, color: m.netRevenue >= 0 ? AppColors.income : AppColors.expense, bold: true),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Per Outlet
// ─────────────────────────────────────────────────────────────────────────────

class _PerOutletTab extends StatefulWidget {
  final OutletAnalyticsData data;
  final String Function(double) fc;
  final Future<void> Function(List<OutletWeekSummary>, String) onExport;
  final Future<void> Function(List<OutletWeekSummary>, String) onExportPDF;

  const _PerOutletTab({
    required this.data,
    required this.fc,
    required this.onExport,
    required this.onExportPDF,
  });

  @override
  State<_PerOutletTab> createState() => _PerOutletTabState();
}

class _PerOutletTabState extends State<_PerOutletTab> {
  String? _selectedId;

  List<OutletWeekSummary> get _outletWeeks {
    if (_selectedId == null) return [];
    return widget.data.allWeeks.where((w) => w.outletId == _selectedId).toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  }

  @override
  Widget build(BuildContext context) {
    final outlets = <String, String>{};
    for (final w in widget.data.allWeeks) {
      outlets[w.outletId] = '${w.outletName} (${w.outletCode})';
    }
    if (outlets.isNotEmpty && _selectedId == null) {
      _selectedId = outlets.keys.first;
    }

    final weeks = _outletWeeks;
    final outletName = _selectedId != null ? (outlets[_selectedId!] ?? '') : '';
    final totalGGR = weeks.fold(0.0, (s, w) => s + w.rawGGR);
    final totalExp = weeks.fold(0.0, (s, w) => s + w.outletExpense);
    final totalNet = weeks.fold(0.0, (s, w) => s + w.netRevenue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outlet selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Select Outlet:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedId,
                    hint: const Text('Choose an outlet'),
                    items: outlets.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedId = v),
                  ),
                  const Spacer(),
                  if (_selectedId != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => widget.onExport(weeks, outletName),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('CSV'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => widget.onExportPDF(weeks, outletName),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('PDF'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedId == null || weeks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    outlets.isEmpty ? 'No outlet revenue data yet.' : 'No data for selected outlet.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ),
            )
          else ...[
            // KPIs for this outlet
            Row(
              children: [
                Expanded(child: _MiniKPI(label: 'Total GGR', value: widget.fc(totalGGR), color: AppColors.info)),
                const SizedBox(width: 12),
                Expanded(child: _MiniKPI(label: 'Total Expense (40%)', value: widget.fc(totalExp), color: AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(child: _MiniKPI(label: 'Net Revenue', value: widget.fc(totalNet), color: totalNet >= 0 ? AppColors.income : AppColors.expense)),
                const SizedBox(width: 12),
                Expanded(child: _MiniKPI(label: 'Weeks Recorded', value: weeks.length.toString(), color: AppColors.secondary)),
              ],
            ),
            const SizedBox(height: 16),
            // Outlet line chart
            _buildOutletChart(context, weeks),
            const SizedBox(height: 16),
            // Full weekly detail table with carry-forward
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Detail — $outletName', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Carry-forward: negative weeks offset the next positive week before 40% is applied',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 16),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.8),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.5),
                        6: FlexColumnWidth(1.5),
                      },
                      children: [
                        _tableHeader(context, ['Week', 'Wk#', 'Raw GGR', 'Carry Fwd', 'Adj. GGR', '40% Exp', 'Net Revenue']),
                        ...weeks.map((w) => _outletWeekRow(context, w)),
                        _tableTotalRow(context, [
                          'TOTAL', '', widget.fc(totalGGR), '—', '—', widget.fc(totalExp), widget.fc(totalNet),
                        ], netPositive: totalNet >= 0),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutletChart(BuildContext context, List<OutletWeekSummary> weeks) {
    final ggrSpots = weeks.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.rawGGR)).toList();
    final netSpots = weeks.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.netRevenue)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Performance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= weeks.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Wk${weeks[idx].weekNumber}',
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 70,
                      getTitlesWidget: (v, _) => Text('${(v / 1000000).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: ggrSpots,
                    isCurved: true,
                    color: AppColors.info,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.info.withOpacity(0.08)),
                  ),
                  LineChartBarData(
                    spots: netSpots,
                    isCurved: true,
                    color: AppColors.income,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: AppColors.income),
                    ),
                    belowBarData: BarAreaData(show: true, color: AppColors.income.withOpacity(0.1)),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend('Raw GGR', AppColors.info),
                const SizedBox(width: 20),
                _Legend('Net Revenue', AppColors.income),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _outletWeekRow(BuildContext context, OutletWeekSummary w) {
    return TableRow(
      decoration: BoxDecoration(
        color: w.rawGGR < 0 ? AppColors.warning.withOpacity(0.06) : null,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      children: [
        _cell('${DateFormat('d MMM').format(w.weekStart)}–${DateFormat('d MMM yyyy').format(w.weekEnd)}', context, size: 11),
        _cell('Wk ${w.weekNumber}', context),
        _cell(widget.fc(w.rawGGR), context, color: w.rawGGR < 0 ? AppColors.expense : null),
        _cell(w.carriedForward != 0 ? widget.fc(w.carriedForward) : '—', context, color: AppColors.warning),
        _cell(widget.fc(w.adjustedGGR), context, color: w.adjustedGGR < 0 ? AppColors.expense : null),
        _cell(w.outletExpense > 0 ? widget.fc(w.outletExpense) : '—', context, color: AppColors.warning),
        _cell(widget.fc(w.netRevenue), context,
            color: w.netRevenue >= 0 ? AppColors.income : AppColors.expense, bold: true),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

TableRow _tableHeader(BuildContext context, List<String> cols) {
  return TableRow(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
    ),
    children: cols.map((c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    )).toList(),
  );
}

TableRow _tableRow(BuildContext context, List<String> vals, {bool netPositive = true}) {
  return TableRow(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
    ),
    children: vals.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        e.value,
        style: TextStyle(
          fontSize: 12,
          color: e.key == vals.length - 1
              ? (netPositive ? AppColors.income : AppColors.expense)
              : null,
          fontWeight: e.key == vals.length - 1 ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: e.key > 1 ? TextAlign.right : TextAlign.left,
      ),
    )).toList(),
  );
}

TableRow _tableTotalRow(BuildContext context, List<String> vals, {bool netPositive = true}) {
  return TableRow(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
    ),
    children: vals.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        e.value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: e.key == vals.length - 1
              ? (netPositive ? AppColors.income : AppColors.expense)
              : null,
        ),
        textAlign: e.key > 1 ? TextAlign.right : TextAlign.left,
      ),
    )).toList(),
  );
}

Widget _cell(String text, BuildContext context, {Color? color, bool bold = false, double size = 12}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
      textAlign: TextAlign.right,
    ),
  );
}

class _KPI extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _KPI({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: highlight ? 4 : 1,
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.w600,
                          )),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: highlight ? color : null,
                    )),
            const SizedBox(height: 4),
            Text(sub,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
          ],
        ),
      ),
    );
  }
}

class _MiniKPI extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniKPI({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;

  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;

  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  )),
        ],
      ),
    );
  }
}
