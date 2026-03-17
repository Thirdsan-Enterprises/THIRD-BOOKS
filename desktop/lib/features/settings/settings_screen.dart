import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/company_settings_service.dart';
import '../../core/services/sync_service.dart';

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
    final users = [
      {'name': 'Admin', 'email': 'admin@magicbet.ug', 'role': 'Administrator', 'status': 'Active'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(context, 'Users & Permissions', 'Manage team access and roles'),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Invite User'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: users.map((user) {
                return DataRow(cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            user['name']![0],
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(user['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(user['email']!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    DropdownButton<String>(
                      value: user['role'],
                      underline: const SizedBox(),
                      items: ['Administrator', 'Accountant', 'Viewer']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) {},
                    ),
                  ),
                  DataCell(_buildStatusBadge(user['status']!)),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          Text('Role Permissions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PermissionRow('View Dashboard', [true, true, true]),
                  _PermissionRow('Manage Transactions', [true, true, false]),
                  _PermissionRow('Create/Edit Invoices', [true, true, false]),
                  _PermissionRow('View Reports', [true, true, true]),
                  _PermissionRow('Export Data', [true, true, false]),
                  _PermissionRow('Manage Users', [true, false, false]),
                  _PermissionRow('Company Settings', [true, false, false]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tax Preferences', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable VAT tracking'),
                    subtitle: const Text('Track VAT on sales and purchases'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  SwitchListTile(
                    title: const Text('Prices include tax'),
                    subtitle: const Text('Default prices entered include tax'),
                    value: false,
                    onChanged: (v) {},
                  ),
                  SwitchListTile(
                    title: const Text('Show tax on invoices'),
                    subtitle: const Text('Display tax breakdown on printed invoices'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tax settings saved'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: const Text('Save Tax Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                          value: 'UGX - Ugandan Shilling',
                          items: [
                            'UGX - Ugandan Shilling',
                            'USD - US Dollar',
                            'EUR - Euro',
                            'GBP - British Pound',
                            'KES - Kenyan Shilling',
                            'TZS - Tanzanian Shilling',
                          ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Currency Format'),
                          value: 'UGX 1,000,000',
                          items: [
                            'UGX 1,000,000',
                            '1,000,000 UGX',
                            'UGX 1.000.000',
                          ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (v) {},
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
    final syncState = ref.watch(syncServiceProvider);
    final connectivity = ref.watch(connectivityProvider);
    final appSettings = ref.watch(appSettingsProvider);

    final isOnline = connectivity.isOnline;
    final isSyncing = syncState.isSyncing;
    final lastSync = syncState.lastSyncTime;
    final pending = syncState.pendingChanges;

    String _formatLastSync() {
      if (lastSync == null) return 'Never synced';
      final now = DateTime.now();
      final diff = now.difference(lastSync);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('d MMM yyyy, h:mm a').format(lastSync);
    }

    Future<void> _confirmClearCache() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear Local Cache?'),
          content: const Text(
              'All locally stored data will be removed from this device. '
              'Your cloud data is untouched and will re-sync automatically.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear Cache')),
          ],
        ),
      );
      if (ok == true && mounted) {
        await ref.read(syncServiceProvider.notifier).clearLocalCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Local cache cleared. Syncing from cloud...'),
            backgroundColor: AppColors.success,
          ));
          ref.read(syncServiceProvider.notifier).syncAll();
        }
      }
    }

    Future<void> _confirmDeleteAllData() async {
      // Step 1: warn
      final step1 = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Delete All Data?'),
          ]),
          content: const Text(
              'This will permanently delete ALL your invoices, bills, customers, '
              'vendors, journal entries and payments from the cloud. '
              'This action CANNOT be undone.\n\n'
              'Are you sure you want to proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, proceed'),
            ),
          ],
        ),
      );
      if (step1 != true || !mounted) return;

      // Step 2: type confirmation
      final confirmCtrl = TextEditingController();
      final step2 = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Final Confirmation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Type DELETE_ALL_MY_DATA to confirm:'),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, decoration: const InputDecoration(hintText: 'DELETE_ALL_MY_DATA')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );
      if (step2 != true || !mounted) return;

      if (confirmCtrl.text.trim() != 'DELETE_ALL_MY_DATA') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Confirmation text did not match. Deletion cancelled.'),
          backgroundColor: AppColors.warning,
        ));
        return;
      }

      try {
        await ref.read(syncServiceProvider.notifier).deleteAllCloudData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('All data has been permanently deleted.'),
            backgroundColor: AppColors.error,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Deletion failed: $e'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Sync & Backup', 'Manage data synchronization and backups'),
          const SizedBox(height: 24),

          // ── Sync Status Card ──────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isOnline ? AppColors.income : AppColors.error).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOnline ? Icons.cloud_done : Icons.cloud_off,
                          color: isOnline ? AppColors.income : AppColors.error,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('Sync Status', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isOnline ? AppColors.income : AppColors.error).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOnline ? AppColors.income : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              isSyncing
                                  ? 'Syncing… ${(syncState.progress * 100).toStringAsFixed(0)}%'
                                  : 'Last synced: ${_formatLastSync()}',
                              style: TextStyle(color: Theme.of(context).colorScheme.outline),
                            ),
                            if (syncState.error != null)
                              Text(syncState.error!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (isSyncing)
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        FilledButton.icon(
                          onPressed: isOnline
                              ? () => ref.read(syncServiceProvider.notifier).syncAll()
                              : null,
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Sync Now'),
                        ),
                    ],
                  ),
                  if (isSyncing) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: syncState.progress),
                  ],
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _SyncStatCard(
                          icon: Icons.upload,
                          label: 'Pending Upload',
                          value: '$pending item${pending == 1 ? '' : 's'}',
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SyncStatCard(
                          icon: Icons.download,
                          label: 'Last Pull',
                          value: lastSync != null ? _formatLastSync() : '—',
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SyncStatCard(
                          icon: isOnline ? Icons.wifi : Icons.wifi_off,
                          label: 'Connection',
                          value: isOnline ? 'Connected' : 'Offline',
                          color: isOnline ? AppColors.income : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Sync Settings Card ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sync Settings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Auto-sync'),
                    subtitle: const Text('Automatically sync when changes are made'),
                    value: appSettings.autoSync,
                    onChanged: (v) =>
                        ref.read(appSettingsProvider.notifier).setAutoSync(v),
                  ),
                  const Divider(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sync Interval'),
                              Text(
                                'How often to auto-sync in the background',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int>(
                          value: [5, 10, 15, 30, 60].contains(appSettings.syncIntervalMinutes)
                              ? appSettings.syncIntervalMinutes
                              : 15,
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('Every 5 min')),
                            DropdownMenuItem(value: 10, child: Text('Every 10 min')),
                            DropdownMenuItem(value: 15, child: Text('Every 15 min')),
                            DropdownMenuItem(value: 30, child: Text('Every 30 min')),
                            DropdownMenuItem(value: 60, child: Text('Every hour')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(appSettingsProvider.notifier).setSyncInterval(v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Local Cache Card ──────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local Cache', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'The app stores a copy of your cloud data locally for offline access. '
                    'Clearing the cache frees device storage; your cloud data is untouched '
                    'and will re-download on the next sync.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _confirmClearCache,
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text('Clear Local Cache'),
                  ),
                ],
              ),
            ),
          ),
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
                    'Permanently delete all your data from the cloud. '
                    'This includes all invoices, bills, customers, vendors, '
                    'journal entries and payments. This action is irreversible.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                    onPressed: isOnline ? _confirmDeleteAllData : null,
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: Text(isOnline ? 'Delete All My Data' : 'Must be online to delete'),
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
                    value: true,
                    onChanged: (v) {},
                  ),
                  SwitchListTile(
                    title: const Text('Show account codes'),
                    subtitle: const Text('Display account numbers in lists'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  SwitchListTile(
                    title: const Text('Animations'),
                    subtitle: const Text('Enable UI animations'),
                    value: true,
                    onChanged: (v) {},
                  ),
                ],
              ),
            ),
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

class _PermissionRow extends StatelessWidget {
  final String permission;
  final List<bool> roles; // [Admin, Accountant, Viewer]

  const _PermissionRow(this.permission, this.roles);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(permission)),
          Expanded(child: Center(child: Icon(roles[0] ? Icons.check : Icons.close, color: roles[0] ? AppColors.income : Colors.grey, size: 20))),
          Expanded(child: Center(child: Icon(roles[1] ? Icons.check : Icons.close, color: roles[1] ? AppColors.income : Colors.grey, size: 20))),
          Expanded(child: Center(child: Icon(roles[2] ? Icons.check : Icons.close, color: roles[2] ? AppColors.income : Colors.grey, size: 20))),
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
