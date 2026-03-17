// Credit Note & Debit Note models — industry-standard documents
// Credit Note: issued TO a customer, reduces their invoice balance.
//   Journal: DR Revenue/Account, CR Accounts Receivable
// Debit Note: issued TO a vendor (or received), reduces a bill/payable.
//   Journal: DR Accounts Payable, CR Expense/Account
// © 2026 ThirdBooks. All rights reserved.

enum NoteStatus { draft, issued, applied, cancelled }

// ─────────────────────────────────────────────────────────────────
// Credit Note (Customer-side)
// ─────────────────────────────────────────────────────────────────
class CreditNote {
  final String id;
  final String creditNoteNumber;
  final String customerId;
  final String? customerName;
  /// Original invoice this note references (optional — can be standalone)
  final String? invoiceId;
  final String? invoiceNumber;
  final DateTime date;
  final double amount;
  final String reason;
  final NoteStatus status;
  final String currencyCode;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditNote({
    required this.id,
    required this.creditNoteNumber,
    required this.customerId,
    this.customerName,
    this.invoiceId,
    this.invoiceNumber,
    required this.date,
    required this.amount,
    required this.reason,
    this.status = NoteStatus.draft,
    this.currencyCode = 'UGX',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get balance => amount; // full amount until applied

  factory CreditNote.fromJson(Map<String, dynamic> j) => CreditNote(
        id: j['id'] as String,
        creditNoteNumber: j['credit_note_number'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String?,
        invoiceId: j['invoice_id'] as String?,
        invoiceNumber: j['invoice_number'] as String?,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        reason: j['reason'] as String,
        status: NoteStatus.values.firstWhere(
            (s) => s.name == j['status'], orElse: () => NoteStatus.draft),
        currencyCode: j['currency_code'] as String? ?? 'UGX',
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'credit_note_number': creditNoteNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'date': date.toIso8601String(),
        'amount': amount,
        'reason': reason,
        'status': status.name,
        'currency_code': currencyCode,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  CreditNote copyWith({
    NoteStatus? status,
    DateTime? updatedAt,
    String? notes,
  }) =>
      CreditNote(
        id: id,
        creditNoteNumber: creditNoteNumber,
        customerId: customerId,
        customerName: customerName,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        date: date,
        amount: amount,
        reason: reason,
        status: status ?? this.status,
        currencyCode: currencyCode,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ─────────────────────────────────────────────────────────────────
// Debit Note (Vendor-side)
// ─────────────────────────────────────────────────────────────────
class DebitNote {
  final String id;
  final String debitNoteNumber;
  final String vendorId;
  final String? vendorName;
  /// Original bill this note references (optional — can be standalone)
  final String? billId;
  final String? billNumber;
  final DateTime date;
  final double amount;
  final String reason;
  final NoteStatus status;
  final String currencyCode;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebitNote({
    required this.id,
    required this.debitNoteNumber,
    required this.vendorId,
    this.vendorName,
    this.billId,
    this.billNumber,
    required this.date,
    required this.amount,
    required this.reason,
    this.status = NoteStatus.draft,
    this.currencyCode = 'UGX',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DebitNote.fromJson(Map<String, dynamic> j) => DebitNote(
        id: j['id'] as String,
        debitNoteNumber: j['debit_note_number'] as String,
        vendorId: j['vendor_id'] as String,
        vendorName: j['vendor_name'] as String?,
        billId: j['bill_id'] as String?,
        billNumber: j['bill_number'] as String?,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        reason: j['reason'] as String,
        status: NoteStatus.values.firstWhere(
            (s) => s.name == j['status'], orElse: () => NoteStatus.draft),
        currencyCode: j['currency_code'] as String? ?? 'UGX',
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'debit_note_number': debitNoteNumber,
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'bill_id': billId,
        'bill_number': billNumber,
        'date': date.toIso8601String(),
        'amount': amount,
        'reason': reason,
        'status': status.name,
        'currency_code': currencyCode,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  DebitNote copyWith({
    NoteStatus? status,
    DateTime? updatedAt,
    String? notes,
  }) =>
      DebitNote(
        id: id,
        debitNoteNumber: debitNoteNumber,
        vendorId: vendorId,
        vendorName: vendorName,
        billId: billId,
        billNumber: billNumber,
        date: date,
        amount: amount,
        reason: reason,
        status: status ?? this.status,
        currencyCode: currencyCode,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
