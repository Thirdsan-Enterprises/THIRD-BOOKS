import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/sync/sync_service.dart';
import '../../core/api/api_client.dart';

// Dashboard Stats Provider
final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getDashboardStats();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(syncServiceProvider);
    final dashboardStats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Sync Status Indicator
          IconButton(
            icon: Icon(
              syncState.status == SyncStatus.syncing
                  ? Icons.sync
                  : syncState.status == SyncStatus.error
                      ? Icons.sync_problem
                      : Icons.cloud_done,
              color: syncState.status == SyncStatus.error
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: () {
              context.push('/sync-status');
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          await ref.read(syncServiceProvider.notifier).sync();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${authState.user?['name'] ?? 'User'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authState.tenant?['name'] ?? 'Company',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sync Status Card
            Card(
              color: syncState.status == SyncStatus.error
                  ? Colors.red.shade50
                  : syncState.conflictsCount > 0
                      ? Colors.orange.shade50
                      : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          syncState.status == SyncStatus.syncing
                              ? Icons.sync
                              : syncState.status == SyncStatus.error
                                  ? Icons.error
                                  : Icons.check_circle,
                          color: syncState.status == SyncStatus.error
                              ? Colors.red
                              : syncState.conflictsCount > 0
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Status',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (syncState.lastSyncAt != null)
                                Text(
                                  'Last synced: ${_formatTime(syncState.lastSyncAt!)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => context.push('/sync-status'),
                        ),
                      ],
                    ),
                    if (syncState.pendingEventsCount > 0 ||
                        syncState.conflictsCount > 0) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          if (syncState.pendingEventsCount > 0)
                            Expanded(
                              child: _buildInfoChip(
                                'Pending: ${syncState.pendingEventsCount}',
                                Colors.blue,
                              ),
                            ),
                          if (syncState.conflictsCount > 0) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => context.push('/conflicts'),
                                child: _buildInfoChip(
                                  'Conflicts: ${syncState.conflictsCount}',
                                  Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dashboard Stats
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            dashboardStats.when(
              data: (stats) => _buildStatsGrid(stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load stats: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(syncServiceProvider.notifier).sync();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync completed')),
          );
        },
        child: const Icon(Icons.sync),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Invoices',
          stats['invoices_count']?.toString() ?? '0',
          Icons.receipt_long,
          Colors.blue,
        ),
        _buildStatCard(
          'Bills',
          stats['bills_count']?.toString() ?? '0',
          Icons.description,
          Colors.purple,
        ),
        _buildStatCard(
          'Revenue',
          '\$${_formatCurrency(stats['total_revenue'] ?? 0)}',
          Icons.trending_up,
          Colors.green,
        ),
        _buildStatCard(
          'Expenses',
          '\$${_formatCurrency(stats['total_expenses'] ?? 0)}',
          Icons.trending_down,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final value = amount is String ? double.tryParse(amount) ?? 0 : amount.toDouble();
    return NumberFormat('#,##0.00').format(value);
  }
}
