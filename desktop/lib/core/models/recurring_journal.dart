import 'package:uuid/uuid.dart';

enum RecurringFrequency { daily, weekly, monthly, quarterly, annually }

class RecurringJournalLine {
  final String accountId;
  final String accountName;
  final String accountCode;
  final double debit;
  final double credit;
  final String? description;

  const RecurringJournalLine({
    required this.accountId,
    required this.accountName,
    required this.accountCode,
    this.debit = 0.0,
    this.credit = 0.0,
    this.description,
  });

  factory RecurringJournalLine.fromJson(Map<String, dynamic> j) => RecurringJournalLine(
    accountId: j['account_id'] as String,
    accountName: j['account_name'] as String? ?? '',
    accountCode: j['account_code'] as String? ?? '',
    debit: (j['debit'] as num?)?.toDouble() ?? 0.0,
    credit: (j['credit'] as num?)?.toDouble() ?? 0.0,
    description: j['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'account_id': accountId,
    'account_name': accountName,
    'account_code': accountCode,
    'debit': debit,
    'credit': credit,
    'description': description,
  };
}

class RecurringJournal {
  final String id;
  final String name;
  final String description;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextRunDate;
  final bool isActive;
  final List<RecurringJournalLine> lines;
  final String? reference;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringJournal({
    required this.id,
    required this.name,
    required this.description,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextRunDate,
    this.isActive = true,
    required this.lines,
    this.reference,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalDebit  => lines.fold(0.0, (s, l) => s + l.debit);
  double get totalCredit => lines.fold(0.0, (s, l) => s + l.credit);
  bool get isBalanced    => (totalDebit - totalCredit).abs() < 0.01;
  bool get isExpired     => endDate != null && DateTime.now().isAfter(endDate!);

  DateTime _advanceDate(DateTime from) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case RecurringFrequency.quarterly:
        return DateTime(from.year, from.month + 3, from.day);
      case RecurringFrequency.annually:
        return DateTime(from.year + 1, from.month, from.day);
    }
  }

  RecurringJournal withNextRunAdvanced() => copyWith(
    nextRunDate: _advanceDate(nextRunDate),
    updatedAt: DateTime.now(),
  );

  factory RecurringJournal.fromJson(Map<String, dynamic> j) => RecurringJournal(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    frequency: RecurringFrequency.values.firstWhere(
      (f) => f.name == j['frequency'],
      orElse: () => RecurringFrequency.monthly,
    ),
    startDate:   DateTime.parse(j['start_date'] as String),
    endDate:     j['end_date'] != null ? DateTime.parse(j['end_date'] as String) : null,
    nextRunDate: DateTime.parse(j['next_run_date'] as String),
    isActive:    (j['is_active'] as bool?) ?? true,
    lines: (j['lines'] as List<dynamic>?)
        ?.map((l) => RecurringJournalLine.fromJson(l as Map<String, dynamic>))
        .toList() ?? [],
    reference:  j['reference'] as String?,
    createdAt:  DateTime.parse(j['created_at'] as String),
    updatedAt:  DateTime.parse(j['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'frequency': frequency.name,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'next_run_date': nextRunDate.toIso8601String(),
    'is_active': isActive,
    'lines': lines.map((l) => l.toJson()).toList(),
    'reference': reference,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  RecurringJournal copyWith({
    String? id,
    String? name,
    String? description,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextRunDate,
    bool? isActive,
    List<RecurringJournalLine>? lines,
    String? reference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RecurringJournal(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    frequency: frequency ?? this.frequency,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    nextRunDate: nextRunDate ?? this.nextRunDate,
    isActive: isActive ?? this.isActive,
    lines: lines ?? this.lines,
    reference: reference ?? this.reference,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
