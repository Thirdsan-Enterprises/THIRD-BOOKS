import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';

/// Expenditure Tracking Screen for Outlets
///
/// Features:
/// - Record expenses per outlet (maintenance, repairs, supplies, etc.)
/// - Categorize expense types
/// - Track approval status (pending, approved, paid)
/// - Filter by outlet, date range, and status
class OutletExpenditureScreen extends ConsumerStatefulWidget {
  final String? outletId;
  final String? outletName;

  const OutletExpenditureScreen({
    super.key,
    this.outletId,
    this.outletName,
  });

  @override
  ConsumerState<OutletExpenditureScreen> createState() => _OutletExpenditureScreenState();
}

class _OutletExpenditureScreenState extends ConsumerState<OutletExpenditureScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedStatus = 'All';

  final List<String> _expenseTypes = [
    'Maintenance',
    'Repairs',
    'Supplies',
    'Utilities',
    'Security',
    'Rent',
    'Transportation',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.outletName != null
            ? '${widget.outletName} - Expenditures'
            : 'Outlet Expenditure Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportExpenditures,
            tooltip: 'Export',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummarySection(),

          // Status Filter Chips
          _buildStatusChips(),

          // Expenditure List
          Expanded(
            child: _buildExpenditureList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenditureDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
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
              'Total Expenses',
              'UGX 0',
              Icons.money_off,
              AppColors.error,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Pending',
              'UGX 0',
              Icons.pending_actions,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Approved',
              'UGX 0',
              Icons.check_circle_outline,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Paid',
              'UGX 0',
              Icons.payment,
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

  Widget _buildStatusChips() {
    final statuses = ['All', 'Pending', 'Approved', 'Paid'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        ],
      ),
    );
  }

  Widget _buildExpenditureList() {
    // TODO: Replace with actual data from database
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No expenditure records found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAddExpenditureDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenditureDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    final paidToController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedType = _expenseTypes.first;
    String selectedStatus = 'pending';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Expenditure'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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

                    // Expense Type
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Expense Type *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _expenseTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedType = value!);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixText: 'UGX ',
                        prefixIcon: Icon(Icons.attach_money),
                        hintText: '250,000',
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
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        prefixIcon: Icon(Icons.description),
                        hintText: 'Machine maintenance and cleaning',
                      ),
                      maxLines: 2,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Paid To
                    TextFormField(
                      controller: paidToController,
                      decoration: const InputDecoration(
                        labelText: 'Paid To',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Service Provider Name',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reference
                    TextFormField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Reference Number',
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'EXP-3000-001',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      ],
                      onChanged: (value) {
                        setState(() => selectedStatus = value!);
                      },
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

                final amount = double.parse(
                  amountController.text.replaceAll(',', ''),
                );

                // TODO: Save to database
                // final expenditure = OutletExpendituresCompanion.insert(
                //   id: const Uuid().v4(),
                //   outletId: widget.outletId!,
                //   date: selectedDate,
                //   expenseType: selectedType,
                //   amount: amount,
                //   description: descriptionController.text,
                //   reference: Value(referenceController.text),
                //   paidTo: Value(paidToController.text),
                //   status: Value(selectedStatus),
                //   createdAt: DateTime.now(),
                //   updatedAt: DateTime.now(),
                // );
                // await ref.read(databaseProvider).insertOutletExpenditure(expenditure);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Expense added: ${_currencyFormat.format(amount)}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Expenditures'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  void _exportExpenditures() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon...'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}
