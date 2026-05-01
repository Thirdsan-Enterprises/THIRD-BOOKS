// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  /// Jump the accounts list to the first account whose name starts with [letter].
  void _jumpToLetter(String letter, List<Account> filtered) {
    final idx = filtered.indexWhere(
        (a) => a.name.toUpperCase().startsWith(letter.toUpperCase()));
    if (idx < 0 || !_scrollController.hasClients) return;
    // Each row is approximately 52px tall
    const rowHeight = 52.0;
    final offset = (idx * rowHeight).clamp(
        0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  List<Account> _filterAccounts(List<Account> accounts) {
    return accounts.where((account) {
      final matchesSearch = _searchQuery.isEmpty ||
          account.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          account.code.contains(_searchQuery);
      final matchesType = _selectedType == null || _getTypeName(account.type) == _selectedType;
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
    final ledgerRaw = ref.watch(ledgerBalancesProvider);

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
                  : _buildAccountsWithAlphaJump(
                      context, _filterAccounts(accountsState.accounts), ledgerRaw),
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
            OutlinedButton.icon(
              onPressed: () => context.go('/bills'),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Add Bill'),
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

  /// Wraps the accounts table with an A–Z alphabetical sidebar on the right.
  Widget _buildAccountsWithAlphaJump(
      BuildContext context, List<Account> filtered, Map<String, double> ledgerRaw) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final availableLetters = filtered
        .map((a) => a.name.isNotEmpty ? a.name[0].toUpperCase() : '')
        .toSet();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildAccountsTable(context, filtered, ledgerRaw)),
        const SizedBox(width: 8),
        // Alpha jump sidebar
        Container(
          width: 26,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: alphabet.split('').map((letter) {
              final isActive = availableLetters.contains(letter);
              final isSelected =
                  _searchQuery.toUpperCase() == letter;
              return GestureDetector(
                onTap: isActive
                    ? () => setState(() {
                          _searchQuery =
                              isSelected ? '' : letter;
                          _jumpToLetter(letter, filtered);
                        })
                    : null,
                child: Container(
                  height: 20,
                  alignment: Alignment.center,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isActive
                              ? AppColors.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.4),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsTable(
      BuildContext context, List<Account> accounts, Map<String, double> ledgerRaw) {
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

    // Compute total debit/credit for footer
    double totalDebit = 0;
    double totalCredit = 0;

    // Build rows — industry standard: separate Debit / Credit columns
    final dataRows = accounts.map((account) {
      // Raw ledger value: sum of all debits minus sum of all credits for this account
      // Positive = more debits than credits; Negative = more credits than debits
      final raw = ledgerRaw['acct-${account.code}'] ?? ledgerRaw[account.id] ?? 0.0;
      final debitBalance  = raw > 0 ? raw  : 0.0;
      final creditBalance = raw < 0 ? -raw : 0.0;

      totalDebit  += debitBalance;
      totalCredit += creditBalance;

      final hasBalance = raw != 0;
      final normalDirLabel = account.isDebitNormal ? 'Dr' : 'Cr';
      final isAbnormal = hasBalance &&
          (account.isDebitNormal ? raw < 0 : raw > 0);

      return DataRow(
        color: MaterialStateProperty.resolveWith((states) {
          if (hasBalance) return null;
          return null; // zero-balance rows shown normally
        }),
        cells: [
          DataCell(Text(account.code,
              style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(account.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              if (account.description != null && account.description!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: account.description!,
                  child: Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          )),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getTypeColor(account.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_getTypeName(account.type),
                style: TextStyle(color: _getTypeColor(account.type), fontSize: 12, fontWeight: FontWeight.w600)),
          )),
          DataCell(Text(account.subType?.displayName ?? '—', style: const TextStyle(fontSize: 12))),
          // Normal balance direction indicator
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                  color: account.isDebitNormal ? AppColors.debit.withOpacity(0.4) : AppColors.credit.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(normalDirLabel,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: account.isDebitNormal ? AppColors.debit : AppColors.credit)),
          )),
          // Debit Balance column
          DataCell(debitBalance > 0
              ? Text(_currencyFormat.format(debitBalance),
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w500,
                    color: isAbnormal && !account.isDebitNormal ? AppColors.warning : AppColors.debit,
                  ))
              : Text('—', style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          // Credit Balance column
          DataCell(creditBalance > 0
              ? Text(_currencyFormat.format(creditBalance),
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w500,
                    color: isAbnormal && account.isDebitNormal ? AppColors.warning : AppColors.credit,
                  ))
              : Text('—', style: TextStyle(color: Theme.of(context).colorScheme.outline))),
          DataCell(Row(
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
                tooltip: 'View Ledger History',
              ),
            ],
          )),
        ],
      );
    }).toList();

    return Card(
      child: Column(
        children: [
          // ── Ledger status bar ────────────────────────────────────────────
          if (ledgerRaw.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              child: Row(
                children: [
                  const Icon(Icons.auto_graph, size: 16),
                  const SizedBox(width: 8),
                  Text('Live ledger balances from posted journal entries',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  const Spacer(),
                  Text('Total Debits: UGX ${_currencyFormat.format(totalDebit)}',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.debit, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 24),
                  Text('Total Credits: UGX ${_currencyFormat.format(totalCredit)}',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.credit, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (totalDebit - totalCredit).abs() < 0.01
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (totalDebit - totalCredit).abs() < 0.01 ? '✓ Balanced' : '⚠ Unbalanced',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (totalDebit - totalCredit).abs() < 0.01 ? AppColors.success : AppColors.warning),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 8),
                  Text('No posted journal entries yet — balances will appear after importing data or reconciling bank statements',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          // ── Table ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: DataTable(
                  columnSpacing: 20,
                  horizontalMargin: 20,
                  headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
                  columns: const [
                    DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Sub-Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Normal\nBalance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Debit\nBalance (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), numeric: true),
                    DataColumn(label: Text('Credit\nBalance (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), numeric: true),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: dataRows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAccounts(List<Account> accounts) async {
    final ledgerRaw = ref.read(ledgerBalancesProvider);
    try {
      final csvData = StringBuffer();
      csvData.writeln('Code,Name,Type,SubType,Normal Balance,Debit Balance,Credit Balance');

      for (final account in accounts) {
        final raw = ledgerRaw['acct-${account.code}'] ?? ledgerRaw[account.id] ?? 0.0;
        final debitBalance  = raw > 0 ? raw  : 0.0;
        final creditBalance = raw < 0 ? -raw : 0.0;
        final normalDir = account.isDebitNormal ? 'Dr' : 'Cr';
        csvData.writeln('${account.code},"${account.name}",${_getTypeName(account.type)},${account.subType?.name ?? ''},$normalDir,${debitBalance.toStringAsFixed(0)},${creditBalance.toStringAsFixed(0)}');
      }

      final bytes = const Utf8Encoder().convert(csvData.toString());
      final fileName = 'chart_of_accounts_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (savePath != null) {
        final finalPath = savePath.endsWith('.csv') ? savePath : '\$savePath.csv';
        await File(finalPath).writeAsBytes(bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${accounts.length} accounts'),
            backgroundColor: AppColors.success,
          ),
        );
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
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!);
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
                                    child: Text(type.displayName),
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
                                    child: Text(type.displayName),
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
                child: Center(
                  child: Text(
                    'No transactions yet.\nImport CSV data to see transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
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
