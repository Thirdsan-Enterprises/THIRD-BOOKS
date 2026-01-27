import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ============================================================================
// SYNC & EVENT SOURCING TABLES
// ============================================================================

/// Events table for local event sourcing - tracks all local changes
class LocalEvents extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get eventType => text()();
  TextColumn get eventData => text()(); // JSON string
  TextColumn get metadata => text().nullable()(); // JSON string
  IntColumn get sequenceNumber => integer().nullable()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// ACCOUNTING CORE TABLES
// ============================================================================

/// Account types - Asset, Liability, Equity, Revenue, Expense
class AccountTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalBalance => text()(); // 'debit' or 'credit'
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chart of Accounts
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get accountTypeId => text()();
  TextColumn get parentAccountId => text().nullable()();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSystemAccount => boolean().withDefault(const Constant(false))();
  BoolColumn get allowDirectPosting => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Journal Entries (headers)
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entryNumber => text()();
  DateTimeColumn get entryDate => dateTime()();
  TextColumn get reference => text().nullable()();
  TextColumn get description => text()();
  TextColumn get sourceType => text().nullable()(); // 'invoice', 'bill', 'manual', etc.
  TextColumn get sourceId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, posted, void
  RealColumn get totalDebit => real().withDefault(const Constant(0.0))();
  RealColumn get totalCredit => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  DateTimeColumn get postedAt => dateTime().nullable()();
  TextColumn get postedBy => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Journal Entry Lines (details)
class JournalEntryLines extends Table {
  TextColumn get id => text()();
  TextColumn get journalEntryId => text()();
  TextColumn get accountId => text()();
  TextColumn get description => text().nullable()();
  RealColumn get debitAmount => real().withDefault(const Constant(0.0))();
  RealColumn get creditAmount => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  IntColumn get lineOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// General Ledger - stores posted transactions
class GeneralLedger extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get journalEntryId => text()();
  TextColumn get journalEntryLineId => text()();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get description => text().nullable()();
  RealColumn get debitAmount => real().withDefault(const Constant(0.0))();
  RealColumn get creditAmount => real().withDefault(const Constant(0.0))();
  RealColumn get runningBalance => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// BUSINESS PARTNER TABLES
// ============================================================================

/// Customers
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().withDefault(const Constant('Uganda'))();
  TextColumn get taxId => text().nullable()(); // TIN number
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  TextColumn get paymentTerms => text().withDefault(const Constant('net_30'))();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Vendors/Suppliers
class Vendors extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().withDefault(const Constant('Uganda'))();
  TextColumn get taxId => text().nullable()(); // TIN number
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  TextColumn get paymentTerms => text().withDefault(const Constant('net_30'))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// SALES TABLES
// ============================================================================

/// Invoices (headers)
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get customerId => text()();
  DateTimeColumn get invoiceDate => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, sent, paid, partial, overdue, void
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  RealColumn get balanceDue => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  TextColumn get terms => text().nullable()();
  TextColumn get journalEntryId => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Invoice Items (line items)
class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get description => text()();
  TextColumn get accountId => text().nullable()(); // Revenue account
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unitOfMeasure => text().nullable()();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0.0))();
  IntColumn get lineOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PURCHASES TABLES
// ============================================================================

/// Bills (vendor invoices)
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get billNumber => text()();
  TextColumn get vendorId => text()();
  TextColumn get vendorInvoiceNumber => text().nullable()();
  DateTimeColumn get billDate => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, approved, paid, partial, overdue, void
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  RealColumn get balanceDue => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  TextColumn get journalEntryId => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Items (line items)
class BillItems extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get description => text()();
  TextColumn get accountId => text().nullable()(); // Expense account
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unitOfMeasure => text().nullable()();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0.0))();
  IntColumn get lineOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PAYMENT TABLES
// ============================================================================

/// Payments (both received and made)
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get paymentNumber => text()();
  TextColumn get paymentType => text()(); // 'received' or 'made'
  TextColumn get customerId => text().nullable()();
  TextColumn get vendorId => text().nullable()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get paymentMethod => text()(); // cash, bank_transfer, mobile_money, cheque, etc.
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get bankAccountId => text().nullable()(); // Bank/cash account
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get journalEntryId => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Payment Allocations - links payments to invoices/bills
class PaymentAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get paymentId => text()();
  TextColumn get invoiceId => text().nullable()();
  TextColumn get billId => text().nullable()();
  RealColumn get allocatedAmount => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// REFERENCE DATA TABLES
// ============================================================================

/// Currencies
class Currencies extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get symbol => text()();
  IntColumn get decimalPlaces => integer().withDefault(const Constant(2))();
  BoolColumn get isBaseCurrency => boolean().withDefault(const Constant(false))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Tax Rates
class TaxRates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  RealColumn get rate => real()();
  TextColumn get taxType => text().withDefault(const Constant('vat'))(); // vat, withholding, etc.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fiscal Years
class FiscalYears extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// SETTINGS & CONFIG TABLES
// ============================================================================

/// App Settings (local)
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Tenant Settings (synced)
class TenantSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get dataType => text().withDefault(const Constant('string'))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

// ============================================================================
// CACHE TABLES (for offline access)
// ============================================================================

/// Cached Dashboard Stats
class CachedDashboardStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get data => text()(); // JSON string
  DateTimeColumn get cachedAt => dateTime()();
}

// ============================================================================
// DATABASE CLASS
// ============================================================================

@DriftDatabase(tables: [
  // Sync & Events
  LocalEvents,
  // Accounting Core
  AccountTypes,
  Accounts,
  JournalEntries,
  JournalEntryLines,
  GeneralLedger,
  // Business Partners
  Customers,
  Vendors,
  // Sales
  Invoices,
  InvoiceItems,
  // Purchases
  Bills,
  BillItems,
  // Payments
  Payments,
  PaymentAllocations,
  // Reference Data
  Currencies,
  TaxRates,
  FiscalYears,
  // Settings
  AppSettings,
  TenantSettings,
  // Cache
  CachedDashboardStats,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedInitialData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Migration from version 1 to 2
          await m.createAll();
        }
      },
    );
  }

  /// Seed initial data (account types, currencies, etc.)
  Future<void> _seedInitialData() async {
    final now = DateTime.now();

    // Seed account types
    final accountTypesList = [
      AccountTypesCompanion.insert(
        id: 'asset',
        name: 'Asset',
        normalBalance: 'debit',
        displayOrder: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
      AccountTypesCompanion.insert(
        id: 'liability',
        name: 'Liability',
        normalBalance: 'credit',
        displayOrder: const Value(2),
        createdAt: now,
        updatedAt: now,
      ),
      AccountTypesCompanion.insert(
        id: 'equity',
        name: 'Equity',
        normalBalance: 'credit',
        displayOrder: const Value(3),
        createdAt: now,
        updatedAt: now,
      ),
      AccountTypesCompanion.insert(
        id: 'revenue',
        name: 'Revenue',
        normalBalance: 'credit',
        displayOrder: const Value(4),
        createdAt: now,
        updatedAt: now,
      ),
      AccountTypesCompanion.insert(
        id: 'expense',
        name: 'Expense',
        normalBalance: 'debit',
        displayOrder: const Value(5),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final type in accountTypesList) {
      await into(accountTypes).insertOnConflictUpdate(type);
    }

    // Seed currencies
    final currenciesList = [
      CurrenciesCompanion.insert(
        code: 'UGX',
        name: 'Ugandan Shilling',
        symbol: 'UGX',
        decimalPlaces: const Value(0),
        isBaseCurrency: const Value(true),
        exchangeRate: const Value(1.0),
        isActive: const Value(true),
        updatedAt: now,
      ),
      CurrenciesCompanion.insert(
        code: 'USD',
        name: 'US Dollar',
        symbol: '\$',
        decimalPlaces: const Value(2),
        isBaseCurrency: const Value(false),
        exchangeRate: const Value(3750.0),
        isActive: const Value(true),
        updatedAt: now,
      ),
      CurrenciesCompanion.insert(
        code: 'EUR',
        name: 'Euro',
        symbol: '€',
        decimalPlaces: const Value(2),
        isBaseCurrency: const Value(false),
        exchangeRate: const Value(4100.0),
        isActive: const Value(true),
        updatedAt: now,
      ),
      CurrenciesCompanion.insert(
        code: 'KES',
        name: 'Kenyan Shilling',
        symbol: 'KES',
        decimalPlaces: const Value(2),
        isBaseCurrency: const Value(false),
        exchangeRate: const Value(29.0),
        isActive: const Value(true),
        updatedAt: now,
      ),
    ];

    for (final currency in currenciesList) {
      await into(currencies).insertOnConflictUpdate(currency);
    }

    // Seed default tax rates (Uganda VAT)
    final taxRatesList = [
      TaxRatesCompanion.insert(
        id: 'vat_18',
        name: 'VAT 18%',
        code: 'VAT',
        rate: 18.0,
        taxType: const Value('vat'),
        isDefault: const Value(true),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      TaxRatesCompanion.insert(
        id: 'vat_0',
        name: 'VAT Exempt',
        code: 'VAT0',
        rate: 0.0,
        taxType: const Value('vat'),
        isDefault: const Value(false),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      TaxRatesCompanion.insert(
        id: 'wht_6',
        name: 'Withholding Tax 6%',
        code: 'WHT',
        rate: 6.0,
        taxType: const Value('withholding'),
        isDefault: const Value(false),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final taxRate in taxRatesList) {
      await into(taxRates).insertOnConflictUpdate(taxRate);
    }
  }

  // ============================================================================
  // EVENT OPERATIONS
  // ============================================================================

  Future<void> insertLocalEvent(LocalEventsCompanion event) async {
    await into(localEvents).insert(event);
  }

  Future<List<LocalEvent>> getPendingEvents() async {
    return (select(localEvents)..where((e) => e.isSynced.equals(false))).get();
  }

  Future<int> getPendingEventsCount() async {
    final count = await (select(localEvents)
          ..where((e) => e.isSynced.equals(false)))
        .get();
    return count.length;
  }

  Future<void> markEventAsSynced(String eventId) async {
    await (update(localEvents)..where((e) => e.id.equals(eventId))).write(
      LocalEventsCompanion(
        isSynced: const Value(true),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> insertDownloadedEvent(Map<String, dynamic> eventData) async {
    final existing = await (select(localEvents)
          ..where((e) => e.id.equals(eventData['id'] as String)))
        .getSingleOrNull();

    if (existing == null) {
      await into(localEvents).insert(
        LocalEventsCompanion.insert(
          id: eventData['id'] as String,
          tenantId: eventData['tenant_id'] as String,
          aggregateType: eventData['aggregate_type'] as String,
          aggregateId: eventData['aggregate_id'] as String,
          eventType: eventData['event_type'] as String,
          eventData: eventData['event_data'].toString(),
          metadata: Value(eventData['metadata']?.toString()),
          sequenceNumber: Value(eventData['sequence_number'] as int?),
          deviceId: eventData['device_id'] as String? ?? '',
          userId: eventData['user_id'] as String,
          occurredAt: DateTime.parse(eventData['occurred_at'] as String),
          syncedAt: Value(DateTime.now()),
          isSynced: const Value(true),
        ),
      );
    }
  }

  // ============================================================================
  // ACCOUNT OPERATIONS
  // ============================================================================

  Future<List<Account>> getAllAccounts() async {
    return (select(accounts)..orderBy([(a) => OrderingTerm.asc(a.code)])).get();
  }

  Future<List<Account>> getActiveAccounts() async {
    return (select(accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm.asc(a.code)]))
        .get();
  }

  Future<List<Account>> getAccountsByType(String typeId) async {
    return (select(accounts)
          ..where((a) => a.accountTypeId.equals(typeId) & a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm.asc(a.code)]))
        .get();
  }

  Future<Account?> getAccountById(String id) async {
    return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  Future<Account?> getAccountByCode(String code) async {
    return (select(accounts)..where((a) => a.code.equals(code))).getSingleOrNull();
  }

  Future<void> insertAccount(AccountsCompanion account) async {
    await into(accounts).insert(account);
  }

  Future<void> updateAccount(String id, AccountsCompanion account) async {
    await (update(accounts)..where((a) => a.id.equals(id))).write(account);
  }

  Future<void> deleteAccount(String id) async {
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
  }

  Stream<List<Account>> watchAllAccounts() {
    return (select(accounts)..orderBy([(a) => OrderingTerm.asc(a.code)])).watch();
  }

  // ============================================================================
  // ACCOUNT TYPE OPERATIONS
  // ============================================================================

  Future<List<AccountType>> getAllAccountTypes() async {
    return (select(accountTypes)..orderBy([(t) => OrderingTerm.asc(t.displayOrder)])).get();
  }

  Future<AccountType?> getAccountTypeById(String id) async {
    return (select(accountTypes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ============================================================================
  // CUSTOMER OPERATIONS
  // ============================================================================

  Future<List<Customer>> getAllCustomers() async {
    return (select(customers)..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  Future<List<Customer>> getActiveCustomers() async {
    return (select(customers)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<Customer?> getCustomerById(String id) async {
    return (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertCustomer(CustomersCompanion customer) async {
    await into(customers).insert(customer);
  }

  Future<void> updateCustomer(String id, CustomersCompanion customer) async {
    await (update(customers)..where((c) => c.id.equals(id))).write(customer);
  }

  Future<void> deleteCustomer(String id) async {
    await (delete(customers)..where((c) => c.id.equals(id))).go();
  }

  Stream<List<Customer>> watchAllCustomers() {
    return (select(customers)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  }

  // ============================================================================
  // VENDOR OPERATIONS
  // ============================================================================

  Future<List<Vendor>> getAllVendors() async {
    return (select(vendors)..orderBy([(v) => OrderingTerm.asc(v.name)])).get();
  }

  Future<List<Vendor>> getActiveVendors() async {
    return (select(vendors)
          ..where((v) => v.isActive.equals(true))
          ..orderBy([(v) => OrderingTerm.asc(v.name)]))
        .get();
  }

  Future<Vendor?> getVendorById(String id) async {
    return (select(vendors)..where((v) => v.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertVendor(VendorsCompanion vendor) async {
    await into(vendors).insert(vendor);
  }

  Future<void> updateVendor(String id, VendorsCompanion vendor) async {
    await (update(vendors)..where((v) => v.id.equals(id))).write(vendor);
  }

  Future<void> deleteVendor(String id) async {
    await (delete(vendors)..where((v) => v.id.equals(id))).go();
  }

  Stream<List<Vendor>> watchAllVendors() {
    return (select(vendors)..orderBy([(v) => OrderingTerm.asc(v.name)])).watch();
  }

  // ============================================================================
  // INVOICE OPERATIONS
  // ============================================================================

  Future<List<Invoice>> getAllInvoices() async {
    return (select(invoices)..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)])).get();
  }

  Future<List<Invoice>> getInvoicesByStatus(String status) async {
    return (select(invoices)
          ..where((i) => i.status.equals(status))
          ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
        .get();
  }

  Future<List<Invoice>> getInvoicesByCustomer(String customerId) async {
    return (select(invoices)
          ..where((i) => i.customerId.equals(customerId))
          ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
        .get();
  }

  Future<Invoice?> getInvoiceById(String id) async {
    return (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertInvoice(InvoicesCompanion invoice) async {
    await into(invoices).insert(invoice);
  }

  Future<void> updateInvoice(String id, InvoicesCompanion invoice) async {
    await (update(invoices)..where((i) => i.id.equals(id))).write(invoice);
  }

  Future<void> deleteInvoice(String id) async {
    // Delete items first
    await (delete(invoiceItems)..where((i) => i.invoiceId.equals(id))).go();
    await (delete(invoices)..where((i) => i.id.equals(id))).go();
  }

  Stream<List<Invoice>> watchAllInvoices() {
    return (select(invoices)..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)])).watch();
  }

  // Invoice Items
  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    return (select(invoiceItems)
          ..where((i) => i.invoiceId.equals(invoiceId))
          ..orderBy([(i) => OrderingTerm.asc(i.lineOrder)]))
        .get();
  }

  Future<void> insertInvoiceItem(InvoiceItemsCompanion item) async {
    await into(invoiceItems).insert(item);
  }

  Future<void> updateInvoiceItem(String id, InvoiceItemsCompanion item) async {
    await (update(invoiceItems)..where((i) => i.id.equals(id))).write(item);
  }

  Future<void> deleteInvoiceItem(String id) async {
    await (delete(invoiceItems)..where((i) => i.id.equals(id))).go();
  }

  // ============================================================================
  // BILL OPERATIONS
  // ============================================================================

  Future<List<Bill>> getAllBills() async {
    return (select(bills)..orderBy([(b) => OrderingTerm.desc(b.billDate)])).get();
  }

  Future<List<Bill>> getBillsByStatus(String status) async {
    return (select(bills)
          ..where((b) => b.status.equals(status))
          ..orderBy([(b) => OrderingTerm.desc(b.billDate)]))
        .get();
  }

  Future<List<Bill>> getBillsByVendor(String vendorId) async {
    return (select(bills)
          ..where((b) => b.vendorId.equals(vendorId))
          ..orderBy([(b) => OrderingTerm.desc(b.billDate)]))
        .get();
  }

  Future<Bill?> getBillById(String id) async {
    return (select(bills)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertBill(BillsCompanion bill) async {
    await into(bills).insert(bill);
  }

  Future<void> updateBill(String id, BillsCompanion bill) async {
    await (update(bills)..where((b) => b.id.equals(id))).write(bill);
  }

  Future<void> deleteBill(String id) async {
    // Delete items first
    await (delete(billItems)..where((i) => i.billId.equals(id))).go();
    await (delete(bills)..where((b) => b.id.equals(id))).go();
  }

  Stream<List<Bill>> watchAllBills() {
    return (select(bills)..orderBy([(b) => OrderingTerm.desc(b.billDate)])).watch();
  }

  // Bill Items
  Future<List<BillItem>> getBillItems(String billId) async {
    return (select(billItems)
          ..where((i) => i.billId.equals(billId))
          ..orderBy([(i) => OrderingTerm.asc(i.lineOrder)]))
        .get();
  }

  Future<void> insertBillItem(BillItemsCompanion item) async {
    await into(billItems).insert(item);
  }

  Future<void> updateBillItem(String id, BillItemsCompanion item) async {
    await (update(billItems)..where((i) => i.id.equals(id))).write(item);
  }

  Future<void> deleteBillItem(String id) async {
    await (delete(billItems)..where((i) => i.id.equals(id))).go();
  }

  // ============================================================================
  // JOURNAL ENTRY OPERATIONS
  // ============================================================================

  Future<List<JournalEntry>> getAllJournalEntries() async {
    return (select(journalEntries)..orderBy([(j) => OrderingTerm.desc(j.entryDate)])).get();
  }

  Future<List<JournalEntry>> getJournalEntriesByStatus(String status) async {
    return (select(journalEntries)
          ..where((j) => j.status.equals(status))
          ..orderBy([(j) => OrderingTerm.desc(j.entryDate)]))
        .get();
  }

  Future<JournalEntry?> getJournalEntryById(String id) async {
    return (select(journalEntries)..where((j) => j.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertJournalEntry(JournalEntriesCompanion entry) async {
    await into(journalEntries).insert(entry);
  }

  Future<void> updateJournalEntry(String id, JournalEntriesCompanion entry) async {
    await (update(journalEntries)..where((j) => j.id.equals(id))).write(entry);
  }

  Future<void> deleteJournalEntry(String id) async {
    // Delete lines first
    await (delete(journalEntryLines)..where((l) => l.journalEntryId.equals(id))).go();
    await (delete(journalEntries)..where((j) => j.id.equals(id))).go();
  }

  Stream<List<JournalEntry>> watchAllJournalEntries() {
    return (select(journalEntries)..orderBy([(j) => OrderingTerm.desc(j.entryDate)])).watch();
  }

  // Journal Entry Lines
  Future<List<JournalEntryLine>> getJournalEntryLines(String journalEntryId) async {
    return (select(journalEntryLines)
          ..where((l) => l.journalEntryId.equals(journalEntryId))
          ..orderBy([(l) => OrderingTerm.asc(l.lineOrder)]))
        .get();
  }

  Future<void> insertJournalEntryLine(JournalEntryLinesCompanion line) async {
    await into(journalEntryLines).insert(line);
  }

  Future<void> updateJournalEntryLine(String id, JournalEntryLinesCompanion line) async {
    await (update(journalEntryLines)..where((l) => l.id.equals(id))).write(line);
  }

  Future<void> deleteJournalEntryLine(String id) async {
    await (delete(journalEntryLines)..where((l) => l.id.equals(id))).go();
  }

  // ============================================================================
  // PAYMENT OPERATIONS
  // ============================================================================

  Future<List<Payment>> getAllPayments() async {
    return (select(payments)..orderBy([(p) => OrderingTerm.desc(p.paymentDate)])).get();
  }

  Future<List<Payment>> getPaymentsByType(String type) async {
    return (select(payments)
          ..where((p) => p.paymentType.equals(type))
          ..orderBy([(p) => OrderingTerm.desc(p.paymentDate)]))
        .get();
  }

  Future<Payment?> getPaymentById(String id) async {
    return (select(payments)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertPayment(PaymentsCompanion payment) async {
    await into(payments).insert(payment);
  }

  Future<void> updatePayment(String id, PaymentsCompanion payment) async {
    await (update(payments)..where((p) => p.id.equals(id))).write(payment);
  }

  Future<void> deletePayment(String id) async {
    // Delete allocations first
    await (delete(paymentAllocations)..where((a) => a.paymentId.equals(id))).go();
    await (delete(payments)..where((p) => p.id.equals(id))).go();
  }

  // ============================================================================
  // GENERAL LEDGER OPERATIONS
  // ============================================================================

  Future<List<GeneralLedgerData>> getGeneralLedgerByAccount(String accountId) async {
    return (select(generalLedger)
          ..where((g) => g.accountId.equals(accountId))
          ..orderBy([(g) => OrderingTerm.asc(g.transactionDate)]))
        .get();
  }

  Future<List<GeneralLedgerData>> getGeneralLedgerByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return (select(generalLedger)
          ..where((g) =>
              g.transactionDate.isBiggerOrEqualValue(startDate) &
              g.transactionDate.isSmallerOrEqualValue(endDate))
          ..orderBy([(g) => OrderingTerm.asc(g.transactionDate)]))
        .get();
  }

  Future<void> insertGeneralLedgerEntry(GeneralLedgerCompanion entry) async {
    await into(generalLedger).insert(entry);
  }

  // ============================================================================
  // CURRENCY OPERATIONS
  // ============================================================================

  Future<List<Currency>> getAllCurrencies() async {
    return (select(currencies)..where((c) => c.isActive.equals(true))).get();
  }

  Future<Currency?> getBaseCurrency() async {
    return (select(currencies)..where((c) => c.isBaseCurrency.equals(true))).getSingleOrNull();
  }

  Future<Currency?> getCurrencyByCode(String code) async {
    return (select(currencies)..where((c) => c.code.equals(code))).getSingleOrNull();
  }

  Future<void> updateCurrencyRate(String code, double rate) async {
    await (update(currencies)..where((c) => c.code.equals(code))).write(
      CurrenciesCompanion(
        exchangeRate: Value(rate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ============================================================================
  // TAX RATE OPERATIONS
  // ============================================================================

  Future<List<TaxRate>> getAllTaxRates() async {
    return (select(taxRates)..where((t) => t.isActive.equals(true))).get();
  }

  Future<TaxRate?> getDefaultTaxRate() async {
    return (select(taxRates)
          ..where((t) => t.isDefault.equals(true) & t.isActive.equals(true)))
        .getSingleOrNull();
  }

  // ============================================================================
  // FISCAL YEAR OPERATIONS
  // ============================================================================

  Future<List<FiscalYear>> getAllFiscalYears() async {
    return (select(fiscalYears)..orderBy([(f) => OrderingTerm.desc(f.startDate)])).get();
  }

  Future<FiscalYear?> getCurrentFiscalYear() async {
    return (select(fiscalYears)..where((f) => f.isCurrent.equals(true))).getSingleOrNull();
  }

  // ============================================================================
  // SETTINGS OPERATIONS
  // ============================================================================

  Future<String?> getAppSetting(String key) async {
    final setting = await (select(appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return setting?.value;
  }

  Future<void> setAppSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String?> getTenantSetting(String key) async {
    final setting =
        await (select(tenantSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return setting?.value;
  }

  Future<void> setTenantSetting(String key, String value, {String dataType = 'string'}) async {
    await into(tenantSettings).insertOnConflictUpdate(
      TenantSettingsCompanion.insert(
        key: key,
        value: value,
        dataType: Value(dataType),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ============================================================================
  // CACHE OPERATIONS
  // ============================================================================

  Future<void> cacheDashboardStats(Map<String, dynamic> data) async {
    await delete(cachedDashboardStats).go();
    await into(cachedDashboardStats).insert(
      CachedDashboardStatsCompanion.insert(
        data: jsonEncode(data),
        cachedAt: DateTime.now(),
      ),
    );
  }

  Future<CachedDashboardStat?> getCachedDashboardStats() async {
    return (select(cachedDashboardStats)
          ..orderBy([(t) => OrderingTerm.desc(t.cachedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ============================================================================
  // CLEAR OPERATIONS
  // ============================================================================

  Future<void> clearAllCache() async {
    await delete(cachedDashboardStats).go();
  }

  Future<void> clearAllEvents() async {
    await delete(localEvents).go();
  }

  Future<void> clearAllData() async {
    await delete(localEvents).go();
    await delete(accounts).go();
    await delete(customers).go();
    await delete(vendors).go();
    await delete(invoices).go();
    await delete(invoiceItems).go();
    await delete(bills).go();
    await delete(billItems).go();
    await delete(journalEntries).go();
    await delete(journalEntryLines).go();
    await delete(generalLedger).go();
    await delete(payments).go();
    await delete(paymentAllocations).go();
    await delete(cachedDashboardStats).go();
    await delete(tenantSettings).go();
  }

  // ============================================================================
  // REPORTING QUERIES
  // ============================================================================

  /// Get trial balance data
  Future<List<Map<String, dynamic>>> getTrialBalance() async {
    final accountsList = await getAllAccounts();
    final types = await getAllAccountTypes();

    final typeMap = {for (var t in types) t.id: t};

    return accountsList.map((account) {
      final type = typeMap[account.accountTypeId];
      final isDebitNormal = type?.normalBalance == 'debit';
      final balance = account.currentBalance;

      return {
        'account_id': account.id,
        'account_code': account.code,
        'account_name': account.name,
        'account_type': account.accountTypeId,
        'debit_balance': isDebitNormal && balance > 0 ? balance : (isDebitNormal ? 0.0 : -balance),
        'credit_balance': !isDebitNormal && balance > 0 ? balance : (!isDebitNormal ? 0.0 : -balance),
      };
    }).toList();
  }

  /// Get income statement data for a period
  Future<Map<String, dynamic>> getIncomeStatement(DateTime startDate, DateTime endDate) async {
    // Get revenue accounts
    final revenueAccounts = await getAccountsByType('revenue');
    final expenseAccounts = await getAccountsByType('expense');

    double totalRevenue = 0;
    double totalExpenses = 0;

    for (final account in revenueAccounts) {
      totalRevenue += account.currentBalance;
    }

    for (final account in expenseAccounts) {
      totalExpenses += account.currentBalance;
    }

    return {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_revenue': totalRevenue,
      'total_expenses': totalExpenses,
      'net_income': totalRevenue - totalExpenses,
      'revenue_accounts': revenueAccounts.map((a) => {
            'code': a.code,
            'name': a.name,
            'balance': a.currentBalance,
          }).toList(),
      'expense_accounts': expenseAccounts.map((a) => {
            'code': a.code,
            'name': a.name,
            'balance': a.currentBalance,
          }).toList(),
    };
  }

  /// Get balance sheet data
  Future<Map<String, dynamic>> getBalanceSheet() async {
    final assetAccounts = await getAccountsByType('asset');
    final liabilityAccounts = await getAccountsByType('liability');
    final equityAccounts = await getAccountsByType('equity');

    double totalAssets = 0;
    double totalLiabilities = 0;
    double totalEquity = 0;

    for (final account in assetAccounts) {
      totalAssets += account.currentBalance;
    }

    for (final account in liabilityAccounts) {
      totalLiabilities += account.currentBalance;
    }

    for (final account in equityAccounts) {
      totalEquity += account.currentBalance;
    }

    return {
      'as_of_date': DateTime.now().toIso8601String(),
      'total_assets': totalAssets,
      'total_liabilities': totalLiabilities,
      'total_equity': totalEquity,
      'assets': assetAccounts.map((a) => {
            'code': a.code,
            'name': a.name,
            'balance': a.currentBalance,
          }).toList(),
      'liabilities': liabilityAccounts.map((a) => {
            'code': a.code,
            'name': a.name,
            'balance': a.currentBalance,
          }).toList(),
      'equity': equityAccounts.map((a) => {
            'code': a.code,
            'name': a.name,
            'balance': a.currentBalance,
          }).toList(),
    };
  }
}

// ============================================================================
// DATABASE CONNECTION
// ============================================================================

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'thirdbooks_app.db'));
    return NativeDatabase(file);
  });
}

// ============================================================================
// PROVIDERS
// ============================================================================

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// ============================================================================
// EXTENSIONS
// ============================================================================

extension LocalEventX on LocalEvent {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'event_type': eventType,
      'event_data': eventData,
      'metadata': metadata,
      'sequence_number': sequenceNumber,
      'device_id': deviceId,
      'user_id': userId,
      'occurred_at': occurredAt.toIso8601String(),
    };
  }
}
