import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// State for accounts list
class AccountsState {
  final List<Account> accounts;
  final List<AccountType> accountTypes;
  final bool isLoading;
  final String? error;
  final String? selectedTypeFilter;

  const AccountsState({
    this.accounts = const [],
    this.accountTypes = const [],
    this.isLoading = false,
    this.error,
    this.selectedTypeFilter,
  });

  AccountsState copyWith({
    List<Account>? accounts,
    List<AccountType>? accountTypes,
    bool? isLoading,
    String? error,
    String? selectedTypeFilter,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      accountTypes: accountTypes ?? this.accountTypes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
    );
  }

  List<Account> get filteredAccounts {
    if (selectedTypeFilter == null || selectedTypeFilter!.isEmpty) {
      return accounts;
    }
    return accounts.where((a) => a.accountTypeId == selectedTypeFilter).toList();
  }

  Map<String, List<Account>> get accountsByType {
    final Map<String, List<Account>> grouped = {};
    for (final type in accountTypes) {
      grouped[type.id] = accounts.where((a) => a.accountTypeId == type.id).toList();
    }
    return grouped;
  }
}

/// Provider for managing accounts
class AccountsNotifier extends StateNotifier<AccountsState> {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  AccountsNotifier(this._db) : super(const AccountsState()) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final accounts = await _db.getAllAccounts();
      final types = await _db.getAllAccountTypes();
      state = state.copyWith(
        accounts: accounts,
        accountTypes: types,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setTypeFilter(String? typeId) {
    state = state.copyWith(selectedTypeFilter: typeId);
  }

  Future<void> createAccount({
    required String code,
    required String name,
    required String accountTypeId,
    String? description,
    String? parentAccountId,
    String currencyCode = 'UGX',
    bool allowDirectPosting = true,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.insertAccount(AccountsCompanion.insert(
      id: id,
      code: code,
      name: name,
      accountTypeId: accountTypeId,
      description: Value(description),
      parentAccountId: Value(parentAccountId),
      currencyCode: Value(currencyCode),
      allowDirectPosting: Value(allowDirectPosting),
      createdAt: now,
      updatedAt: now,
    ));

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '', // Will be set by sync service
      aggregateType: 'account',
      aggregateId: id,
      eventType: 'account_created',
      eventData: jsonEncode({
        'id': id,
        'code': code,
        'name': name,
        'account_type_id': accountTypeId,
        'description': description,
        'parent_account_id': parentAccountId,
        'currency_code': currencyCode,
        'allow_direct_posting': allowDirectPosting,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadAccounts();
  }

  Future<void> updateAccount(
    String id, {
    String? code,
    String? name,
    String? description,
    String? parentAccountId,
    bool? isActive,
    bool? allowDirectPosting,
  }) async {
    final now = DateTime.now();

    await _db.updateAccount(
      id,
      AccountsCompanion(
        code: code != null ? Value(code) : const Value.absent(),
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        parentAccountId: parentAccountId != null ? Value(parentAccountId) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        allowDirectPosting: allowDirectPosting != null ? Value(allowDirectPosting) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'account',
      aggregateId: id,
      eventType: 'account_updated',
      eventData: jsonEncode({
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'parent_account_id': parentAccountId,
        'is_active': isActive,
        'allow_direct_posting': allowDirectPosting,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'account',
      aggregateId: id,
      eventType: 'account_deleted',
      eventData: jsonEncode({'id': id}),
      deviceId: '',
      userId: '',
      occurredAt: DateTime.now(),
    ));

    await loadAccounts();
  }

  Future<void> seedDefaultAccounts() async {
    final now = DateTime.now();

    // Default chart of accounts for a small business
    final defaultAccounts = [
      // Assets (1000-1999)
      {'code': '1000', 'name': 'Cash on Hand', 'type': 'asset'},
      {'code': '1010', 'name': 'Petty Cash', 'type': 'asset'},
      {'code': '1100', 'name': 'Bank Account - UGX', 'type': 'asset'},
      {'code': '1110', 'name': 'Bank Account - USD', 'type': 'asset'},
      {'code': '1200', 'name': 'Accounts Receivable', 'type': 'asset'},
      {'code': '1300', 'name': 'Inventory', 'type': 'asset'},
      {'code': '1400', 'name': 'Prepaid Expenses', 'type': 'asset'},
      {'code': '1500', 'name': 'Equipment', 'type': 'asset'},
      {'code': '1510', 'name': 'Accumulated Depreciation - Equipment', 'type': 'asset'},
      {'code': '1600', 'name': 'Vehicles', 'type': 'asset'},
      {'code': '1610', 'name': 'Accumulated Depreciation - Vehicles', 'type': 'asset'},

      // Liabilities (2000-2999)
      {'code': '2000', 'name': 'Accounts Payable', 'type': 'liability'},
      {'code': '2100', 'name': 'VAT Payable', 'type': 'liability'},
      {'code': '2200', 'name': 'PAYE Payable', 'type': 'liability'},
      {'code': '2300', 'name': 'NSSF Payable', 'type': 'liability'},
      {'code': '2400', 'name': 'Accrued Expenses', 'type': 'liability'},
      {'code': '2500', 'name': 'Short-term Loans', 'type': 'liability'},
      {'code': '2600', 'name': 'Long-term Loans', 'type': 'liability'},

      // Equity (3000-3999)
      {'code': '3000', 'name': 'Owner\'s Capital', 'type': 'equity'},
      {'code': '3100', 'name': 'Owner\'s Drawings', 'type': 'equity'},
      {'code': '3200', 'name': 'Retained Earnings', 'type': 'equity'},

      // Revenue (4000-4999)
      {'code': '4000', 'name': 'Sales Revenue', 'type': 'revenue'},
      {'code': '4100', 'name': 'Service Revenue', 'type': 'revenue'},
      {'code': '4200', 'name': 'Interest Income', 'type': 'revenue'},
      {'code': '4300', 'name': 'Other Income', 'type': 'revenue'},

      // Expenses (5000-5999)
      {'code': '5000', 'name': 'Cost of Goods Sold', 'type': 'expense'},
      {'code': '5100', 'name': 'Salaries & Wages', 'type': 'expense'},
      {'code': '5200', 'name': 'Rent Expense', 'type': 'expense'},
      {'code': '5300', 'name': 'Utilities', 'type': 'expense'},
      {'code': '5400', 'name': 'Office Supplies', 'type': 'expense'},
      {'code': '5500', 'name': 'Transport & Fuel', 'type': 'expense'},
      {'code': '5600', 'name': 'Repairs & Maintenance', 'type': 'expense'},
      {'code': '5700', 'name': 'Insurance', 'type': 'expense'},
      {'code': '5800', 'name': 'Depreciation Expense', 'type': 'expense'},
      {'code': '5900', 'name': 'Bank Charges', 'type': 'expense'},
      {'code': '5950', 'name': 'Interest Expense', 'type': 'expense'},
      {'code': '5990', 'name': 'Miscellaneous Expenses', 'type': 'expense'},
    ];

    for (final acc in defaultAccounts) {
      final id = _uuid.v4();
      await _db.insertAccount(AccountsCompanion.insert(
        id: id,
        code: acc['code'] as String,
        name: acc['name'] as String,
        accountTypeId: acc['type'] as String,
        createdAt: now,
        updatedAt: now,
      ));
    }

    await loadAccounts();
  }
}

/// Provider instance
final accountsProvider = StateNotifierProvider<AccountsNotifier, AccountsState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AccountsNotifier(db);
});

/// Provider for a single account by ID
final accountByIdProvider = FutureProvider.family<Account?, String>((ref, id) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getAccountById(id);
});

/// Stream provider for watching accounts
final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllAccounts();
});
