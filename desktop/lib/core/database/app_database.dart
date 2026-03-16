import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'tables.dart';
import 'outlet_seed_data.dart';

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
  Outlets,
  OutletRevenues,
  OutletExpenditures,
  CommissionPayments,
  Assets,
  AssetDepreciation,
  DepreciationEntries,
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
        // Initialize sync state
        await into(syncState).insert(SyncStateCompanion.insert());
        // Pre-load all 72 MagicBet outlet locations
        await seedOutlets();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from v1 to v2 - add new tables for MAGIC BET LTD
        if (from == 1 && to == 2) {
          await m.createTable(outlets);
          await m.createTable(outletRevenues);
          await m.createTable(outletExpenditures);
          await m.createTable(commissionPayments);
          await m.createTable(assets);
          await m.createTable(assetDepreciation);
          await m.createTable(depreciationEntries);
        }
        // Always ensure the 72 real outlets are present after any schema upgrade
        await seedOutlets();
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

  // ========== OUTLET OPERATIONS ==========
  Future<List<Outlet>> getAllOutlets() => select(outlets).get();

  Stream<List<Outlet>> watchAllOutlets() => select(outlets).watch();

  Future<List<Outlet>> getActiveOutlets() =>
      (select(outlets)..where((o) => o.isActive.equals(true))).get();

  Future<Outlet?> getOutletById(String id) =>
      (select(outlets)..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<Outlet?> getOutletByCode(String code) =>
      (select(outlets)..where((o) => o.outletCode.equals(code))).getSingleOrNull();

  Future<int> insertOutlet(OutletsCompanion outlet) =>
      into(outlets).insert(outlet);

  Future<bool> updateOutlet(OutletsCompanion outlet) =>
      update(outlets).replace(outlet);

  Future<int> deleteOutlet(String id) =>
      (delete(outlets)..where((o) => o.id.equals(id))).go();

  /// Inserts the 72 canonical MagicBet outlet locations from kOutletSeedData.
  /// Idempotent: inserts only codes that do not yet exist, so calling this
  /// after a schema upgrade or after clearAllData() is always safe.
  /// If the DB contains only stale old-format codes (23101xxx), they are
  /// removed first so the correct codes (23103xxx) can be seeded cleanly.
  Future<void> seedOutlets() async {
    final existing = await getAllOutlets();
    final seedCodes = kOutletSeedData.map((r) => r[0]).toSet();
    final existingCodes = existing.map((o) => o.outletCode).toSet();

    // Detect stale data: if none of the existing codes match the seed codes,
    // wipe the stale outlets table before re-seeding.
    if (existing.isNotEmpty && existingCodes.intersection(seedCodes).isEmpty) {
      await delete(outlets).go();
      existing.clear();
      existingCodes.clear();
    }

    final missingCodes = seedCodes.difference(existingCodes);
    if (missingCodes.isEmpty) return;

    final now = DateTime.now();
    const uuid = Uuid();
    for (final row in kOutletSeedData) {
      if (!missingCodes.contains(row[0])) continue;
      await into(outlets).insert(OutletsCompanion.insert(
        id: uuid.v4(),
        outletCode: row[0],
        name: row[1],
        city: Value(row[2]),
        region: Value(row[3]),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  // ========== OUTLET REVENUE OPERATIONS ==========
  Future<List<OutletRevenue>> getAllOutletRevenues() =>
      select(outletRevenues).get();

  Stream<List<OutletRevenue>> watchOutletRevenues(String outletId) =>
      (select(outletRevenues)..where((r) => r.outletId.equals(outletId))).watch();

  Future<List<OutletRevenue>> getOutletRevenuesByPeriod(
      String outletId, DateTime start, DateTime end) =>
      (select(outletRevenues)
            ..where((r) =>
                r.outletId.equals(outletId) &
                r.date.isBiggerOrEqualValue(start) &
                r.date.isSmallerOrEqualValue(end)))
          .get();

  Future<int> insertOutletRevenue(OutletRevenuesCompanion revenue) =>
      into(outletRevenues).insert(revenue);

  Future<bool> updateOutletRevenue(OutletRevenuesCompanion revenue) =>
      update(outletRevenues).replace(revenue);

  // ========== OUTLET EXPENDITURE OPERATIONS ==========
  Future<List<OutletExpenditure>> getAllOutletExpenditures() =>
      select(outletExpenditures).get();

  Stream<List<OutletExpenditure>> watchOutletExpenditures(String outletId) =>
      (select(outletExpenditures)..where((e) => e.outletId.equals(outletId))).watch();

  Future<int> insertOutletExpenditure(OutletExpendituresCompanion expenditure) =>
      into(outletExpenditures).insert(expenditure);

  Future<bool> updateOutletExpenditure(OutletExpendituresCompanion expenditure) =>
      update(outletExpenditures).replace(expenditure);

  // ========== COMMISSION PAYMENT OPERATIONS ==========
  Future<List<CommissionPayment>> getAllCommissionPayments() =>
      select(commissionPayments).get();

  Stream<List<CommissionPayment>> watchPendingCommissions() =>
      (select(commissionPayments)..where((c) => c.status.equals('pending'))).watch();

  Future<int> insertCommissionPayment(CommissionPaymentsCompanion payment) =>
      into(commissionPayments).insert(payment);

  Future<bool> updateCommissionPayment(CommissionPaymentsCompanion payment) =>
      update(commissionPayments).replace(payment);

  // ========== ASSET OPERATIONS ==========
  Future<List<Asset>> getAllAssets() => select(assets).get();

  Stream<List<Asset>> watchAllAssets() => select(assets).watch();

  Future<List<Asset>> getActiveAssets() =>
      (select(assets)..where((a) => a.isActive.equals(true))).get();

  Future<Asset?> getAssetById(String id) =>
      (select(assets)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<int> insertAsset(AssetsCompanion asset) =>
      into(assets).insert(asset);

  Future<bool> updateAsset(AssetsCompanion asset) =>
      update(assets).replace(asset);

  // ========== ASSET DEPRECIATION OPERATIONS ==========
  Future<List<AssetDepreciationData>> getAssetDepreciationSchedules(String assetId) =>
      (select(assetDepreciation)..where((d) => d.assetId.equals(assetId))).get();

  Future<int> insertAssetDepreciation(AssetDepreciationCompanion depreciation) =>
      into(assetDepreciation).insert(depreciation);

  Future<bool> updateAssetDepreciation(AssetDepreciationCompanion depreciation) =>
      update(assetDepreciation).replace(depreciation);

  // ========== DEPRECIATION ENTRY OPERATIONS ==========
  Future<List<DepreciationEntry>> getDepreciationEntries(String assetId) =>
      (select(depreciationEntries)..where((e) => e.assetId.equals(assetId))).get();

  Future<int> insertDepreciationEntry(DepreciationEntriesCompanion entry) =>
      into(depreciationEntries).insert(entry);

  Stream<List<DepreciationEntry>> watchPendingDepreciationEntries() =>
      (select(depreciationEntries)..where((e) => e.status.equals('draft'))).watch();

  // ========== BULK / RESET OPERATIONS ==========

  /// Delete an outlet plus all its associated revenues, expenditures,
  /// and commission payments in a single transaction.
  Future<void> deleteOutletWithData(String outletId) async {
    await transaction(() async {
      await (delete(outletRevenues)..where((r) => r.outletId.equals(outletId))).go();
      await (delete(outletExpenditures)..where((e) => e.outletId.equals(outletId))).go();
      await (delete(commissionPayments)..where((c) => c.outletId.equals(outletId))).go();
      await (delete(outlets)..where((o) => o.id.equals(outletId))).go();
    });
  }

  /// Wipe all transactional data (revenues, expenditures, etc.) and reset
  /// the sync sequence to zero — same as a fresh install.
  /// The 72 outlet location records are preserved and re-seeded automatically
  /// so CSV imports continue to work after a data reset.
  Future<void> clearAllData() async {
    await transaction(() async {
      // Child tables first (FK order) — revenues & expenditures only
      await delete(depreciationEntries).go();
      await delete(assetDepreciation).go();
      await delete(assets).go();
      await delete(commissionPayments).go();
      await delete(outletExpenditures).go();
      await delete(outletRevenues).go();
      await delete(journalLines).go();
      await delete(journalEntries).go();
      await delete(invoiceLines).go();
      await delete(invoices).go();
      await delete(billLines).go();
      await delete(bills).go();
      await delete(customers).go();
      await delete(vendors).go();
      await delete(accounts).go();
      await delete(syncEvents).go();
      // Reset sync state row (id=1) back to defaults
      await (update(syncState)..where((s) => s.id.equals(1))).write(
        const SyncStateCompanion(
          lastSyncedSequence: Value(0),
          lastSyncAt: Value(null),
          syncStatus: Value('idle'),
          lastError: Value(null),
        ),
      );
    });
    // Re-seed the 72 outlet locations outside the transaction so
    // outlets are always available for CSV import after a data reset.
    await seedOutlets();
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
