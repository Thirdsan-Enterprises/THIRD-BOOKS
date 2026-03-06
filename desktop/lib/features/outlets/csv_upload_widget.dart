import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/services/data_service.dart';

/// CSV Upload Widget for Outlet Machine Data
///
/// Expected CSV format (AccountingTotalsInOut.csv):
/// Outlet, Business Day, Total In, Total Out, Total GGR
class CSVUploadWidget extends ConsumerStatefulWidget {
  const CSVUploadWidget({super.key});

  @override
  ConsumerState<CSVUploadWidget> createState() => _CSVUploadWidgetState();
}

class _CSVUploadWidgetState extends ConsumerState<CSVUploadWidget> {
  List<List<dynamic>>? _csvData;
  String? _fileName;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickAndReadCSV() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Pick CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();
        
        // Parse CSV
        final csvConverter = const CsvToListConverter();
        final csvData = csvConverter.convert(csvString);

        setState(() {
          _csvData = csvData;
          _fileName = result.files.single.name;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error reading CSV: $e';
        _isLoading = false;
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

    setState(() => _isLoading = true);

    try {
      // Get database instance
      final db = ref.read(databaseProvider);

      // Create import service
      final importService = CSVImportService(db);

      // Import CSV data with GGR calculations
      final result = await importService.importCSVData(_csvData!);

      if (mounted) {
        if (result.isSuccess) {
          // Show success dialog with statistics
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('✅ Import Successful!'),
              content: SingleChildScrollView(
                child: Text(result.summary),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _csvData = null;
                      _fileName = null;
                      _isLoading = false;
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Show errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import completed with ${result.errorCount} errors'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  String _formatCellValue(dynamic value, int columnIndex) {
    if (value == null) return '';
    
    // Date column (index 0)
    if (columnIndex == 0) {
      try {
        // Parse MM/DD/YYYY format
        final dateFormat = DateFormat('MM/dd/yyyy');
        final date = dateFormat.parse(value.toString());
        return DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        return value.toString();
      }
    }
    
    // Amount columns (index 2, 3, 4)
    if (columnIndex >= 2 && columnIndex <= 4) {
      try {
        final amount = double.parse(value.toString());
        final numberFormat = NumberFormat('#,##0', 'en_US');
        return 'UGX ${numberFormat.format(amount)}';
      } catch (e) {
        return value.toString();
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
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.upload_file,
                  size: 28,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Outlet Machine Data',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Import CSV data from betting machines to populate revenue and expenses',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_csvData == null)
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _pickAndReadCSV,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Select CSV File'),
                  ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => setState(() => _errorMessage = null),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_csvData == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No file selected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CSV Format: Outlet, Business Day (m/d/yyyy), Total In, Total Out, Total GGR',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // File info and actions
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withOpacity(0.05),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileName ?? 'Unknown file',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_csvData!.length - 1} data rows',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _csvData = null;
                          _fileName = null;
                        }),
                        icon: const Icon(Icons.close),
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

                // Data preview table
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          AppColors.primary.withOpacity(0.1),
                        ),
                        columns: _csvData![0]
                            .map((header) => DataColumn(
                                  label: Text(
                                    header.toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ))
                            .toList(),
                        rows: _csvData!
                            .skip(1)
                            .take(20) // Show first 20 rows
                            .map((row) => DataRow(
                                  cells: row
                                      .asMap()
                                      .entries
                                      .map((entry) => DataCell(
                                            Text(_formatCellValue(
                                              entry.value,
                                              entry.key,
                                            )),
                                          ))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),

                if (_csvData!.length > 21)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Showing first 20 rows of ${_csvData!.length - 1} total rows',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
