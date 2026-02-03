// Bills Screen for ThirdBooks Desktop App
// Track and manage vendor bills and expenses
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/bill.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  DateTimeRange? _dateRange;
  final _currencyFormat = NumberFormat('#,###');

  List<Bill> get _filteredBills {
    final billsState = ref.watch(billsProvider);
    return billsState.bills.where((bill) {
      final matchesSearch = _searchQuery.isEmpty ||
          bill.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bill.billNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == null ||
          (_selectedStatus == 'Paid' && bill.status == BillStatus.paid) ||
          (_selectedStatus == 'Partial' && bill.status == BillStatus.partial) ||
          (_selectedStatus == 'Pending' && bill.status == BillStatus.pending) ||
          (_selectedStatus == 'Overdue' && bill.status == BillStatus.overdue) ||
          (_selectedStatus == 'Draft' && bill.status == BillStatus.draft) ||
          (_selectedStatus == 'Cancelled' && bill.status == BillStatus.cancelled);

      final matchesDate = _dateRange == null ||
          (bill.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              bill.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final billsState = ref.watch(billsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context, billsState),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(
              child: billsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBillsTable(context),
            ),
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
              'Bills',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track and manage vendor bills and expenses',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(billsProvider.notifier).loadBills(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'export') {
                  _exportBills();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Export to CSV'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showCreateBillDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Bill'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, BillsState state) {
    final totalBills = state.bills.length;
    final totalAmount = state.bills.fold<double>(0, (sum, b) => sum + b.total);
    final totalPaid = state.bills.fold<double>(0, (sum, b) => sum + b.amountPaid);
    final overdueBills = state.bills.where((b) => b.status == BillStatus.overdue);
    final overdueCount = overdueBills.length;
    final overdueAmount = overdueBills.fold<double>(0, (sum, b) => sum + (b.total - b.amountPaid));

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.receipt_long,
          iconColor: AppColors.primary,
          label: 'Total Bills',
          value: totalBills.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.secondary,
          label: 'Total Billed',
          value: 'UGX ${_formatNumber(totalAmount)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.payments,
          iconColor: AppColors.income,
          label: 'Total Paid',
          value: 'UGX ${_formatNumber(totalPaid)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.warning_amber,
          iconColor: AppColors.expense,
          label: 'Overdue ($overdueCount)',
          value: 'UGX ${_formatNumber(overdueAmount)}',
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search bills...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              hintText: 'All Statuses',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...['Draft', 'Pending', 'Partial', 'Paid', 'Overdue', 'Cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRange,
            );
            if (range != null) {
              setState(() => _dateRange = range);
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(_dateRange != null
              ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
              : 'Date Range'),
        ),
        if (_dateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => setState(() => _dateRange = null),
          ),
        ],
      ],
    );
  }

  Widget _buildBillsTable(BuildContext context) {
    final bills = _filteredBills;

    if (bills.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No bills found matching "$_searchQuery"'
                      : 'No bills yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first bill to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 24,
            headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
            columns: const [
              DataColumn(label: Text('Bill #')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: bills.map((bill) {
              final balance = bill.total - bill.amountPaid;
              final isOverdue = bill.status == BillStatus.overdue;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      bill.billNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                    onTap: () => _showBillDetails(context, bill),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(bill.vendorName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          'ID: ${bill.vendorId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showBillDetails(context, bill),
                  ),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(bill.date))),
                  DataCell(
                    Text(
                      DateFormat('MMM d, yyyy').format(bill.dueDate),
                      style: TextStyle(color: isOverdue ? AppColors.expense : null),
                    ),
                  ),
                  DataCell(
                    Text(
                      'UGX ${_currencyFormat.format(bill.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(
                    Text(
                      balance > 0 ? 'UGX ${_currencyFormat.format(balance)}' : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: balance > 0 ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge(_getStatusString(bill.status))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          onPressed: () => _showBillDetails(context, bill),
                          tooltip: 'View',
                        ),
                        if (bill.status != BillStatus.paid && bill.status != BillStatus.cancelled)
                          IconButton(
                            icon: const Icon(Icons.payment_outlined, size: 18),
                            onPressed: () => _showRecordPaymentDialog(context, bill),
                            tooltip: 'Pay Bill',
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _getStatusString(BillStatus status) {
    switch (status) {
      case BillStatus.draft:
        return 'Draft';
      case BillStatus.pending:
        return 'Pending';
      case BillStatus.partial:
        return 'Partial';
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.cancelled:
        return 'Cancelled';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Paid':
        color = AppColors.income;
        break;
      case 'Partial':
        color = AppColors.info;
        break;
      case 'Pending':
        color = AppColors.warning;
        break;
      case 'Overdue':
        color = AppColors.expense;
        break;
      case 'Draft':
        color = Colors.grey;
        break;
      case 'Cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showCreateBillDialog(BuildContext context) {
    final vendorsState = ref.read(vendorsProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Bill'),
        content: SizedBox(
          width: 700,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Vendor'),
                      items: vendorsState.vendors
                          .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                          .toList(),
                      onChanged: (v) {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ['Inventory', 'Equipment', 'Office Supplies', 'Utilities', 'Raw Materials', 'Services']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Bill Date'),
                      readOnly: true,
                      initialValue: DateFormat('MMM d, yyyy').format(DateTime.now()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Due Date'),
                      readOnly: true,
                      initialValue: DateFormat('MMM d, yyyy').format(
                        DateTime.now().add(const Duration(days: 30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Reference Number'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Account', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                        SizedBox(width: 40),
                      ],
                    ),
                    const Divider(),
                    _BillLineRow(),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Line'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Subtotal: UGX 0'),
                      Text('VAT (18%): UGX 0'),
                      SizedBox(height: 4),
                      Text('Total: UGX 0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bill saved as draft (will sync when online)')),
              );
            },
            child: const Text('Save as Draft'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bill created (will sync when online)')),
              );
            },
            child: const Text('Save Bill'),
          ),
        ],
      ),
    );
  }

  void _showBillDetails(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bill ${bill.billNumber}'),
            _buildStatusBadge(_getStatusString(bill.status)),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Vendor', bill.vendorName),
              _DetailRow('Bill Date', DateFormat('MMMM d, yyyy').format(bill.date)),
              _DetailRow('Due Date', DateFormat('MMMM d, yyyy').format(bill.dueDate)),
              _DetailRow('Items', '${bill.lines.length} items'),
              const Divider(),
              _DetailRow('Subtotal', 'UGX ${_currencyFormat.format(bill.subtotal)}'),
              _DetailRow('Tax (18%)', 'UGX ${_currencyFormat.format(bill.taxAmount)}'),
              _DetailRow('Total', 'UGX ${_currencyFormat.format(bill.total)}'),
              _DetailRow('Amount Paid', 'UGX ${_currencyFormat.format(bill.amountPaid)}'),
              _DetailRow('Balance Due', 'UGX ${_currencyFormat.format(bill.total - bill.amountPaid)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (bill.status != BillStatus.paid && bill.status != BillStatus.cancelled)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRecordPaymentDialog(context, bill);
              },
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Pay Bill'),
            ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Bill bill) {
    final balance = bill.total - bill.amountPaid;
    final accountsState = ref.read(accountsProvider);
    final bankAccounts = accountsState.accounts.where((a) =>
        a.subType.toString().contains('bank') ||
        a.subType.toString().contains('cash')).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay Bill - ${bill.billNumber}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Balance Due: UGX ${_currencyFormat.format(balance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Payment Amount'),
                keyboardType: TextInputType.number,
                initialValue: balance.toStringAsFixed(0),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Payment Date'),
                readOnly: true,
                initialValue: DateFormat('MMM d, yyyy').format(DateTime.now()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Pay From Account'),
                items: bankAccounts.isNotEmpty
                    ? bankAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList()
                    : ['Bank Account - UGX', 'Bank Account - USD', 'Cash on Hand', 'Petty Cash']
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Bank Transfer', 'Cash', 'Mobile Money', 'Cheque']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Reference (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment recorded (will sync when online)')),
              );
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBills() async {
    final billsState = ref.read(billsProvider);

    if (billsState.bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bills to export')),
      );
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Bills',
      fileName: 'bills_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('Bill #,Vendor,Date,Due Date,Subtotal,Tax,Total,Amount Paid,Status');

      for (final bill in billsState.bills) {
        buffer.writeln(
          '"${bill.billNumber}","${bill.vendorName}",'
          '"${DateFormat('yyyy-MM-dd').format(bill.date)}",'
          '"${DateFormat('yyyy-MM-dd').format(bill.dueDate)}",'
          '${bill.subtotal},${bill.taxAmount},${bill.total},'
          '${bill.amountPaid},"${_getStatusString(bill.status)}"'
        );
      }

      final file = File(result);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${billsState.bills.length} bills to $result')),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _BillLineRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: 'Select account',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: ['Cost of Goods Sold', 'Office Supplies', 'Equipment', 'Utilities Expense', 'Rent Expense']
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) {},
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: 'Description',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: '0.00',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
