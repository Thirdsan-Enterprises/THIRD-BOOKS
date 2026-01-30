import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  final List<Map<String, dynamic>> _customers = [
    {
      'id': 'CUST-001',
      'name': 'Kampala Traders Ltd',
      'email': 'info@kampalatraders.co.ug',
      'phone': '+256 700 123456',
      'address': 'Plot 45, Kampala Road, Kampala',
      'taxId': 'TIN123456789',
      'creditLimit': 50000000.0,
      'balance': 12500000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 18),
      'invoiceCount': 15,
    },
    {
      'id': 'CUST-002',
      'name': 'Jinja Hardware Supplies',
      'email': 'sales@jinjahardware.ug',
      'phone': '+256 752 987654',
      'address': '23 Main Street, Jinja',
      'taxId': 'TIN987654321',
      'creditLimit': 30000000.0,
      'balance': 8450000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 15),
      'invoiceCount': 8,
    },
    {
      'id': 'CUST-003',
      'name': 'Entebbe Fresh Farms',
      'email': 'orders@entebbefarms.com',
      'phone': '+256 780 456789',
      'address': 'Entebbe Highway, Kampala',
      'taxId': 'TIN456789123',
      'creditLimit': 20000000.0,
      'balance': 0.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 10),
      'invoiceCount': 5,
    },
    {
      'id': 'CUST-004',
      'name': 'Mbarara Beverages Co',
      'email': 'accounts@mbararabev.ug',
      'phone': '+256 701 234567',
      'address': 'Industrial Area, Mbarara',
      'taxId': 'TIN234567891',
      'creditLimit': 75000000.0,
      'balance': 45000000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 20),
      'invoiceCount': 22,
    },
    {
      'id': 'CUST-005',
      'name': 'Gulu Construction Works',
      'email': 'info@guluconst.co.ug',
      'phone': '+256 772 345678',
      'address': 'Plot 12, Gulu Town',
      'taxId': 'TIN345678912',
      'creditLimit': 100000000.0,
      'balance': 67500000.0,
      'status': 'On Hold',
      'lastTransaction': DateTime(2023, 12, 15),
      'invoiceCount': 18,
    },
    {
      'id': 'CUST-006',
      'name': 'Lira Agro Products',
      'email': 'sales@liraagro.ug',
      'phone': '+256 783 456789',
      'address': 'Main Market, Lira',
      'taxId': 'TIN567891234',
      'creditLimit': 15000000.0,
      'balance': 2500000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 12),
      'invoiceCount': 6,
    },
  ];

  List<Map<String, dynamic>> get _filteredCustomers {
    return _customers.where((customer) {
      final matchesSearch = _searchQuery.isEmpty ||
          customer['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          customer['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          customer['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || customer['status'] == _selectedStatus;
      return matchesSearch && matchesStatus;
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
            Expanded(child: _buildCustomersTable(context)),
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
              'Customers',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your customer accounts and receivables',
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
              onPressed: () => _showAddCustomerDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Customer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final totalCustomers = _customers.length;
    final activeCustomers = _customers.where((c) => c['status'] == 'Active').length;
    final totalReceivable = _customers.fold<double>(0, (sum, c) => sum + (c['balance'] as double));
    final overdueCount = _customers.where((c) => (c['balance'] as double) > (c['creditLimit'] as double) * 0.8).length;

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.people,
          iconColor: AppColors.primary,
          label: 'Total Customers',
          value: totalCustomers.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.check_circle,
          iconColor: AppColors.income,
          label: 'Active',
          value: activeCustomers.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.debit,
          label: 'Total Receivable',
          value: 'UGX ${_formatNumber(totalReceivable)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.warning_amber,
          iconColor: AppColors.expense,
          label: 'Near Credit Limit',
          value: overdueCount.toString(),
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
              hintText: 'Search customers...',
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
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              hintText: 'All Statuses',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...['Active', 'On Hold', 'Inactive']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersTable(BuildContext context) {
    return Card(
      child: DataTable2(
        columnSpacing: 24,
        horizontalMargin: 24,
        minWidth: 1100,
        headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
        columns: const [
          DataColumn2(label: Text('Customer'), size: ColumnSize.L),
          DataColumn2(label: Text('Contact'), size: ColumnSize.L),
          DataColumn2(label: Text('Credit Limit'), size: ColumnSize.M, numeric: true),
          DataColumn2(label: Text('Balance'), size: ColumnSize.M, numeric: true),
          DataColumn2(label: Text('Invoices'), size: ColumnSize.S, numeric: true),
          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: _filteredCustomers.map((customer) {
          final balance = customer['balance'] as double;
          final creditLimit = customer['creditLimit'] as double;
          final utilizationPercent = creditLimit > 0 ? (balance / creditLimit * 100) : 0;

          return DataRow2(
            onTap: () => _showCustomerDetails(context, customer),
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      customer['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      customer['id'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(customer['email'], style: const TextStyle(fontSize: 13)),
                    Text(
                      customer['phone'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  'UGX ${_formatNumber(creditLimit)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'UGX ${_formatNumber(balance)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: utilizationPercent > 80 ? AppColors.expense : null,
                      ),
                    ),
                    Text(
                      '${utilizationPercent.toStringAsFixed(0)}% used',
                      style: TextStyle(
                        fontSize: 11,
                        color: utilizationPercent > 80 ? AppColors.expense : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  customer['invoiceCount'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(_buildStatusBadge(customer['status'])),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      onPressed: () {},
                      tooltip: 'View Invoices',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () {},
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Active':
        color = AppColors.income;
        break;
      case 'On Hold':
        color = AppColors.warning;
        break;
      case 'Inactive':
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

  void _showAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Company Name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Tax ID (TIN)'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Credit Limit'),
                      keyboardType: TextInputType.number,
                    ),
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Add Customer'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(customer['name']),
            _buildStatusBadge(customer['status']),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Customer ID', customer['id']),
              _DetailRow('Email', customer['email']),
              _DetailRow('Phone', customer['phone']),
              _DetailRow('Address', customer['address']),
              _DetailRow('Tax ID', customer['taxId']),
              const Divider(),
              _DetailRow('Credit Limit', 'UGX ${NumberFormat('#,###').format(customer['creditLimit'])}'),
              _DetailRow('Current Balance', 'UGX ${NumberFormat('#,###').format(customer['balance'])}'),
              _DetailRow('Total Invoices', customer['invoiceCount'].toString()),
              _DetailRow('Last Transaction', DateFormat('MMMM d, yyyy').format(customer['lastTransaction'])),
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
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('View Invoices'),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Invoice'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
