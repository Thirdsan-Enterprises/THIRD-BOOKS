import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedPeriod = 'This Month';
  String _selectedReportType = 'all';

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
      'category': 'Accounts Receivable',
      'icon': Icons.people,
      'color': AppColors.debit,
      'reports': [
        {'name': 'Aging Report', 'description': 'Outstanding invoices by age', 'icon': Icons.access_time},
        {'name': 'Customer Statement', 'description': 'Transaction history by customer', 'icon': Icons.person},
        {'name': 'Sales by Customer', 'description': 'Revenue breakdown by customer', 'icon': Icons.bar_chart},
        {'name': 'Invoice List', 'description': 'All invoices with status', 'icon': Icons.receipt_long},
      ],
    },
    {
      'category': 'Accounts Payable',
      'icon': Icons.store,
      'color': AppColors.credit,
      'reports': [
        {'name': 'Aging Report', 'description': 'Outstanding bills by age', 'icon': Icons.access_time},
        {'name': 'Vendor Statement', 'description': 'Transaction history by vendor', 'icon': Icons.storefront},
        {'name': 'Purchases by Vendor', 'description': 'Expense breakdown by vendor', 'icon': Icons.bar_chart},
        {'name': 'Bills List', 'description': 'All bills with status', 'icon': Icons.receipt},
      ],
    },
    {
      'category': 'Tax Reports',
      'icon': Icons.calculate,
      'color': AppColors.warning,
      'reports': [
        {'name': 'VAT Report', 'description': 'VAT collected and paid', 'icon': Icons.receipt},
        {'name': 'Tax Summary', 'description': 'Tax obligations summary', 'icon': Icons.summarize},
        {'name': 'Withholding Tax', 'description': 'WHT deducted and remitted', 'icon': Icons.remove_circle_outline},
      ],
    },
    {
      'category': 'Management Reports',
      'icon': Icons.insights,
      'color': AppColors.secondary,
      'reports': [
        {'name': 'Profit & Loss by Month', 'description': 'Monthly performance comparison', 'icon': Icons.calendar_month},
        {'name': 'Budget vs Actual', 'description': 'Performance against budget', 'icon': Icons.compare_arrows},
        {'name': 'Expense Analysis', 'description': 'Expense breakdown by category', 'icon': Icons.pie_chart},
        {'name': 'Revenue Analysis', 'description': 'Revenue breakdown by source', 'icon': Icons.show_chart},
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
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            title: 'Net Income',
            value: 'UGX 16.9M',
            change: '+12.5%',
            isPositive: true,
            icon: Icons.trending_up,
            color: AppColors.income,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _QuickStatCard(
            title: 'Total Revenue',
            value: 'UGX 64.8M',
            change: '+8.3%',
            isPositive: true,
            icon: Icons.attach_money,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _QuickStatCard(
            title: 'Total Expenses',
            value: 'UGX 47.9M',
            change: '+5.2%',
            isPositive: false,
            icon: Icons.money_off,
            color: AppColors.expense,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _QuickStatCard(
            title: 'Gross Margin',
            value: '56.8%',
            change: '+2.1%',
            isPositive: true,
            icon: Icons.pie_chart,
            color: AppColors.primary,
          ),
        ),
      ],
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
          label: const Text('Receivables'),
          selected: _selectedReportType == 'receivables',
          onSelected: (selected) => setState(() => _selectedReportType = 'receivables'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Payables'),
          selected: _selectedReportType == 'payables',
          onSelected: (selected) => setState(() => _selectedReportType = 'payables'),
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
    if (reportName == 'Income Statement' || reportName == 'Profit & Loss by Month') {
      return _buildIncomeStatementPreview(context);
    } else if (reportName == 'Balance Sheet') {
      return _buildBalanceSheetPreview(context);
    } else if (reportName.contains('Aging')) {
      return _buildAgingReportPreview(context);
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportSection(
            title: 'Revenue',
            items: [
              {'name': 'Sales Revenue', 'amount': 52340000.0},
              {'name': 'Service Revenue', 'amount': 12500000.0},
            ],
            total: 64840000.0,
            isPositive: true,
          ),
          const SizedBox(height: 16),
          _ReportSection(
            title: 'Cost of Sales',
            items: [
              {'name': 'Cost of Goods Sold', 'amount': 28000000.0},
            ],
            total: 28000000.0,
            isPositive: false,
          ),
          const Divider(),
          _ReportTotalRow(label: 'Gross Profit', amount: 36840000.0, isHighlight: true),
          const SizedBox(height: 16),
          _ReportSection(
            title: 'Operating Expenses',
            items: [
              {'name': 'Salaries & Wages', 'amount': 15000000.0},
              {'name': 'Rent Expense', 'amount': 6000000.0},
              {'name': 'Utilities Expense', 'amount': 1800000.0},
              {'name': 'Office Supplies', 'amount': 450000.0},
            ],
            total: 23250000.0,
            isPositive: false,
          ),
          const Divider(),
          _ReportTotalRow(label: 'Operating Income', amount: 13590000.0, isHighlight: true),
          const Divider(height: 32),
          _ReportTotalRow(label: 'Net Income', amount: 13590000.0, isHighlight: true, isFinal: true),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetPreview(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ASSETS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ReportSection(
            title: 'Current Assets',
            items: [
              {'name': 'Cash on Hand', 'amount': 5250000.0},
              {'name': 'Petty Cash', 'amount': 500000.0},
              {'name': 'Bank Account - UGX', 'amount': 45000000.0},
              {'name': 'Accounts Receivable', 'amount': 8450000.0},
            ],
            total: 59200000.0,
            isPositive: true,
          ),
          _ReportSection(
            title: 'Fixed Assets',
            items: [
              {'name': 'Office Equipment', 'amount': 15000000.0},
              {'name': 'Computer Equipment', 'amount': 8500000.0},
            ],
            total: 23500000.0,
            isPositive: true,
          ),
          _ReportTotalRow(label: 'Total Assets', amount: 82700000.0, isHighlight: true),
          const Divider(height: 32),
          Text('LIABILITIES', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ReportSection(
            title: 'Current Liabilities',
            items: [
              {'name': 'Accounts Payable', 'amount': 6200000.0},
              {'name': 'VAT Payable', 'amount': 2100000.0},
              {'name': 'Salaries Payable', 'amount': 4500000.0},
            ],
            total: 12800000.0,
            isPositive: false,
          ),
          _ReportTotalRow(label: 'Total Liabilities', amount: 12800000.0, isHighlight: true),
          const Divider(height: 32),
          Text('EQUITY', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ReportSection(
            title: "Owner's Equity",
            items: [
              {'name': "Owner's Capital", 'amount': 50000000.0},
              {'name': 'Retained Earnings', 'amount': 19900000.0},
            ],
            total: 69900000.0,
            isPositive: true,
          ),
          const Divider(),
          _ReportTotalRow(label: 'Total Liabilities & Equity', amount: 82700000.0, isHighlight: true, isFinal: true),
        ],
      ),
    );
  }

  Widget _buildAgingReportPreview(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: const [
              Expanded(flex: 2, child: Text('Customer/Vendor', style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text('Current', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              Expanded(child: Text('1-30 Days', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              Expanded(child: Text('31-60 Days', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              Expanded(child: Text('61-90 Days', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              Expanded(child: Text('90+ Days', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              _AgingRow('Kampala Traders Ltd', [3500000, 5000000, 2500000, 1500000, 0]),
              _AgingRow('Jinja Hardware Supplies', [2000000, 3450000, 3000000, 0, 0]),
              _AgingRow('Mbarara Beverages Co', [10000000, 15000000, 12000000, 8000000, 0]),
              _AgingRow('Gulu Construction Works', [5000000, 12500000, 25000000, 15000000, 10000000]),
            ],
          ),
        ),
        const Divider(),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('UGX 20.5M', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text('UGX 35.9M', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text('UGX 42.5M', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text('UGX 24.5M', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text('UGX 10M', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense), textAlign: TextAlign.right)),
              Expanded(child: Text('UGX 133.4M', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ],
          ),
        ),
      ],
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
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: isPositive ? AppColors.income : AppColors.expense,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    color: isPositive ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' vs last period',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
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

class _AgingRow extends StatelessWidget {
  final String name;
  final List<int> amounts;

  const _AgingRow(this.name, this.amounts);

  String _formatAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final total = amounts.reduce((a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(name)),
          ...amounts.map((a) => Expanded(
                child: Text(
                  a > 0 ? 'UGX ${_formatAmount(a)}' : '-',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: amounts.indexOf(a) >= 3 && a > 0 ? AppColors.expense : null,
                  ),
                ),
              )),
          Expanded(
            child: Text(
              'UGX ${_formatAmount(total)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
