import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

/// Commission Management Screen
///
/// Features:
/// - Calculate 40% commission for location owners
/// - Generate commission payment vouchers
/// - Track payment status (pending/paid)
/// - Filter by outlet, period, and status
/// - Process bulk payments
class CommissionManagementScreen extends ConsumerStatefulWidget {
  const CommissionManagementScreen({super.key});

  @override
  ConsumerState<CommissionManagementScreen> createState() => _CommissionManagementScreenState();
}

class _CommissionManagementScreenState extends ConsumerState<CommissionManagementScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  String _selectedStatus = 'All';
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodEnd = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _showCalculateCommissionsDialog,
            tooltip: 'Calculate Commissions',
          ),
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: _processBulkPayments,
            tooltip: 'Process Bulk Payments',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummarySection(),

          // Status Filter
          _buildStatusFilter(),

          // Commission List
          Expanded(
            child: _buildCommissionList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCalculateCommissionsDialog,
        icon: const Icon(Icons.calculate),
        label: const Text('Calculate Commissions'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Pending',
              'UGX 0',
              Icons.pending_actions,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Total Paid',
              'UGX 0',
              Icons.check_circle,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'This Month',
              'UGX 0',
              Icons.calendar_today,
              AppColors.info,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Outlets',
              '0',
              Icons.store,
              AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = ['All', 'Pending', 'Paid'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          ...statuses.map((status) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(status),
                  selected: _selectedStatus == status,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = status);
                  },
                ),
              )),
          const Spacer(),
          TextButton.icon(
            onPressed: _showPeriodFilter,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${DateFormat('MMM dd').format(_periodStart)} - ${DateFormat('MMM dd, yyyy').format(_periodEnd)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionList() {
    // TODO: Replace with actual data from database
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No commission records found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Calculate commissions to get started'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showCalculateCommissionsDialog,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate Commissions'),
          ),
        ],
      ),
    );
  }

  void _showCalculateCommissionsDialog() {
    DateTime periodStart = DateTime.now().subtract(const Duration(days: 30));
    DateTime periodEnd = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Calculate Commissions'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the period for commission calculation:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Period Start
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: periodStart,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => periodStart = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Period Start',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM dd, yyyy').format(periodStart)),
                  ),
                ),
                const SizedBox(height: 16),

                // Period End
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: periodEnd,
                      firstDate: periodStart,
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => periodEnd = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Period End',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM dd, yyyy').format(periodEnd)),
                  ),
                ),
                const SizedBox(height: 24),

                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Commission Calculation',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Calculates 40% commission on all outlet revenues\n'
                        '• Groups by outlet and period\n'
                        '• Creates payment vouchers for location owners\n'
                        '• Excludes already calculated periods',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                // TODO: Calculate commissions for all outlets
                // 1. Get all outlets
                // 2. For each outlet, get revenue in period
                // 3. Calculate 40% commission
                // 4. Create CommissionPayment record
                // 5. Mark as pending

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Commissions calculated successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPeriodFilter() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _periodStart, end: _periodEnd),
    );

    if (picked != null) {
      setState(() {
        _periodStart = picked.start;
        _periodEnd = picked.end;
      });
    }
  }

  void _processBulkPayments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Bulk Payments'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will mark all pending commissions as paid.'),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to continue?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Update all pending commissions to paid
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bulk payment processed'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
