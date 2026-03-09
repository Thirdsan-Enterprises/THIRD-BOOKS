import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/auth_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return 'UGX ${NumberFormat('#,###').format(amount.round())}';
    }
    return 'UGX ${NumberFormat('#,###').format(amount.round())}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final user = ref.watch(currentUserProvider);

    // Use .value to get DashboardData, fallback to empty on error
    final data = dashboardAsync.valueOrNull ?? DashboardData.empty();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, user?.name),
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
    );
  }

  Widget _buildHeader(BuildContext context, String? userName) {
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
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () {},
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
            title: 'Total Revenue',
            value: _formatCurrency(data.totalRevenue),
            change: '+${data.revenueChange.toStringAsFixed(1)}%',
            isPositive: data.revenueChange >= 0,
            icon: Icons.trending_up,
            color: AppColors.income,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Total Expenses',
            value: _formatCurrency(data.totalExpenses),
            change: '+${data.expenseChange.toStringAsFixed(1)}%',
            isPositive: false,
            icon: Icons.trending_down,
            color: AppColors.expense,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Net Income',
            value: _formatCurrency(data.netIncome),
            change: '+${data.incomeChange.toStringAsFixed(1)}%',
            isPositive: data.incomeChange >= 0,
            icon: Icons.account_balance_wallet,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Outstanding Invoices',
            value: _formatCurrency(data.outstandingInvoices),
            change: '${data.invoiceCount} invoices',
            isPositive: null,
            icon: Icons.receipt_long,
            color: AppColors.warning,
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
                  'Revenue vs Expenses',
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
                _buildLegendItem('Revenue', AppColors.income),
                const SizedBox(width: 24),
                _buildLegendItem('Expenses', AppColors.expense),
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
    final total = data.cashIn + data.cashOut;
    final cashInPercent = total > 0 ? (data.cashIn / total * 100).round() : 50;
    final cashOutPercent = 100 - cashInPercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cash Flow',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            _buildCashFlowItem(context, 'Cash In', _formatCurrency(data.cashIn), AppColors.income),
            const SizedBox(height: 12),
            _buildCashFlowItem(context, 'Cash Out', _formatCurrency(data.cashOut), AppColors.expense),
            const Divider(height: 32),
            _buildCashFlowItem(context, 'Net Cash', _formatCurrency(data.netCash), AppColors.secondary, isBold: true),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: data.cashIn,
                      title: '$cashInPercent%',
                      color: AppColors.income,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: data.cashOut,
                      title: '$cashOutPercent%',
                      color: AppColors.expense,
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
                  onPressed: () {},
                  child: const Text('View All'),
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
                  'Accounts Receivable Aging',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Details'),
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
                  'Total Outstanding',
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

  const _KPICard({
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
