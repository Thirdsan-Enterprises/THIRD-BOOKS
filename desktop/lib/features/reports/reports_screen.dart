import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
              onPressed: () {},
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
            onPressed: () {},
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export PDF'),
          ),
        ],
      ),
    );
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
