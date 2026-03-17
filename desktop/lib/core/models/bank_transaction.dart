// Bank Transaction Model — records every activity against a bank account
// so a running balance and statement can be maintained.
// © 2026 ThirdBooks. All rights reserved.

enum BankTxType { credit, debit }

class BankTransaction {
  final String id;
  final String bankAccountId;
  final DateTime date;
  final String description;
  final BankTxType type;
  final double amount; // always positive
  final double runningBalance;
  final String? reference;
  /// Where the money was matched: 'account' | 'outlet' | 'invoice' | 'bill'
  final String? sourceType;
  final String? sourceId;
  final String? sourceLabel;
  final DateTime createdAt;

  const BankTransaction({
    required this.id,
    required this.bankAccountId,
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    required this.runningBalance,
    this.reference,
    this.sourceType,
    this.sourceId,
    this.sourceLabel,
    required this.createdAt,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> j) => BankTransaction(
        id: j['id'] as String,
        bankAccountId: j['bank_account_id'] as String,
        date: DateTime.parse(j['date'] as String),
        description: j['description'] as String,
        type: BankTxType.values.firstWhere((e) => e.name == j['type']),
        amount: (j['amount'] as num).toDouble(),
        runningBalance: (j['running_balance'] as num).toDouble(),
        reference: j['reference'] as String?,
        sourceType: j['source_type'] as String?,
        sourceId: j['source_id'] as String?,
        sourceLabel: j['source_label'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_account_id': bankAccountId,
        'date': date.toIso8601String(),
        'description': description,
        'type': type.name,
        'amount': amount,
        'running_balance': runningBalance,
        'reference': reference,
        'source_type': sourceType,
        'source_id': sourceId,
        'source_label': sourceLabel,
        'created_at': createdAt.toIso8601String(),
      };
}

// Settlement record — links a bank activity to an outlet
class OutletSettlement {
  final String id;
  final String bankTransactionId;
  final String outletId;
  final String outletCode;
  final String outletName;
  final double amount;
  final DateTime date;
  final String? bankAccountName;
  final String? reference;

  const OutletSettlement({
    required this.id,
    required this.bankTransactionId,
    required this.outletId,
    required this.outletCode,
    required this.outletName,
    required this.amount,
    required this.date,
    this.bankAccountName,
    this.reference,
  });

  factory OutletSettlement.fromJson(Map<String, dynamic> j) => OutletSettlement(
        id: j['id'] as String,
        bankTransactionId: j['bank_transaction_id'] as String,
        outletId: j['outlet_id'] as String,
        outletCode: j['outlet_code'] as String,
        outletName: j['outlet_name'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        bankAccountName: j['bank_account_name'] as String?,
        reference: j['reference'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_transaction_id': bankTransactionId,
        'outlet_id': outletId,
        'outlet_code': outletCode,
        'outlet_name': outletName,
        'amount': amount,
        'date': date.toIso8601String(),
        'bank_account_name': bankAccountName,
        'reference': reference,
      };
}
