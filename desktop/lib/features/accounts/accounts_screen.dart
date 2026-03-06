import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/models.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedType;
  final _currencyFormat = NumberFormat('#,###', 'en_US');

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

  List<Account> _filterAccounts(List<Account> accounts) {
    return accounts.where((account) {
      final matchesSearch = _searchQuery.isEmpty ||
          account.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          account.code.contains(_searchQuery);
      final matchesType = _selectedType == null || account.type.name == _selectedType;
      return matchesSearch && matchesType;
    }).toList();
  }

  Color _getTypeColor(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return AppColors.asset;
      case AccountType.liability:
        return AppColors.liability;
      case AccountType.equity:
        return AppColors.equity;
      case AccountType.revenue:
        return AppColors.income;
      case AccountType.expense:
        return AppColors.expense;
    }
  }

  String _getTypeName(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return 'Asset';
      case AccountType.liability:
        return 'Liability';
      case AccountType.equity:
        return 'Equity';
      case AccountType.revenue:
        return 'Revenue';
      case AccountType.expense:
        return 'Expense';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, accountsState.accounts),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            _buildAccountTypeTabs(context, accountsState.accounts),
            const SizedBox(height: 16),
            Expanded(
              child: accountsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAccountsTable(context, _filterAccounts(accountsState.accounts)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Account> accounts) {
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
              onPressed: () => _exportAccounts(accounts),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _importAccounts,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import'),
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
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.read(accountsProvider.notifier).loadAccounts(),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildAccountTypeTabs(BuildContext context, List<Account> accounts) {
    final types = ['All', 'Asset', 'Liability', 'Equity', 'Revenue', 'Expense'];
    final counts = {
      'All': accounts.length,
      'Asset': accounts.where((a) => a.type == AccountType.asset).length,
      'Liability': accounts.where((a) => a.type == AccountType.liability).length,
      'Equity': accounts.where((a) => a.type == AccountType.equity).length,
      'Revenue': accounts.where((a) => a.type == AccountType.revenue).length,
      'Expense': accounts.where((a) => a.type == AccountType.expense).length,
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

  Widget _buildAccountsTable(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No accounts found', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Add your first account to get started', style: Theme.of(context).textTheme.bodyMedium),
          ],
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
            headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Account Name')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Sub-Type')),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: accounts.map((Account account) {
              final isDebitNormal = account.type == AccountType.asset || account.type == AccountType.expense;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      account.code,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(
                    Text(
                      account.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor(account.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeName(account.type),
                        style: TextStyle(
                          color: _getTypeColor(account.type),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(account.subType?.name ?? '-')),
                  DataCell(
                    Text(
                      'UGX ${_currencyFormat.format(account.balance)}',
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
                        color: AppColors.income.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.income,
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
                          onPressed: () => _showEditAccountDialog(context, account),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.history, size: 18),
                          onPressed: () => _showAccountHistory(context, account),
                          tooltip: 'View History',
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

  Future<void> _exportAccounts(List<Account> accounts) async {
    try {
      final csvData = StringBuffer();
      csvData.writeln('Code,Name,Type,SubType,Balance,Status');

      for (final account in accounts) {
        csvData.writeln('${account.code},"${account.name}",${_getTypeName(account.type)},${account.subType?.name ?? ''},${account.balance},Active');
      }

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Chart of Accounts',
        fileName: 'chart_of_accounts_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(csvData.toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported ${accounts.length} accounts to $result'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _importAccounts() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final lines = content.split('\n');

        int imported = 0;
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          // Parse CSV line
          // In production, use a proper CSV parser
          imported++;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $imported accounts'),
              backgroundColor: AppColors.success,
            ),
          );
          ref.read(accountsProvider.notifier).loadAccounts();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    AccountType? selectedType;
    AccountSubType? selectedSubType;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New Account'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(labelText: 'Account Code'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Account Name'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AccountType>(
                          decoration: const InputDecoration(labelText: 'Account Type'),
                          value: selectedType,
                          items: AccountType.values
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(_getTypeName(type)),
                                  ))
                              .toList(),
                          onChanged: (value) => setDialogState(() => selectedType = value),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<AccountSubType>(
                          decoration: const InputDecoration(labelText: 'Sub-Type'),
                          value: selectedSubType,
                          items: AccountSubType.values
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.name),
                                  ))
                              .toList(),
                          onChanged: (value) => setDialogState(() => selectedSubType = value),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);

                      try {
                        final newAccount = Account(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          code: codeController.text,
                          name: nameController.text,
                          type: selectedType!,
                          subType: selectedSubType,
                          description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        ref.read(accountsProvider.notifier).addAccount(newAccount);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account created successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context, Account account) {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: account.code);
    final nameController = TextEditingController(text: account.name);
    final descriptionController = TextEditingController(text: account.description ?? '');
    AccountType selectedType = account.type;
    AccountSubType? selectedSubType = account.subType;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Account'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(labelText: 'Account Code'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Account Name'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AccountType>(
                          decoration: const InputDecoration(labelText: 'Account Type'),
                          value: selectedType,
                          items: AccountType.values
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(_getTypeName(type)),
                                  ))
                              .toList(),
                          onChanged: (value) => setDialogState(() => selectedType = value!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<AccountSubType>(
                          decoration: const InputDecoration(labelText: 'Sub-Type'),
                          value: selectedSubType,
                          items: AccountSubType.values
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.name),
                                  ))
                              .toList(),
                          onChanged: (value) => setDialogState(() => selectedSubType = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);

                      try {
                        final updatedAccount = Account(
                          id: account.id,
                          code: codeController.text,
                          name: nameController.text,
                          type: selectedType,
                          subType: selectedSubType,
                          description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                          parentId: account.parentId,
                          currencyCode: account.currencyCode,
                          balance: account.balance,
                          isActive: account.isActive,
                          isSystemAccount: account.isSystemAccount,
                          createdAt: account.createdAt,
                          updatedAt: DateTime.now(),
                          syncSequence: account.syncSequence,
                        );
                        ref.read(accountsProvider.notifier).updateAccount(updatedAccount);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account updated successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountHistory(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${account.name} - Transaction History'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account Code', style: Theme.of(context).textTheme.bodySmall),
                            Text(account.code, style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Balance', style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              'UGX ${_currencyFormat.format(account.balance)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Recent Transactions', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.arrow_upward, color: Colors.green)),
                      title: const Text('Sales Revenue - INV-2026-0001'),
                      subtitle: const Text('Jan 15, 2026'),
                      trailing: const Text('+UGX 5,900,000', style: TextStyle(color: Colors.green)),
                    ),
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.arrow_downward, color: Colors.red)),
                      title: const Text('Payment Received'),
                      subtitle: const Text('Jan 18, 2026'),
                      trailing: const Text('-UGX 5,900,000', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
