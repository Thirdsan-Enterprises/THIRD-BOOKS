// Local Outlet CSV Uploads Provider
// Stores a record of each outlet CSV import so it can be reversed (deleted).
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class LocalOutletCsvUpload {
  final String id;
  final String fileName;
  final DateTime uploadedAt;
  final DateTime? fromDate;   // earliest date in the imported data
  final DateTime? toDate;     // latest date in the imported data
  final int rowCount;         // total CSV data rows
  final int successCount;
  final int skippedCount;
  final double totalCashIn;
  final double totalCashOut;
  final double totalGGR;
  final List<String> revenueIds;   // OutletRevenue.id values inserted into SQLite
  final List<String> dailyJeIds;   // JournalEntry.id values for daily revenue JEs

  const LocalOutletCsvUpload({
    required this.id,
    required this.fileName,
    required this.uploadedAt,
    this.fromDate,
    this.toDate,
    required this.rowCount,
    required this.successCount,
    required this.skippedCount,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalGGR,
    this.revenueIds = const [],
    this.dailyJeIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'uploadedAt': uploadedAt.toIso8601String(),
        'fromDate': fromDate?.toIso8601String(),
        'toDate': toDate?.toIso8601String(),
        'rowCount': rowCount,
        'successCount': successCount,
        'skippedCount': skippedCount,
        'totalCashIn': totalCashIn,
        'totalCashOut': totalCashOut,
        'totalGGR': totalGGR,
        'revenueIds': revenueIds,
        'dailyJeIds': dailyJeIds,
      };

  factory LocalOutletCsvUpload.fromJson(Map<String, dynamic> j) {
    final rawRevenueIds = j['revenueIds'] as List<dynamic>? ?? [];
    final rawDailyJeIds = j['dailyJeIds'] as List<dynamic>? ?? [];
    return LocalOutletCsvUpload(
      id: j['id'] as String,
      fileName: j['fileName'] as String,
      uploadedAt: DateTime.parse(j['uploadedAt'] as String),
      fromDate: j['fromDate'] != null
          ? DateTime.parse(j['fromDate'] as String)
          : null,
      toDate: j['toDate'] != null
          ? DateTime.parse(j['toDate'] as String)
          : null,
      rowCount: (j['rowCount'] as num?)?.toInt() ?? 0,
      successCount: (j['successCount'] as num?)?.toInt() ?? 0,
      skippedCount: (j['skippedCount'] as num?)?.toInt() ?? 0,
      totalCashIn: (j['totalCashIn'] as num?)?.toDouble() ?? 0.0,
      totalCashOut: (j['totalCashOut'] as num?)?.toDouble() ?? 0.0,
      totalGGR: (j['totalGGR'] as num?)?.toDouble() ?? 0.0,
      revenueIds: rawRevenueIds.map((e) => e.toString()).toList(),
      dailyJeIds: rawDailyJeIds.map((e) => e.toString()).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------
class LocalOutletCsvUploadsNotifier
    extends StateNotifier<List<LocalOutletCsvUpload>> {
  final LocalStorageService _storage;

  LocalOutletCsvUploadsNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _storage.loadData(
          'outlet_csv_uploads', LocalOutletCsvUpload.fromJson);
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    await _storage.saveData(
        'outlet_csv_uploads', state, (s) => s.toJson());
  }

  Future<void> add(LocalOutletCsvUpload upload) async {
    state = [upload, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  /// Reload from disk.
  Future<void> reload() => _load();

  /// Clear all records — used by settings "clear cache" action.
  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final localOutletCsvUploadsProvider = StateNotifierProvider<
    LocalOutletCsvUploadsNotifier, List<LocalOutletCsvUpload>>(
  (ref) =>
      LocalOutletCsvUploadsNotifier(ref.read(localStorageServiceProvider)),
);
