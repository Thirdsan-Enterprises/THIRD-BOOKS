enum PaymentType {
  received,
  made,
}

enum PaymentStatus {
  pending,
  completed,
  cancelled,
  refunded,
}

class Payment {
  final String id;
  final String paymentNumber;
  final PaymentType paymentType;
  final String? customerId;
  final String? customerName;
  final String? vendorId;
  final String? vendorName;
  final DateTime paymentDate;
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final String? accountId;
  final String? accountName;
  final PaymentStatus status;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncSequence;

  Payment({
    required this.id,
    required this.paymentNumber,
    required this.paymentType,
    this.customerId,
    this.customerName,
    this.vendorId,
    this.vendorName,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethod,
    this.reference,
    this.notes,
    this.accountId,
    this.accountName,
    this.status = PaymentStatus.completed,
    this.currencyCode = 'UGX',
    required this.createdAt,
    required this.updatedAt,
    this.syncSequence,
  });

  bool get isReceived => paymentType == PaymentType.received;
  bool get isMade => paymentType == PaymentType.made;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: (json['id'] ?? '').toString(),
      paymentNumber: json['payment_number'] as String,
      paymentType: PaymentType.values.firstWhere(
        (e) => e.name == json['payment_type'],
        orElse: () => PaymentType.received,
      ),
      customerId: json['customer_id'] == null ? null : json['customer_id'].toString(),
      customerName: json['customer_name'] as String?,
      vendorId: json['vendor_id'] == null ? null : json['vendor_id'].toString(),
      vendorName: json['vendor_name'] as String?,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      accountId: json['account_id'] == null ? null : json['account_id'].toString(),
      accountName: json['account_name'] as String?,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.completed,
      ),
      currencyCode: json['currency_code'] as String? ?? 'UGX',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncSequence: json['sync_sequence'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_number': paymentNumber,
      'payment_type': paymentType.name,
      'customer_id': customerId,
      'customer_name': customerName,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'payment_date': paymentDate.toIso8601String(),
      'amount': amount,
      'payment_method': paymentMethod,
      'reference': reference,
      'notes': notes,
      'account_id': accountId,
      'account_name': accountName,
      'status': status.name,
      'currency_code': currencyCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_sequence': syncSequence,
    };
  }

  Payment copyWith({
    String? id,
    String? paymentNumber,
    PaymentType? paymentType,
    String? customerId,
    String? customerName,
    String? vendorId,
    String? vendorName,
    DateTime? paymentDate,
    double? amount,
    String? paymentMethod,
    String? reference,
    String? notes,
    String? accountId,
    String? accountName,
    PaymentStatus? status,
    String? currencyCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncSequence,
  }) {
    return Payment(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      paymentType: paymentType ?? this.paymentType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncSequence: syncSequence ?? this.syncSequence,
    );
  }
}
