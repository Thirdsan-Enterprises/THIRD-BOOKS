import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  DateTimeRange? _dateRange;

  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'INV-2024-001',
      'customer': 'Kampala Traders Ltd',
      'customerId': 'CUST-001',
      'date': DateTime(2024, 1, 15),
      'dueDate': DateTime(2024, 2, 14),
      'subtotal': 5000000.0,
      'tax': 850000.0,
      'total': 5850000.0,
      'amountPaid': 3500000.0,
      'status': 'Partial',
      'items': 5,
    },
    {
      'id': 'INV-2024-002',
      'customer': 'Jinja Hardware Supplies',
      'customerId': 'CUST-002',
      'date': DateTime(2024, 1, 16),
      'dueDate': DateTime(2024, 2, 15),
      'subtotal': 8500000.0,
      'tax': 1445000.0,
      'total': 9945000.0,
      'amountPaid': 9945000.0,
      'status': 'Paid',
      'items': 12,
    },
    {
      'id': 'INV-2024-003',
      'customer': 'Entebbe Fresh Farms',
      'customerId': 'CUST-003',
      'date': DateTime(2024, 1, 17),
      'dueDate': DateTime(2024, 2, 16),
      'subtotal': 3200000.0,
      'tax': 544000.0,
      'total': 3744000.0,
      'amountPaid': 0.0,
      'status': 'Pending',
      'items': 3,
    },
    {
      'id': 'INV-2024-004',
      'customer': 'Mbarara Beverages Co',
      'customerId': 'CUST-004',
      'date': DateTime(2024, 1, 10),
      'dueDate': DateTime(2024, 1, 25),
      'subtotal': 15000000.0,
      'tax': 2550000.0,
      'total': 17550000.0,
      'amountPaid': 0.0,
      'status': 'Overdue',
      'items': 8,
    },
    {
      'id': 'INV-2024-005',
      'customer': 'Gulu Construction Works',
      'customerId': 'CUST-005',
      'date': DateTime(2024, 1, 18),
      'dueDate': DateTime(2024, 2, 17),
      'subtotal': 25000000.0,
      'tax': 4250000.0,
      'total': 29250000.0,
      'amountPaid': 0.0,
      'status': 'Draft',
      'items': 15,
    },
    {
      'id': 'INV-2024-006',
      'customer': 'Lira Agro Products',
      'customerId': 'CUST-006',
      'date': DateTime(2024, 1, 19),
      'dueDate': DateTime(2024, 2, 18),
      'subtotal': 1800000.0,
      'tax': 306000.0,
      'total': 2106000.0,
      'amountPaid': 2106000.0,
      'status': 'Paid',
      'items': 4,
    },
  ];

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((invoice) {
      final matchesSearch = _searchQuery.isEmpty ||
          invoice['customer'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          invoice['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || invoice['status'] == _selectedStatus;
      final matchesDate = _dateRange == null ||
          ((invoice['date'] as DateTime).isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              (invoice['date'] as DateTime).isBefore(_dateRange!.end.add(const Duration(days: 1))));
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
            Expanded(child: _buildInvoicesTable(context)),
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
              'Invoices',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create and manage customer invoices',
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
              onPressed: () => _showCreateInvoiceDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Invoice'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final totalInvoices = _invoices.length;
    final totalAmount = _invoices.fold<double>(0, (sum, i) => sum + (i['total'] as double));
    final totalPaid = _invoices.fold<double>(0, (sum, i) => sum + (i['amountPaid'] as double));
    final overdueCount = _invoices.where((i) => i['status'] == 'Overdue').length;
    final overdueAmount = _invoices
        .where((i) => i['status'] == 'Overdue')
        .fold<double>(0, (sum, i) => sum + ((i['total'] as double) - (i['amountPaid'] as double)));

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.receipt_long,
          iconColor: AppColors.primary,
          label: 'Total Invoices',
          value: totalInvoices.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.secondary,
          label: 'Total Invoiced',
          value: 'UGX ${_formatNumber(totalAmount)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.payments,
          iconColor: AppColors.income,
          label: 'Total Collected',
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
              hintText: 'Search invoices...',
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

  Widget _buildInvoicesTable(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 24,
            headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Invoice #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _filteredInvoices.map((invoice) {
              final total = invoice['total'] as double;
              final paid = invoice['amountPaid'] as double;
              final balance = total - paid;
              final isOverdue = invoice['status'] == 'Overdue';

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      invoice['id'],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                    onTap: () => _showInvoiceDetails(context, invoice),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(invoice['customer'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          invoice['customerId'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showInvoiceDetails(context, invoice),
                  ),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(invoice['date']))),
                  DataCell(
                    Text(
                      DateFormat('MMM d, yyyy').format(invoice['dueDate']),
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
                  DataCell(_buildStatusBadge(invoice['status'])),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          onPressed: () => _showInvoiceDetails(context, invoice),
                          tooltip: 'View',
                        ),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 18),
                          onPressed: () {},
                          tooltip: 'Print',
                        ),
                        if (invoice['status'] != 'Paid' && invoice['status'] != 'Cancelled')
                          IconButton(
                            icon: const Icon(Icons.payment_outlined, size: 18),
                            onPressed: () => _showRecordPaymentDialog(context, invoice),
                            tooltip: 'Record Payment',
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

  void _showCreateInvoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Invoice'),
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
                      decoration: const InputDecoration(labelText: 'Customer'),
                      items: _invoices
                          .map((i) => i['customer'] as String)
                          .toSet()
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Invoice Date'),
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
                        Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                        SizedBox(width: 40),
                      ],
                    ),
                    const Divider(),
                    _InvoiceLineRow(),
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
            child: const Text('Create & Send'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context, Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Invoice ${invoice['id']}'),
            _buildStatusBadge(invoice['status']),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Customer', invoice['customer']),
              _DetailRow('Invoice Date', DateFormat('MMMM d, yyyy').format(invoice['date'])),
              _DetailRow('Due Date', DateFormat('MMMM d, yyyy').format(invoice['dueDate'])),
              _DetailRow('Items', '${invoice['items']} items'),
              const Divider(),
              _DetailRow('Subtotal', 'UGX ${NumberFormat('#,###').format(invoice['subtotal'])}'),
              _DetailRow('Tax (18%)', 'UGX ${NumberFormat('#,###').format(invoice['tax'])}'),
              _DetailRow('Total', 'UGX ${NumberFormat('#,###').format(invoice['total'])}'),
              _DetailRow('Amount Paid', 'UGX ${NumberFormat('#,###').format(invoice['amountPaid'])}'),
              _DetailRow(
                'Balance Due',
                'UGX ${NumberFormat('#,###').format((invoice['total'] as double) - (invoice['amountPaid'] as double))}',
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
          if (invoice['status'] != 'Paid' && invoice['status'] != 'Cancelled')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRecordPaymentDialog(context, invoice);
              },
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Record Payment'),
            ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Map<String, dynamic> invoice) {
    final balance = (invoice['total'] as double) - (invoice['amountPaid'] as double);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment - ${invoice['id']}'),
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

class _InvoiceLineRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: 'Item description',
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
                hintText: '1',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: '0.00',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: '0.00',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              readOnly: true,
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
