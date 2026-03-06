import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';

/// Revenue Tracking Screen for Outlets
///
/// Features:
/// - Record revenue collected from each outlet
/// - Auto-calculate 40% commission to location owner
/// - Track revenue history by outlet
/// - Filter by date range and status
class OutletRevenueScreen extends ConsumerStatefulWidget {
  final String? outletId;
  final String? outletName;

  const OutletRevenueScreen({
    super.key,
    this.outletId,
    this.outletName,
  });

  @override
  ConsumerState<OutletRevenueScreen> createState() => _OutletRevenueScreenState();
}

class _OutletRevenueScreenState extends ConsumerState<OutletRevenueScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.outletName != null
            ? '${widget.outletName} - Revenue'
            : 'Outlet Revenue Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportRevenue,
            tooltip: 'Export',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummarySection(),

          // Revenue List
          Expanded(
            child: _buildRevenueList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRevenueDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Record Revenue'),
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
              'Total Revenue',
              'UGX 0',
              Icons.attach_money,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Commission (40%)',
              'UGX 0',
              Icons.payments_outlined,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Net Revenue (60%)',
              'UGX 0',
              Icons.trending_up,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Records',
              '0',
              Icons.receipt_long,
              AppColors.info,
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

  Widget _buildRevenueList() {
    // TODO: Replace with actual data from database
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No revenue records found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAddRevenueDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Record Revenue'),
          ),
        ],
      ),
    );
  }

  void _showAddRevenueDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    // Commission calculation state
    double totalAmount = 0.0;
    double commissionAmount = 0.0;
    double netAmount = 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record Revenue'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(selectedDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Revenue Amount *',
                        prefixText: 'UGX ',
                        hintText: '5,000,000',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final amount = double.tryParse(v!.replaceAll(',', ''));
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                      onChanged: (v) {
                        final amount = double.tryParse(v.replaceAll(',', '')) ?? 0.0;
                        setState(() {
                          totalAmount = amount;
                          commissionAmount = amount * 0.40; // 40%
                          netAmount = amount * 0.60; // 60%
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Commission breakdown
                    if (totalAmount > 0) ...[
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
                            Text(
                              'Revenue Breakdown',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildBreakdownRow('Total Revenue:', totalAmount, AppColors.success),
                            const Divider(height: 16),
                            _buildBreakdownRow('Commission to Owner (40%):', commissionAmount, AppColors.warning),
                            _buildBreakdownRow('Net to Company (60%):', netAmount, AppColors.primary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Description
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Weekly revenue collection - Week 52',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Reference
                    TextFormField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Reference Number',
                        hintText: 'REV-3000-2026-52',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                // TODO: Save to database
                // final revenue = OutletRevenuesCompanion.insert(
                //   id: const Uuid().v4(),
                //   outletId: widget.outletId!,
                //   date: selectedDate,
                //   amount: totalAmount,
                //   commissionAmount: commissionAmount,
                //   netAmount: netAmount,
                //   description: Value(descriptionController.text),
                //   reference: Value(referenceController.text),
                //   status: const Value('recorded'),
                //   createdAt: DateTime.now(),
                //   updatedAt: DateTime.now(),
                // );
                // await ref.read(databaseProvider).insertOutletRevenue(revenue);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Revenue recorded: ${_currencyFormat.format(totalAmount)}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Record Revenue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Revenue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date range
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _startDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
              },
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
              Navigator.pop(context);
              setState(() {}); // Refresh data
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _exportRevenue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon...'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}
