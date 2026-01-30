import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  final List<Map<String, dynamic>> _vendors = [
    {
      'id': 'VEN-001',
      'name': 'Quality Supplies Uganda',
      'email': 'orders@qualitysupplies.ug',
      'phone': '+256 414 123456',
      'address': 'Industrial Area, Kampala',
      'taxId': 'TIN111222333',
      'paymentTerms': 'Net 30',
      'balance': 8500000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 18),
      'billCount': 12,
    },
    {
      'id': 'VEN-002',
      'name': 'Tech Solutions Ltd',
      'email': 'sales@techsolutions.co.ug',
      'phone': '+256 752 234567',
      'address': 'Nakasero, Kampala',
      'taxId': 'TIN444555666',
      'paymentTerms': 'Net 15',
      'balance': 3200000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 15),
      'billCount': 6,
    },
    {
      'id': 'VEN-003',
      'name': 'Office Essentials Corp',
      'email': 'procurement@officeess.ug',
      'phone': '+256 780 345678',
      'address': 'Kololo, Kampala',
      'taxId': 'TIN777888999',
      'paymentTerms': 'Net 30',
      'balance': 0.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 10),
      'billCount': 8,
    },
    {
      'id': 'VEN-004',
      'name': 'Uganda Power Solutions',
      'email': 'accounts@ugandapower.com',
      'phone': '+256 701 456789',
      'address': 'Ntinda, Kampala',
      'taxId': 'TIN000111222',
      'paymentTerms': 'Due on Receipt',
      'balance': 15000000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 20),
      'billCount': 15,
    },
    {
      'id': 'VEN-005',
      'name': 'Global Imports Ltd',
      'email': 'info@globalimports.ug',
      'phone': '+256 772 567890',
      'address': 'Port Bell, Kampala',
      'taxId': 'TIN333444555',
      'paymentTerms': 'Net 45',
      'balance': 25000000.0,
      'status': 'On Hold',
      'lastTransaction': DateTime(2023, 12, 20),
      'billCount': 20,
    },
    {
      'id': 'VEN-006',
      'name': 'Local Farmers Cooperative',
      'email': 'sales@localfarmers.ug',
      'phone': '+256 783 678901',
      'address': 'Mukono',
      'taxId': 'TIN666777888',
      'paymentTerms': 'Net 7',
      'balance': 1500000.0,
      'status': 'Active',
      'lastTransaction': DateTime(2024, 1, 19),
      'billCount': 25,
    },
  ];

  List<Map<String, dynamic>> get _filteredVendors {
    return _vendors.where((vendor) {
      final matchesSearch = _searchQuery.isEmpty ||
          vendor['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          vendor['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          vendor['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || vendor['status'] == _selectedStatus;
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
            Expanded(child: _buildVendorsTable(context)),
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
              'Vendors',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your supplier accounts and payables',
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
              onPressed: () => _showAddVendorDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Vendor'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final totalVendors = _vendors.length;
    final activeVendors = _vendors.where((v) => v['status'] == 'Active').length;
    final totalPayable = _vendors.fold<double>(0, (sum, v) => sum + (v['balance'] as double));
    final overdueCount = _vendors.where((v) => (v['balance'] as double) > 10000000).length;

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.store,
          iconColor: AppColors.primary,
          label: 'Total Vendors',
          value: totalVendors.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.check_circle,
          iconColor: AppColors.income,
          label: 'Active',
          value: activeVendors.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.expense,
          label: 'Total Payable',
          value: 'UGX ${_formatNumber(totalPayable)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.warning_amber,
          iconColor: AppColors.warning,
          label: 'High Balance',
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
              hintText: 'Search vendors...',
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

  Widget _buildVendorsTable(BuildContext context) {
    return Card(
      child: DataTable2(
        columnSpacing: 24,
        horizontalMargin: 24,
        minWidth: 1100,
        headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
        columns: const [
          DataColumn2(label: Text('Vendor'), size: ColumnSize.L),
          DataColumn2(label: Text('Contact'), size: ColumnSize.L),
          DataColumn2(label: Text('Payment Terms'), size: ColumnSize.M),
          DataColumn2(label: Text('Balance'), size: ColumnSize.M, numeric: true),
          DataColumn2(label: Text('Bills'), size: ColumnSize.S, numeric: true),
          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: _filteredVendors.map((vendor) {
          final balance = vendor['balance'] as double;

          return DataRow2(
            onTap: () => _showVendorDetails(context, vendor),
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vendor['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      vendor['id'],
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
                    Text(vendor['email'], style: const TextStyle(fontSize: 13)),
                    Text(
                      vendor['phone'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(vendor['paymentTerms'])),
              DataCell(
                Text(
                  'UGX ${_formatNumber(balance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    color: balance > 10000000 ? AppColors.expense : null,
                  ),
                ),
              ),
              DataCell(
                Text(
                  vendor['billCount'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(_buildStatusBadge(vendor['status'])),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.receipt_outlined, size: 18),
                      onPressed: () {},
                      tooltip: 'View Bills',
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

  void _showAddVendorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Vendor'),
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
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Payment Terms'),
                      items: ['Due on Receipt', 'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {},
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
            child: const Text('Add Vendor'),
          ),
        ],
      ),
    );
  }

  void _showVendorDetails(BuildContext context, Map<String, dynamic> vendor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(vendor['name']),
            _buildStatusBadge(vendor['status']),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Vendor ID', vendor['id']),
              _DetailRow('Email', vendor['email']),
              _DetailRow('Phone', vendor['phone']),
              _DetailRow('Address', vendor['address']),
              _DetailRow('Tax ID', vendor['taxId']),
              const Divider(),
              _DetailRow('Payment Terms', vendor['paymentTerms']),
              _DetailRow('Current Balance', 'UGX ${NumberFormat('#,###').format(vendor['balance'])}'),
              _DetailRow('Total Bills', vendor['billCount'].toString()),
              _DetailRow('Last Transaction', DateFormat('MMMM d, yyyy').format(vendor['lastTransaction'])),
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
            label: const Text('View Bills'),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Bill'),
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
