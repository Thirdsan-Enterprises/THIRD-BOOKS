import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/company_settings_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/api_client.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/local_backup_service.dart';
import '../../core/services/snapshot_service.dart';
import '../../core/services/data_service.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/local_bank_statements_provider.dart';
import '../../core/providers/local_outlet_csv_uploads_provider.dart';
import '../../core/providers/asset_drafts_provider.dart';
import '../../core/providers/depreciation_schedules_provider.dart';
import '../../core/providers/local_attachments_provider.dart';
import '../../core/services/server_sync_service.dart';
import '../../core/database/app_database.dart';
import '../banking/banking_screen.dart' show bankTransactionsProvider;
import '../outlets/outlet_settled_screen.dart' show outletSettlementsProvider;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedSection = 0;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Company Profile', 'icon': Icons.business},
    {'title': 'Users & Permissions', 'icon': Icons.people},
    {'title': 'Chart of Accounts', 'icon': Icons.account_tree},
    {'title': 'Tax Settings', 'icon': Icons.calculate},
    {'title': 'Currency & Localization', 'icon': Icons.language},
    {'title': 'Invoice Settings', 'icon': Icons.receipt_long},
    {'title': 'Sync & Backup', 'icon': Icons.sync},
    {'title': 'Appearance', 'icon': Icons.palette},
    {'title': 'Restore Points', 'icon': Icons.history},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Settings Navigation Sidebar
          Container(
            width: 280,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      final isSelected = _selectedSection == index;
                      return ListTile(
                        leading: Icon(
                          section['icon'],
                          color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(
                          section['title'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : null,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onTap: () => setState(() => _selectedSection = index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Settings Content
          Expanded(
            child: _buildSettingsContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    switch (_selectedSection) {
      case 0:
        return _buildCompanyProfile(context);
      case 1:
        return _buildUsersPermissions(context);
      case 2:
        return _buildChartOfAccountsSettings(context);
      case 3:
        return _buildTaxSettings(context);
      case 4:
        return _buildCurrencySettings(context);
      case 5:
        return _buildInvoiceSettings(context);
      case 6:
        return _buildSyncSettings(context);
      case 7:
        return _buildAppearanceSettings(context);
      case 8:
        return _buildRestorePointsSettings(context);
      default:
        return _buildCompanyProfile(context);
    }
  }

  Widget _buildCompanyProfile(BuildContext context) {
    final settings = ref.watch(companySettingsProvider);

    final nameCtrl = TextEditingController(text: settings.companyName);
    final regCtrl = TextEditingController(text: settings.registrationNumber);
    final tinCtrl = TextEditingController(text: settings.taxId);
    final emailCtrl = TextEditingController(text: settings.email);
    final phoneCtrl = TextEditingController(text: settings.phone);
    final websiteCtrl = TextEditingController(text: settings.website);
    final addressCtrl = TextEditingController(text: settings.address);
    String fiscalYear = settings.fiscalYearStart;
    String accountingMethod = settings.accountingMethod;

    return StatefulBuilder(
      builder: (context, setPageState) {
        final logoPath = settings.logoPath;

        Future<void> pickLogo() async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['png', 'jpg', 'jpeg'],
            dialogTitle: 'Select Company Logo',
          );
          if (result != null && result.files.single.path != null) {
            await ref.read(companySettingsProvider.notifier).save(
                  settings.copyWith(logoPath: result.files.single.path),
                );
            setPageState(() {});
          }
        }

        void saveProfile() {
          final updated = settings.copyWith(
            companyName: nameCtrl.text.trim(),
            registrationNumber: regCtrl.text.trim(),
            taxId: tinCtrl.text.trim(),
            email: emailCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            website: websiteCtrl.text.trim(),
            address: addressCtrl.text.trim(),
            fiscalYearStart: fiscalYear,
            accountingMethod: accountingMethod,
          );
          ref.read(companySettingsProvider.notifier).save(updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company profile saved successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Company Profile', 'Manage your business information'),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo Upload
                          Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: logoPath != null && File(logoPath).existsSync()
                                    ? Image.file(File(logoPath), fit: BoxFit.cover)
                                    : Icon(
                                        Icons.business,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: pickLogo,
                                icon: const Icon(Icons.upload, size: 18),
                                label: const Text('Upload Logo'),
                              ),
                              if (logoPath != null) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: () async {
                                    await ref
                                        .read(companySettingsProvider.notifier)
                                        .save(settings.copyWith(clearLogo: true));
                                    setPageState(() {});
                                  },
                                  icon: Icon(Icons.close, size: 14, color: AppColors.error),
                                  label: Text('Remove',
                                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 32),
                          // Company Details
                          Expanded(
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: nameCtrl,
                                  decoration: const InputDecoration(labelText: 'Company Name'),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: regCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Registration Number'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: tinCtrl,
                                        decoration:
                                            const InputDecoration(labelText: 'Tax ID (TIN)'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 48),
                      Text('Contact Information',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(labelText: 'Email'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(labelText: 'Phone'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: websiteCtrl,
                              decoration: const InputDecoration(labelText: 'Website'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              nameCtrl.text = settings.companyName;
                              regCtrl.text = settings.registrationNumber;
                              tinCtrl.text = settings.taxId;
                              emailCtrl.text = settings.email;
                              phoneCtrl.text = settings.phone;
                              websiteCtrl.text = settings.website;
                              addressCtrl.text = settings.address;
                              setPageState(() {});
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: saveProfile,
                            child: const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fiscal Year Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Fiscal Year Start'),
                              value: fiscalYear,
                              items: ['January', 'April', 'July', 'October']
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) => setPageState(() => fiscalYear = v ?? fiscalYear),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration:
                                  const InputDecoration(labelText: 'Accounting Method'),
                              value: accountingMethod,
                              items: ['Accrual', 'Cash']
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) =>
                                  setPageState(() => accountingMethod = v ?? accountingMethod),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: saveProfile,
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersPermissions(BuildContext context) {
    final api = ref.read(apiClientProvider);
    final connectivity = ref.watch(connectivityProvider);

    return StatefulBuilder(builder: (context, setS) {
      List<Map<String, dynamic>> users = [];
      bool loading = true;
      String? error;

      void loadUsers() {
        setS(() { loading = true; error = null; });
        api.listUsers().then((list) {
          setS(() { users = list; loading = false; });
        }).catchError((e) {
          setS(() { loading = false; error = e.toString(); });
        });
      }

      Future<void> showInviteDialog() async {
        final nameCtrl = TextEditingController();
        final emailCtrl = TextEditingController();
        final passCtrl = TextEditingController();
        String role = 'accountant';
        final formKey = GlobalKey<FormState>();

        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (ctx, setSd) => AlertDialog(
            title: const Text('Add Team Member'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *'),
                      validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v ?? '').contains('@') ? null : 'Valid email required',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Password *'),
                      obscureText: true,
                      validator: (v) => (v ?? '').length >= 8 ? null : 'Min 8 characters',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role *'),
                      items: const [
                        DropdownMenuItem(value: 'admin',       child: Text('Admin')),
                        DropdownMenuItem(value: 'accountant',  child: Text('Accountant')),
                        DropdownMenuItem(value: 'manager',     child: Text('Manager')),
                        DropdownMenuItem(value: 'user',        child: Text('Staff')),
                        DropdownMenuItem(value: 'viewer',      child: Text('Viewer (read-only)')),
                      ],
                      onChanged: (v) => setSd(() => role = v ?? role),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final newName  = nameCtrl.text.trim();
                  final newEmail = emailCtrl.text.trim();
                  final newPass  = passCtrl.text;
                  final newRole  = role;
                  Navigator.pop(ctx);
                  try {
                    await api.createUser(
                      name: newName,
                      email: newEmail,
                      password: newPass,
                      role: newRole,
                    );
                    loadUsers();
                    if (mounted) {
                      // Show shareable credentials dialog
                      final roleLabel = {
                        'admin': 'Admin', 'accountant': 'Accountant',
                        'manager': 'Manager', 'user': 'Staff', 'viewer': 'Viewer',
                      }[newRole] ?? newRole;
                      final appUrl = ApiConfig.baseUrl;
                      final shareText =
                          'Hi $newName,\n\n'
                          'Your ThirdBooks account has been created.\n\n'
                          'Login: $newEmail\n'
                          'Password: $newPass\n'
                          'Role: $roleLabel\n\n'
                          'Download & install ThirdBooks desktop app, then '
                          'sign in with the credentials above.\n\n'
                          'Server: $appUrl';
                      await showDialog(
                        context: context,
                        builder: (ctx2) => AlertDialog(
                          title: Row(children: [
                            Icon(Icons.check_circle, color: AppColors.success, size: 22),
                            const SizedBox(width: 8),
                            const Text('User Created'),
                          ]),
                          content: SizedBox(
                            width: 420,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Share these login credentials with the user '
                                  '(e.g. via WhatsApp):',
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: SelectableText(
                                    shareText,
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontSize: 13, height: 1.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx2),
                              child: const Text('Close'),
                            ),
                            FilledButton.icon(
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy to Clipboard'),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: shareText));
                                Navigator.pop(ctx2);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Credentials copied — paste into WhatsApp'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed to create user: $e'),
                        backgroundColor: AppColors.error,
                      ));
                    }
                  }
                },
                child: const Text('Create User'),
              ),
            ],
          )),
        );
      }

      Future<void> changeRole(Map<String, dynamic> user, String newRole) async {
        try {
          await api.updateUser(user['id'] as int, role: newRole);
          loadUsers();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to update role: $e'),
              backgroundColor: AppColors.error,
            ));
          }
        }
      }

      Future<void> toggleActive(Map<String, dynamic> user) async {
        final active = user['is_active'] as bool? ?? true;
        try {
          await api.updateUser(user['id'] as int, isActive: !active);
          loadUsers();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: AppColors.error,
            ));
          }
        }
      }

      Future<void> deleteUser(Map<String, dynamic> user) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove User'),
            content: Text('Remove ${user['name']} (${user['email']}) from this tenant?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (ok == true) {
          try {
            await api.deleteUser(user['id'] as int);
            loadUsers();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Failed: $e'),
                backgroundColor: AppColors.error,
              ));
            }
          }
        }
      }

      // Trigger initial load once
      if (loading && error == null && users.isEmpty) {
        Future.microtask(loadUsers);
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(context, 'Users & Permissions', 'Manage team access and roles'),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: loadUsers,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: connectivity.isOnline ? showInviteDialog : null,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add User'),
                  ),
                ]),
              ],
            ),
            if (!connectivity.isOnline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    const Text('Offline — user management requires an internet connection.',
                        style: TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: loadUsers, child: const Text('Retry')),
                ]),
              )
            else
              Card(
                child: users.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No users found. Add a team member above.')),
                      )
                    : DataTable(
                        columns: const [
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: users.map((user) {
                          final active = user['is_active'] as bool? ?? true;
                          final role = user['role'] as String? ?? 'user';
                          return DataRow(cells: [
                            DataCell(Row(children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  ((user['name'] as String?) ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text(user['email'] ?? '',
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                                ],
                              ),
                            ])),
                            DataCell(DropdownButton<String>(
                              value: ['admin', 'accountant', 'manager', 'user', 'viewer'].contains(role)
                                  ? role : 'user',
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'admin',      child: Text('Admin')),
                                DropdownMenuItem(value: 'accountant', child: Text('Accountant')),
                                DropdownMenuItem(value: 'manager',    child: Text('Manager')),
                                DropdownMenuItem(value: 'user',       child: Text('Staff')),
                                DropdownMenuItem(value: 'viewer',     child: Text('Viewer')),
                              ],
                              onChanged: connectivity.isOnline
                                  ? (v) { if (v != null) changeRole(user, v); }
                                  : null,
                            )),
                            DataCell(_buildStatusBadge(active ? 'Active' : 'Inactive')),
                            DataCell(Row(children: [
                              Tooltip(
                                message: active ? 'Deactivate' : 'Activate',
                                child: IconButton(
                                  icon: Icon(
                                    active ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                    size: 18,
                                    color: active ? AppColors.warning : AppColors.success,
                                  ),
                                  onPressed: connectivity.isOnline ? () => toggleActive(user) : null,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.error,
                                tooltip: 'Remove user',
                                onPressed: connectivity.isOnline ? () => deleteUser(user) : null,
                              ),
                            ])),
                          ]);
                        }).toList(),
                      ),
              ),
            const SizedBox(height: 32),
            Text('Role Permissions Matrix', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _PermissionRow('', []),                    // column headers
                  const Divider(height: 8),
                  _PermissionRow('View Dashboard & Reports', [true, true, true, true, true]),
                  _PermissionRow('Create & Edit Invoices',   [true, true, true, false, false]),
                  _PermissionRow('Create & Edit Bills',      [true, true, true, false, false]),
                  _PermissionRow('Post Journal Entries',     [true, true, false, false, false]),
                  _PermissionRow('Approve Payments',         [true, true, true, false, false]),
                  _PermissionRow('Bank Reconciliation',      [true, true, false, false, false]),
                  _PermissionRow('Manage Users',             [true, false, false, false, false]),
                  _PermissionRow('Company Settings',         [true, false, false, false, false]),
                  _PermissionRow('Export & Backup Data',     [true, true, false, false, false]),
                ]),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildChartOfAccountsSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Chart of Accounts', 'Configure account structure and defaults'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default Accounts', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _DefaultAccountRow('Sales Revenue', 'Revenue account for sales'),
                  _DefaultAccountRow('Cost of Goods Sold', 'Expense account for COGS'),
                  _DefaultAccountRow('Accounts Receivable', 'Asset account for receivables'),
                  _DefaultAccountRow('Accounts Payable', 'Liability account for payables'),
                  _DefaultAccountRow('Inventory', 'Asset account for inventory'),
                  _DefaultAccountRow('VAT Payable', 'Liability account for VAT'),
                  _DefaultAccountRow('Bank Account', 'Default bank account'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Account Number Format', style: Theme.of(context).textTheme.titleMedium),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Preview'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Format'),
                          value: '4-digit',
                          items: ['4-digit', '5-digit', '6-digit', 'Custom']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Example', enabled: false),
                          initialValue: '1000 - 9999',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(context, 'Tax Settings', 'Configure tax rates and rules'),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Tax Rate'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Tax Name')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Default')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                _buildTaxRow('VAT', '18%', 'Sales & Purchases', true),
                _buildTaxRow('Withholding Tax', '6%', 'Purchases', false),
                _buildTaxRow('Zero Rated', '0%', 'Sales', false),
                _buildTaxRow('Exempt', '0%', 'Sales & Purchases', false),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Builder(builder: (context) {
            final taxSettings = ref.watch(appSettingsProvider);
            final taxNotifier = ref.read(appSettingsProvider.notifier);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Tax Preferences', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.4)),
                          ),
                          child: const Text('Regulatory', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MagicBet Ltd is subject to Gaming Tax (15% GGR) handled automatically. '
                      'Standard 18% VAT applies only if separately registered with URA as a VAT-able trader. '
                      'Enable below only if advised by your accountant or URA.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Enable 18% VAT on invoices'),
                      subtitle: const Text('Adds URA 18% VAT to all customer invoices and bills — only activate if VAT-registered'),
                      value: taxSettings.enableVAT,
                      onChanged: (v) => taxNotifier.setEnableVAT(v),
                    ),
                    SwitchListTile(
                      title: const Text('Prices include tax'),
                      subtitle: const Text('Default prices entered include tax'),
                      value: taxSettings.pricesIncludeTax,
                      onChanged: (v) => taxNotifier.setPricesIncludeTax(v),
                    ),
                    SwitchListTile(
                      title: const Text('Show tax on invoices'),
                      subtitle: const Text('Display tax breakdown on printed invoices'),
                      value: taxSettings.showTaxOnInvoices,
                      onChanged: (v) => taxNotifier.setShowTaxOnInvoices(v),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          _buildAutoJECard(context),
        ],
      ),
    );
  }

  Widget _buildAutoJECard(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Text('Auto-Journalization', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'When enabled, the system automatically creates double-entry journal entries '
              'for the selected transactions. Disable any item to post entries manually instead.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
            const Divider(height: 28),
            SwitchListTile(
              title: const Text('Gaming Tax (GRB) — 15% of monthly GGR'),
              subtitle: const Text(
                'Auto-posts DR 108 Gaming Tax / CR 147 Gaming Tax Payable at month-end '
                'when CSV data is imported.',
              ),
              secondary: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: settings.autoGamingTaxJE
                      ? AppColors.success.withOpacity(0.12)
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  settings.autoGamingTaxJE ? 'AUTO' : 'MANUAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: settings.autoGamingTaxJE
                        ? AppColors.success
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              value: settings.autoGamingTaxJE,
              onChanged: (v) => notifier.setAutoGamingTaxJE(v),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Payroll — Employer NSSF (10% of gross salary)'),
              subtitle: const Text(
                'Auto-posts DR 135 Employer NSSF / CR 149 NSSF Payable whenever a '
                'journal entry debiting account 132 (Salaries) is posted. '
                'PAYE and employee NSSF (5%) amounts are noted in the entry description.',
              ),
              secondary: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: settings.autoPayrollNSSFJE
                      ? AppColors.success.withOpacity(0.12)
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  settings.autoPayrollNSSFJE ? 'AUTO' : 'MANUAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: settings.autoPayrollNSSFJE
                        ? AppColors.success
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              value: settings.autoPayrollNSSFJE,
              onChanged: (v) => notifier.setAutoPayrollNSSFJE(v),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Withholding Tax (WHT) — 6% on supplier payments'),
              subtitle: const Text(
                'Auto-posts DR 144 Withholding Tax / CR 146 WHT Payable — Suppliers '
                'when a bill payment is recorded for a WHT-liable vendor.',
              ),
              secondary: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: settings.autoWHTJE
                      ? AppColors.success.withOpacity(0.12)
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  settings.autoWHTJE ? 'AUTO' : 'MANUAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: settings.autoWHTJE
                        ? AppColors.success
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              value: settings.autoWHTJE,
              onChanged: (v) => notifier.setAutoWHTJE(v),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Settings take effect immediately. Turning off auto-journalization does not '
                      'reverse previously created entries. Use the Journal Entries screen to '
                      'void any unwanted auto-entries.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySettings(BuildContext context) {
    final currencySettings = ref.watch(appSettingsProvider);
    final currencyNotifier = ref.read(appSettingsProvider.notifier);

    // Map display strings ↔ currency codes
    const currencyOptions = {
      'UGX - Ugandan Shilling': 'UGX',
      'USD - US Dollar': 'USD',
      'EUR - Euro': 'EUR',
      'GBP - British Pound': 'GBP',
      'KES - Kenyan Shilling': 'KES',
      'TZS - Tanzanian Shilling': 'TZS',
    };
    final currentCurrencyDisplay = currencyOptions.entries
        .firstWhere((e) => e.value == currencySettings.currency,
            orElse: () => const MapEntry('UGX - Ugandan Shilling', 'UGX'))
        .key;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Currency & Localization', 'Configure currency and regional settings'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Primary Currency', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Base Currency'),
                          value: currentCurrencyDisplay,
                          items: currencyOptions.keys
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              currencyNotifier.setCurrency(currencyOptions[v] ?? 'UGX');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Date Format'),
                          value: currencySettings.dateFormat,
                          items: ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd', 'd MMM yyyy']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) currencyNotifier.setDateFormat(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exchange Rate Feed', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the URL of an exchange-rate API. Rates are fetched on demand and can be overridden per transaction.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Exchange Rate API URL',
                            hintText:
                                'https://api.exchangerate-api.com/v4/latest/UGX',
                            prefixIcon: Icon(Icons.link, size: 20),
                          ),
                          initialValue:
                              'https://api.exchangerate-api.com/v4/latest/UGX',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Fetching latest rates...')),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Fetch Now'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Allow manual rate override on billing'),
                    subtitle: const Text(
                        'Users can adjust the rate when creating invoices or bills'),
                    value: true,
                    onChanged: (v) {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Multi-Currency Support', style: Theme.of(context).textTheme.titleMedium),
                      Switch(value: true, onChanged: (v) {}),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Active Currencies', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: const Text('UGX'), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () {}),
                      Chip(label: const Text('USD'), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () {}),
                      Chip(label: const Text('EUR'), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () {}),
                      ActionChip(label: const Text('+ Add Currency'), onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Regional Settings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Date Format'),
                          value: 'DD/MM/YYYY',
                          items: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Time Zone'),
                          value: 'Africa/Kampala (UTC+3)',
                          items: [
                            'Africa/Kampala (UTC+3)',
                            'Africa/Nairobi (UTC+3)',
                            'Africa/Dar_es_Salaam (UTC+3)',
                            'UTC',
                          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Currency & localization settings saved'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: const Text('Save Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Invoice Settings', 'Customize invoice appearance and defaults'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice Numbering', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Prefix'),
                          initialValue: 'INV-',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Next Number'),
                          initialValue: '2026-001',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Reset'),
                          value: 'Yearly',
                          items: ['Never', 'Monthly', 'Yearly']
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Preview: INV-2026-001', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default Terms', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Payment Terms'),
                          value: 'Net 30',
                          items: ['Due on Receipt', 'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Default Tax'),
                          value: 'VAT (18%)',
                          items: ['None', 'VAT (18%)', 'Zero Rated', 'Exempt']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Default Notes / Terms & Conditions'),
                    maxLines: 3,
                    initialValue: 'Payment is due within 30 days. Please include invoice number with your payment.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invoice settings saved'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: const Text('Save Invoice Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSettings(BuildContext context) {
    Future<void> _confirmResetLocalData() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Reset All Local Data?'),
          ]),
          content: const Text(
              'This will permanently delete all data stored on this device — '
              'outlet records, journals, invoices and everything else.\n\n'
              'Export a backup first if you need to keep a copy.\n\n'
              'This action CANNOT be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset Device Data'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await ref.read(syncServiceProvider.notifier).clearLocalCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('All local data has been reset.'),
            backgroundColor: AppColors.success,
          ));
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Backup & Data Transfer',
              'Export your data to share with another computer via USB or email'),
          const SizedBox(height: 24),

          // ── Manual Sync Info Card ─────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.swap_horiz, color: AppColors.secondary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Manual Sync Supported', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Data is shared between computers using backup files — no internet required.',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const _ManualSyncStep(step: '1', title: 'Accountant exports a backup',
                      detail: 'On the accountant\'s computer, go to Export Backup below and save the .thirdbooks file to a USB drive or send by email.'),
                  const _ManualSyncStep(step: '2', title: 'Transfer to boss\'s computer',
                      detail: 'Plug in the USB drive (or open the email attachment) on the boss\'s computer.'),
                  const _ManualSyncStep(step: '3', title: 'Boss imports the backup',
                      detail: 'Open ThirdBooks, go to Import Backup below and select the .thirdbooks file. All records will load instantly.'),
                  const _ManualSyncStep(step: '4', title: 'View and review',
                      detail: 'The boss can browse all outlets, revenues, reports and journals — no login required when offline.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Local Backup & Restore Card ───────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.save_alt, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Backup & Restore', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Export ALL data (outlets, revenues, expenditures, journals, invoices…) '
                          'to a single .thirdbooks file. Import it on any machine to restore or share.',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        final backup = LocalBackupService(LocalStorageService.instance, db);
                        try {
                          final result = await backup.exportBackup();
                          if (result == null) return;
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Row(children: [
                                const Icon(Icons.check_circle, color: AppColors.success),
                                const SizedBox(width: 8),
                                const Text('Backup Created'),
                              ]),
                              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Saved to:\n${result.filePath}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                ...result.counts.entries
                                    .where((e) => e.value > 0)
                                    .map((e) => Text('${e.key.replaceAll('_', ' ')}: ${e.value}',
                                        style: const TextStyle(fontSize: 13))),
                                const SizedBox(height: 8),
                                Text('Total: ${result.totalRecords} records',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              actions: [
                                FilledButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Done')),
                              ],
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Export failed: $e'),
                              backgroundColor: AppColors.error,
                            ));
                          }
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export Backup'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          dialogTitle: 'Select ThirdBooks Backup',
                          type: FileType.any,
                        );
                        if (picked == null || picked.files.single.path == null) return;
                        final filePath = picked.files.single.path!;

                        final db = ref.read(databaseProvider);
                        final backup = LocalBackupService(LocalStorageService.instance, db);
                        try {
                          final preview = await backup.previewRestoreFromPath(filePath);
                          if (!mounted) return;
                          if (preview.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(preview.error!),
                              backgroundColor: AppColors.error,
                            ));
                            return;
                          }

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Import Backup?'),
                              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Exported: ${preview.exportedAt}'),
                                const SizedBox(height: 12),
                                const Text('This will OVERWRITE all current local data with:'),
                                const SizedBox(height: 8),
                                ...preview.counts.entries
                                    .where((e) => e.value > 0)
                                    .map((e) => Text('  • ${e.key.replaceAll('_', ' ')}: ${e.value}',
                                        style: const TextStyle(fontSize: 13))),
                                const SizedBox(height: 8),
                                Text('Total: ${preview.totalRecords} records',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Import & Overwrite'),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true || !mounted) return;
                          final result = await backup.restoreFromFile(filePath);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Restored ${result.totalRecords} records successfully'),
                              backgroundColor: AppColors.success,
                            ));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Import failed: $e'),
                              backgroundColor: AppColors.error,
                            ));
                          }
                        }
                      },
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Import Backup'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Server Backup Card ────────────────────────────────────────────
          const _ServerBackupCard(),
          const SizedBox(height: 24),

          // ── Danger Zone Card ──────────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppColors.error.withOpacity(0.4), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.dangerous_outlined, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Danger Zone',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.error)),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'Permanently delete all data stored on this device. '
                    'Export a backup first if you need to keep a copy.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                    onPressed: _confirmResetLocalData,
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Reset All Local Data'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings(BuildContext context) {
    final currentTheme = ref.watch(themeModeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Appearance', 'Customize the look and feel'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ThemeOption(
                        label: 'Light',
                        icon: Icons.light_mode,
                        isSelected: currentTheme == ThemeMode.light,
                        onTap: () {
                          ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                        },
                      ),
                      const SizedBox(width: 16),
                      _ThemeOption(
                        label: 'Dark',
                        icon: Icons.dark_mode,
                        isSelected: currentTheme == ThemeMode.dark,
                        onTap: () {
                          ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                        },
                      ),
                      const SizedBox(width: 16),
                      _ThemeOption(
                        label: 'System',
                        icon: Icons.settings_brightness,
                        isSelected: currentTheme == ThemeMode.system,
                        onTap: () {
                          ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accent Color', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ColorOption(color: AppColors.primary, isSelected: true),
                      _ColorOption(color: AppColors.secondary, isSelected: false),
                      _ColorOption(color: Colors.indigo, isSelected: false),
                      _ColorOption(color: Colors.purple, isSelected: false),
                      _ColorOption(color: Colors.orange, isSelected: false),
                      _ColorOption(color: Colors.pink, isSelected: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Display Options', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Compact sidebar'),
                    subtitle: const Text('Use icons-only sidebar when collapsed'),
                    value: ref.watch(appSettingsProvider).compactMode,
                    onChanged: (v) => ref.read(appSettingsProvider.notifier).setCompactMode(v),
                  ),
                  SwitchListTile(
                    title: const Text('Show account codes'),
                    subtitle: const Text('Display account numbers in lists'),
                    value: ref.watch(appSettingsProvider).showAccountCodes,
                    onChanged: (v) => ref.read(appSettingsProvider.notifier).setShowAccountCodes(v),
                  ),
                  SwitchListTile(
                    title: const Text('Animations'),
                    subtitle: const Text('Enable UI animations'),
                    value: ref.watch(appSettingsProvider).enableAnimations,
                    onChanged: (v) => ref.read(appSettingsProvider.notifier).setEnableAnimations(v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestorePointsSettings(BuildContext context) {
    final snapshotsAsync = ref.watch(snapshotListProvider);
    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    Future<void> createSnapshot() async {
      final controller = TextEditingController();
      final label = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Create Restore Point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give this restore point a short description so you can identify it later.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Before payroll adjustment',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (label == null || label.isEmpty || !mounted) return;
      try {
        final svc = ref.read(snapshotServiceProvider);
        await svc.createSnapshot(label);
        ref.invalidate(snapshotListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Restore point "$label" created'),
            backgroundColor: AppColors.success,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to create restore point: $e'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }

    Future<void> restoreSnapshot(SnapshotMeta snap) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Restore this point?'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('"${snap.label}"', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(fmt.format(snap.createdAt),
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Text('${snap.totalRecords} records will be restored.'),
            const SizedBox(height: 12),
            const Text(
              'All data entered AFTER this restore point was created will be '
              'overwritten. This cannot be undone.\n\n'
              'Tip: create another restore point first if you want to keep the current state.',
              style: TextStyle(fontSize: 13),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      try {
        final svc = ref.read(snapshotServiceProvider);
        await svc.restoreSnapshot(snap.id);

        // Reload every data provider so all screens reflect the restored
        // state immediately — no app restart needed.
        ref.invalidate(accountsProvider);
        ref.invalidate(customersProvider);
        ref.invalidate(vendorsProvider);
        ref.invalidate(invoicesProvider);
        ref.invalidate(billsProvider);
        ref.invalidate(journalsProvider);
        ref.invalidate(paymentsProvider);
        ref.invalidate(bankTransactionsProvider);
        ref.invalidate(creditNotesProvider);
        ref.invalidate(debitNotesProvider);
        ref.invalidate(localBankStatementsProvider);
        ref.invalidate(assetDraftsProvider);
        ref.invalidate(depreciationSchedulesProvider);
        ref.invalidate(localAttachmentsProvider);
        ref.invalidate(localOutletCsvUploadsProvider);
        ref.invalidate(outletSettlementsProvider);
        ref.invalidate(allOutletRevenuesProvider);
        ref.invalidate(allOutletExpendituresProvider);
        ref.invalidate(outletRevenueSummaryProvider);
        ref.invalidate(outletAnalyticsProvider);
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(snapshotListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Restored to "${snap.label}" successfully.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }

    Future<void> deleteSnapshot(SnapshotMeta snap) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Restore Point?'),
          content: Text('Delete "${snap.label}"? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      final svc = ref.read(snapshotServiceProvider);
      await svc.deleteSnapshot(snap.id);
      ref.invalidate(snapshotListProvider);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Restore Points',
              'Checkpoints that let you roll back to a known-good state after a mistake'),
          const SizedBox(height: 24),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('How restore points work',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a restore point before making large changes — end-of-month '
                        'adjustments, bulk imports, or any entry you might want to undo. '
                        'Up to 20 points are kept; the oldest is removed when the limit is reached.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Create button
          Row(children: [
            FilledButton.icon(
              onPressed: createSnapshot,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Restore Point'),
            ),
          ]),
          const SizedBox(height: 24),

          // Snapshot list
          snapshotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading restore points: $e',
                style: TextStyle(color: AppColors.error)),
            data: (snapshots) {
              if (snapshots.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.history, size: 48,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('No restore points yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Create one before making important changes.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.outline)),
                      ]),
                    ),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (int i = 0; i < snapshots.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _SnapshotTile(
                        snap: snapshots[i],
                        fmt: fmt,
                        onRestore: () => restoreSnapshot(snapshots[i]),
                        onDelete: () => deleteSnapshot(snapshots[i]),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'Active' ? AppColors.income : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  DataRow _buildTaxRow(String name, String rate, String type, bool isDefault) {
    return DataRow(cells: [
      DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(rate)),
      DataCell(Text(type)),
      DataCell(isDefault
          ? const Icon(Icons.check_circle, color: AppColors.income, size: 20)
          : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20)),
      DataCell(
        Row(
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () {}),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () {}),
          ],
        ),
      ),
    ]);
  }
}

// ── Cloud Sync Step ───────────────────────────────────────────────────────────
class _ManualSyncStep extends StatelessWidget {
  final String step;
  final String title;
  final String detail;

  const _ManualSyncStep({required this.step, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.12), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(step, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ]),
        ),
      ]),
    );
  }
}

class _CloudSyncStep extends StatelessWidget {
  final String step;
  final String title;
  final String detail;

  const _CloudSyncStep({required this.step, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(step, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ]),
        ),
      ]),
    );
  }
}

// ── Permission Matrix Row ─────────────────────────────────────────────────────
class _PermissionRow extends StatelessWidget {
  final String permission;
  /// [Admin, Accountant, Manager, Staff, Viewer]
  final List<bool> roles;

  const _PermissionRow(this.permission, this.roles);

  @override
  Widget build(BuildContext context) {
    // Header row sentinel — permission == '' means render column labels
    if (permission.isEmpty) {
      const labels = ['Admin', 'Accountant', 'Manager', 'Staff', 'Viewer'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            const Expanded(flex: 3, child: SizedBox()),
            ...labels.map((l) => Expanded(
                  child: Center(
                    child: Text(l,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ),
                )),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(permission, style: const TextStyle(fontSize: 13))),
          ...List.generate(roles.length, (i) {
            final has = i < roles.length ? roles[i] : false;
            return Expanded(
              child: Center(
                child: Icon(has ? Icons.check_circle : Icons.remove,
                    color: has ? AppColors.income : Colors.grey.shade300, size: 18),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DefaultAccountRow extends StatelessWidget {
  final String name;
  final String description;

  const _DefaultAccountRow(this.name, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(description, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              value: '1000 - $name',
              items: ['1000 - $name'].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SyncStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final bool isSelected;

  const _ColorOption({required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
              : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final SnapshotMeta snap;
  final DateFormat fmt;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _SnapshotTile({
    required this.snap,
    required this.fmt,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.restore, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snap.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(fmt.format(snap.createdAt),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 2),
                Text('${snap.totalRecords} records',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restore'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error.withOpacity(0.8)),
            tooltip: 'Delete restore point',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Server Backup ─────────────────────────────────────────────────────────────

class _ServerBackupCard extends StatefulWidget {
  const _ServerBackupCard();
  @override
  State<_ServerBackupCard> createState() => _ServerBackupCardState();
}

class _ServerBackupCardState extends State<_ServerBackupCard> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _obscureKey  = true;
  bool _syncing     = false;
  bool _restoring   = false;
  String? _lastSync;
  String? _statusMsg;
  bool _statusOk    = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final url  = await ServerSyncService.getSyncUrl();
    final key  = await ServerSyncService.getApiKey();
    final last = await ServerSyncService.getLastSyncedAt();
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = url;
      _keyCtrl.text = key;
      _lastSync     = last;
    });
  }

  Future<void> _saveConfig() async {
    await ServerSyncService.saveConfig(_urlCtrl.text, _keyCtrl.text);
    if (!mounted) return;
    setState(() { _statusMsg = 'Configuration saved.'; _statusOk = true; });
  }

  Future<void> _syncNow() async {
    setState(() { _syncing = true; _statusMsg = null; });
    final db     = AppDatabase();
    final result = await ServerSyncService.pushBackup(db);
    if (!mounted) return;
    setState(() {
      _syncing    = false;
      _statusOk   = result.success;
      _statusMsg  = result.success
          ? 'Backup pushed to server successfully.'
          : 'Sync failed: ${result.error}';
      if (result.success) _lastSync = result.syncedAt;
    });
  }

  Future<void> _restoreFromServer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Server?'),
        content: const Text(
          'This will replace all local data with the latest backup from the server.\n\n'
          'A local restore point will be created first so you can roll back if needed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() { _restoring = true; _statusMsg = null; });
    final db     = AppDatabase();
    final result = await ServerSyncService.pullAndRestore(db);
    if (!mounted) return;
    setState(() {
      _restoring  = false;
      _statusOk   = result.success;
      _statusMsg  = result.success
          ? 'Restore complete — ${result.counts.values.fold(0, (a, b) => a + b)} records loaded.'
          : 'Restore failed: ${result.error}';
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = _urlCtrl.text.isNotEmpty && _keyCtrl.text.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Server Backup', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Automatically push a backup to your server on every login.',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                ),
              ])),
              if (_lastSync != null)
                Chip(
                  label: Text(
                    'Last sync: ${_formatSync(_lastSync!)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.green.withOpacity(0.1),
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                ),
            ]),
            const SizedBox(height: 20),

            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://magicbet.thirdbooks.digital/sync',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            Row(children: [
              ElevatedButton(
                onPressed: _saveConfig,
                child: const Text('Save Config'),
              ),
              const SizedBox(width: 12),
              if (configured) ...[
                OutlinedButton.icon(
                  icon: _syncing
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload, size: 16),
                  label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
                  onPressed: _syncing ? null : _syncNow,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: _restoring
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_download, size: 16),
                  label: Text(_restoring ? 'Restoring…' : 'Restore from Server'),
                  onPressed: _restoring ? null : _restoreFromServer,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ]),

            if (_statusMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (_statusOk ? Colors.green : AppColors.error).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (_statusOk ? Colors.green : AppColors.error).withOpacity(0.3),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _statusOk ? Icons.check_circle_outline : Icons.error_outline,
                    size: 16,
                    color: _statusOk ? Colors.green : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusMsg!, style: const TextStyle(fontSize: 13))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSync(String iso) {
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      }
      return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                           'Jul','Aug','Sep','Oct','Nov','Dec'];
}
