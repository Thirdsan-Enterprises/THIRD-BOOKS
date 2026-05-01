import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
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

        // CSV Upload Widget
        const Expanded(
          child: SingleChildScrollView(
            child: CSVUploadWidget(),
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
