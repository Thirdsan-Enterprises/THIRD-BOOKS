// CSV Import Service — removed: local SQLite database has been retired.
// Outlet data now lives on the server.
// The CSVImportService and CSVImportResult classes are preserved as stubs
// so that any remaining import sites compile without modification.

import 'package:intl/intl.dart';

class CSVImportService {
  CSVImportService(dynamic database);

  Future<CSVImportResult> importCSVData(
    List<List<dynamic>> csvData, {
    void Function(int processed, int total)? onProgress,
  }) async {
    return CSVImportResult(
      successCount: 0,
      errorCount: 0,
      skippedCount: 0,
      errors: ['Local database has been retired. Outlet data now lives on the server.'],
      totalCashIn: 0,
      totalCashOut: 0,
      totalGGR: 0,
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

  CSVImportResult({
    required this.successCount,
    required this.errorCount,
    this.skippedCount = 0,
    required this.errors,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.totalGGR,
  });

  bool get hasErrors => errorCount > 0;
  bool get isSuccess => successCount > 0;

  String get summary {
    final formatter = NumberFormat('#,##0', 'en_US');
    final buf = StringBuffer();
    buf.writeln('Import complete:');
    buf.writeln('  Imported:  $successCount rows');
    if (skippedCount > 0) buf.writeln('  Skipped (duplicate): $skippedCount rows');
    if (errorCount > 0) buf.writeln('  Errors:   $errorCount rows');
    buf.writeln('');
    buf.writeln('Totals imported in this batch:');
    buf.writeln('  Cash In (Stakes):  UGX ${formatter.format(totalCashIn)}');
    buf.writeln('  Cash Out (Payouts): UGX ${formatter.format(totalCashOut)}');
    buf.writeln('  Net GGR:            UGX ${formatter.format(totalGGR)}');
    return buf.toString();
  }
}
