import 'package:drift/drift.dart';

enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense,
}

enum AccountSubType {
  // Assets
  cash,
  bank,
  accountsReceivable,
  inventory,
  fixedAsset,
  otherCurrentAsset,
  otherAsset,

  // Liabilities
  accountsPayable,
  creditCard,
  currentLiability,
  longTermLiability,

  // Equity
  ownersEquity,
  retainedEarnings,

  // Revenue
  salesRevenue,
  serviceRevenue,
  otherIncome,

  // Expenses
  costOfGoodsSold,
  operatingExpense,
  payrollExpense,
  otherExpense,
}

class Account {
  final String id;
  final String code;
  final String name;
  final String? description;
  final AccountType type;
  final AccountSubType? subType;
  final String? parentId;
  final String currencyCode;
  final double balance;
  final bool isActive;
  final bool isSystemAccount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncSequence;

  Account({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    this.subType,
    this.parentId,
    this.currencyCode = 'UGX',
    this.balance = 0.0,
    this.isActive = true,
    this.isSystemAccount = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncSequence,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: AccountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AccountType.asset,
      ),
      subType: json['sub_type'] != null
          ? AccountSubType.values.firstWhere(
              (e) => e.name == json['sub_type'],
              orElse: () => AccountSubType.otherAsset,
            )
          : null,
      parentId: json['parent_id'] as String?,
      currencyCode: json['currency_code'] as String? ?? 'UGX',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      isSystemAccount: json['is_system_account'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncSequence: json['sync_sequence'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'type': type.name,
      'sub_type': subType?.name,
      'parent_id': parentId,
      'currency_code': currencyCode,
      'balance': balance,
      'is_active': isActive,
      'is_system_account': isSystemAccount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_sequence': syncSequence,
    };
  }

  Account copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    AccountType? type,
    AccountSubType? subType,
    String? parentId,
    String? currencyCode,
    double? balance,
    bool? isActive,
    bool? isSystemAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncSequence,
  }) {
    return Account(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      parentId: parentId ?? this.parentId,
      currencyCode: currencyCode ?? this.currencyCode,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      isSystemAccount: isSystemAccount ?? this.isSystemAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncSequence: syncSequence ?? this.syncSequence,
    );
  }

  bool get isDebitNormal => type == AccountType.asset || type == AccountType.expense;
  bool get isCreditNormal => type == AccountType.liability || type == AccountType.equity || type == AccountType.revenue;
}
