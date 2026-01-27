import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Invoice with items for display
class InvoiceWithItems {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final Customer? customer;

  InvoiceWithItems({
    required this.invoice,
    required this.items,
    this.customer,
  });
}

/// State for invoices
class InvoicesState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;
  final String? statusFilter;
  final String? searchQuery;

  const InvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.searchQuery,
  });

  InvoicesState copyWith({
    List<Invoice>? invoices,
    bool? isLoading,
    String? error,
    String? statusFilter,
    String? searchQuery,
  }) {
    return InvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Invoice> get filteredInvoices {
    var result = invoices;

    if (statusFilter != null && statusFilter!.isNotEmpty) {
      result = result.where((i) => i.status == statusFilter).toList();
    }

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      result = result.where((i) =>
          i.invoiceNumber.toLowerCase().contains(query)).toList();
    }

    return result;
  }

  double get totalOutstanding =>
      invoices.fold(0, (sum, inv) => sum + inv.balanceDue);

  int get overdueCount => invoices
      .where((i) => i.status == 'overdue' ||
          (i.balanceDue > 0 && i.dueDate.isBefore(DateTime.now())))
      .length;
}

/// Provider for managing invoices
class InvoicesNotifier extends StateNotifier<InvoicesState> {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  InvoicesNotifier(this._db) : super(const InvoicesState()) {
    loadInvoices();
  }

  Future<void> loadInvoices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final invoices = await _db.getAllInvoices();
      state = state.copyWith(invoices: invoices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<String> generateNextNumber() async {
    final invoices = await _db.getAllInvoices();
    int maxNum = 0;
    for (final inv in invoices) {
      final match = RegExp(r'INV-(\d+)').firstMatch(inv.invoiceNumber);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'INV-${(maxNum + 1).toString().padLeft(5, '0')}';
  }

  Future<String> createInvoice({
    required String customerId,
    required DateTime invoiceDate,
    required DateTime dueDate,
    required List<Map<String, dynamic>> items,
    String? invoiceNumber,
    String currencyCode = 'UGX',
    double exchangeRate = 1.0,
    String? notes,
    String? terms,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final number = invoiceNumber ?? await generateNextNumber();

    // Calculate totals
    double subtotal = 0;
    double taxAmount = 0;
    double discountAmount = 0;

    for (final item in items) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final discountPct = (item['discount_percent'] as num?)?.toDouble() ?? 0.0;
      final taxPct = (item['tax_percent'] as num?)?.toDouble() ?? 0.0;

      final lineSubtotal = qty * price;
      final lineDiscount = lineSubtotal * discountPct / 100;
      final lineTaxable = lineSubtotal - lineDiscount;
      final lineTax = lineTaxable * taxPct / 100;

      subtotal += lineSubtotal;
      discountAmount += lineDiscount;
      taxAmount += lineTax;
    }

    final totalAmount = subtotal - discountAmount + taxAmount;

    // Insert invoice
    await _db.insertInvoice(InvoicesCompanion.insert(
      id: id,
      invoiceNumber: number,
      customerId: customerId,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      currencyCode: Value(currencyCode),
      exchangeRate: Value(exchangeRate),
      subtotal: Value(subtotal),
      taxAmount: Value(taxAmount),
      discountAmount: Value(discountAmount),
      totalAmount: Value(totalAmount),
      balanceDue: Value(totalAmount),
      notes: Value(notes),
      terms: Value(terms),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    ));

    // Insert line items
    int lineOrder = 0;
    for (final item in items) {
      final itemId = _uuid.v4();
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final discountPct = (item['discount_percent'] as num?)?.toDouble() ?? 0.0;
      final taxPct = (item['tax_percent'] as num?)?.toDouble() ?? 0.0;

      final lineSubtotal = qty * price;
      final lineDiscount = lineSubtotal * discountPct / 100;
      final lineTaxable = lineSubtotal - lineDiscount;
      final lineTax = lineTaxable * taxPct / 100;
      final lineTotal = lineTaxable + lineTax;

      await _db.insertInvoiceItem(InvoiceItemsCompanion.insert(
        id: itemId,
        invoiceId: id,
        description: item['description'] as String,
        accountId: Value(item['account_id'] as String?),
        quantity: Value(qty),
        unitOfMeasure: Value(item['unit_of_measure'] as String?),
        unitPrice: Value(price),
        discountPercent: Value(discountPct),
        taxPercent: Value(taxPct),
        taxAmount: Value(lineTax),
        lineTotal: Value(lineTotal),
        lineOrder: Value(lineOrder++),
        createdAt: now,
        updatedAt: now,
      ));
    }

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'invoice',
      aggregateId: id,
      eventType: 'invoice_created',
      eventData: jsonEncode({
        'id': id,
        'invoice_number': number,
        'customer_id': customerId,
        'invoice_date': invoiceDate.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'currency_code': currencyCode,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'discount_amount': discountAmount,
        'total_amount': totalAmount,
        'items': items,
      }),
      deviceId: '',
      userId: createdBy,
      occurredAt: now,
    ));

    await loadInvoices();
    return id;
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    final now = DateTime.now();

    await _db.updateInvoice(id, InvoicesCompanion(
      status: Value(status),
      updatedAt: Value(now),
    ));

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'invoice',
      aggregateId: id,
      eventType: 'invoice_status_changed',
      eventData: jsonEncode({'id': id, 'status': status}),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadInvoices();
  }

  Future<void> recordPayment(String invoiceId, double amount) async {
    final invoice = await _db.getInvoiceById(invoiceId);
    if (invoice == null) return;

    final now = DateTime.now();
    final newAmountPaid = invoice.amountPaid + amount;
    final newBalanceDue = invoice.totalAmount - newAmountPaid;
    final newStatus = newBalanceDue <= 0 ? 'paid' : 'partial';

    await _db.updateInvoice(invoiceId, InvoicesCompanion(
      amountPaid: Value(newAmountPaid),
      balanceDue: Value(newBalanceDue),
      status: Value(newStatus),
      updatedAt: Value(now),
    ));

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'invoice',
      aggregateId: invoiceId,
      eventType: 'invoice_payment_recorded',
      eventData: jsonEncode({
        'invoice_id': invoiceId,
        'amount': amount,
        'new_balance': newBalanceDue,
        'status': newStatus,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadInvoices();
  }

  Future<void> deleteInvoice(String id) async {
    await _db.deleteInvoice(id);

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'invoice',
      aggregateId: id,
      eventType: 'invoice_deleted',
      eventData: jsonEncode({'id': id}),
      deviceId: '',
      userId: '',
      occurredAt: DateTime.now(),
    ));

    await loadInvoices();
  }

  Future<InvoiceWithItems?> getInvoiceWithItems(String id) async {
    final invoice = await _db.getInvoiceById(id);
    if (invoice == null) return null;

    final items = await _db.getInvoiceItems(id);
    final customer = await _db.getCustomerById(invoice.customerId);

    return InvoiceWithItems(
      invoice: invoice,
      items: items,
      customer: customer,
    );
  }
}

/// Provider instance
final invoicesProvider = StateNotifierProvider<InvoicesNotifier, InvoicesState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InvoicesNotifier(db);
});

/// Provider for a single invoice with items
final invoiceWithItemsProvider = FutureProvider.family<InvoiceWithItems?, String>((ref, id) async {
  final notifier = ref.watch(invoicesProvider.notifier);
  return notifier.getInvoiceWithItems(id);
});

/// Stream provider for watching invoices
final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllInvoices();
});
