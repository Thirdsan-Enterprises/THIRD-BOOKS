// Banking Screen for ThirdBooks Desktop App
// Manage bank accounts and view balances
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';

// ---------------------------------------------------------------------------
// Simple in-memory bank account model (persisted via Riverpod state)
// ---------------------------------------------------------------------------
class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String currency;
  final double balance;
  final String accountType; // Savings, Current, Mobile Money
  final bool isActive;
  final DateTime createdAt;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.currency,
    this.balance = 0,
    this.accountType = 'Current',
    this.isActive = true,
    required this.createdAt,
  });

  BankAccount copyWith({double? balance, bool? isActive}) => BankAccount(
        id: id,
        bankName: bankName,
        accountNumber: accountNumber,
        currency: currency,
        balance: balance ?? this.balance,
        accountType: accountType,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}

class BankingState {
  final List<BankAccount> accounts;
  BankingState({required this.accounts});
  BankingState copyWith({List<BankAccount>? accounts}) =>
      BankingState(accounts: accounts ?? this.accounts);
}

class BankingNotifier extends StateNotifier<BankingState> {
  BankingNotifier() : super(BankingState(accounts: _defaultAccounts()));

  static List<BankAccount> _defaultAccounts() => [
        BankAccount(
          id: 'bank-1',
          bankName: 'Stanbic Bank Uganda',
          accountNumber: '9030012345678',
          currency: 'UGX',
          balance: 0,
          accountType: 'Current',
          createdAt: DateTime(2024, 1, 1),
        ),
        BankAccount(
          id: 'bank-2',
          bankName: 'MTN Mobile Money',
          accountNumber: '0772000000',
          currency: 'UGX',
          balance: 0,
          accountType: 'Mobile Money',
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

  void addAccount(BankAccount account) {
    state = state.copyWith(accounts: [...state.accounts, account]);
  }

  void toggleActive(String id) {
    state = state.copyWith(
      accounts: state.accounts
          .map((a) => a.id == id ? a.copyWith(isActive: !a.isActive) : a)
          .toList(),
    );
  }

  void removeAccount(String id) {
    state = state.copyWith(
      accounts: state.accounts.where((a) => a.id != id).toList(),
    );
  }
}

final bankingProvider = StateNotifierProvider<BankingNotifier, BankingState>(
  (ref) => BankingNotifier(),
);

// ---------------------------------------------------------------------------
// Banking Screen
// ---------------------------------------------------------------------------
class BankingScreen extends ConsumerStatefulWidget {
  const BankingScreen({super.key});

  @override
  ConsumerState<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends ConsumerState<BankingScreen> {
  final _currencyFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankingProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context, state),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Bank Accounts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '${state.accounts.length} account(s)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: state.accounts.isEmpty
                  ? _buildEmptyState(context)
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        mainAxisExtent: 200,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: state.accounts.length,
                      itemBuilder: (context, index) =>
                          _BankTile(account: state.accounts[index]),
                    ),
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
              'Banking',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your bank accounts and balances',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => _showAddBankDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Bank Account'),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, BankingState state) {
    final totalUGX = state.accounts
        .where((a) => a.currency == 'UGX' && a.isActive)
        .fold<double>(0, (sum, a) => sum + a.balance);
    final totalUSD = state.accounts
        .where((a) => a.currency == 'USD' && a.isActive)
        .fold<double>(0, (sum, a) => sum + a.balance);
    final activeCount = state.accounts.where((a) => a.isActive).length;

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.account_balance,
          iconColor: AppColors.primary,
          label: 'Total (UGX)',
          value: 'UGX ${_currencyFormat.format(totalUGX)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.attach_money,
          iconColor: AppColors.secondary,
          label: 'Total (USD)',
          value: '\$ ${_currencyFormat.format(totalUSD)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.check_circle_outline,
          iconColor: AppColors.income,
          label: 'Active Accounts',
          value: activeCount.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.corporate_fare,
          iconColor: AppColors.info,
          label: 'Total Accounts',
          value: state.accounts.length.toString(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No bank accounts yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first bank account to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddBankDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Bank Account'),
          ),
        ],
      ),
    );
  }

  void _showAddBankDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    String selectedCurrency = 'UGX';
    String selectedType = 'Current';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance, size: 24),
              SizedBox(width: 12),
              Text('Add Bank Account'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name *',
                      hintText: 'e.g. Stanbic Bank Uganda',
                      prefixIcon: Icon(Icons.business, size: 20),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Bank name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: accountNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number *',
                      hintText: 'e.g. 9030012345678',
                      prefixIcon: Icon(Icons.credit_card, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Account number is required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.attach_money, size: 20),
                          ),
                          items: ['UGX', 'USD', 'EUR', 'GBP', 'KES', 'TZS']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedCurrency = v ?? 'UGX'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Account Type',
                            prefixIcon: Icon(Icons.category, size: 20),
                          ),
                          items: [
                            'Current',
                            'Savings',
                            'Mobile Money',
                            'Forex',
                          ]
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedType = v ?? 'Current'),
                        ),
                      ),
                    ],
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
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Account'),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final account = BankAccount(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  bankName: bankNameController.text.trim(),
                  accountNumber: accountNumberController.text.trim(),
                  currency: selectedCurrency,
                  accountType: selectedType,
                  createdAt: DateTime.now(),
                );
                ref.read(bankingProvider.notifier).addAccount(account);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${account.bankName} account added successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bank Tile Widget
// ---------------------------------------------------------------------------
class _BankTile extends ConsumerWidget {
  final BankAccount account;

  const _BankTile({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat('#,###');

    // Gradient colors per currency
    final gradients = {
      'UGX': [const Color(0xFF1A237E), const Color(0xFF3949AB)],
      'USD': [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
      'EUR': [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
      'GBP': [const Color(0xFF880E4F), const Color(0xFFC2185B)],
      'KES': [const Color(0xFFB71C1C), const Color(0xFFE53935)],
      'TZS': [const Color(0xFF004D40), const Color(0xFF00897B)],
    };
    final colors =
        gradients[account.currency] ?? [AppColors.primary, AppColors.secondary];

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: account.isActive ? colors : [Colors.grey.shade600, Colors.grey.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative circle
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -16,
            left: -16,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (!account.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Inactive',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white70, size: 18),
                      color: Theme.of(context).cardColor,
                      onSelected: (value) {
                        if (value == 'toggle') {
                          ref
                              .read(bankingProvider.notifier)
                              .toggleActive(account.id);
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                account.isActive
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(account.isActive
                                  ? 'Deactivate'
                                  : 'Activate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Remove',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  account.bankName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '•••• ${account.accountNumber.length > 4 ? account.accountNumber.substring(account.accountNumber.length - 4) : account.accountNumber}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        account.accountType,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      account.currency,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currencyFormat.format(account.balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bank Account'),
        content: Text(
            'Remove "${account.bankName}" account ending in ...${account.accountNumber.substring(account.accountNumber.length > 4 ? account.accountNumber.length - 4 : 0)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(bankingProvider.notifier).removeAccount(account.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Card
// ---------------------------------------------------------------------------
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
