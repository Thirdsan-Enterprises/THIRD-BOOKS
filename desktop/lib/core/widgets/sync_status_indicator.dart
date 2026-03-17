import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncServiceProvider);

    return Tooltip(
      message: _getTooltipMessage(connectivity, syncState),
      child: InkWell(
        onTap: () => _showSyncDialog(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _getBackgroundColor(connectivity, syncState).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIcon(connectivity, syncState),
              const SizedBox(width: 8),
              _buildStatusText(connectivity, syncState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ConnectivityState connectivity, SyncState syncState) {
    if (syncState.isSyncing) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
        ),
      );
    }

    if (connectivity.isOffline) {
      return const Icon(
        Icons.cloud_off,
        size: 18,
        color: AppColors.warning,
      );
    }

    if (syncState.pendingChanges > 0) {
      return Stack(
        children: [
          const Icon(
            Icons.cloud_upload,
            size: 18,
            color: AppColors.warning,
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.expense,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${syncState.pendingChanges}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const Icon(
      Icons.cloud_done,
      size: 18,
      color: AppColors.income,
    );
  }

  Widget _buildStatusText(ConnectivityState connectivity, SyncState syncState) {
    String text;
    Color color;

    if (syncState.isSyncing) {
      text = 'Syncing...';
      color = AppColors.info;
    } else if (connectivity.isOffline) {
      text = 'Offline';
      color = AppColors.warning;
    } else if (syncState.pendingChanges > 0) {
      text = '${syncState.pendingChanges} pending';
      color = AppColors.warning;
    } else {
      text = 'Synced';
      color = AppColors.income;
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Color _getBackgroundColor(ConnectivityState connectivity, SyncState syncState) {
    if (syncState.isSyncing) return AppColors.info;
    if (connectivity.isOffline) return AppColors.warning;
    if (syncState.pendingChanges > 0) return AppColors.warning;
    return AppColors.income;
  }

  String _getTooltipMessage(ConnectivityState connectivity, SyncState syncState) {
    final buffer = StringBuffer();

    if (connectivity.isOnline) {
      buffer.writeln('Connected to server');
    } else {
      buffer.writeln('Working offline — changes will sync when reconnected');
      if (connectivity.lastError != null) {
        buffer.writeln('(${connectivity.lastError})');
      }
    }

    if (syncState.pendingChanges > 0) {
      buffer.writeln('${syncState.pendingChanges} changes waiting to sync');
    }

    if (syncState.lastSyncTime != null) {
      buffer.write('Last synced: ${DateFormat('MMM d, HH:mm').format(syncState.lastSyncTime!)}');
    }

    return buffer.toString().trim();
  }

  void _showSyncDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _SyncDialog(),
    );
  }
}

class _SyncDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncServiceProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            connectivity.isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: connectivity.isOnline ? AppColors.income : AppColors.warning,
          ),
          const SizedBox(width: 12),
          const Text('Sync Status'),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow(
              'Connection',
              connectivity.isOnline ? 'Online' : 'Offline',
              connectivity.isOnline ? AppColors.income : AppColors.warning,
            ),
            const Divider(),
            _buildStatusRow(
              'Pending Changes',
              syncState.pendingChanges.toString(),
              syncState.pendingChanges > 0 ? AppColors.warning : AppColors.income,
            ),
            const Divider(),
            _buildStatusRow(
              'Last Synced',
              syncState.lastSyncTime != null
                  ? DateFormat('MMM d, yyyy HH:mm').format(syncState.lastSyncTime!)
                  : 'Never',
              null,
            ),
            if (syncState.isSyncing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: syncState.progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Syncing... ${(syncState.progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (syncState.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.expense, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncState.error!,
                        style: const TextStyle(
                          color: AppColors.expense,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!syncState.isSyncing)
          FilledButton.icon(
            onPressed: connectivity.isOnline
                ? () {
                    ref.read(syncServiceProvider.notifier).syncAll();
                  }
                : null,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Sync Now'),
          ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Compact version for status bar
class SyncStatusCompact extends ConsumerWidget {
  const SyncStatusCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final syncState = ref.watch(syncServiceProvider);

    IconData icon;
    Color color;

    if (syncState.isSyncing) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
        ),
      );
    } else if (connectivity.isOffline) {
      icon = Icons.cloud_off;
      color = AppColors.warning;
    } else if (syncState.pendingChanges > 0) {
      icon = Icons.cloud_upload;
      color = AppColors.warning;
    } else {
      icon = Icons.cloud_done;
      color = AppColors.income;
    }

    return Icon(icon, size: 18, color: color);
  }
}
