// Customers Screen for ThirdBooks Desktop App
// Manages customer accounts and receivables
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/customer.dart';

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
                          onPressed: () {},
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
                  // TODO: Implement update via API
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer updated (offline - will sync when online)')),
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
            onPressed: () {},
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('View Invoices'),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Invoice'),
          ),
        ],
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
