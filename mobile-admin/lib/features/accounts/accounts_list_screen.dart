import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/accounts_provider.dart';

class AccountsListScreen extends ConsumerStatefulWidget {
  const AccountsListScreen({super.key});

  @override
  ConsumerState<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends ConsumerState<AccountsListScreen> {
  String? _selectedTypeFilter;

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart of Accounts'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedTypeFilter = value == 'all' ? null : value;
              });
              ref.read(accountsProvider.notifier).setTypeFilter(_selectedTypeFilter);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Types')),
              const PopupMenuItem(value: 'asset', child: Text('Assets')),
              const PopupMenuItem(value: 'liability', child: Text('Liabilities')),
              const PopupMenuItem(value: 'equity', child: Text('Equity')),
              const PopupMenuItem(value: 'revenue', child: Text('Revenue')),
              const PopupMenuItem(value: 'expense', child: Text('Expenses')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'seed') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Seed Default Accounts'),
                    content: const Text(
                      'This will create a standard chart of accounts. Continue?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(accountsProvider.notifier).seedDefaultAccounts();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Default accounts created')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'seed',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high),
                    SizedBox(width: 8),
                    Text('Seed Default Accounts'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: accountsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : accountsState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${accountsState.error}'),
                      ElevatedButton(
                        onPressed: () => ref.read(accountsProvider.notifier).loadAccounts(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : accountsState.accounts.isEmpty
                  ? _buildEmptyState(context)
                  : _buildAccountsList(context, accountsState),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAccountDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No accounts yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your chart of accounts to start bookkeeping',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(accountsProvider.notifier).seedDefaultAccounts();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Default accounts created')),
                );
              }
            },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Create Default Accounts'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList(BuildContext context, AccountsState state) {
    final groupedAccounts = state.accountsByType;
    final types = state.accountTypes;

    return RefreshIndicator(
      onRefresh: () => ref.read(accountsProvider.notifier).loadAccounts(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];
          final accounts = groupedAccounts[type.id] ?? [];

          if (_selectedTypeFilter != null && type.id != _selectedTypeFilter) {
            return const SizedBox.shrink();
          }

          if (accounts.isEmpty && _selectedTypeFilter == null) {
            return const SizedBox.shrink();
          }

          return _buildTypeSection(context, type, accounts);
        },
      ),
    );
  }

  Widget _buildTypeSection(BuildContext context, AccountType type, List<Account> accounts) {
    final theme = Theme.of(context);
    final typeColor = _getTypeColor(type.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: typeColor.withOpacity(0.1),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                type.name.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${accounts.length} accounts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No ${type.name.toLowerCase()} accounts',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          ...accounts.map((account) => _buildAccountTile(context, account, typeColor)),
      ],
    );
  }

  Widget _buildAccountTile(BuildContext context, Account account, Color typeColor) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: typeColor.withOpacity(0.1),
        child: Text(
          account.code.substring(0, account.code.length > 2 ? 2 : account.code.length),
          style: TextStyle(
            color: typeColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(account.name),
      subtitle: Text(
        account.code,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatCurrency(account.currentBalance, account.currencyCode),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: account.currentBalance >= 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
          if (!account.isActive)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.block,
                size: 16,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      onTap: () => _showAccountDetails(context, account),
    );
  }

  Color _getTypeColor(String typeId) {
    switch (typeId) {
      case 'asset':
        return Colors.blue;
      case 'liability':
        return Colors.orange;
      case 'equity':
        return Colors.purple;
      case 'revenue':
        return Colors.green;
      case 'expense':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      )}';
    }
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }

  void _showAccountDetails(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _AccountDetailsSheet(
          account: account,
          scrollController: scrollController,
          onEdit: () {
            Navigator.pop(context);
            _showEditAccountDialog(context, account);
          },
          onDelete: () async {
            Navigator.pop(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Account'),
                content: Text('Are you sure you want to delete "${account.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(accountsProvider.notifier).deleteAccount(account.id);
            }
          },
        ),
      ),
    );
  }

  void _showCreateAccountDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AccountFormSheet(
          title: 'Create Account',
          accountTypes: ref.read(accountsProvider).accountTypes,
          onSave: (data) async {
            await ref.read(accountsProvider.notifier).createAccount(
              code: data['code'] as String,
              name: data['name'] as String,
              accountTypeId: data['account_type_id'] as String,
              description: data['description'] as String?,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account created')),
              );
            }
          },
        ),
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AccountFormSheet(
          title: 'Edit Account',
          accountTypes: ref.read(accountsProvider).accountTypes,
          initialData: {
            'code': account.code,
            'name': account.name,
            'account_type_id': account.accountTypeId,
            'description': account.description,
          },
          onSave: (data) async {
            await ref.read(accountsProvider.notifier).updateAccount(
              account.id,
              code: data['code'] as String?,
              name: data['name'] as String?,
              description: data['description'] as String?,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account updated')),
              );
            }
          },
        ),
      ),
    );
  }
}

class _AccountDetailsSheet extends StatelessWidget {
  final Account account;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountDetailsSheet({
    required this.account,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            account.name,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(account.code),
                avatar: const Icon(Icons.tag, size: 16),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(account.accountTypeId.toUpperCase()),
              ),
              if (!account.isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(
                    label: const Text('Inactive'),
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _DetailRow(
            label: 'Current Balance',
            value: '${account.currencyCode} ${account.currentBalance.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
          _DetailRow(
            label: 'Currency',
            value: account.currencyCode,
          ),
          _DetailRow(
            label: 'Allow Direct Posting',
            value: account.allowDirectPosting ? 'Yes' : 'No',
          ),
          if (account.description != null && account.description!.isNotEmpty)
            _DetailRow(
              label: 'Description',
              value: account.description!,
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: isHighlighted
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AccountFormSheet extends StatefulWidget {
  final String title;
  final List<AccountType> accountTypes;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _AccountFormSheet({
    required this.title,
    required this.accountTypes,
    this.initialData,
    required this.onSave,
  });

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedTypeId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialData?['code'] ?? '');
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData?['description'] ?? '');
    _selectedTypeId = widget.initialData?['account_type_id'];
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Account Code',
                hintText: 'e.g., 1000',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an account code';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g., Cash on Hand',
                prefixIcon: Icon(Icons.account_balance),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an account name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTypeId,
              decoration: const InputDecoration(
                labelText: 'Account Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: widget.accountTypes.map((type) {
                return DropdownMenuItem(
                  value: type.id,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: widget.initialData != null
                  ? null // Disable changing type for existing accounts
                  : (value) {
                      setState(() {
                        _selectedTypeId = value;
                      });
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an account type';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onSave({
        'code': _codeController.text,
        'name': _nameController.text,
        'account_type_id': _selectedTypeId,
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
