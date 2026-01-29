import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Bill with items for display
class BillWithItems {
  final Bill bill;
  final List<BillItem> items;
  final Vendor? vendor;

  BillWithItems({
    required this.bill,
    required this.items,
    this.vendor,
  });
}

/// State for bills
class BillsState {
  final List<Bill> bills;
  final bool isLoading;
  final String? error;
  final String? statusFilter;
  final String? searchQuery;

  const BillsState({
    this.bills = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.searchQuery,
  });

  BillsState copyWith({
    List<Bill>? bills,
    bool? isLoading,
    String? error,
    String? statusFilter,
    String? searchQuery,
  }) {
    return BillsState(
      bills: bills ?? this.bills,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Bill> get filteredBills {
    var result = bills;

    if (statusFilter != null && statusFilter!.isNotEmpty) {
      result = result.where((b) => b.status == statusFilter).toList();
    }

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      result = result.where((b) =>
          b.billNumber.toLowerCase().contains(query) ||
          (b.vendorInvoiceNumber?.toLowerCase().contains(query) ?? false)).toList();
    }

    return result;
  }

  double get totalOutstanding =>
      bills.fold(0, (sum, bill) => sum + bill.balanceDue);

  int get overdueCount => bills
      .where((b) => b.status == 'overdue' ||
          (b.balanceDue > 0 && b.dueDate.isBefore(DateTime.now())))
      .length;
}

/// Provider for managing bills
class BillsNotifier extends StateNotifier<BillsState> {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  BillsNotifier(this._db) : super(const BillsState()) {
    loadBills();
  }

  Future<void> loadBills() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final bills = await _db.getAllBills();
      state = state.copyWith(bills: bills, isLoading: false);
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
    final bills = await _db.getAllBills();
    int maxNum = 0;
    for (final bill in bills) {
      final match = RegExp(r'BILL-(\d+)').firstMatch(bill.billNumber);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'BILL-${(maxNum + 1).toString().padLeft(5, '0')}';
  }

  Future<String> createBill({
    required String vendorId,
    required DateTime billDate,
    required DateTime dueDate,
    required List<Map<String, dynamic>> items,
    String? billNumber,
    String? vendorInvoiceNumber,
    String currencyCode = 'UGX',
    double exchangeRate = 1.0,
    String? notes,
    required String createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final number = billNumber ?? await generateNextNumber();

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

    // Insert bill
    await _db.insertBill(BillsCompanion.insert(
      id: id,
      billNumber: number,
      vendorId: vendorId,
      vendorInvoiceNumber: Value(vendorInvoiceNumber),
      billDate: billDate,
      dueDate: dueDate,
      currencyCode: Value(currencyCode),
      exchangeRate: Value(exchangeRate),
      subtotal: Value(subtotal),
      taxAmount: Value(taxAmount),
      discountAmount: Value(discountAmount),
      totalAmount: Value(totalAmount),
      balanceDue: Value(totalAmount),
      notes: Value(notes),
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

      await _db.insertBillItem(BillItemsCompanion.insert(
        id: itemId,
        billId: id,
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
      aggregateType: 'bill',
      aggregateId: id,
      eventType: 'bill_created',
      eventData: jsonEncode({
        'id': id,
        'bill_number': number,
        'vendor_id': vendorId,
        'vendor_invoice_number': vendorInvoiceNumber,
        'bill_date': billDate.toIso8601String(),
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

    await loadBills();
    return id;
  }

  Future<void> updateBillStatus(String id, String status) async {
    final now = DateTime.now();

    await _db.updateBill(id, BillsCompanion(
      status: Value(status),
      updatedAt: Value(now),
    ));

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'bill',
      aggregateId: id,
      eventType: 'bill_status_changed',
      eventData: jsonEncode({'id': id, 'status': status}),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadBills();
  }

  Future<void> recordPayment(String billId, double amount) async {
    final bill = await _db.getBillById(billId);
    if (bill == null) return;

    final now = DateTime.now();
    final newAmountPaid = bill.amountPaid + amount;
    final newBalanceDue = bill.totalAmount - newAmountPaid;
    final newStatus = newBalanceDue <= 0 ? 'paid' : 'partial';

    await _db.updateBill(billId, BillsCompanion(
      amountPaid: Value(newAmountPaid),
      balanceDue: Value(newBalanceDue),
      status: Value(newStatus),
      updatedAt: Value(now),
    ));

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'bill',
      aggregateId: billId,
      eventType: 'bill_payment_recorded',
      eventData: jsonEncode({
        'bill_id': billId,
        'amount': amount,
        'new_balance': newBalanceDue,
        'status': newStatus,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadBills();
  }

  Future<void> deleteBill(String id) async {
    await _db.deleteBill(id);

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'bill',
      aggregateId: id,
      eventType: 'bill_deleted',
      eventData: jsonEncode({'id': id}),
      deviceId: '',
      userId: '',
      occurredAt: DateTime.now(),
    ));

    await loadBills();
  }

  Future<BillWithItems?> getBillWithItems(String id) async {
    final bill = await _db.getBillById(id);
    if (bill == null) return null;

    final items = await _db.getBillItems(id);
    final vendor = await _db.getVendorById(bill.vendorId);

    return BillWithItems(
      bill: bill,
      items: items,
      vendor: vendor,
    );
  }
}

/// Provider instance
final billsProvider = StateNotifierProvider<BillsNotifier, BillsState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BillsNotifier(db);
});

/// Provider for a single bill with items
final billWithItemsProvider = FutureProvider.family<BillWithItems?, String>((ref, id) async {
  final notifier = ref.watch(billsProvider.notifier);
  return notifier.getBillWithItems(id);
});

/// Stream provider for watching bills
final billsStreamProvider = StreamProvider<List<Bill>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllBills();
});
