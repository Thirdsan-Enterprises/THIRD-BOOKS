import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  DateTimeRange? _dateRange;

  final List<Map<String, dynamic>> _bills = [
    {
      'id': 'BILL-2024-001',
      'vendor': 'Quality Supplies Uganda',
      'vendorId': 'VEN-001',
      'date': DateTime(2024, 1, 10),
      'dueDate': DateTime(2024, 2, 9),
      'subtotal': 7500000.0,
      'tax': 1275000.0,
      'total': 8775000.0,
      'amountPaid': 0.0,
      'status': 'Pending',
      'category': 'Inventory',
    },
    {
      'id': 'BILL-2024-002',
      'vendor': 'Tech Solutions Ltd',
      'vendorId': 'VEN-002',
      'date': DateTime(2024, 1, 12),
      'dueDate': DateTime(2024, 1, 27),
      'subtotal': 3200000.0,
      'tax': 544000.0,
      'total': 3744000.0,
      'amountPaid': 3744000.0,
      'status': 'Paid',
      'category': 'Equipment',
    },
    {
      'id': 'BILL-2024-003',
      'vendor': 'Office Essentials Corp',
      'vendorId': 'VEN-003',
      'date': DateTime(2024, 1, 15),
      'dueDate': DateTime(2024, 2, 14),
      'subtotal': 450000.0,
      'tax': 76500.0,
      'total': 526500.0,
      'amountPaid': 0.0,
      'status': 'Pending',
      'category': 'Office Supplies',
    },
    {
      'id': 'BILL-2024-004',
      'vendor': 'Uganda Power Solutions',
      'vendorId': 'VEN-004',
      'date': DateTime(2024, 1, 5),
      'dueDate': DateTime(2024, 1, 5),
      'subtotal': 2500000.0,
      'tax': 425000.0,
      'total': 2925000.0,
      'amountPaid': 0.0,
      'status': 'Overdue',
      'category': 'Utilities',
    },
    {
      'id': 'BILL-2024-005',
      'vendor': 'Global Imports Ltd',
      'vendorId': 'VEN-005',
      'date': DateTime(2024, 1, 8),
      'dueDate': DateTime(2024, 2, 22),
      'subtotal': 25000000.0,
      'tax': 4250000.0,
      'total': 29250000.0,
      'amountPaid': 15000000.0,
      'status': 'Partial',
      'category': 'Inventory',
    },
    {
      'id': 'BILL-2024-006',
      'vendor': 'Local Farmers Cooperative',
      'vendorId': 'VEN-006',
      'date': DateTime(2024, 1, 19),
      'dueDate': DateTime(2024, 1, 26),
      'subtotal': 1500000.0,
      'tax': 0.0,
      'total': 1500000.0,
      'amountPaid': 1500000.0,
      'status': 'Paid',
      'category': 'Raw Materials',
    },
  ];

  List<Map<String, dynamic>> get _filteredBills {
    return _bills.where((bill) {
      final matchesSearch = _searchQuery.isEmpty ||
          bill['vendor'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bill['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || bill['status'] == _selectedStatus;
      final matchesDate = _dateRange == null ||
          ((bill['date'] as DateTime).isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              (bill['date'] as DateTime).isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

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
            _buildSummaryCards(context),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(child: _buildBillsTable(context)),
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
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
            const SizedBox(width: 12),
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

  Widget _buildSummaryCards(BuildContext context) {
    final totalBills = _bills.length;
    final totalAmount = _bills.fold<double>(0, (sum, b) => sum + (b['total'] as double));
    final totalPaid = _bills.fold<double>(0, (sum, b) => sum + (b['amountPaid'] as double));
    final overdueCount = _bills.where((b) => b['status'] == 'Overdue').length;
    final overdueAmount = _bills
        .where((b) => b['status'] == 'Overdue')
        .fold<double>(0, (sum, b) => sum + ((b['total'] as double) - (b['amountPaid'] as double)));

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
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 24,
            headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Bill #')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _filteredBills.map((bill) {
              final total = bill['total'] as double;
              final paid = bill['amountPaid'] as double;
              final balance = total - paid;
              final isOverdue = bill['status'] == 'Overdue';

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      bill['id'],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                    onTap: () => _showBillDetails(context, bill),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(bill['vendor'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          bill['vendorId'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showBillDetails(context, bill),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(bill['category'], style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(bill['date']))),
                  DataCell(
                    Text(
                      DateFormat('MMM d, yyyy').format(bill['dueDate']),
                      style: TextStyle(color: isOverdue ? AppColors.expense : null),
                    ),
                  ),
                  DataCell(
                    Text(
                      'UGX ${_formatNumber(total)}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(
                    Text(
                      balance > 0 ? 'UGX ${_formatNumber(balance)}' : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: balance > 0 ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge(bill['status'])),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          onPressed: () => _showBillDetails(context, bill),
                          tooltip: 'View',
                        ),
                        if (bill['status'] != 'Paid' && bill['status'] != 'Cancelled')
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
                      items: _bills
                          .map((b) => b['vendor'] as String)
                          .toSet()
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
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
                    Row(
                      children: const [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Subtotal: UGX 0'),
                      Text('VAT (18%): UGX 0'),
                      const SizedBox(height: 4),
                      Text('Total: UGX 0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save as Draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save Bill'),
          ),
        ],
      ),
    );
  }

  void _showBillDetails(BuildContext context, Map<String, dynamic> bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bill ${bill['id']}'),
            _buildStatusBadge(bill['status']),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Vendor', bill['vendor']),
              _DetailRow('Category', bill['category']),
              _DetailRow('Bill Date', DateFormat('MMMM d, yyyy').format(bill['date'])),
              _DetailRow('Due Date', DateFormat('MMMM d, yyyy').format(bill['dueDate'])),
              const Divider(),
              _DetailRow('Subtotal', 'UGX ${NumberFormat('#,###').format(bill['subtotal'])}'),
              _DetailRow('Tax (18%)', 'UGX ${NumberFormat('#,###').format(bill['tax'])}'),
              _DetailRow('Total', 'UGX ${NumberFormat('#,###').format(bill['total'])}'),
              _DetailRow('Amount Paid', 'UGX ${NumberFormat('#,###').format(bill['amountPaid'])}'),
              _DetailRow(
                'Balance Due',
                'UGX ${NumberFormat('#,###').format((bill['total'] as double) - (bill['amountPaid'] as double))}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (bill['status'] != 'Paid' && bill['status'] != 'Cancelled')
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

  void _showRecordPaymentDialog(BuildContext context, Map<String, dynamic> bill) {
    final balance = (bill['total'] as double) - (bill['amountPaid'] as double);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay Bill - ${bill['id']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Balance Due: UGX ${NumberFormat('#,###').format(balance)}',
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
                items: ['Bank Account - UGX', 'Bank Account - USD', 'Cash on Hand', 'Petty Cash']
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
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
