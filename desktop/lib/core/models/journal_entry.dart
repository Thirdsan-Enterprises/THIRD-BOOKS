enum JournalEntryStatus {
  draft,
  pending,
  posted,
  voided,
}

class JournalEntry {
  final String id;
  final String entryNumber;
  final DateTime date;
  final String description;
  final String? reference;
  final JournalEntryStatus status;
  final List<JournalLine> lines;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncSequence;

  JournalEntry({
    required this.id,
    required this.entryNumber,
    required this.date,
    required this.description,
    this.reference,
    this.status = JournalEntryStatus.draft,
    required this.lines,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.syncSequence,
  });

  double get totalDebit => lines.fold(0.0, (sum, line) => sum + line.debit);
  double get totalCredit => lines.fold(0.0, (sum, line) => sum + line.credit);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: (json['id'] ?? '').toString(),
      entryNumber: json['entry_number'] as String,
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String? ?? '',
      reference: json['reference'] as String?,
      status: JournalEntryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => JournalEntryStatus.draft,
      ),
      lines: (json['lines'] as List<dynamic>?)
              ?.map((l) => JournalLine.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      createdBy: json['created_by'] == null ? null : json['created_by'].toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncSequence: json['sync_sequence'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_number': entryNumber,
      'date': date.toIso8601String(),
      'description': description,
      'reference': reference,
      'status': status.name,
      'lines': lines.map((l) => l.toJson()).toList(),
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_sequence': syncSequence,
    };
  }

  JournalEntry copyWith({
    String? id,
    String? entryNumber,
    DateTime? date,
    String? description,
    String? reference,
    JournalEntryStatus? status,
    List<JournalLine>? lines,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncSequence,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      entryNumber: entryNumber ?? this.entryNumber,
      date: date ?? this.date,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncSequence: syncSequence ?? this.syncSequence,
    );
  }
}

class JournalLine {
  final String id;
  final String journalEntryId;
  final String accountId;
  final String? accountName;
  final String? accountCode;
  final double debit;
  final double credit;
  final String? description;

  JournalLine({
    required this.id,
    required this.journalEntryId,
    required this.accountId,
    this.accountName,
    this.accountCode,
    this.debit = 0.0,
    this.credit = 0.0,
    this.description,
  });

  factory JournalLine.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>?;
    return JournalLine(
      id: (json['id'] ?? '').toString(),
      journalEntryId: (json['journal_entry_id'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      accountName: json['account_name'] as String? ?? account?['name'] as String?,
      accountCode: json['account_code'] as String? ?? account?['code'] as String?,
      debit: _parseAmount(json['debit']),
      credit: _parseAmount(json['credit']),
      description: json['description'] as String?,
    );
  }

  static double _parseAmount(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journal_entry_id': journalEntryId,
      'account_id': accountId,
      'account_name': accountName,
      'account_code': accountCode,
      'debit': debit,
      'credit': credit,
      'description': description,
    };
  }

  JournalLine copyWith({
    String? id,
    String? journalEntryId,
    String? accountId,
    String? accountName,
    String? accountCode,
    double? debit,
    double? credit,
    String? description,
  }) {
    return JournalLine(
      id: id ?? this.id,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountCode: accountCode ?? this.accountCode,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      description: description ?? this.description,
    );
  }
}
