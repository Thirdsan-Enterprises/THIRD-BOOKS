import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/providers/local_outlet_csv_uploads_provider.dart';
import 'csv_upload_widget.dart';

/// Dedicated Upload Screen for CSV data import
///
/// Appears as a separate tab under the OUTLETS section in the sidebar.
/// Shows import history and provides the CSV upload interface.
class OutletUploadScreen extends ConsumerWidget {
  const OutletUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletsAsync = ref.watch(outletsStreamProvider);
    final revenuesAsync = ref.watch(allOutletRevenuesProvider);
    final numberFormat = NumberFormat('#,##0', 'en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title Bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CSV Data Upload',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Import outlet machine data from CSV files',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stats cards
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _buildStatCard(
                context,
                icon: Icons.store,
                label: 'Total Outlets',
                value: outletsAsync.when(
                  data: (outlets) => outlets.length.toString(),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                icon: Icons.receipt_long,
                label: 'Revenue Records',
                value: revenuesAsync.when(
                  data: (revenues) => numberFormat.format(revenues.length),
                  loading: () => '...',
                  error: (_, __) => '0',
                ),
                color: AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                icon: Icons.trending_up,
                label: 'Total GGR',
                value: revenuesAsync.when(
                  data: (revenues) {
                    final totalGGR = revenues.fold<double>(
                      0.0,
                      (sum, r) => sum + r.netAmount,
                    );
                    return 'UGX ${numberFormat.format(totalGGR)}';
                  },
                  loading: () => '...',
                  error: (_, __) => 'UGX 0',
                ),
                color: AppColors.info,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                icon: Icons.date_range,
                label: 'Date Range',
                value: revenuesAsync.when(
                  data: (revenues) {
                    if (revenues.isEmpty) return 'No data';
                    final dates = revenues.map((r) => r.date).toList()..sort();
                    final fmt = DateFormat('MMM yyyy');
                    return '${fmt.format(dates.first)} - ${fmt.format(dates.last)}';
                  },
                  loading: () => '...',
                  error: (_, __) => 'No data',
                ),
                color: AppColors.warning,
              ),
            ],
          ),
        ),

        // CSV Upload Widget + Upload History
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const CSVUploadWidget(),
                const _UploadHistorySection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload History Section
// ---------------------------------------------------------------------------

class _UploadHistorySection extends ConsumerWidget {
  const _UploadHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploads = ref.watch(localOutletCsvUploadsProvider);
    final numberFormat = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('d MMM yyyy, HH:mm');
    final rangeFmt = DateFormat('d MMM yyyy');

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                const Icon(Icons.history, size: 24, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload History',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Previously imported CSV files. Delete to fully reverse an upload and its journal entries.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          if (uploads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No upload history',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Imported CSV files will appear here.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: uploads.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (context, index) {
                final upload = uploads[index];

                String dateRange = '';
                if (upload.fromDate != null && upload.toDate != null) {
                  dateRange =
                      '${rangeFmt.format(upload.fromDate!)} – ${rangeFmt.format(upload.toDate!)}';
                } else if (upload.fromDate != null) {
                  dateRange = rangeFmt.format(upload.fromDate!);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      // File icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.description,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),

                      // File name + upload time
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              upload.fileName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFmt.format(upload.uploadedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date range
                      if (dateRange.isNotEmpty)
                        Expanded(
                          flex: 3,
                          child: Text(
                            dateRange,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),

                      // Row count
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${numberFormat.format(upload.successCount)} rows',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                            if (upload.skippedCount > 0)
                              Text(
                                '${upload.skippedCount} skipped',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline),
                              ),
                          ],
                        ),
                      ),

                      // GGR total
                      Expanded(
                        flex: 2,
                        child: Text(
                          'UGX ${numberFormat.format(upload.totalGGR)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace'),
                        ),
                      ),

                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error, size: 20),
                        tooltip: 'Delete upload and reverse all its journal entries',
                        onPressed: () =>
                            _confirmDelete(context, ref, upload),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LocalOutletCsvUpload upload,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Upload?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete the import "${upload.fileName}" '
              'and reverse everything it created:',
            ),
            const SizedBox(height: 12),
            const Text('  • All outlet revenue rows from this import'),
            const Text('  • All daily journal entries from this import'),
            const Text('  • All commission JEs (regenerated from remaining data)'),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(csvImportProvider.notifier)
          .deleteOutletCsvUpload(upload);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Upload "${upload.fileName}" deleted and all its journal entries reversed.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete upload: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
