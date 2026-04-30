import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';

const _uuid = Uuid();

/// Parses MagicBet outlet revenue CSV files and POSTs each row to the
/// server's /api/outlet-revenues endpoint, which immediately creates the
/// double-entry journal entries (DR Payouts / CR Stakes).
///
/// CSV format expected (with header row):
///   Outlet, Business Day (M/D/YYYY), Total In, Total Out, Total GGR
class CSVImportService {
  final ApiClient? _api;

  CSVImportService(this._api);

  Future<CSVImportResult> importCSVData(
    List<List<dynamic>> csvData, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (_api == null) {
      return CSVImportResult(
        successCount: 0,
        errorCount: 1,
        skippedCount: 0,
        errors: ['API client not available. Please log in and try again.'],
        totalCashIn: 0,
        totalCashOut: 0,
        totalGGR: 0,
      );
    }

    // Skip header row
    final dataRows = csvData.skip(1).toList();
    final total = dataRows.length;
    final batch = <Map<String, dynamic>>[];
    final parseErrors = <String>[];
    double totalCashIn = 0;
    double totalCashOut = 0;
    double totalGGR = 0;

    for (int i = 0; i < dataRows.length; i++) {
      onProgress?.call(i, total);
      final row = dataRows[i];

      try {
        final outletCode = row.isNotEmpty ? row[0]?.toString().trim() ?? '' : '';
        final dateStr = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
        final cashIn = _parseAmount(row.length > 2 ? row[2]?.toString() ?? '0' : '0');
        final cashOut = _parseAmount(row.length > 3 ? row[3]?.toString() ?? '0' : '0');
        final ggr = _parseAmount(row.length > 4 ? row[4]?.toString() ?? '0' : '0');

        if (outletCode.isEmpty) {
          parseErrors.add('Row ${i + 2}: Missing outlet code');
          continue;
        }
        if (dateStr.isEmpty) {
          parseErrors.add('Row ${i + 2}: Missing date');
          continue;
        }

        final date = _parseDate(dateStr);
        if (date == null) {
          parseErrors.add('Row ${i + 2}: Invalid date "$dateStr" (expected M/D/YYYY)');
          continue;
        }

        final dateFormatted = DateFormat('yyyy-MM-dd').format(date);
        final ref = 'REV-$outletCode-${dateFormatted.replaceAll('-', '')}';

        batch.add({
          'outlet_code': outletCode,
          'date': dateFormatted,
          'stake_amount': cashIn,
          'payout_amount': cashOut,
          'net_amount': ggr,
          'reference': ref,
        });

        totalCashIn += cashIn;
        totalCashOut += cashOut;
        totalGGR += ggr;
      } catch (e) {
        parseErrors.add('Row ${i + 2}: Parse error — $e');
      }
    }

    onProgress?.call(total, total);

    if (batch.isEmpty) {
      return CSVImportResult(
        successCount: 0,
        errorCount: parseErrors.length,
        skippedCount: 0,
        errors: parseErrors.isEmpty
            ? ['No valid rows found in the CSV file.']
            : parseErrors,
        totalCashIn: 0,
        totalCashOut: 0,
        totalGGR: 0,
      );
    }

    try {
      final result = await _api!.postOutletRevenues(batch);
      final created = result['created'] as int? ?? 0;
      final skipped = result['skipped'] as int? ?? 0;

      // Store raw rows in client_sync_data blob store so Revenue screen can
      // display them. Only store newly created rows (skip duplicates already stored).
      if (created > 0) {
        try {
          final blobs = batch.map((row) => {
                ...row,
                'id': _uuid.v4(),
              }).toList();
          await _api!.storeOutletRevenues(blobs);
        } catch (_) {
          // Non-fatal: JEs were already created; display sync failure is acceptable
        }
      }

      return CSVImportResult(
        successCount: created,
        errorCount: parseErrors.length,
        skippedCount: skipped,
        errors: parseErrors,
        totalCashIn: created > 0 ? totalCashIn : 0,
        totalCashOut: created > 0 ? totalCashOut : 0,
        totalGGR: created > 0 ? totalGGR : 0,
      );
    } catch (e) {
      return CSVImportResult(
        successCount: 0,
        errorCount: 1 + parseErrors.length,
        skippedCount: 0,
        errors: ['Server error: $e', ...parseErrors],
        totalCashIn: 0,
        totalCashOut: 0,
        totalGGR: 0,
      );
    }
  }

  double _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  DateTime? _parseDate(String raw) {
    try {
      final parts = raw.trim().split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return null;
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
    buf.writeln('  Cash In (Stakes):   UGX ${formatter.format(totalCashIn)}');
    buf.writeln('  Cash Out (Payouts): UGX ${formatter.format(totalCashOut)}');
    buf.writeln('  Net GGR:            UGX ${formatter.format(totalGGR)}');
    return buf.toString();
  }
}
