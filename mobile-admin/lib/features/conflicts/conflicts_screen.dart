import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

// Conflicts Provider
final conflictsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getConflicts(status: 'pending');
});

final conflictStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getConflictStatistics();
});

class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(conflictsProvider);
    final statsAsync = ref.watch(conflictStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflicts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(conflictsProvider);
              ref.invalidate(conflictStatsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conflictsProvider);
          ref.invalidate(conflictStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statistics
            statsAsync.when(
              data: (stats) => _buildStatistics(context, stats),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $error'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Conflicts List
            Text(
              'Pending Conflicts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            conflictsAsync.when(
              data: (data) {
                final conflicts = data['data'] as List<dynamic>? ?? [];

                if (conflicts.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'No pending conflicts',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All sync conflicts have been resolved',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: conflicts.map((conflict) {
                    return _buildConflictCard(context, ref, conflict);
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load conflicts: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(BuildContext context, Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflict Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    stats['total']?.toString() ?? '0',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Pending',
                    stats['pending']?.toString() ?? '0',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Resolved',
                    stats['resolved']?.toString() ?? '0',
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildConflictCard(BuildContext context, WidgetRef ref, Map<String, dynamic> conflict) {
    final conflictType = conflict['conflict_type'] as String?;
    final aggregateType = conflict['aggregate_type'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBadge(conflictType ?? '', Colors.purple),
                const SizedBox(width: 8),
                _buildBadge(aggregateType ?? '', Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Aggregate ID: ${conflict['aggregate_id']}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Text(
              'Devices: ${conflict['server_device_id'] ?? 'Server'} ⟷ ${conflict['client_device_id']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolveConflict(context, ref, conflict['id'], 'server'),
                    child: const Text('Use Server'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolveConflict(context, ref, conflict['id'], 'client'),
                    child: const Text('Use Client'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    String conflictId,
    String strategy,
  ) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.resolveConflict(conflictId, strategy);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conflict resolved')),
        );
      }

      // Refresh list
      ref.invalidate(conflictsProvider);
      ref.invalidate(conflictStatsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
