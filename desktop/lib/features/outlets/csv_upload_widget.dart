import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/services/data_service.dart';

/// CSV Upload Widget with real-time progress, deduplication feedback,
/// and per-row status reporting.
class CSVUploadWidget extends ConsumerStatefulWidget {
  const CSVUploadWidget({super.key});

  @override
  ConsumerState<CSVUploadWidget> createState() => _CSVUploadWidgetState();
}

class _CSVUploadWidgetState extends ConsumerState<CSVUploadWidget> {
  List<List<dynamic>>? _csvData;
  String? _fileName;
  bool _isImporting = false;
  bool _isParsing = false;
  String? _errorMessage;

  // Progress state
  int _processed = 0;
  int _total = 0;
  CSVImportResult? _lastResult;

  Future<void> _pickAndReadCSV() async {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _lastResult = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();
        final csvData = const CsvToListConverter().convert(csvString);

        setState(() {
          _csvData = csvData;
          _fileName = result.files.single.name;
          _isParsing = false;
        });
      } else {
        setState(() => _isParsing = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error reading CSV: $e';
        _isParsing = false;
      });
    }
  }

  Future<void> _importData() async {
    if (_csvData == null || _csvData!.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to import'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _processed = 0;
      _total = _csvData!.length - 1;
      _lastResult = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final importService = CSVImportService(db);

      final result = await importService.importCSVData(
        _csvData!,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _processed = processed;
              _total = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isImporting = false;
          _lastResult = result;
          _csvData = null;
          _fileName = null;
        });
        // Invalidate all data providers so dashboard and reports reflect new data immediately
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(outletRevenueSummaryProvider);
        ref.invalidate(outletAnalyticsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Import failed: $e';
          _isImporting = false;
        });
      }
    }
  }

  String _formatCellValue(dynamic value, int columnIndex) {
    if (value == null) return '';
    if (columnIndex == 1) {
      // Date column
      try {
        final parts = value.toString().trim().split('/');
        if (parts.length == 3) {
          final date = DateTime(
              int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
          return DateFormat('MMM d, yyyy').format(date);
        }
      } catch (_) {}
    }
    if (columnIndex >= 2 && columnIndex <= 4) {
      final amount = double.tryParse(
          value.toString().trim().replaceAll(',', '').replaceAll(' ', ''));
      if (amount != null) {
        return 'UGX ${NumberFormat('#,##0').format(amount)}';
      }
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.upload_file, size: 28, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Outlet Machine Data',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Format: Outlet, Business Day (M/D/YYYY), Total In, Total Out, Total GGR  •  Duplicates (same outlet + date) are skipped automatically.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_csvData == null && !_isImporting)
                  FilledButton.icon(
                    onPressed: _isParsing ? null : _pickAndReadCSV,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Select CSV File'),
                  ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────

          // Importing in progress
          if (_isImporting)
            _buildProgressView()

          // Parsing indicator
          else if (_isParsing)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )

          // Error
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(_errorMessage!,
                        style: TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _errorMessage = null),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )

          // Last result summary
          else if (_lastResult != null)
            _buildResultView(_lastResult!)

          // File loaded — show preview
          else if (_csvData != null)
            _buildPreviewView()

          // Empty state
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    final pct = _total > 0 ? _processed / _total : 0.0;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload, size: 48, color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'Importing data...',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$_processed of $_total rows processed',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withOpacity(0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(pct * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Please wait — do not close this window.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(CSVImportResult r) {
    final fmt = NumberFormat('#,##0');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.successCount > 0
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color:
                    r.successCount > 0 ? AppColors.success : AppColors.warning,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                r.successCount > 0 ? 'Import Successful' : 'Import Complete',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _resultCard('Imported', r.successCount.toString(),
                  Icons.check_circle_outline, AppColors.success),
              const SizedBox(width: 12),
              _resultCard(
                  'Skipped (duplicate)',
                  r.skippedCount.toString(),
                  Icons.skip_next,
                  AppColors.info),
              const SizedBox(width: 12),
              _resultCard('Errors', r.errorCount.toString(),
                  Icons.error_outline, AppColors.error),
            ],
          ),
          const SizedBox(height: 20),

          // Totals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _totalRow('Cash In (Stakes)', 'UGX ${fmt.format(r.totalCashIn)}'),
                const Divider(height: 12),
                _totalRow('Cash Out (Payouts)', 'UGX ${fmt.format(r.totalCashOut)}'),
                const Divider(height: 12),
                _totalRow('Net GGR', 'UGX ${fmt.format(r.totalGGR)}',
                    bold: true),
              ],
            ),
          ),

          if (r.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text('${r.errors.length} row errors (click to expand)',
                  style: TextStyle(color: AppColors.error, fontSize: 13)),
              children: r.errors
                  .map((e) => ListTile(
                        dense: true,
                        leading:
                            Icon(Icons.error_outline, size: 16, color: AppColors.error),
                        title: Text(e, style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Another File'),
            onPressed: () => setState(() => _lastResult = null),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(
          String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline)),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: color)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _totalRow(String label, String value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w500,
                  fontFamily: 'monospace')),
        ],
      );

  Widget _buildPreviewView() {
    final dataRows = _csvData!.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primary.withOpacity(0.05),
          child: Row(
            children: [
              const Icon(Icons.description, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName ?? 'file.csv',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    Text('$dataRows data rows ready to import',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _csvData = null;
                  _fileName = null;
                }),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _importData,
                icon: const Icon(Icons.save),
                label: const Text('Import Data'),
              ),
            ],
          ),
        ),

        // Preview table
        Container(
          constraints: const BoxConstraints(maxHeight: 380),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
                columns: _csvData![0]
                    .map((h) => DataColumn(
                          label: Text(h.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ))
                    .toList(),
                rows: _csvData!
                    .skip(1)
                    .take(20)
                    .map((row) => DataRow(
                          cells: row
                              .asMap()
                              .entries
                              .map((e) => DataCell(
                                    Text(_formatCellValue(e.value, e.key)),
                                  ))
                              .toList(),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),

        if (dataRows > 20)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Showing first 20 of $dataRows rows',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload,
                size: 64,
                color:
                    Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text('No file selected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      )),
              const SizedBox(height: 8),
              Text(
                'CSV columns: Outlet Code, Business Day (M/D/YYYY), Total In, Total Out, Total GGR\n'
                'Duplicate records (same outlet + date) are skipped automatically.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
