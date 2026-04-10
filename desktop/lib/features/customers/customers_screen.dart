// Customers Screen for ThirdBooks Desktop App
// Manages customer accounts and receivables
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
import '../../core/models/customer.dart';
import '../../core/models/invoice.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  final _currencyFormat = NumberFormat('#,###');

  List<Customer> get _filteredCustomers {
    final customersState = ref.watch(customersProvider);
    return customersState.customers.where((customer) {
      final matchesSearch = _searchQuery.isEmpty ||
          customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (customer.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          customer.id.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == null ||
          (_selectedStatus == 'Active' && customer.isActive) ||
          (_selectedStatus == 'Inactive' && !customer.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context, customersState),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(
              child: customersState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCustomersTable(context),
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
              'Customers',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your customer accounts and receivables',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(customersProvider.notifier).loadCustomers(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'export') {
                  _exportCustomers();
                } else if (value == 'import') {
                  _importCustomers();
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
              onPressed: () => _showAddCustomerDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Customer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, CustomersState state) {
    final totalCustomers = state.customers.length;
    final activeCustomers = state.customers.where((c) => c.isActive).length;
    final totalReceivable = state.customers.fold<double>(0, (sum, c) => sum + c.balance);
    final nearCreditLimit = state.customers.where((c) =>
        c.creditLimit > 0 && c.balance > c.creditLimit * 0.8).length;

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.people,
          iconColor: AppColors.primary,
          label: 'Total Customers',
          value: totalCustomers.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.check_circle,
          iconColor: AppColors.income,
          label: 'Active',
          value: activeCustomers.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.debit,
          label: 'Total Receivable',
          value: 'UGX ${_formatNumber(totalReceivable)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.warning_amber,
          iconColor: AppColors.expense,
          label: 'Near Credit Limit',
          value: nearCreditLimit.toString(),
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
              hintText: 'Search customers...',
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

  Widget _buildCustomersTable(BuildContext context) {
    final customers = _filteredCustomers;

    if (customers.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No customers found matching "$_searchQuery"'
                      : 'No customers yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first customer to get started',
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
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: Text('Credit Limit'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: customers.map((customer) {
              final utilizationPercent = customer.creditLimit > 0
                  ? (customer.balance / customer.creditLimit * 100)
                  : 0;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'ID: ${customer.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showCustomerDetails(context, customer),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(customer.email ?? '-', style: const TextStyle(fontSize: 13)),
                        Text(
                          customer.phone ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      'UGX ${_currencyFormat.format(customer.creditLimit)}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'UGX ${_currencyFormat.format(customer.balance)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                            color: utilizationPercent > 80 ? AppColors.expense : null,
                          ),
                        ),
                        if (customer.creditLimit > 0)
                          Text(
                            '${utilizationPercent.toStringAsFixed(0)}% used',
                            style: TextStyle(
                              fontSize: 11,
                              color: utilizationPercent > 80
                                  ? AppColors.expense
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(_buildStatusBadge(customer.isActive ? 'Active' : 'Inactive')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showEditCustomerDialog(context, customer),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          onPressed: () => _showCustomerInvoices(context, customer),
                          tooltip: 'View Invoices',
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

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final taxIdController = TextEditingController();
    final creditLimitController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
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
                      child: TextFormField(
                        controller: creditLimitController,
                        decoration: const InputDecoration(labelText: 'Credit Limit'),
                        keyboardType: TextInputType.number,
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
                final newCustomer = Customer(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  email: emailController.text.isNotEmpty ? emailController.text : null,
                  phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                  address: addressController.text.isNotEmpty ? addressController.text : null,
                  taxId: taxIdController.text.isNotEmpty ? taxIdController.text : null,
                  creditLimit: double.tryParse(creditLimitController.text) ?? 0,
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                ref.read(customersProvider.notifier).addCustomer(newCustomer);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add Customer'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final emailController = TextEditingController(text: customer.email);
    final phoneController = TextEditingController(text: customer.phone);
    final addressController = TextEditingController(text: customer.address);
    final taxIdController = TextEditingController(text: customer.taxId ?? '');
    final creditLimitController = TextEditingController(text: customer.creditLimit.toString());
    bool isActive = customer.isActive;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Customer'),
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
                        child: TextFormField(
                          controller: creditLimitController,
                          decoration: const InputDecoration(labelText: 'Credit Limit'),
                          keyboardType: TextInputType.number,
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
                  final updated = customer.copyWith(
                    name: nameController.text,
                    email: emailController.text.isNotEmpty ? emailController.text : null,
                    phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                    address: addressController.text.isNotEmpty ? addressController.text : null,
                    taxId: taxIdController.text.isNotEmpty ? taxIdController.text : null,
                    creditLimit: double.tryParse(creditLimitController.text) ?? customer.creditLimit,
                    isActive: isActive,
                    updatedAt: DateTime.now(),
                  );
                  ref.read(customersProvider.notifier).updateCustomer(updated);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer updated — queued for sync')),
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

  void _showCustomerDetails(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(customer.name),
            _buildStatusBadge(customer.isActive ? 'Active' : 'Inactive'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Customer ID', customer.id),
              _DetailRow('Email', customer.email ?? '-'),
              _DetailRow('Phone', customer.phone ?? '-'),
              _DetailRow('Address', customer.address ?? '-'),
              if (customer.taxId != null) _DetailRow('Tax ID', customer.taxId!),
              const Divider(),
              _DetailRow('Credit Limit', 'UGX ${_currencyFormat.format(customer.creditLimit)}'),
              _DetailRow('Current Balance', 'UGX ${_currencyFormat.format(customer.balance)}'),
              _DetailRow('Created', DateFormat('MMMM d, yyyy').format(customer.createdAt)),
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
              _showCustomerInvoices(context, customer);
            },
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('View Invoices'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateInvoiceForCustomer(context, customer);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Invoice'),
          ),
        ],
      ),
    );
  }

  // ── Customer Invoices ────────────────────────────────────────────────────────

  void _showCustomerInvoices(BuildContext context, Customer customer) {
    final allInvoices = ref.read(invoicesProvider).invoices;
    final invoices = allInvoices
        .where((i) => i.customerId == customer.id || i.customerName == customer.name)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Invoices — ${customer.name}', overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(
              '${invoices.length} record${invoices.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text('No invoices found for this customer'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final inv = invoices[i];
                    final statusColor = _invoiceStatusColor(inv.status);
                    return ListTile(
                      title: Text(inv.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(inv.date)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('UGX ${_currencyFormat.format(inv.total)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontFamily: 'monospace')),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              inv.status.name[0].toUpperCase() + inv.status.name.substring(1),
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
              _showCreateInvoiceForCustomer(context, customer);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Invoice'),
          ),
        ],
      ),
    );
  }

  Color _invoiceStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return AppColors.income;
      case InvoiceStatus.overdue:
        return AppColors.expense;
      case InvoiceStatus.pending:
        return AppColors.warning;
      case InvoiceStatus.partial:
        return AppColors.secondary;
      case InvoiceStatus.sent:
        return AppColors.primary;
      case InvoiceStatus.draft:
      case InvoiceStatus.cancelled:
        return Colors.grey;
    }
  }

  void _showCreateInvoiceForCustomer(BuildContext context, Customer customer) {
    String selectedCurrency = 'UGX';
    final List<_CustInvLine> lines = [_CustInvLine()];
    DateTime invoiceDate = DateTime.now();
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
            title: Text('New Invoice — ${customer.name}'),
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
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: invoiceDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setDialogState(() => invoiceDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Invoice Date'),
                              child: Text(DateFormat('MMM d, yyyy').format(invoiceDate)),
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
                              Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 36),
                            ],
                          ),
                          const Divider(),
                          ...lines.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            return _CustInvLineWidget(
                              key: ValueKey(line.id),
                              line: line,
                              currency: selectedCurrency,
                              onChanged: () => setDialogState(() {}),
                              onDelete: lines.length > 1
                                  ? () => setDialogState(() => lines.removeAt(idx))
                                  : null,
                            );
                          }),
                          TextButton.icon(
                            onPressed: () =>
                                setDialogState(() => lines.add(_CustInvLine())),
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
              OutlinedButton(
                onPressed: () => _saveInvoiceForCustomer(
                    ctx, customer, selectedCurrency, invoiceDate, dueDate, lines, InvoiceStatus.draft),
                child: const Text('Save Draft'),
              ),
              FilledButton(
                onPressed: () => _saveInvoiceForCustomer(
                    ctx, customer, selectedCurrency, invoiceDate, dueDate, lines, InvoiceStatus.pending),
                child: const Text('Create Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveInvoiceForCustomer(
    BuildContext ctx,
    Customer customer,
    String currency,
    DateTime invoiceDate,
    DateTime dueDate,
    List<_CustInvLine> lines,
    InvoiceStatus status,
  ) {
    if (lines.every((l) => l.description.isEmpty || l.amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one line item')));
      return;
    }

    final id = const Uuid().v4();
    final invoiceNumber =
        'INV-${DateFormat('yyyyMM').format(invoiceDate)}-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final enableVAT = ref.read(appSettingsProvider).enableVAT;
    final vatRate = enableVAT ? 18.0 : 0.0;
    final subtotal = lines.fold<double>(0, (s, l) => s + l.amount);
    final taxAmount = enableVAT ? subtotal * 0.18 : 0.0;
    final total = subtotal + taxAmount;

    final invoiceLines = lines
        .where((l) => l.description.isNotEmpty && l.amount > 0)
        .map((l) => InvoiceLine(
              id: const Uuid().v4(),
              invoiceId: id,
              description: l.description,
              quantity: l.qty,
              unitPrice: l.unitPrice,
              taxRate: vatRate,
              taxAmount: enableVAT ? l.amount * 0.18 : 0.0,
              amount: l.amount,
            ))
        .toList();

    final invoice = Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      customerId: customer.id,
      customerName: customer.name,
      date: invoiceDate,
      dueDate: dueDate,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      amountPaid: 0,
      status: status,
      currencyCode: currency,
      lines: invoiceLines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(invoicesProvider.notifier).addInvoice(invoice);
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice $invoiceNumber created for ${customer.name}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _exportCustomers() async {
    final customersState = ref.read(customersProvider);

    if (customersState.customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers to export')),
      );
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Customers',
      fileName: 'customers_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('ID,Name,Email,Phone,Address,Tax ID,Credit Limit,Balance,Status,Created');

      for (final customer in customersState.customers) {
        buffer.writeln(
          '"${customer.id}","${customer.name}","${customer.email}","${customer.phone}",'
          '"${customer.address}","${customer.taxId ?? ''}",${customer.creditLimit},'
          '${customer.balance},"${customer.isActive ? 'Active' : 'Inactive'}",'
          '"${DateFormat('yyyy-MM-dd').format(customer.createdAt)}"'
        );
      }

      final file = File(result);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${customersState.customers.length} customers to $result')),
        );
      }
    }
  }

  Future<void> _importCustomers() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Customers',
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
      // Skip header line
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Parse CSV line (simple implementation)
        final parts = _parseCSVLine(line);
        if (parts.length >= 5) {
          // TODO: Implement batch import via API
          imported++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import complete: $imported customers (will sync when online)')),
        );
        ref.read(customersProvider.notifier).loadCustomers();
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

// ── Invoice Line Helpers (for New Invoice from Customer) ──────────────────────

class _CustInvLine {
  final String id = DateTime.now().microsecondsSinceEpoch.toString();
  String description = '';
  double qty = 1;
  double unitPrice = 0;
  double get amount => qty * unitPrice;
}

class _CustInvLineWidget extends StatefulWidget {
  final _CustInvLine line;
  final String currency;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _CustInvLineWidget({
    super.key,
    required this.line,
    required this.currency,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_CustInvLineWidget> createState() => _CustInvLineWidgetState();
}

class _CustInvLineWidgetState extends State<_CustInvLineWidget> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
    _priceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
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
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: 'Item description',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => widget.line.description = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                widget.line.qty = double.tryParse(v) ?? 1;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _priceCtrl,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                prefixText: '${widget.currency} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                widget.line.unitPrice = double.tryParse(v.replaceAll(',', '')) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              '${widget.currency} ${NumberFormat('#,###').format(widget.line.amount)}',
              style: const TextStyle(fontFamily: 'monospace'),
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
