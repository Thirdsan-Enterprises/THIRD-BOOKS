import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sync/sync_service.dart';
import '../../core/api/api_client.dart';

// Server Sync Status Provider
final serverSyncStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return await ref.watch(syncServiceProvider.notifier).getSyncStatus();
});

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncServiceProvider);
    final serverStatusAsync = ref.watch(serverSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(serverSyncStatusProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serverSyncStatusProvider);
          await ref.read(syncServiceProvider.notifier).sync();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Local Sync Status
            _buildStatusCard(
              context,
              'Local Sync Status',
              [
                _buildStatusRow(
                  'Status',
                  _getSyncStatusText(syncState.status),
                  _getSyncStatusColor(syncState.status),
                ),
                if (syncState.lastSyncAt != null)
                  _buildStatusRow(
                    'Last Sync',
                    _formatDateTime(syncState.lastSyncAt!),
                    null,
                  ),
                if (syncState.lastSyncedSequence != null)
                  _buildStatusRow(
                    'Last Sequence',
                    syncState.lastSyncedSequence.toString(),
                    null,
                  ),
                _buildStatusRow(
                  'Pending Events',
                  syncState.pendingEventsCount.toString(),
                  syncState.pendingEventsCount > 0 ? Colors.orange : Colors.green,
                ),
                _buildStatusRow(
                  'Conflicts',
                  syncState.conflictsCount.toString(),
                  syncState.conflictsCount > 0 ? Colors.red : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Server Sync Status
            serverStatusAsync.when(
              data: (serverStatus) => _buildStatusCard(
                context,
                'Server Sync Status',
                [
                  _buildStatusRow(
                    'Device ID',
                    serverStatus['device_id'] ?? 'Unknown',
                    null,
                  ),
                  _buildStatusRow(
                    'Total Events',
                    serverStatus['total_events']?.toString() ?? '0',
                    null,
                  ),
                  _buildStatusRow(
                    'Unsynced Events',
                    serverStatus['unsynced_events']?.toString() ?? '0',
                    (serverStatus['unsynced_events'] ?? 0) > 0 ? Colors.orange : Colors.green,
                  ),
                  _buildStatusRow(
                    'Is Synced',
                    (serverStatus['is_synced'] ?? false) ? 'Yes' : 'No',
                    (serverStatus['is_synced'] ?? false) ? Colors.green : Colors.orange,
                  ),
                  if (serverStatus['last_sync_at'] != null)
                    _buildStatusRow(
                      'Last Server Sync',
                      _formatDateTime(DateTime.parse(serverStatus['last_sync_at'])),
                      null,
                    ),
                ],
              ),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Status Error',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sync Actions
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: syncState.status == SyncStatus.syncing
                  ? null
                  : () async {
                      await ref.read(syncServiceProvider.notifier).sync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Full sync completed')),
                        );
                      }
                    },
              icon: const Icon(Icons.sync),
              label: const Text('Full Sync'),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: syncState.status == SyncStatus.syncing
                  ? null
                  : () async {
                      await ref.read(syncServiceProvider.notifier).push();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Push completed')),
                        );
                      }
                    },
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Push to Server'),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: syncState.status == SyncStatus.syncing
                  ? null
                  : () async {
                      await ref.read(syncServiceProvider.notifier).pull();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pull completed')),
                        );
                      }
                    },
              icon: const Icon(Icons.cloud_download),
              label: const Text('Pull from Server'),
            ),

            if (syncState.errorMessage != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Sync Error',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        syncState.errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getSyncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Success';
      case SyncStatus.error:
        return 'Error';
    }
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }
}
