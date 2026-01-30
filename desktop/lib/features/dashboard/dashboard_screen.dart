import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildKPICards(context),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRevenueChart(context)),
                const SizedBox(width: 24),
                Expanded(child: _buildCashFlowSummary(context)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentTransactions(context)),
                const SizedBox(width: 24),
                Expanded(child: _buildAccountsReceivable(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting!',
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

  Widget _buildKPICards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KPICard(
            title: 'Total Revenue',
            value: 'UGX 45,250,000',
            change: '+12.5%',
            isPositive: true,
            icon: Icons.trending_up,
            color: AppColors.income,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Total Expenses',
            value: 'UGX 28,340,000',
            change: '+5.2%',
            isPositive: false,
            icon: Icons.trending_down,
            color: AppColors.expense,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Net Income',
            value: 'UGX 16,910,000',
            change: '+18.3%',
            isPositive: true,
            icon: Icons.account_balance_wallet,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KPICard(
            title: 'Outstanding Invoices',
            value: 'UGX 8,450,000',
            change: '12 invoices',
            isPositive: null,
            icon: Icons.receipt_long,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(BuildContext context) {
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
                  style: ButtonStyle(
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
                      spots: const [
                        FlSpot(0, 35000000),
                        FlSpot(1, 42000000),
                        FlSpot(2, 38000000),
                        FlSpot(3, 45000000),
                        FlSpot(4, 48000000),
                        FlSpot(5, 52000000),
                      ],
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
                      spots: const [
                        FlSpot(0, 25000000),
                        FlSpot(1, 28000000),
                        FlSpot(2, 24000000),
                        FlSpot(3, 30000000),
                        FlSpot(4, 32000000),
                        FlSpot(5, 35000000),
                      ],
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

  Widget _buildCashFlowSummary(BuildContext context) {
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
            _buildCashFlowItem(context, 'Cash In', 'UGX 52,340,000', AppColors.income),
            const SizedBox(height: 12),
            _buildCashFlowItem(context, 'Cash Out', 'UGX 38,120,000', AppColors.expense),
            const Divider(height: 32),
            _buildCashFlowItem(context, 'Net Cash', 'UGX 14,220,000', AppColors.secondary, isBold: true),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: 52340000,
                      title: '58%',
                      color: AppColors.income,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: 38120000,
                      title: '42%',
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

  Widget _buildRecentTransactions(BuildContext context) {
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
            _buildTransactionItem(
              context,
              'Invoice #INV-2024-0042',
              'Customer: ABC Ltd',
              'UGX 2,450,000',
              true,
              Icons.receipt_long,
            ),
            const Divider(height: 24),
            _buildTransactionItem(
              context,
              'Bill #BILL-2024-0018',
              'Vendor: XYZ Supplies',
              'UGX 1,250,000',
              false,
              Icons.description,
            ),
            const Divider(height: 24),
            _buildTransactionItem(
              context,
              'Payment Received',
              'From: DEF Corp',
              'UGX 3,800,000',
              true,
              Icons.payments,
            ),
            const Divider(height: 24),
            _buildTransactionItem(
              context,
              'Expense: Office Supplies',
              'Petty Cash',
              'UGX 185,000',
              false,
              Icons.shopping_bag,
            ),
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

  Widget _buildAccountsReceivable(BuildContext context) {
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
            _buildAgingItem(context, 'Current', 'UGX 4,250,000', 0.50, AppColors.income),
            const SizedBox(height: 12),
            _buildAgingItem(context, '1-30 Days', 'UGX 2,100,000', 0.25, AppColors.warning),
            const SizedBox(height: 12),
            _buildAgingItem(context, '31-60 Days', 'UGX 1,350,000', 0.16, Colors.orange),
            const SizedBox(height: 12),
            _buildAgingItem(context, '60+ Days', 'UGX 750,000', 0.09, AppColors.expense),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Outstanding',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'UGX 8,450,000',
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
