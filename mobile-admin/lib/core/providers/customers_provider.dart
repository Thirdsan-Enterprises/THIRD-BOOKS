import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// State for customers list
class CustomersState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final String? searchQuery;

  const CustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Customer> get filteredCustomers {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return customers;
    }
    final query = searchQuery!.toLowerCase();
    return customers.where((c) =>
        c.name.toLowerCase().contains(query) ||
        c.code.toLowerCase().contains(query) ||
        (c.email?.toLowerCase().contains(query) ?? false) ||
        (c.phone?.toLowerCase().contains(query) ?? false)).toList();
  }

  List<Customer> get activeCustomers =>
      customers.where((c) => c.isActive).toList();
}

/// Provider for managing customers
class CustomersNotifier extends StateNotifier<CustomersState> {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  CustomersNotifier(this._db) : super(const CustomersState()) {
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final customers = await _db.getAllCustomers();
      state = state.copyWith(customers: customers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<String> generateNextCode() async {
    final customers = await _db.getAllCustomers();
    int maxNum = 0;
    for (final c in customers) {
      final match = RegExp(r'CUST-(\d+)').firstMatch(c.code);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'CUST-${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  Future<void> createCustomer({
    required String name,
    String? code,
    String? email,
    String? phone,
    String? address,
    String? city,
    String country = 'Uganda',
    String? taxId,
    String currencyCode = 'UGX',
    String paymentTerms = 'net_30',
    double creditLimit = 0.0,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final customerCode = code ?? await generateNextCode();

    await _db.insertCustomer(CustomersCompanion.insert(
      id: id,
      code: customerCode,
      name: name,
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      city: Value(city),
      country: Value(country),
      taxId: Value(taxId),
      currencyCode: Value(currencyCode),
      paymentTerms: Value(paymentTerms),
      creditLimit: Value(creditLimit),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ));

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'customer',
      aggregateId: id,
      eventType: 'customer_created',
      eventData: jsonEncode({
        'id': id,
        'code': customerCode,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'country': country,
        'tax_id': taxId,
        'currency_code': currencyCode,
        'payment_terms': paymentTerms,
        'credit_limit': creditLimit,
        'notes': notes,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadCustomers();
  }

  Future<void> updateCustomer(
    String id, {
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
    String? taxId,
    String? currencyCode,
    String? paymentTerms,
    double? creditLimit,
    String? notes,
    bool? isActive,
  }) async {
    final now = DateTime.now();

    await _db.updateCustomer(
      id,
      CustomersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        email: email != null ? Value(email) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        city: city != null ? Value(city) : const Value.absent(),
        country: country != null ? Value(country) : const Value.absent(),
        taxId: taxId != null ? Value(taxId) : const Value.absent(),
        currencyCode: currencyCode != null ? Value(currencyCode) : const Value.absent(),
        paymentTerms: paymentTerms != null ? Value(paymentTerms) : const Value.absent(),
        creditLimit: creditLimit != null ? Value(creditLimit) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'customer',
      aggregateId: id,
      eventType: 'customer_updated',
      eventData: jsonEncode({
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'country': country,
        'tax_id': taxId,
        'currency_code': currencyCode,
        'payment_terms': paymentTerms,
        'credit_limit': creditLimit,
        'notes': notes,
        'is_active': isActive,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await _db.deleteCustomer(id);

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'customer',
      aggregateId: id,
      eventType: 'customer_deleted',
      eventData: jsonEncode({'id': id}),
      deviceId: '',
      userId: '',
      occurredAt: DateTime.now(),
    ));

    await loadCustomers();
  }
}

/// Provider instance
final customersProvider = StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomersNotifier(db);
});

/// Provider for a single customer by ID
final customerByIdProvider = FutureProvider.family<Customer?, String>((ref, id) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getCustomerById(id);
});

/// Stream provider for watching customers
final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllCustomers();
});
