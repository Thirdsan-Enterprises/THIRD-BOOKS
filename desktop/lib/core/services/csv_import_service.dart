import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide JsonKey;

import '../database/app_database.dart';

/// CSV Import Service for Betting Machine Data
///
/// Imports outlet transaction data and calculates:
/// - Cash In (Total bets placed)
/// - Cash Out (Total winnings paid)  
/// - GGR (Gross Gaming Revenue = Cash In - Cash Out)
class CSVImportService {
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  CSVImportService(this.database);

  /// Import CSV data and populate all relevant tables
  /// 
  /// CSV Format: Date(MM/DD/YYYY), OutletID, TotalIn, TotalOut, NetAmount, TransactionCount, Currency
  Future<CSVImportResult> importCSVData(List<List<dynamic>> csvData) async {
    if (csvData.length < 2) {
      throw Exception('CSV file must have at least a header row and one data row');
    }

    // Skip header row
    final dataRows = csvData.skip(1);
    
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];
    
    // Statistics
    double totalCashIn = 0;
    double totalCashOut = 0;
    double totalGGR = 0;

    for (var row in dataRows) {
      try {
        // Parse CSV row
        final dateStr = row[0]?.toString() ?? '';
        final outletCode = row[1]?.toString() ?? '';
        final cashIn = double.parse(row[2]?.toString() ?? '0');
        final cashOut = double.parse(row[3]?.toString() ?? '0');
        final netAmount = double.parse(row[4]?.toString() ?? '0');
        final transactionCount = int.parse(row[5]?.toString() ?? '0');
        final currency = row[6]?.toString() ?? 'UGX';

        // Parse date (MM/DD/YYYY format)
        final dateFormat = DateFormat('MM/dd/yyyy');
        final date = dateFormat.parse(dateStr);

        // Calculate GGR (Gross Gaming Revenue)
        final ggr = cashIn - cashOut;

        // Find outlet by code
        final outlet = await database.getOutletByCode(outletCode);
        if (outlet == null) {
          errors.add('Outlet not found: $outletCode');
          errorCount++;
          continue;
        }

        // Create revenue entry for Cash In (TotalIn)
        if (cashIn > 0) {
          final revenueId = _uuid.v4();
          await database.into(database.outletRevenues).insert(
            OutletRevenuesCompanion.insert(
              id: revenueId,
              outletId: outlet.id,
              date: date,
              amount: cashIn,
              description: Value('Betting Revenue - $transactionCount transactions'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Create expenditure entry for Cash Out (TotalOut)
        if (cashOut > 0) {
          final expenditureId = _uuid.v4();
          await database.into(database.outletExpenditures).insert(
            OutletExpendituresCompanion.insert(
              id: expenditureId,
              outletId: outlet.id,
              date: date,
              expenseType: 'Winnings/Payouts',
              amount: cashOut,
              description: 'Winnings Paid - $transactionCount transactions',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Accumulate totals
        totalCashIn += cashIn;
        totalCashOut += cashOut;
        totalGGR += ggr;

        successCount++;
      } catch (e) {
        errors.add('Row error: $e');
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
✅ Successfully imported: $successCount rows
${errorCount > 0 ? '❌ Errors: $errorCount rows' : ''}

📊 Summary:
  • Total Cash In:  UGX ${_formatNumber(totalCashIn)}
  • Total Cash Out: UGX ${_formatNumber(totalCashOut)}
  • Total GGR:      UGX ${_formatNumber(totalGGR)}
''';
  }

  String _formatNumber(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value);
  }
}
