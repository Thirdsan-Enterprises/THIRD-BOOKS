import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// State for vendors list
class VendorsState {
  final List<Vendor> vendors;
  final bool isLoading;
  final String? error;
  final String? searchQuery;

  const VendorsState({
    this.vendors = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
  });

  VendorsState copyWith({
    List<Vendor>? vendors,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return VendorsState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Vendor> get filteredVendors {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return vendors;
    }
    final query = searchQuery!.toLowerCase();
    return vendors.where((v) =>
        v.name.toLowerCase().contains(query) ||
        v.code.toLowerCase().contains(query) ||
        (v.email?.toLowerCase().contains(query) ?? false) ||
        (v.phone?.toLowerCase().contains(query) ?? false)).toList();
  }

  List<Vendor> get activeVendors => vendors.where((v) => v.isActive).toList();
}

/// Provider for managing vendors
class VendorsNotifier extends StateNotifier<VendorsState> {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  VendorsNotifier(this._db) : super(const VendorsState()) {
    loadVendors();
  }

  Future<void> loadVendors() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final vendors = await _db.getAllVendors();
      state = state.copyWith(vendors: vendors, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<String> generateNextCode() async {
    final vendors = await _db.getAllVendors();
    int maxNum = 0;
    for (final v in vendors) {
      final match = RegExp(r'VEND-(\d+)').firstMatch(v.code);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'VEND-${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  Future<void> createVendor({
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
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final vendorCode = code ?? await generateNextCode();

    await _db.insertVendor(VendorsCompanion.insert(
      id: id,
      code: vendorCode,
      name: name,
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      city: Value(city),
      country: Value(country),
      taxId: Value(taxId),
      currencyCode: Value(currencyCode),
      paymentTerms: Value(paymentTerms),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ));

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'vendor',
      aggregateId: id,
      eventType: 'vendor_created',
      eventData: jsonEncode({
        'id': id,
        'code': vendorCode,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'country': country,
        'tax_id': taxId,
        'currency_code': currencyCode,
        'payment_terms': paymentTerms,
        'notes': notes,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadVendors();
  }

  Future<void> updateVendor(
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
    String? notes,
    bool? isActive,
  }) async {
    final now = DateTime.now();

    await _db.updateVendor(
      id,
      VendorsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        email: email != null ? Value(email) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        city: city != null ? Value(city) : const Value.absent(),
        country: country != null ? Value(country) : const Value.absent(),
        taxId: taxId != null ? Value(taxId) : const Value.absent(),
        currencyCode: currencyCode != null ? Value(currencyCode) : const Value.absent(),
        paymentTerms: paymentTerms != null ? Value(paymentTerms) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'vendor',
      aggregateId: id,
      eventType: 'vendor_updated',
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
        'notes': notes,
        'is_active': isActive,
      }),
      deviceId: '',
      userId: '',
      occurredAt: now,
    ));

    await loadVendors();
  }

  Future<void> deleteVendor(String id) async {
    await _db.deleteVendor(id);

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'vendor',
      aggregateId: id,
      eventType: 'vendor_deleted',
      eventData: jsonEncode({'id': id}),
      deviceId: '',
      userId: '',
      occurredAt: DateTime.now(),
    ));

    await loadVendors();
  }
}

/// Provider instance
final vendorsProvider = StateNotifierProvider<VendorsNotifier, VendorsState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return VendorsNotifier(db);
});

/// Provider for a single vendor by ID
final vendorByIdProvider = FutureProvider.family<Vendor?, String>((ref, id) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getVendorById(id);
});

/// Stream provider for watching vendors
final vendorsStreamProvider = StreamProvider<List<Vendor>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllVendors();
});
