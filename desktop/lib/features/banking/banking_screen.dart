// Banking Screen for ThirdBooks Desktop App
// Manage bank accounts and view balances
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/models/bank_transaction.dart';

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
  final LocalStorageService _localStorage = LocalStorageService.instance;

  BankingNotifier() : super(BankingState(accounts: _defaultAccounts()));

  static List<BankAccount> _defaultAccounts() => [
        BankAccount(
          id: 'bank-1',
          bankName: 'ABSA Bank Uganda',
          accountNumber: '6009239292',
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

  /// Apply a running-balance update to a bank account after reconciliation.
  void updateBalance(String bankAccountId, double delta) {
    state = state.copyWith(
      accounts: state.accounts.map((a) {
        if (a.id == bankAccountId) {
          return a.copyWith(balance: a.balance + delta);
        }
        return a;
      }).toList(),
    );
  }

  /// Record a transaction and persist it; returns the saved transaction.
  Future<BankTransaction> recordTransaction({
    required String bankAccountId,
    required DateTime date,
    required String description,
    required BankTxType type,
    required double amount,
    String? reference,
    String? sourceType,
    String? sourceId,
    String? sourceLabel,
  }) async {
    final existing = await _localStorage.loadBankTransactions();
    final accountTxns = existing
        .where((t) => t.bankAccountId == bankAccountId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final lastBalance = accountTxns.isNotEmpty
        ? accountTxns.last.runningBalance
        : (state.accounts
                .cast<BankAccount?>()
                .firstWhere((a) => a?.id == bankAccountId, orElse: () => null)
                ?.balance ??
            0);

    final newBalance = type == BankTxType.credit
        ? lastBalance + amount
        : lastBalance - amount;

    final tx = BankTransaction(
      id: const Uuid().v4(),
      bankAccountId: bankAccountId,
      date: date,
      description: description,
      type: type,
      amount: amount,
      runningBalance: newBalance,
      reference: reference,
      sourceType: sourceType,
      sourceId: sourceId,
      sourceLabel: sourceLabel,
      createdAt: DateTime.now(),
    );

    await _localStorage.saveBankTransactions([...existing, tx]);

    // Update the in-memory account balance
    final delta = type == BankTxType.credit ? amount : -amount;
    updateBalance(bankAccountId, delta);

    return tx;
  }
}

final bankingProvider = StateNotifierProvider<BankingNotifier, BankingState>(
  (ref) => BankingNotifier(),
);

/// Provider for reading all transactions for a specific bank account.
final bankTransactionsProvider =
    FutureProvider.family<List<BankTransaction>, String>((ref, bankAccountId) async {
  final ls = LocalStorageService.instance;
  final all = await ls.loadBankTransactions();
  return all.where((t) => t.bankAccountId == bankAccountId).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

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
                        mainAxisExtent: 230,
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
                      hintText: 'e.g. ABSA Bank Uganda',
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

    // For MTN Mobile Money (bank-2) the displayed balance is driven by CoA
    // account 102 in the ledger so that CSV uploads, reconciliations and any
    // manual JEs all flow through to the card automatically.
    final ledgerRaw = account.id == 'bank-2'
        ? ref.watch(ledgerBalancesProvider)
        : const <String, double>{};
    final displayBalance = account.id == 'bank-2'
        ? (ledgerRaw['acct-102'] ?? 0.0)
        : account.balance;

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
                      currencyFormat.format(displayBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showStatementDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white70, size: 12),
                        SizedBox(width: 4),
                        Text('View Statement',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _BankStatementDialog(account: account),
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
// Bank Statement Dialog
// ---------------------------------------------------------------------------
class _BankStatementDialog extends ConsumerStatefulWidget {
  final BankAccount account;

  const _BankStatementDialog({required this.account});

  @override
  ConsumerState<_BankStatementDialog> createState() => _BankStatementDialogState();
}

class _BankStatementDialogState extends ConsumerState<_BankStatementDialog> {
  final fmt = NumberFormat('#,###');
  final dateFmt = DateFormat('MMM d, yyyy');

  Future<void> _exportStatement(List<BankTransaction> txns) async {
    if (txns.isEmpty) return;

    // Build running balance sorted list
    final rows = <List<dynamic>>[
      ['Date', 'Description', 'Reference', 'Debit (UGX)', 'Credit (UGX)', 'Balance (UGX)'],
    ];
    for (final tx in txns) {
      final isCredit = tx.type == BankTxType.credit;
      rows.add([
        dateFmt.format(tx.date),
        tx.description,
        tx.reference ?? '',
        isCredit ? '' : tx.amount.toStringAsFixed(0),
        isCredit ? tx.amount.toStringAsFixed(0) : '',
        tx.runningBalance.toStringAsFixed(0),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final fileName = '${widget.account.bankName.replaceAll(' ', '_')}_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Bank Statement',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (savePath != null) {
      await File(savePath).writeAsString(csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statement exported to $savePath'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnAsync = ref.watch(bankTransactionsProvider(widget.account.id));
    final txns = txnAsync.valueOrNull ?? [];

    // For MTN Mobile Money, drive the header balance from CoA acct-102 so
    // it always matches the general ledger regardless of how the balance moved.
    final ledgerRaw = widget.account.id == 'bank-2'
        ? ref.watch(ledgerBalancesProvider)
        : const <String, double>{};
    final displayBalance = widget.account.id == 'bank-2'
        ? (ledgerRaw['acct-102'] ?? 0.0)
        : widget.account.balance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 740,
        height: 580,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.account.bankName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${widget.account.accountType}  •  ${widget.account.currency}  •  ****${widget.account.accountNumber.length > 4 ? widget.account.accountNumber.substring(widget.account.accountNumber.length - 4) : widget.account.accountNumber}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Current Balance',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        '${widget.account.currency} ${fmt.format(displayBalance)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Column headers ─────────────────────────────────────────────
            Container(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('Date',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.outline)),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text('Description',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text('Debit',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense),
                        textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text('Credit',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.income),
                        textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text('Balance',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Transactions ───────────────────────────────────────────────
            Expanded(
              child: txnAsync.when(
                data: (txns) {
                  if (txns.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No transactions recorded yet.\nTransactions appear here after reconciling bank statements.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: txns.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final tx = txns[i];
                      final isCredit = tx.type == BankTxType.credit;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(dateFmt.format(tx.date),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tx.description,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                  if (tx.reference != null &&
                                      tx.reference!.isNotEmpty)
                                    Text('Ref: ${tx.reference}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: isCredit
                                  ? const SizedBox.shrink()
                                  : Text(
                                      fmt.format(tx.amount),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.expense,
                                          fontFamily: 'monospace'),
                                      textAlign: TextAlign.right,
                                    ),
                            ),
                            SizedBox(
                              width: 100,
                              child: isCredit
                                  ? Text(
                                      fmt.format(tx.amount),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.income,
                                          fontFamily: 'monospace'),
                                      textAlign: TextAlign.right,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                fmt.format(tx.runningBalance),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: tx.runningBalance >= 0
                                      ? null
                                      : AppColors.error,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            // ── Footer ─────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Download statement as CSV',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export CSV'),
                      onPressed: txns.isEmpty ? null : () => _exportStatement(txns),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
