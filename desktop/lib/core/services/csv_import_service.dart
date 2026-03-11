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
class CSVImportService {
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  CSVImportService(this.database);

  /// Parse a number string like " 746,000 " or " 1,585,000 " to double
  double _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll(' ', '').replaceAll('"', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse date in m/d/yyyy format
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

  /// Map CSV outlet code (e.g. "23103000") to DB outlet code (e.g. "3000")
  String _mapOutletCode(String csvCode) {
    final trimmed = csvCode.trim().replaceAll('"', '');
    if (trimmed.startsWith('2310')) {
      return trimmed.substring(4);
    }
    return trimmed;
  }

  /// Import CSV data from parsed rows (List<List<dynamic>> from csv package)
  ///
  /// Expected columns: Outlet, Business Day, Total In, Total Out, Total GGR
  Future<CSVImportResult> importCSVData(List<List<dynamic>> csvData) async {
    if (csvData.length < 2) {
      throw Exception('CSV file must have at least a header row and one data row');
    }

    final dataRows = csvData.skip(1);

    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    double totalCashIn = 0;
    double totalCashOut = 0;
    double totalGGR = 0;

    // Cache outlets for lookup
    final outlets = await database.getAllOutlets();
    final outletMap = <String, Outlet>{};
    for (final outlet in outlets) {
      outletMap[outlet.outletCode] = outlet;
    }

    int rowNum = 1;
    for (var row in dataRows) {
      rowNum++;
      try {
        if (row.isEmpty || row.length < 5) {
          errors.add('Row $rowNum: Not enough columns');
          errorCount++;
          continue;
        }

        final csvOutletCode = row[0]?.toString() ?? '';
        final dateStr = row[1]?.toString() ?? '';
        final cashIn = _parseAmount(row[2]?.toString() ?? '0');
        final cashOut = _parseAmount(row[3]?.toString() ?? '0');
        final ggr = _parseAmount(row[4]?.toString() ?? '0');

        // Map outlet code
        final outletCode = _mapOutletCode(csvOutletCode);
        final outlet = outletMap[outletCode];

        if (outlet == null) {
          errors.add('Row $rowNum: Outlet $outletCode not found');
          errorCount++;
          continue;
        }

        // Parse date
        final date = _parseDate(dateStr);
        if (date == null) {
          errors.add('Row $rowNum: Invalid date "$dateStr"');
          errorCount++;
          continue;
        }

        // Create revenue entry
        // amount = Total In, commissionAmount = Total Out, netAmount = GGR
        final revenueId = _uuid.v4();
        await database.insertOutletRevenue(
          OutletRevenuesCompanion.insert(
            id: revenueId,
            outletId: outlet.id,
            date: date,
            amount: Value(cashIn),
            commissionAmount: Value(cashOut),
            netAmount: Value(ggr),
            description: Value('${outlet.name} - ${DateFormat('MMM d, yyyy').format(date)}'),
            reference: Value('CSV-$csvOutletCode-${DateFormat('yyyyMMdd').format(date)}'),
            status: const Value('recorded'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        totalCashIn += cashIn;
        totalCashOut += cashOut;
        totalGGR += ggr;
        successCount++;
      } catch (e) {
        errors.add('Row $rowNum: $e');
        errorCount++;
      }
    }

    return CSVImportResult(
      successCount: successCount,
      errorCount: errorCount,
      errors: errors,
      totalCashIn: totalCashIn,
      totalCashOut: totalCashOut,
      totalGGR: totalGGR,
    );
  }
}

/// Result of CSV import operation
class CSVImportResult {
  final int successCount;
  final int errorCount;
  final List<String> errors;
  final double totalCashIn;
  final double totalCashOut;
  final double totalGGR;

  CSVImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalGGR,
  });

  bool get hasErrors => errorCount > 0;
  bool get isSuccess => successCount > 0 && errorCount == 0;

  String get summary {
    return '''
Successfully imported: $successCount rows
${errorCount > 0 ? 'Errors: $errorCount rows' : ''}

Summary:
  Total Cash In (Stakes):  UGX ${_formatNumber(totalCashIn)}
  Total Cash Out (Payouts): UGX ${_formatNumber(totalCashOut)}
  Total GGR:               UGX ${_formatNumber(totalGGR)}
''';
  }

  String _formatNumber(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value);
  }
}
