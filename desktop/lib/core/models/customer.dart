class Customer {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? taxId;
  final double creditLimit;
  final double balance;
  final String currencyCode;
  final String? paymentTerms;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? syncSequence;

  Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.taxId,
    this.creditLimit = 0.0,
    this.balance = 0.0,
    this.currencyCode = 'UGX',
    this.paymentTerms,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncSequence,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      taxId: json['tax_id'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currency_code'] as String? ?? 'UGX',
      paymentTerms: json['payment_terms'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncSequence: json['sync_sequence'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'tax_id': taxId,
      'credit_limit': creditLimit,
      'balance': balance,
      'currency_code': currencyCode,
      'payment_terms': paymentTerms,
      'is_active': isActive,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_sequence': syncSequence,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    double? creditLimit,
    double? balance,
    String? currencyCode,
    String? paymentTerms,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncSequence,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      creditLimit: creditLimit ?? this.creditLimit,
      balance: balance ?? this.balance,
      currencyCode: currencyCode ?? this.currencyCode,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncSequence: syncSequence ?? this.syncSequence,
    );
  }

  double get availableCredit => creditLimit - balance;
  double get creditUtilization => creditLimit > 0 ? (balance / creditLimit) * 100 : 0;
}
