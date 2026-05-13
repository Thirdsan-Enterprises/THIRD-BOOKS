import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide JsonKey;

import '../database/app_database.dart';

/// CSV Import Service for MagicBet Outlet Data
///
/// Imports AccountingTotalsInOut.csv with format:
/// Outlet, Business Day, Total In, Total Out, Total GGR
///
/// CSV outlet codes are prefixed with '2310' (e.g. 23103000 -> outlet code 3000)
/// Date format is m/d/yyyy (e.g. 1/1/2026)
/// Amounts may contain commas and spaces (e.g. " 746,000 ")
///
/// Deduplication: skips rows where the same outlet + date already exists in DB.
class CSVImportService {
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  CSVImportService(this.database);

  double _parseAmount(String raw) {
    final cleaned =
        raw.trim().replaceAll(',', '').replaceAll(' ', '').replaceAll('"', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  DateTime? _parseDate(String raw) {
    try {
      final trimmed = raw.trim();
      final parts = trimmed.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  String _mapOutletCode(String csvCode) =>
      csvCode.trim().replaceAll('"', '');

  /// Import CSV data rows.
  ///
  /// [onProgress] callback: (processedRows, totalRows) for UI progress bar.
  Future<CSVImportResult> importCSVData(
    List<List<dynamic>> csvData, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (csvData.length < 2) {
      throw Exception(
          'CSV file must have at least a header row and one data row');
    }

    final dataRows = csvData.skip(1).toList();
    final total = dataRows.length;

    int successCount = 0;
    int errorCount = 0;
    int skippedCount = 0;
    final errors = <String>[];
    final revenueIds = <String>[];

    double totalCashIn = 0;
    double totalCashOut = 0;
    double totalGGR = 0;

    // Cache outlets for lookup
    final outlets = await database.getAllOutlets();
    final outletMap = <String, Outlet>{};
    for (final outlet in outlets) {
      outletMap[outlet.outletCode] = outlet;
    }

    // Cache existing revenue records to detect duplicates
    // Key: "{outletId}|{yyyyMMdd}"
    final existingRevenues = await database.getAllOutletRevenues();
    final existingKeys = <String>{};
    for (final r in existingRevenues) {
      final key =
          '${r.outletId}|${DateFormat('yyyyMMdd').format(r.date)}';
      existingKeys.add(key);
    }

    int rowNum = 1;
    for (var row in dataRows) {
      rowNum++;
      try {
        if (row.isEmpty || row.length < 5) {
          errors.add('Row $rowNum: Not enough columns (need 5, found ${row.length})');
          errorCount++;
          onProgress?.call(rowNum - 1, total);
          continue;
        }

        final csvOutletCode = row[0]?.toString() ?? '';
        final dateStr = row[1]?.toString() ?? '';
        final cashIn = _parseAmount(row[2]?.toString() ?? '0');
        final cashOut = _parseAmount(row[3]?.toString() ?? '0');
        final ggr = _parseAmount(row[4]?.toString() ?? '0');

        final outletCode = _mapOutletCode(csvOutletCode);
        final outlet = outletMap[outletCode];

        if (outlet == null) {
          errors.add('Row $rowNum: Outlet "$outletCode" not found in system');
          errorCount++;
          onProgress?.call(rowNum - 1, total);
          continue;
        }

        final date = _parseDate(dateStr);
        if (date == null) {
          errors.add('Row $rowNum: Invalid date "$dateStr"');
          errorCount++;
          onProgress?.call(rowNum - 1, total);
          continue;
        }

        // Deduplication check: skip if this outlet+date already recorded
        final dupKey =
            '${outlet.id}|${DateFormat('yyyyMMdd').format(date)}';
        if (existingKeys.contains(dupKey)) {
          skippedCount++;
          onProgress?.call(rowNum - 1, total);
          continue;
        }

        final revenueId = _uuid.v4();
        await database.insertOutletRevenue(
          OutletRevenuesCompanion.insert(
            id: revenueId,
            outletId: outlet.id,
            date: date,
            amount: Value(cashIn),
            commissionAmount: Value(cashOut),
            netAmount: Value(ggr),
            description: Value(
                '${outlet.name} - ${DateFormat('MMM d, yyyy').format(date)}'),
            reference: Value(
                'CSV-$outletCode-${DateFormat('yyyyMMdd').format(date)}'),
            status: const Value('recorded'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Track inserted revenue ID for upload history
        revenueIds.add(revenueId);

        // Add to known keys to prevent duplicates within the same file
        existingKeys.add(dupKey);

        totalCashIn += cashIn;
        totalCashOut += cashOut;
        totalGGR += ggr;
        successCount++;
      } catch (e) {
        errors.add('Row $rowNum: $e');
        errorCount++;
      }

      onProgress?.call(rowNum - 1, total);
    }

    return CSVImportResult(
      successCount: successCount,
      errorCount: errorCount,
      skippedCount: skippedCount,
      errors: errors,
      totalCashIn: totalCashIn,
      totalCashOut: totalCashOut,
      totalGGR: totalGGR,
      revenueIds: revenueIds,
    );
  }
}

class CSVImportResult {
  final int successCount;
  final int errorCount;
  final int skippedCount;
  final List<String> errors;
  final double totalCashIn;
  final double totalCashOut;
  final double totalGGR;
  /// IDs of OutletRevenue rows inserted into SQLite during this import.
  final List<String> revenueIds;

  CSVImportResult({
    required this.successCount,
    required this.errorCount,
    this.skippedCount = 0,
    required this.errors,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalGGR,
    this.revenueIds = const [],
  });

  bool get hasErrors => errorCount > 0;
  bool get isSuccess => successCount > 0;

  String get summary {
    final formatter = NumberFormat('#,##0', 'en_US');
    final buf = StringBuffer();
    buf.writeln('Import complete:');
    buf.writeln('  ✅ Imported:  $successCount rows');
    if (skippedCount > 0) buf.writeln('  ⏭  Skipped (duplicate): $skippedCount rows');
    if (errorCount > 0) buf.writeln('  ❌ Errors:   $errorCount rows');
    buf.writeln('');
    buf.writeln('Totals imported in this batch:');
    buf.writeln('  Cash In (Stakes):  UGX ${formatter.format(totalCashIn)}');
    buf.writeln('  Cash Out (Payouts): UGX ${formatter.format(totalCashOut)}');
    buf.writeln('  Net GGR:            UGX ${formatter.format(totalGGR)}');
    return buf.toString();
  }
}
