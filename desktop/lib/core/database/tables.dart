import 'package:drift/drift.dart';

// Accounts table for Chart of Accounts
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().withLength(min: 1, max: 20)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()(); // asset, liability, equity, revenue, expense
  TextColumn get subType => text().nullable()();
  TextColumn get parentId => text().nullable().references(Accounts, #id)();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSystemAccount => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncSequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Customers table
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxId => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  TextColumn get paymentTerms => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncSequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Vendors table
class Vendors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxId => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  TextColumn get paymentTerms => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get bankAccountNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncSequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Journal Entries table
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entryNumber => text().withLength(min: 1, max: 50)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, pending, posted, voided
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncSequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Journal Lines table
class JournalLines extends Table {
  TextColumn get id => text()();
  TextColumn get journalEntryId => text().references(JournalEntries, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  RealColumn get debit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Invoices table
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().withLength(min: 1, max: 50)();
  TextColumn get customerId => text().references(Customers, #id)();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  TextColumn get notes => text().nullable()();
  TextColumn get terms => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncSequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Invoice Lines table
class InvoiceLines extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(Invoices, #id)();
  TextColumn get description => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

// Bills table
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get billNumber => text().withLength(min: 1, max: 50)();
  TextColumn get vendorId => text().references(Vendors, #id)();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get currencyCode => text().withDefault(const Constant('UGX'))();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncSequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Bill Lines table
class BillLines extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text().references(Bills, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get description => text()();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Sync Events table - for offline-first sync
class SyncEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // account, customer, vendor, invoice, bill, journal_entry
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // create, update, delete
  TextColumn get payload => text()(); // JSON payload
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

// Sync State table - track sync progress
class SyncState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastSyncedSequence => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('idle'))(); // idle, syncing, error
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
