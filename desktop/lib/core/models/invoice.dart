enum InvoiceStatus {
  draft,
  pending,
  sent,
  partial,
  paid,
  overdue,
  cancelled,
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String? customerName;
  final DateTime date;
  final DateTime dueDate;
  final double subtotal;
  final double taxAmount;
  final double total;
  final double amountPaid;
  final InvoiceStatus status;
  final String currencyCode;
  final List<InvoiceLine> lines;
  final String? notes;
  final String? terms;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncSequence;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    this.customerName,
    required this.date,
    required this.dueDate,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    this.amountPaid = 0.0,
    this.status = InvoiceStatus.draft,
    this.currencyCode = 'UGX',
    required this.lines,
    this.notes,
    this.terms,
    required this.createdAt,
    required this.updatedAt,
    this.syncSequence,
  });

  double get balance => total - amountPaid;
  bool get isPaid => status == InvoiceStatus.paid;
  bool get isOverdue => DateTime.now().isAfter(dueDate) && balance > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: json['invoice_number'] as String,
      customerId: (json['customer_id'] ?? '').toString(),
      customerName: json['customer_name'] as String?,
      date: DateTime.parse(json['date'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      currencyCode: json['currency_code'] as String? ?? 'UGX',
      lines: (json['lines'] as List<dynamic>?)
              ?.map((l) => InvoiceLine.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      terms: json['terms'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncSequence: json['sync_sequence'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'date': date.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'amount_paid': amountPaid,
      'status': status.name,
      'currency_code': currencyCode,
      'lines': lines.map((l) => l.toJson()).toList(),
      'notes': notes,
      'terms': terms,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_sequence': syncSequence,
    };
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    DateTime? date,
    DateTime? dueDate,
    double? subtotal,
    double? taxAmount,
    double? total,
    double? amountPaid,
    InvoiceStatus? status,
    String? currencyCode,
    List<InvoiceLine>? lines,
    String? notes,
    String? terms,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncSequence,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncSequence: syncSequence ?? this.syncSequence,
    );
  }
}

class InvoiceLine {
  final String id;
  final String invoiceId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final double taxAmount;
  final double amount;
  final String? accountId;

  InvoiceLine({
    required this.id,
    required this.invoiceId,
    required this.description,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.amount = 0.0,
    this.accountId,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      id: (json['id'] ?? '').toString(),
      invoiceId: (json['invoice_id'] ?? '').toString(),
      description: json['description'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      accountId: json['account_id'] == null ? null : json['account_id'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'amount': amount,
      'account_id': accountId,
    };
  }
}
