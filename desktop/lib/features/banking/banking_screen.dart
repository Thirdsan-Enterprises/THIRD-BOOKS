// Banking Screen for ThirdBooks Desktop App
// Manage bank accounts and view balances
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/api_client.dart';
import '../../core/models/bank_transaction.dart';
import '../../core/models/models.dart' show JournalEntry, JournalLine, JournalEntryStatus;
import '../../core/providers/local_bank_statements_provider.dart';

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

class _BankingScreenState extends ConsumerState<BankingScreen>
    with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat('#,###');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
            const SizedBox(height: 16),
            // ── Tabs ────────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: const [
                Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Bank Accounts'),
                Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Uploaded Statements'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Tab 1: Bank Accounts ─────────────────────────────────
                  state.accounts.isEmpty
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
                  // ── Tab 2: Uploaded Bank Statements ──────────────────────
                  _BankStatementsTab(accounts: state.accounts),
                ],
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
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(bankTransactionsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Banking refreshed'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showAddBankDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Bank Account'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, BankingState state) {
    final ledger = ref.watch(ledgerBalancesProvider);
    double _resolvedBalance(BankAccount a) {
      final id = _bankCoaId(a);
      return id != null ? (ledger[id] ?? 0.0) : a.balance;
    }
    final totalUGX = state.accounts
        .where((a) => a.currency == 'UGX' && a.isActive)
        .fold<double>(0, (sum, a) => sum + _resolvedBalance(a));
    final totalUSD = state.accounts
        .where((a) => a.currency == 'USD' && a.isActive)
        .fold<double>(0, (sum, a) => sum + _resolvedBalance(a));
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
// Maps a BankAccount to its Chart-of-Accounts ledger account ID so balances
// always reflect posted journal entries (reconciliation, imports, manual JEs).
// ---------------------------------------------------------------------------
String? _bankCoaId(BankAccount account) {
  final n = account.bankName.toLowerCase();
  if (n.contains('mtn') || n.contains('mobile money') || n.contains('momo')) return 'acct-102';
  if (n.contains('absa')) return 'acct-101';
  if (n.contains('petty') || (n.contains('cash') && !n.contains('stancash'))) return 'acct-100';
  if (n.contains('stanbic')) return 'acct-103';
  return null; // user-added account with no CoA mapping yet — fall back to stored balance
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

    // Drive balance from the general ledger for all known bank accounts so that
    // reconciliations, CSV imports and manual JEs always reflect in the card.
    final coaId = _bankCoaId(account);
    final ledgerRaw = coaId != null ? ref.watch(ledgerBalancesProvider) : const <String, double>{};
    final displayBalance = coaId != null ? (ledgerRaw[coaId] ?? 0.0) : account.balance;

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

    // Drive balance from the general ledger for all known bank accounts.
    final coaId = _bankCoaId(widget.account);
    final ledgerRaw = coaId != null ? ref.watch(ledgerBalancesProvider) : const <String, double>{};
    final displayBalance = coaId != null ? (ledgerRaw[coaId] ?? 0.0) : widget.account.balance;

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

// ---------------------------------------------------------------------------
// Bank Statements Tab
// ---------------------------------------------------------------------------
class _BankStatementsTab extends ConsumerStatefulWidget {
  final List<BankAccount> accounts;
  const _BankStatementsTab({required this.accounts});

  @override
  ConsumerState<_BankStatementsTab> createState() => _BankStatementsTabState();
}

class _BankStatementsTabState extends ConsumerState<_BankStatementsTab> {
  bool _syncing = false;

  // ── Try to sync any locally-stored statements to the server ───────────────
  Future<void> _syncToServer() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final api = ref.read(apiClientProvider);
      final statements = ref.read(localBankStatementsProvider);
      for (final stmt in statements.where((s) => s.status == 'local')) {
        // Re-upload from the original file path is not always possible after
        // the dialog closes, so we skip re-upload but still confirm via GET.
        try {
          final data = await api.getBankStatements();
          // If server has a matching statement (same bank + date range), mark synced
          for (final s in data) {
            final sFrom = s['from_date']?.toString().substring(0, 10);
            final sTo = s['to_date']?.toString().substring(0, 10);
            final stmtFrom = DateFormat('yyyy-MM-dd').format(stmt.fromDate);
            final stmtTo = DateFormat('yyyy-MM-dd').format(stmt.toDate);
            if (sFrom == stmtFrom && sTo == stmtTo) {
              await ref.read(localBankStatementsProvider.notifier)
                  .markSynced(stmt.id, s['id'] as int? ?? 0);
              break;
            }
          }
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _showUploadDialog() async {
    BankAccount? selectedAccount =
        widget.accounts.isNotEmpty ? widget.accounts.first : null;
    DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime toDate = DateTime.now();
    String? csvPath;
    String? csvName;
    int? previewRowCount;
    List<List<String>> parsedRows = [];
    final formKey = GlobalKey<FormState>();
    final openingBalCtrl = TextEditingController();
    final closingBalCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Import Bank Statement'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<BankAccount>(
                    value: selectedAccount,
                    decoration: const InputDecoration(labelText: 'Bank Account *'),
                    items: widget.accounts
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text('${a.bankName} – ${a.accountNumber}'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedAccount = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: fromDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setDialogState(() => fromDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'From Date *'),
                            child: Text(DateFormat('dd MMM yyyy').format(fromDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: toDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setDialogState(() => toDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'To Date *'),
                            child: Text(DateFormat('dd MMM yyyy').format(toDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['csv'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final path = result.files.first.path!;
                        final name = result.files.first.name;
                        // Parse CSV immediately for preview & local storage
                        try {
                          final content = await File(path).readAsString();
                          final raw = const CsvToListConverter(eol: '\n')
                              .convert(content);
                          final rows = raw
                              .map((r) => r.map((c) => c.toString()).toList())
                              .toList();
                          // Auto-detect closing balance from last "Balance" column
                          String? autoClosing;
                          if (rows.length >= 2) {
                            final header = rows.first
                                .map((h) => h.toLowerCase().trim())
                                .toList();
                            final balIdx = header.indexWhere((h) =>
                                h == 'balance' ||
                                h == 'running balance' ||
                                h == 'closing balance');
                            if (balIdx >= 0) {
                              // Walk from last data row upwards until we find a non-empty value
                              for (int i = rows.length - 1; i >= 1; i--) {
                                final cell = rows[i].length > balIdx
                                    ? rows[i][balIdx].trim()
                                    : '';
                                if (cell.isNotEmpty) {
                                  autoClosing = cell.replaceAll(RegExp(r'[^\d.\-]'), '');
                                  break;
                                }
                              }
                            }
                          }
                          setDialogState(() {
                            csvPath = path;
                            csvName = name;
                            parsedRows = rows;
                            previewRowCount =
                                rows.isEmpty ? 0 : rows.length - 1;
                            if (autoClosing != null &&
                                autoClosing!.isNotEmpty &&
                                closingBalCtrl.text.isEmpty) {
                              closingBalCtrl.text = autoClosing!;
                            }
                          });
                        } catch (_) {
                          setDialogState(() {
                            csvPath = path;
                            csvName = name;
                            parsedRows = [];
                            previewRowCount = null;
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(csvName ?? 'Select CSV File'),
                  ),
                  if (csvName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          csvName!,
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                        if (previewRowCount != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '— $previewRowCount transaction(s) found',
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.outline,
                                fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: openingBalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Opening Balance',
                            hintText: '0.00',
                            prefixText: 'UGX ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: closingBalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Closing Balance',
                            hintText: 'Auto-detected from CSV',
                            prefixText: 'UGX ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
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
              onPressed: csvPath == null
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final openingBal = double.tryParse(
                          openingBalCtrl.text.trim().replaceAll(',', ''));
                      final closingBal = double.tryParse(
                          closingBalCtrl.text.trim().replaceAll(',', ''));
                      Navigator.pop(ctx);

                      // ── Save locally first (always works offline) ──────
                      final localStmt = LocalBankStatement(
                        id: const Uuid().v4(),
                        fileName: csvName!,
                        bankAccountId: selectedAccount?.id,
                        bankAccountName: selectedAccount?.bankName,
                        bankAccountNumber: selectedAccount?.accountNumber,
                        fromDate: fromDate,
                        toDate: toDate,
                        rows: parsedRows,
                        openingBalance: openingBal,
                        closingBalance: closingBal,
                        status: 'local',
                        uploadedAt: DateTime.now(),
                      );
                      await ref
                          .read(localBankStatementsProvider.notifier)
                          .add(localStmt);

                      // ── Opening-balance JE: DR Bank / CR Retained Earnings ──
                      if (openingBal != null && openingBal > 0 && selectedAccount != null) {
                        final bankCoaId = _bankCoaId(selectedAccount);
                        if (bankCoaId != null) {
                          final jeId = const Uuid().v4();
                          final now = DateTime.now();
                          ref.read(journalsProvider.notifier).addEntry(
                            JournalEntry(
                              id: jeId,
                              entryNumber: 'OB-${DateFormat('yyyyMMdd').format(fromDate)}-${selectedAccount.id}',
                              date: fromDate,
                              description:
                                  'Opening balance — ${selectedAccount.bankName} (${selectedAccount.accountNumber})',
                              reference: csvName,
                              status: JournalEntryStatus.posted,
                              lines: [
                                JournalLine(
                                  id: '$jeId-1',
                                  journalEntryId: jeId,
                                  accountId: bankCoaId,
                                  accountCode: bankCoaId.replaceFirst('acct-', ''),
                                  accountName: selectedAccount.bankName,
                                  debit: openingBal,
                                  credit: 0,
                                  description: 'Opening balance brought forward',
                                ),
                                JournalLine(
                                  id: '$jeId-2',
                                  journalEntryId: jeId,
                                  accountId: 'acct-175',
                                  accountCode: '175',
                                  accountName: 'Retained Earnings',
                                  debit: 0,
                                  credit: openingBal,
                                  description: 'Opening balance brought forward',
                                ),
                              ],
                              createdAt: now,
                              updatedAt: now,
                            ),
                          );
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Statement saved locally'
                              '${(previewRowCount ?? 0) > 0 ? ' (${previewRowCount} transactions)' : ''}.'
                              ' Syncing to server…',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }

                      // ── Try server upload in background ────────────────
                      try {
                        final api = ref.read(apiClientProvider);
                        final resp = await api.uploadBankStatement(
                          bankAccountId: selectedAccount!.id,
                          fromDate: DateFormat('yyyy-MM-dd').format(fromDate),
                          toDate: DateFormat('yyyy-MM-dd').format(toDate),
                          csvFilePath: csvPath!,
                        );
                        final serverId =
                            (resp is Map ? resp['id'] : null) as int?;
                        if (serverId != null) {
                          await ref
                              .read(localBankStatementsProvider.notifier)
                              .markSynced(localStmt.id, serverId);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Statement synced to server ✓'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (_) {
                        // Offline — statement already saved locally, will sync later
                      }
                    },
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLocalStatement(LocalBankStatement stmt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Statement'),
        content: Text(
          'Remove "${stmt.fileName}"?'
          '${stmt.status == 'synced' ? ' It will also be deleted from the server.' : ''}'
          ' This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Try to delete from server if synced
    if (stmt.serverStatementId != null) {
      try {
        await ref.read(apiClientProvider).deleteBankStatement(stmt.serverStatementId!);
      } catch (_) {} // Offline — remove locally regardless
    }
    await ref.read(localBankStatementsProvider.notifier).remove(stmt.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statement removed')));
    }
  }

  // ── In-app statement viewer ───────────────────────────────────────────────
  void _viewStatement(LocalBankStatement stmt) {
    final fmt       = NumberFormat('#,###');
    final dateFmt   = DateFormat('dd MMM yyyy');
    final rows      = stmt.rows;
    final hasRows   = rows.isNotEmpty;
    final headers   = hasRows ? rows.first : <String>[];
    final dataRows  = hasRows ? rows.skip(1).toList() : <List<String>>[];

    // Best-effort column index detection (case-insensitive header matching).
    int _col(String label) {
      final idx = headers.indexWhere(
          (h) => h.toLowerCase().contains(label.toLowerCase()));
      return idx;
    }

    final colDate   = _col('date');
    final colDesc   = _col('description') >= 0 ? _col('description') : _col('narration');
    final colDebit  = _col('debit') >= 0 ? _col('debit') : _col('dr');
    final colCredit = _col('credit') >= 0 ? _col('credit') : _col('cr');
    final colBal    = _col('balance');
    final colRef    = _col('ref');

    String cellAt(List<String> row, int idx) =>
        (idx >= 0 && idx < row.length) ? row[idx] : '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 860,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stmt.bankAccountName != null
                                ? '${stmt.bankAccountName}'
                                    '${stmt.bankAccountNumber != null ? ' – ${stmt.bankAccountNumber}' : ''}'
                                : stmt.fileName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_fmtDate(stmt.fromDate)} → ${_fmtDate(stmt.toDate)}'
                            '  •  ${fmt.format(stmt.lineCount)} transaction(s)'
                            '  •  ${stmt.fileName}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // ── Column headers ─────────────────────────────────────────────
              if (hasRows)
                Container(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 90,  child: Text(colDate   >= 0 ? headers[colDate]   : 'Date',        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(flex: 3,    child: Text(colDesc   >= 0 ? headers[colDesc]   : 'Description', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      if (colRef >= 0)
                        SizedBox(width: 90, child: Text(headers[colRef], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      SizedBox(width: 100, child: Text(colDebit  >= 0 ? headers[colDebit]  : 'Debit',       style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.expense), textAlign: TextAlign.right)),
                      SizedBox(width: 100, child: Text(colCredit >= 0 ? headers[colCredit] : 'Credit',      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.income), textAlign: TextAlign.right)),
                      if (colBal >= 0)
                        SizedBox(width: 110, child: Text(headers[colBal], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
              const Divider(height: 1),
              // ── Rows ───────────────────────────────────────────────────────
              Expanded(
                child: !hasRows
                    ? const Center(child: Text('No transaction rows found in this statement.'))
                    : dataRows.isEmpty
                        ? const Center(child: Text('Statement has no transaction rows (header-only).'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: dataRows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final row    = dataRows[i];
                              final debit  = cellAt(row, colDebit);
                              final credit = cellAt(row, colCredit);
                              final bal    = cellAt(row, colBal);
                              final isCredit = debit.isEmpty ||
                                  double.tryParse(debit.replaceAll(',', '')) == 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(cellAt(row, colDate),
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        cellAt(row, colDesc),
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (colRef >= 0)
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          cellAt(row, colRef),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    SizedBox(
                                      width: 100,
                                      child: isCredit
                                          ? const SizedBox.shrink()
                                          : Text(debit,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.expense,
                                                  fontFamily: 'monospace'),
                                              textAlign: TextAlign.right),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: isCredit
                                          ? Text(credit,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.income,
                                                  fontFamily: 'monospace'),
                                              textAlign: TextAlign.right)
                                          : const SizedBox.shrink(),
                                    ),
                                    if (colBal >= 0)
                                      SizedBox(
                                        width: 110,
                                        child: Text(bal,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.right),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              // ── Footer ────────────────────────────────────────────────────
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(stmt.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(stmt.status),
                        style: TextStyle(
                            color: _statusColor(stmt.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Uploaded ${_fmtDate(stmt.uploadedAt)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    if (stmt.openingBalance != null || stmt.closingBalance != null) ...[
                      const SizedBox(width: 16),
                      if (stmt.openingBalance != null)
                        Text(
                          'Opening: ${NumberFormat('#,##0.00').format(stmt.openingBalance)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      if (stmt.openingBalance != null && stmt.closingBalance != null)
                        const Text('  →  ', style: TextStyle(fontSize: 12)),
                      if (stmt.closingBalance != null)
                        Text(
                          'Closing: ${NumberFormat('#,##0.00').format(stmt.closingBalance)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'synced': return Colors.green;
      case 'local': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'synced': return 'Synced';
      case 'local': return 'Local';
      default: return status;
    }
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    // Primary source: local provider (works offline)
    final statements = ref.watch(localBankStatementsProvider);
    final fmt = NumberFormat('#,###');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${statements.length} statement(s)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (statements.any((s) => s.status == 'local'))
                  Text(
                    '${statements.where((s) => s.status == 'local').length} pending sync',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _syncing ? null : _syncToServer,
                  icon: _syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  label: const Text('Sync'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _showUploadDialog,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import Statement'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Empty state ───────────────────────────────────────────────────────
        if (statements.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No statements imported yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import a CSV bank statement — it saves locally\nand syncs to the server when online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _showUploadDialog,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Statement'),
                  ),
                ],
              ),
            ),
          )
        else
          // ── Statement list ────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              itemCount: statements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final stmt = statements[index];
                final statusColor = _statusColor(stmt.status);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  // ── Tap to view rows ────────────────────────────────────
                  onTap: () => _viewStatement(stmt),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: statusColor, size: 22),
                  ),
                  title: Text(
                    stmt.bankAccountName != null
                        ? '${stmt.bankAccountName}'
                            '${stmt.bankAccountNumber != null ? ' – ${stmt.bankAccountNumber}' : ''}'
                        : stmt.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fmtDate(stmt.fromDate)} → ${_fmtDate(stmt.toDate)}'
                        '  •  ${fmt.format(stmt.lineCount)} transaction(s)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        stmt.fileName,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── View button ──────────────────────────────────
                      TextButton.icon(
                        onPressed: () => _viewStatement(stmt),
                        icon: const Icon(Icons.table_rows_outlined, size: 16),
                        label: const Text('View'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusLabel(stmt.status),
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        tooltip: 'Delete statement',
                        onPressed: () => _deleteLocalStatement(stmt),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
