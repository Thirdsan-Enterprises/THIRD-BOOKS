import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../core/theme/app_theme.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedType;

  final List<Map<String, dynamic>> _accounts = [
    {'code': '1000', 'name': 'Cash on Hand', 'type': 'Asset', 'subtype': 'Current Asset', 'balance': 5250000.0, 'isActive': true},
    {'code': '1010', 'name': 'Petty Cash', 'type': 'Asset', 'subtype': 'Current Asset', 'balance': 500000.0, 'isActive': true},
    {'code': '1100', 'name': 'Bank Account - UGX', 'type': 'Asset', 'subtype': 'Current Asset', 'balance': 45000000.0, 'isActive': true},
    {'code': '1110', 'name': 'Bank Account - USD', 'type': 'Asset', 'subtype': 'Current Asset', 'balance': 12500000.0, 'isActive': true},
    {'code': '1200', 'name': 'Accounts Receivable', 'type': 'Asset', 'subtype': 'Current Asset', 'balance': 8450000.0, 'isActive': true},
    {'code': '1500', 'name': 'Office Equipment', 'type': 'Asset', 'subtype': 'Fixed Asset', 'balance': 15000000.0, 'isActive': true},
    {'code': '1510', 'name': 'Computer Equipment', 'type': 'Asset', 'subtype': 'Fixed Asset', 'balance': 8500000.0, 'isActive': true},
    {'code': '2000', 'name': 'Accounts Payable', 'type': 'Liability', 'subtype': 'Current Liability', 'balance': 6200000.0, 'isActive': true},
    {'code': '2100', 'name': 'VAT Payable', 'type': 'Liability', 'subtype': 'Current Liability', 'balance': 2100000.0, 'isActive': true},
    {'code': '2200', 'name': 'Salaries Payable', 'type': 'Liability', 'subtype': 'Current Liability', 'balance': 4500000.0, 'isActive': true},
    {'code': '3000', 'name': 'Owner\'s Capital', 'type': 'Equity', 'subtype': 'Equity', 'balance': 50000000.0, 'isActive': true},
    {'code': '3100', 'name': 'Retained Earnings', 'type': 'Equity', 'subtype': 'Equity', 'balance': 16910000.0, 'isActive': true},
    {'code': '4000', 'name': 'Sales Revenue', 'type': 'Revenue', 'subtype': 'Operating Revenue', 'balance': 52340000.0, 'isActive': true},
    {'code': '4100', 'name': 'Service Revenue', 'type': 'Revenue', 'subtype': 'Operating Revenue', 'balance': 12500000.0, 'isActive': true},
    {'code': '5000', 'name': 'Cost of Goods Sold', 'type': 'Expense', 'subtype': 'Direct Cost', 'balance': 28000000.0, 'isActive': true},
    {'code': '6000', 'name': 'Salaries & Wages', 'type': 'Expense', 'subtype': 'Operating Expense', 'balance': 15000000.0, 'isActive': true},
    {'code': '6100', 'name': 'Rent Expense', 'type': 'Expense', 'subtype': 'Operating Expense', 'balance': 6000000.0, 'isActive': true},
    {'code': '6200', 'name': 'Utilities Expense', 'type': 'Expense', 'subtype': 'Operating Expense', 'balance': 1800000.0, 'isActive': true},
    {'code': '6300', 'name': 'Office Supplies', 'type': 'Expense', 'subtype': 'Operating Expense', 'balance': 450000.0, 'isActive': true},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredAccounts {
    return _accounts.where((account) {
      final matchesSearch = _searchQuery.isEmpty ||
          account['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          account['code'].toString().contains(_searchQuery);
      final matchesType = _selectedType == null || account['type'] == _selectedType;
      return matchesSearch && matchesType;
    }).toList();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Asset':
        return AppColors.asset;
      case 'Liability':
        return AppColors.liability;
      case 'Equity':
        return AppColors.equity;
      case 'Revenue':
        return AppColors.income;
      case 'Expense':
        return AppColors.expense;
      default:
        return Colors.grey;
    }
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
            _buildFilters(context),
            const SizedBox(height: 16),
            _buildAccountTypeTabs(context),
            const SizedBox(height: 16),
            Expanded(child: _buildAccountsTable(context)),
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
              'Chart of Accounts',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your company\'s accounts structure',
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
              onPressed: () => _showAddAccountDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Account'),
            ),
          ],
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
              hintText: 'Search accounts...',
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
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              hintText: 'All Types',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Types')),
              ...['Asset', 'Liability', 'Equity', 'Revenue', 'Expense']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type))),
            ],
            onChanged: (value) => setState(() => _selectedType = value),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTypeTabs(BuildContext context) {
    final types = ['All', 'Asset', 'Liability', 'Equity', 'Revenue', 'Expense'];
    final counts = {
      'All': _accounts.length,
      'Asset': _accounts.where((a) => a['type'] == 'Asset').length,
      'Liability': _accounts.where((a) => a['type'] == 'Liability').length,
      'Equity': _accounts.where((a) => a['type'] == 'Equity').length,
      'Revenue': _accounts.where((a) => a['type'] == 'Revenue').length,
      'Expense': _accounts.where((a) => a['type'] == 'Expense').length,
    };

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            _selectedType = index == 0 ? null : types[index];
          });
        },
        tabs: types.map((type) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${counts[type]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildAccountsTable(BuildContext context) {
    return Card(
      child: DataTable2(
        columnSpacing: 24,
        horizontalMargin: 24,
        minWidth: 800,
        headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
        columns: const [
          DataColumn2(label: Text('Code'), size: ColumnSize.S),
          DataColumn2(label: Text('Account Name'), size: ColumnSize.L),
          DataColumn2(label: Text('Type'), size: ColumnSize.M),
          DataColumn2(label: Text('Sub-Type'), size: ColumnSize.M),
          DataColumn2(label: Text('Balance'), size: ColumnSize.M, numeric: true),
          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: _filteredAccounts.map((account) {
          final type = account['type'] as String;
          final balance = account['balance'] as double;
          final isDebitNormal = type == 'Asset' || type == 'Expense';

          return DataRow2(
            cells: [
              DataCell(
                Text(
                  account['code'],
                  style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                ),
              ),
              DataCell(
                Text(
                  account['name'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: _getTypeColor(type),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              DataCell(Text(account['subtype'])),
              DataCell(
                Text(
                  'UGX ${_formatNumber(balance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDebitNormal ? AppColors.debit : AppColors.credit,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: account['isActive'] ? AppColors.income.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    account['isActive'] ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: account['isActive'] ? AppColors.income : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () {},
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, size: 18),
                      onPressed: () {},
                      tooltip: 'View History',
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

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Account'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Account Code'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Account Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Account Type'),
                      items: ['Asset', 'Liability', 'Equity', 'Revenue', 'Expense']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Sub-Type'),
                      items: const [
                        DropdownMenuItem(value: 'current', child: Text('Current Asset')),
                        DropdownMenuItem(value: 'fixed', child: Text('Fixed Asset')),
                      ],
                      onChanged: (value) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 2,
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
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}
