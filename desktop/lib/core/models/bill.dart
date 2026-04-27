enum BillStatus {
  draft,
  pending,
  partial,
  paid,
  overdue,
  cancelled,
}

class Bill {
  final String id;
  final String billNumber;
  final String vendorId;
  final String? vendorName;
  final DateTime date;
  final DateTime dueDate;
  final double subtotal;
  final double taxAmount;
  final double total;
  final double amountPaid;
  final BillStatus status;
  final String currencyCode;
  final String? category;
  final List<BillLine> lines;
  final String? notes;
  final String? reference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncSequence;

  Bill({
    required this.id,
    required this.billNumber,
    required this.vendorId,
    this.vendorName,
    required this.date,
    required this.dueDate,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    this.amountPaid = 0.0,
    this.status = BillStatus.draft,
    this.currencyCode = 'UGX',
    this.category,
    required this.lines,
    this.notes,
    this.reference,
    required this.createdAt,
    required this.updatedAt,
    this.syncSequence,
  });

  double get balance => total - amountPaid;
  bool get isPaid => status == BillStatus.paid;
  bool get isOverdue => DateTime.now().isAfter(dueDate) && balance > 0;

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: (json['id'] ?? '').toString(),
      billNumber: json['bill_number'] as String,
      vendorId: (json['vendor_id'] ?? '').toString(),
      vendorName: json['vendor_name'] as String?,
      date: DateTime.parse(json['date'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      status: BillStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BillStatus.draft,
      ),
      currencyCode: json['currency_code'] as String? ?? 'UGX',
      category: json['category'] as String?,
      lines: (json['lines'] as List<dynamic>?)
              ?.map((l) => BillLine.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      reference: json['reference'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncSequence: json['sync_sequence'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_number': billNumber,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'date': date.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'amount_paid': amountPaid,
      'status': status.name,
      'currency_code': currencyCode,
      'category': category,
      'lines': lines.map((l) => l.toJson()).toList(),
      'notes': notes,
      'reference': reference,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_sequence': syncSequence,
    };
  }

  Bill copyWith({
    String? id,
    String? billNumber,
    String? vendorId,
    String? vendorName,
    DateTime? date,
    DateTime? dueDate,
    double? subtotal,
    double? taxAmount,
    double? total,
    double? amountPaid,
    BillStatus? status,
    String? currencyCode,
    String? category,
    List<BillLine>? lines,
    String? notes,
    String? reference,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncSequence,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      category: category ?? this.category,
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncSequence: syncSequence ?? this.syncSequence,
    );
  }
}

class BillLine {
  final String id;
  final String billId;
  final String accountId;
  final String? accountName;
  final String description;
  final double quantity;
  final double unitPrice;
  final double amount;
  final double taxRate;
  final double taxAmount;

  BillLine({
    required this.id,
    required this.billId,
    required this.accountId,
    this.accountName,
    required this.description,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.amount = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
  });

  factory BillLine.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>?;
    final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    return BillLine(
      id: (json['id'] ?? '').toString(),
      billId: (json['bill_id'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      accountName: json['account_name'] as String? ?? account?['name'] as String?,
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? amount,
      amount: amount,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'account_id': accountId,
      'account_name': accountName,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
    };
  }
}
