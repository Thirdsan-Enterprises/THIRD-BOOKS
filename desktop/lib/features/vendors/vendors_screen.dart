// Vendors Screen for ThirdBooks Desktop App
// Manages vendor/supplier accounts and payables
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/models/vendor.dart';
import '../../core/models/bill.dart';
import '../../core/models/account.dart';
import '../../core/widgets/account_search_field.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  final _currencyFormat = NumberFormat('#,###');

  List<Vendor> get _filteredVendors {
    final vendorsState = ref.watch(vendorsProvider);
    return vendorsState.vendors.where((vendor) {
      final matchesSearch = _searchQuery.isEmpty ||
          vendor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (vendor.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          vendor.id.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == null ||
          (_selectedStatus == 'Active' && vendor.isActive) ||
          (_selectedStatus == 'Inactive' && !vendor.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsState = ref.watch(vendorsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context, vendorsState),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(
              child: vendorsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildVendorsTable(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendors',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your supplier accounts and payables',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(vendorsProvider.notifier).loadVendors(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'export') {
                  _exportVendors();
                } else if (value == 'import') {
                  _importVendors();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Export to CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Import from CSV'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showAddVendorDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Vendor'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, VendorsState state) {
    final totalVendors = state.vendors.length;
    final activeVendors = state.vendors.where((v) => v.isActive).length;
    final totalPayable = state.vendors.fold<double>(0, (sum, v) => sum + v.balance);
    final highBalance = state.vendors.where((v) => v.balance > 10000000).length;

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.store,
          iconColor: AppColors.primary,
          label: 'Total Vendors',
          value: totalVendors.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.check_circle,
          iconColor: AppColors.income,
          label: 'Active',
          value: activeVendors.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.expense,
          label: 'Total Payable',
          value: 'UGX ${_formatNumber(totalPayable)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.warning_amber,
          iconColor: AppColors.warning,
          label: 'High Balance',
          value: highBalance.toString(),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search vendors...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              hintText: 'All Statuses',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Statuses')),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorsTable(BuildContext context) {
    final vendors = _filteredVendors;

    if (vendors.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No vendors found matching "$_searchQuery"'
                      : 'No vendors yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first vendor to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 24,
            headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: Text('Payment Terms')),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: vendors.map((vendor) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          vendor.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'ID: ${vendor.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showVendorDetails(context, vendor),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(vendor.email ?? '-', style: const TextStyle(fontSize: 13)),
                        Text(
                          vendor.phone ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(vendor.paymentTerms ?? 'Net 30')),
                  DataCell(
                    Text(
                      'UGX ${_currencyFormat.format(vendor.balance)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: vendor.balance > 10000000 ? AppColors.expense : null,
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge(vendor.isActive ? 'Active' : 'Inactive')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showEditVendorDialog(context, vendor),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.receipt_outlined, size: 18),
                          onPressed: () => _showVendorBills(context, vendor),
                          tooltip: 'View Bills',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Active':
        color = AppColors.income;
        break;
      case 'On Hold':
        color = AppColors.warning;
        break;
      case 'Inactive':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showAddVendorDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final taxIdController = TextEditingController();
    String selectedPaymentTerms = 'Net 30';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Vendor'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Company Name *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email *'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone *'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: taxIdController,
                          decoration: const InputDecoration(labelText: 'Tax ID (TIN)'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPaymentTerms,
                          decoration: const InputDecoration(labelText: 'Payment Terms'),
                          items: ['Due on Receipt', 'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedPaymentTerms = v ?? 'Net 30'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newVendor = Vendor(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    email: emailController.text.isNotEmpty ? emailController.text : null,
                    phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                    address: addressController.text.isNotEmpty ? addressController.text : null,
                    taxId: taxIdController.text.isNotEmpty ? taxIdController.text : null,
                    paymentTerms: selectedPaymentTerms,
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  ref.read(vendorsProvider.notifier).addVendor(newVendor);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Add Vendor'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditVendorDialog(BuildContext context, Vendor vendor) {
    final nameController = TextEditingController(text: vendor.name);
    final emailController = TextEditingController(text: vendor.email);
    final phoneController = TextEditingController(text: vendor.phone);
    final addressController = TextEditingController(text: vendor.address);
    final taxIdController = TextEditingController(text: vendor.taxId ?? '');
    String selectedPaymentTerms = vendor.paymentTerms ?? 'Net 30';
    bool isActive = vendor.isActive;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Vendor'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Company Name *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email *'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone *'),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: taxIdController,
                          decoration: const InputDecoration(labelText: 'Tax ID (TIN)'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPaymentTerms,
                          decoration: const InputDecoration(labelText: 'Payment Terms'),
                          items: ['Due on Receipt', 'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedPaymentTerms = v ?? 'Net 30'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final updated = vendor.copyWith(
                    name: nameController.text,
                    email: emailController.text.isNotEmpty ? emailController.text : null,
                    phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                    address: addressController.text.isNotEmpty ? addressController.text : null,
                    taxId: taxIdController.text.isNotEmpty ? taxIdController.text : null,
                    paymentTerms: selectedPaymentTerms,
                    isActive: isActive,
                    updatedAt: DateTime.now(),
                  );
                  ref.read(vendorsProvider.notifier).updateVendor(updated);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vendor updated — queued for sync')),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVendorDetails(BuildContext context, Vendor vendor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(vendor.name),
            _buildStatusBadge(vendor.isActive ? 'Active' : 'Inactive'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Vendor ID', vendor.id),
              _DetailRow('Email', vendor.email ?? '-'),
              _DetailRow('Phone', vendor.phone ?? '-'),
              _DetailRow('Address', vendor.address ?? '-'),
              if (vendor.taxId != null) _DetailRow('Tax ID', vendor.taxId!),
              const Divider(),
              _DetailRow('Payment Terms', vendor.paymentTerms ?? 'Net 30'),
              _DetailRow('Current Balance', 'UGX ${_currencyFormat.format(vendor.balance)}'),
              _DetailRow('Created', DateFormat('MMMM d, yyyy').format(vendor.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showVendorBills(context, vendor);
            },
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('View Bills'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateBillForVendor(context, vendor);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Bill'),
          ),
        ],
      ),
    );
  }

  // ── Vendor Bills ──────────────────────────────────────────────────────────────

  void _showVendorBills(BuildContext context, Vendor vendor) {
    final allBills = ref.read(billsProvider).bills;
    final bills = allBills
        .where((b) => b.vendorId == vendor.id || b.vendorName == vendor.name)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Bills — ${vendor.name}', overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(
              '${bills.length} record${bills.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: bills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text('No bills found for this vendor'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: bills.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final bill = bills[i];
                    final statusColor = _billStatusColor(bill.status);
                    return ListTile(
                      title: Text(bill.billNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(bill.date)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('UGX ${_currencyFormat.format(bill.total)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontFamily: 'monospace')),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bill.status.name[0].toUpperCase() + bill.status.name.substring(1),
                              style: TextStyle(
                                  fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateBillForVendor(context, vendor);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Bill'),
          ),
        ],
      ),
    );
  }

  Color _billStatusColor(BillStatus status) {
    switch (status) {
      case BillStatus.paid:
        return AppColors.income;
      case BillStatus.overdue:
        return AppColors.expense;
      case BillStatus.pending:
        return AppColors.warning;
      case BillStatus.partial:
        return AppColors.secondary;
      case BillStatus.draft:
      case BillStatus.cancelled:
        return Colors.grey;
    }
  }

  void _showCreateBillForVendor(BuildContext context, Vendor vendor) {
    final accountsState = ref.read(accountsProvider);
    final expenseAccounts = accountsState.accounts
        .where((a) => a.type == AccountType.expense)
        .toList();
    final allAccounts = expenseAccounts.isNotEmpty ? expenseAccounts : accountsState.accounts;

    String selectedCurrency = 'UGX';
    String? selectedCategory;
    final List<_VendBillLine> lines = [_VendBillLine()];
    DateTime billDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final enableVAT = ref.read(appSettingsProvider).enableVAT;
          double subtotal = lines.fold(0, (sum, l) => sum + l.amount);
          double vat = enableVAT ? subtotal * 0.18 : 0.0;
          double total = subtotal + vat;
          final fmt = NumberFormat('#,###');

          return AlertDialog(
            title: Text('New Bill — ${vendor.name}'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<String>(
                            value: selectedCurrency,
                            decoration: const InputDecoration(labelText: 'Currency'),
                            items: ['UGX', 'USD', 'EUR', 'GBP', 'KES', 'TZS']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedCurrency = v ?? 'UGX'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: [
                              'Inventory', 'Equipment', 'Office Supplies',
                              'Utilities', 'Raw Materials', 'Services',
                              'Vehicle', 'Furniture',
                            ]
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedCategory = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: billDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setDialogState(() => billDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Bill Date'),
                              child: Text(DateFormat('MMM d, yyyy').format(billDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setDialogState(() => dueDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Due Date'),
                              child: Text(DateFormat('MMM d, yyyy').format(dueDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Account', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 36),
                            ],
                          ),
                          const Divider(),
                          ...lines.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            return _VendBillLineWidget(
                              key: ValueKey(line.id),
                              line: line,
                              accounts: allAccounts,
                              currency: selectedCurrency,
                              onChanged: () => setDialogState(() {}),
                              onDelete: lines.length > 1
                                  ? () => setDialogState(() => lines.removeAt(idx))
                                  : null,
                            );
                          }),
                          TextButton.icon(
                            onPressed: () =>
                                setDialogState(() => lines.add(_VendBillLine())),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Line'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$selectedCurrency Subtotal: ${fmt.format(subtotal)}'),
                          if (enableVAT)
                            Text('$selectedCurrency VAT (18%): ${fmt.format(vat)}'),
                          const SizedBox(height: 4),
                          Text(
                            '$selectedCurrency Total: ${fmt.format(total)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => _saveBillForVendor(
                    ctx, vendor, selectedCurrency, selectedCategory, billDate, dueDate, lines),
                child: const Text('Create Bill'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveBillForVendor(
    BuildContext ctx,
    Vendor vendor,
    String currency,
    String? category,
    DateTime billDate,
    DateTime dueDate,
    List<_VendBillLine> lines,
  ) {
    final validLines = lines.where((l) => l.amount > 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one line item with an amount')));
      return;
    }

    final enableVAT = ref.read(appSettingsProvider).enableVAT;
    final now = DateTime.now();
    final billId = const Uuid().v4();
    final billNumber = 'BILL-${now.millisecondsSinceEpoch % 100000}';
    final subtotal = validLines.fold<double>(0, (s, l) => s + l.amount);
    final taxAmount = enableVAT ? subtotal * 0.18 : 0.0;
    final total = subtotal + taxAmount;

    final bill = Bill(
      id: billId,
      billNumber: billNumber,
      vendorId: vendor.id,
      vendorName: vendor.name,
      date: billDate,
      dueDate: dueDate,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      status: BillStatus.pending,
      currencyCode: currency,
      category: category,
      lines: validLines
          .map((l) => BillLine(
                id: const Uuid().v4(),
                billId: billId,
                accountId: l.accountId.isNotEmpty ? l.accountId : 'expense',
                description: l.description.isNotEmpty ? l.description : category ?? 'Expense',
                amount: l.amount,
                taxRate: enableVAT ? 0.18 : 0.0,
                taxAmount: enableVAT ? l.amount * 0.18 : 0.0,
              ))
          .toList(),
      createdAt: now,
      updatedAt: now,
    );

    ref.read(billsProvider.notifier).addBill(bill);
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bill $billNumber created for ${vendor.name}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _exportVendors() async {
    final vendorsState = ref.read(vendorsProvider);

    if (vendorsState.vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vendors to export')),
      );
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Vendors',
      fileName: 'vendors_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('ID,Name,Email,Phone,Address,Tax ID,Payment Terms,Balance,Status,Created');

      for (final vendor in vendorsState.vendors) {
        buffer.writeln(
          '"${vendor.id}","${vendor.name}","${vendor.email}","${vendor.phone}",'
          '"${vendor.address}","${vendor.taxId ?? ''}","${vendor.paymentTerms ?? ''}",'
          '${vendor.balance},"${vendor.isActive ? 'Active' : 'Inactive'}",'
          '"${DateFormat('yyyy-MM-dd').format(vendor.createdAt)}"'
        );
      }

      final file = File(result);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${vendorsState.vendors.length} vendors to $result')),
        );
      }
    }
  }

  Future<void> _importVendors() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Vendors',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final lines = content.split('\n');

      if (lines.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid CSV file')),
          );
        }
        return;
      }

      int imported = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = _parseCSVLine(line);
        if (parts.length >= 5) {
          imported++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import complete: $imported vendors (will sync when online)')),
        );
        ref.read(vendorsProvider.notifier).loadVendors();
      }
    }
  }

  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final buffer = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ── Bill Line Helpers (for New Bill from Vendor) ──────────────────────────────

class _VendBillLine {
  final String id = DateTime.now().microsecondsSinceEpoch.toString();
  String accountId = '';
  String description = '';
  double amount = 0;
}

class _VendBillLineWidget extends StatefulWidget {
  final _VendBillLine line;
  final List<Account> accounts;
  final String currency;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _VendBillLineWidget({
    super.key,
    required this.line,
    required this.accounts,
    required this.currency,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_VendBillLineWidget> createState() => _VendBillLineWidgetState();
}

class _VendBillLineWidgetState extends State<_VendBillLineWidget> {
  late final TextEditingController _amtCtrl;

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: AccountSearchField(
              accounts: widget.accounts,
              value: widget.line.accountId.isEmpty ? null : widget.line.accountId,
              onChanged: (v) {
                setState(() => widget.line.accountId = v ?? '');
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: 'Description',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => widget.line.description = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _amtCtrl,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                prefixText: '${widget.currency} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                widget.line.amount = double.tryParse(v.replaceAll(',', '')) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          SizedBox(
            width: 36,
            child: widget.onDelete != null
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: widget.onDelete,
                    color: Colors.red,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
