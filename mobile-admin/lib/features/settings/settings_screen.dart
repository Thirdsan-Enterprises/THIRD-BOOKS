import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(syncServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User Section
          _SectionHeader('Account'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      authState.user?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  title: Text(authState.user?['name'] ?? 'User'),
                  subtitle: Text(authState.user?['email'] ?? ''),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Tenant'),
                  subtitle: Text(authState.tenant?['name'] ?? 'Not set'),
                ),
              ],
            ),
          ),

          // Sync Section
          _SectionHeader('Synchronization'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    syncState.status == SyncStatus.syncing ? Icons.sync : Icons.cloud_done,
                    color: _getSyncStatusColor(syncState.status),
                  ),
                  title: const Text('Sync Status'),
                  subtitle: Text(_getSyncStatusText(syncState)),
                  trailing: syncState.status == SyncStatus.syncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pending_actions),
                  title: const Text('Pending Events'),
                  trailing: Text('${syncState.pendingEventsCount}', style: theme.textTheme.titleMedium),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text('Conflicts'),
                  trailing: Text(
                    '${syncState.conflictsCount}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: syncState.conflictsCount > 0 ? theme.colorScheme.error : null,
                    ),
                  ),
                  onTap: syncState.conflictsCount > 0 ? () => Navigator.pushNamed(context, '/conflicts') : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Manual Sync'),
                  subtitle: const Text('Sync data with server'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ref.read(syncServiceProvider.notifier).fullSync(),
                ),
              ],
            ),
          ),

          // Data Management
          _SectionHeader('Data Management'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Export Data'),
                  subtitle: const Text('Export all data to file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Import Data'),
                  subtitle: const Text('Import data from file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showImportDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                  title: Text('Clear Local Data', style: TextStyle(color: theme.colorScheme.error)),
                  subtitle: const Text('Delete all cached data'),
                  trailing: _isClearing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _isClearing ? null : () => _showClearDataDialog(context),
                ),
              ],
            ),
          ),

          // App Settings
          _SectionHeader('App Settings'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme'),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (value) {
                    // TODO: Implement theme switching
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Theme switching coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Language selection coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Default Currency'),
                  subtitle: const Text('UGX - Ugandan Shilling'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyDialog(context),
                ),
              ],
            ),
          ),

          // About
          _SectionHeader('About'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
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

  String _getSyncStatusText(SyncState state) {
    if (state.lastSyncAt == null) return 'Never synced';
    final diff = DateTime.now().difference(state.lastSyncAt!);
    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours} hours ago';
    return 'Synced ${diff.inDays} days ago';
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('This will export all your local data to a JSON file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('This will import data from a JSON file. Existing data may be overwritten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import feature coming soon')),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Local Data'),
        content: const Text(
          'This will delete all locally cached data. Your data on the server will not be affected. '
          'You will need to sync again to restore data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isClearing = true);
              try {
                final db = ref.read(appDatabaseProvider);
                await db.clearAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local data cleared')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isClearing = false);
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('UGX - Ugandan Shilling'),
            trailing: const Icon(Icons.check),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            title: const Text('USD - US Dollar'),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Currency changed to USD')),
              );
            },
          ),
          ListTile(
            title: const Text('EUR - Euro'),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Currency changed to EUR')),
              );
            },
          ),
          ListTile(
            title: const Text('KES - Kenyan Shilling'),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Currency changed to KES')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? Any unsynced data will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
