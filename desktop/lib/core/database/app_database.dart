import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Customers,
  Vendors,
  JournalEntries,
  JournalLines,
  Invoices,
  InvoiceLines,
  Bills,
  BillLines,
  SyncEvents,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Initialize sync state
        await into(syncState).insert(SyncStateCompanion.insert());
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
    );
  }

  // Account operations
  Future<List<Account>> getAllAccounts() => select(accounts).get();

  Stream<List<Account>> watchAllAccounts() => select(accounts).watch();

  Future<Account?> getAccountById(String id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  Future<bool> updateAccount(AccountsCompanion account) =>
      update(accounts).replace(account);

  Future<int> deleteAccount(String id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  // Customer operations
  Future<List<Customer>> getAllCustomers() => select(customers).get();

  Stream<List<Customer>> watchAllCustomers() => select(customers).watch();

  Future<Customer?> getCustomerById(String id) =>
      (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);

  Future<bool> updateCustomer(CustomersCompanion customer) =>
      update(customers).replace(customer);

  // Vendor operations
  Future<List<Vendor>> getAllVendors() => select(vendors).get();

  Stream<List<Vendor>> watchAllVendors() => select(vendors).watch();

  Future<Vendor?> getVendorById(String id) =>
      (select(vendors)..where((v) => v.id.equals(id))).getSingleOrNull();

  Future<int> insertVendor(VendorsCompanion vendor) =>
      into(vendors).insert(vendor);

  Future<bool> updateVendor(VendorsCompanion vendor) =>
      update(vendors).replace(vendor);

  // Journal Entry operations
  Future<List<JournalEntry>> getAllJournalEntries() =>
      select(journalEntries).get();

  Stream<List<JournalEntry>> watchAllJournalEntries() =>
      select(journalEntries).watch();

  Future<int> insertJournalEntry(JournalEntriesCompanion entry) =>
      into(journalEntries).insert(entry);

  Future<List<JournalLine>> getJournalLines(String journalEntryId) =>
      (select(journalLines)..where((l) => l.journalEntryId.equals(journalEntryId))).get();

  // Invoice operations
  Future<List<Invoice>> getAllInvoices() => select(invoices).get();

  Stream<List<Invoice>> watchAllInvoices() => select(invoices).watch();

  Future<int> insertInvoice(InvoicesCompanion invoice) =>
      into(invoices).insert(invoice);

  Future<List<InvoiceLine>> getInvoiceLines(String invoiceId) =>
      (select(invoiceLines)..where((l) => l.invoiceId.equals(invoiceId))).get();

  // Bill operations
  Future<List<Bill>> getAllBills() => select(bills).get();

  Stream<List<Bill>> watchAllBills() => select(bills).watch();

  Future<int> insertBill(BillsCompanion bill) => into(bills).insert(bill);

  Future<List<BillLine>> getBillLines(String billId) =>
      (select(billLines)..where((l) => l.billId.equals(billId))).get();

  // Sync operations
  Future<List<SyncEvent>> getPendingSyncEvents() =>
      (select(syncEvents)..where((e) => e.isSynced.equals(false))).get();

  Future<int> insertSyncEvent(SyncEventsCompanion event) =>
      into(syncEvents).insert(event);

  Future<void> markSyncEventsSynced(List<int> ids) async {
    await (update(syncEvents)..where((e) => e.id.isIn(ids))).write(
      SyncEventsCompanion(
        isSynced: const Value(true),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<SyncStateData?> getSyncState() =>
      (select(syncState)..where((s) => s.id.equals(1))).getSingleOrNull();

  Future<void> updateSyncState({
    int? lastSyncedSequence,
    DateTime? lastSyncAt,
    String? syncStatus,
    String? lastError,
  }) async {
    await (update(syncState)..where((s) => s.id.equals(1))).write(
      SyncStateCompanion(
        lastSyncedSequence: lastSyncedSequence != null
            ? Value(lastSyncedSequence)
            : const Value.absent(),
        lastSyncAt:
            lastSyncAt != null ? Value(lastSyncAt) : const Value.absent(),
        syncStatus:
            syncStatus != null ? Value(syncStatus) : const Value.absent(),
        lastError: lastError != null ? Value(lastError) : const Value.absent(),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'thirdbooks', 'thirdbooks.db'));

    // Create directory if it doesn't exist
    await file.parent.create(recursive: true);

    return NativeDatabase.createInBackground(file);
  });
}
