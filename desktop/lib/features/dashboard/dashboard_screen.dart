// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/auth_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _formatCurrency(double amount) {
    return 'UGX ${NumberFormat('#,###').format(amount.round())}';
  }

  Future<void> _exportDashboard(DashboardData data) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('MagicBet Dashboard Export - ${DateFormat('MMMM yyyy').format(DateTime.now())}');
      buffer.writeln('');
      buffer.writeln('Metric,Value');
      buffer.writeln('Total GGR,${data.totalRevenue}');
      buffer.writeln('Total Expenses,${data.totalExpenses}');
      buffer.writeln('Net Income,${data.netIncome}');
      buffer.writeln('Outstanding Invoices,${data.outstandingInvoices}');
      buffer.writeln('Cash In,${data.cashIn}');
      buffer.writeln('Cash Out,${data.cashOut}');
      buffer.writeln('Net Cash,${data.netCash}');
      buffer.writeln('');
      buffer.writeln('Recent Transactions');
      buffer.writeln('Description,Type,Amount');
      for (final tx in data.recentTransactions) {
        buffer.writeln(
            '"${tx['title']}","${tx['isIncome'] == true ? 'Income' : 'Expense'}",${tx['amount']}');
      }
      final bytes = const Utf8Encoder().convert(buffer.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'dashboard_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard exported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final user = ref.watch(currentUserProvider);

    // Use .value to get DashboardData, fallback to empty on error
    final data = dashboardAsync.valueOrNull ?? DashboardData.empty();

    return Scaffold(
      body: dashboardAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, user?.name, data),
              const SizedBox(height: 24),
              _buildKPICards(context, data),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildRevenueChart(context, data)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildCashFlowSummary(context, data)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRecentTransactions(context, data)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildAccountsReceivable(context, data)),
                ],
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard data...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? userName, DashboardData data) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    final displayName = userName ?? 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $displayName!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(now),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _exportDashboard(data),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => context.go('/journals'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Transaction'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICards(BuildContext context, DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: _KPICard(
            title: 'Total GGR',
            value: _formatCurrency(data.totalRevenue),
            change: 'Gross Gaming Revenue',
            isPositive: data.totalRevenue >= 0,
            icon: Icons.bar_chart,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Outlet Expense (40%)',
            value: _formatCurrency(data.totalExpenses),
            change: 'Commission to owners',
            isPositive: false,
            icon: Icons.handshake_outlined,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Net Revenue',
            value: _formatCurrency(data.netIncome),
            change: 'Real money available',
            isPositive: data.netIncome >= 0,
            icon: Icons.account_balance_wallet,
            color: AppColors.income,
            highlight: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Active Outlets',
            value: data.invoiceCount.toString(),
            change: 'Contributing outlets',
            isPositive: null,
            icon: Icons.store_mall_directory,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(BuildContext context, DashboardData data) {
    final revenueSpots = data.revenueData
        .map((e) => FlSpot(e['month']!, e['value']!))
        .toList();
    final expenseSpots = data.expenseData
        .map((e) => FlSpot(e['month']!, e['value']!))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GGR vs Net Revenue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('Week')),
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: 'year', label: Text('Year')),
                  ],
                  selected: const {'month'},
                  onSelectionChanged: (value) {},
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10000000,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context).dividerColor,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 80,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000000).toStringAsFixed(0)}M',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                          if (value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                months[value.toInt()],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Revenue line
                    LineChartBarData(
                      spots: revenueSpots.isNotEmpty
                          ? revenueSpots
                          : const [FlSpot(0, 0)],
                      isCurved: true,
                      color: AppColors.income,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.income.withOpacity(0.1),
                      ),
                    ),
                    // Expenses line
                    LineChartBarData(
                      spots: expenseSpots.isNotEmpty
                          ? expenseSpots
                          : const [FlSpot(0, 0)],
                      isCurved: true,
                      color: AppColors.expense,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.expense.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('GGR', AppColors.income),
                const SizedBox(width: 24),
                _buildLegendItem('Net Revenue', AppColors.expense),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildCashFlowSummary(BuildContext context, DashboardData data) {
    final total = data.totalRevenue.abs() + data.totalExpenses.abs();
    final cashInPercent = total > 0 ? (data.totalRevenue / total * 100).round().clamp(0, 100) : 60;
    final cashOutPercent = 100 - cashInPercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            _buildCashFlowItem(context, 'Total GGR', _formatCurrency(data.totalRevenue), AppColors.info),
            const SizedBox(height: 12),
            _buildCashFlowItem(context, 'Outlet Expense (40%)', _formatCurrency(data.totalExpenses), AppColors.warning),
            const Divider(height: 32),
            _buildCashFlowItem(context, 'Net Revenue', _formatCurrency(data.netCash), AppColors.income, isBold: true),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: data.totalRevenue.clamp(0, double.infinity),
                      title: '$cashInPercent%',
                      color: AppColors.info,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: data.totalExpenses.clamp(0, double.infinity),
                      title: '$cashOutPercent%',
                      color: AppColors.warning,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowItem(BuildContext context, String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: isBold ? color : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(BuildContext context, DashboardData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => context.go('/outlet-analytics'),
                  child: const Text('View Analytics'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.recentTransactions.asMap().entries.map((entry) {
              final tx = entry.value;
              final isLast = entry.key == data.recentTransactions.length - 1;

              IconData icon;
              switch (tx['icon']) {
                case 'receipt_long':
                  icon = Icons.receipt_long;
                  break;
                case 'description':
                  icon = Icons.description;
                  break;
                case 'payments':
                  icon = Icons.payments;
                  break;
                case 'shopping_bag':
                  icon = Icons.shopping_bag;
                  break;
                default:
                  icon = Icons.payment;
              }

              return Column(
                children: [
                  _buildTransactionItem(
                    context,
                    tx['title'] as String,
                    tx['subtitle'] as String,
                    _formatCurrency((tx['amount'] as num).toDouble()),
                    tx['isIncome'] as bool,
                    icon,
                  ),
                  if (!isLast) const Divider(height: 24),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    String title,
    String subtitle,
    String amount,
    bool isIncome,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isIncome ? AppColors.income : AppColors.expense).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isIncome ? AppColors.income : AppColors.expense,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          '${isIncome ? '+' : '-'}$amount',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isIncome ? AppColors.income : AppColors.expense,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsReceivable(BuildContext context, DashboardData data) {
    final total = data.receivableAging.fold<double>(
      0,
      (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Outlets by Net Revenue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => context.go('/outlet-analytics'),
                  child: const Text('Full Report'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.receivableAging.asMap().entries.map((entry) {
              final item = entry.value;
              final index = entry.key;
              final colors = [AppColors.income, AppColors.warning, Colors.orange, AppColors.expense];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAgingItem(
                  context,
                  item['label'] as String? ?? 'Unknown',
                  _formatCurrency((item['amount'] as num?)?.toDouble() ?? 0),
                  (item['percentage'] as num?)?.toDouble() ?? 0,
                  colors[index % colors.length],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Net Revenue',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  _formatCurrency(total),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingItem(BuildContext context, String label, String amount, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(amount, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Theme.of(context).dividerColor,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool? isPositive;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _KPICard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
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
            Row(
              children: [
                if (isPositive != null)
                  Icon(
                    isPositive! ? Icons.trending_up : Icons.trending_down,
                    color: isPositive! ? AppColors.income : AppColors.expense,
                    size: 16,
                  ),
                if (isPositive != null) const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isPositive == null
                        ? Theme.of(context).colorScheme.outline
                        : isPositive!
                            ? AppColors.income
                            : AppColors.expense,
                  ),
                ),
                if (isPositive != null)
                  Text(
                    ' vs last month',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
