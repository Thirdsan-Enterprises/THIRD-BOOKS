import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Events table for local event sourcing
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

// Cached data tables for offline access
class CachedInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()(); // JSON string
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedBills extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()(); // JSON string
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedDashboardStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get data => text()(); // JSON string
  DateTimeColumn get cachedAt => dateTime()();
}

// Database class
@DriftDatabase(tables: [
  LocalEvents,
  CachedInvoices,
  CachedBills,
  CachedDashboardStats,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Event operations
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
    // Check if event already exists
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

  // Cache operations for invoices
  Future<void> cacheInvoice(String id, Map<String, dynamic> data) async {
    await into(cachedInvoices).insertOnConflictUpdate(
      CachedInvoicesCompanion.insert(
        id: id,
        data: data.toString(),
        cachedAt: DateTime.now(),
      ),
    );
  }

  Future<CachedInvoice?> getCachedInvoice(String id) async {
    return (select(cachedInvoices)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<CachedInvoice>> getAllCachedInvoices() async {
    return select(cachedInvoices).get();
  }

  // Cache operations for bills
  Future<void> cacheBill(String id, Map<String, dynamic> data) async {
    await into(cachedBills).insertOnConflictUpdate(
      CachedBillsCompanion.insert(
        id: id,
        data: data.toString(),
        cachedAt: DateTime.now(),
      ),
    );
  }

  Future<CachedBill?> getCachedBill(String id) async {
    return (select(cachedBills)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<List<CachedBill>> getAllCachedBills() async {
    return select(cachedBills).get();
  }

  // Cache operations for dashboard stats
  Future<void> cacheDashboardStats(Map<String, dynamic> data) async {
    // Delete old stats
    await delete(cachedDashboardStats).go();

    // Insert new stats
    await into(cachedDashboardStats).insert(
      CachedDashboardStatsCompanion.insert(
        data: data.toString(),
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

  // Clear all cached data
  Future<void> clearAllCache() async {
    await delete(cachedInvoices).go();
    await delete(cachedBills).go();
    await delete(cachedDashboardStats).go();
  }

  // Clear all local events (use with caution!)
  Future<void> clearAllEvents() async {
    await delete(localEvents).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'thirdbooks_app.db'));
    return NativeDatabase(file);
  });
}

// Database Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Extension for LocalEvent to convert to JSON
extension LocalEventX on LocalEvent {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'event_type': eventType,
      'event_data': eventData, // Already JSON string
      'metadata': metadata,
      'sequence_number': sequenceNumber,
      'device_id': deviceId,
      'user_id': userId,
      'occurred_at': occurredAt.toIso8601String(),
    };
  }
}
