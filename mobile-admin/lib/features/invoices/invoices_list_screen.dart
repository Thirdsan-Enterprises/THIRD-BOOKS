import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/providers/customers_provider.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final invoicesState = ref.watch(invoicesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedStatus = value == 'all' ? null : value;
              });
              ref.read(invoicesProvider.notifier).setStatusFilter(_selectedStatus);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'draft', child: Text('Draft')),
              const PopupMenuItem(value: 'sent', child: Text('Sent')),
              const PopupMenuItem(value: 'paid', child: Text('Paid')),
              const PopupMenuItem(value: 'partial', child: Text('Partial')),
              const PopupMenuItem(value: 'overdue', child: Text('Overdue')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(context, invoicesState),
          Expanded(
            child: invoicesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : invoicesState.error != null
                    ? Center(child: Text('Error: ${invoicesState.error}'))
                    : invoicesState.filteredInvoices.isEmpty
                        ? _buildEmptyState(context)
                        : _buildInvoicesList(context, invoicesState.filteredInvoices),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateInvoiceDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, InvoicesState state) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outstanding',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    _formatCurrency(state.totalOutstanding, 'UGX'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Overdue',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    '${state.overdueCount}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: state.overdueCount > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    '${state.invoices.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No invoices yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first invoice to get started',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(BuildContext context, List<Invoice> invoices) {
    return RefreshIndicator(
      onRefresh: () => ref.read(invoicesProvider.notifier).loadInvoices(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          return _buildInvoiceTile(context, invoice);
        },
      ),
    );
  }

  Widget _buildInvoiceTile(BuildContext context, Invoice invoice) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final statusColor = _getStatusColor(invoice.status, theme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showInvoiceDetails(context, invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      invoice.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    invoice.invoiceNumber,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatCurrency(invoice.totalAmount, invoice.currencyCode),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(invoice.invoiceDate),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.event, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${dateFormat.format(invoice.dueDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: invoice.dueDate.isBefore(DateTime.now()) && invoice.balanceDue > 0
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
              if (invoice.balanceDue > 0 && invoice.balanceDue < invoice.totalAmount)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    value: invoice.amountPaid / invoice.totalAmount,
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'void':
        return Colors.grey;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      )}';
    }
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }

  void _showInvoiceDetails(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _InvoiceDetailsSheet(
          invoice: invoice,
          scrollController: scrollController,
          onRecordPayment: () {
            Navigator.pop(context);
            _showRecordPaymentDialog(context, invoice);
          },
          onDelete: () async {
            Navigator.pop(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Invoice'),
                content: Text('Are you sure you want to delete ${invoice.invoiceNumber}?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(invoicesProvider.notifier).deleteInvoice(invoice.id);
            }
          },
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Invoice invoice) {
    final controller = TextEditingController(text: invoice.balanceDue.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${invoice.invoiceNumber}'),
            Text('Balance Due: ${_formatCurrency(invoice.balanceDue, invoice.currencyCode)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixIcon: Icon(Icons.payments),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                await ref.read(invoicesProvider.notifier).recordPayment(invoice.id, amount);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded')),
                  );
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _showCreateInvoiceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _InvoiceFormSheet(
          onSave: (data) async {
            await ref.read(invoicesProvider.notifier).createInvoice(
              customerId: data['customer_id'] as String,
              invoiceDate: data['invoice_date'] as DateTime,
              dueDate: data['due_date'] as DateTime,
              items: data['items'] as List<Map<String, dynamic>>,
              notes: data['notes'] as String?,
              createdBy: 'user', // TODO: Get from auth
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice created')),
              );
            }
          },
        ),
      ),
    );
  }
}

class _InvoiceDetailsSheet extends StatelessWidget {
  final Invoice invoice;
  final ScrollController scrollController;
  final VoidCallback onRecordPayment;
  final VoidCallback onDelete;

  const _InvoiceDetailsSheet({
    required this.invoice,
    required this.scrollController,
    required this.onRecordPayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(invoice.invoiceNumber, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          _DetailRow('Invoice Date', dateFormat.format(invoice.invoiceDate)),
          _DetailRow('Due Date', dateFormat.format(invoice.dueDate)),
          _DetailRow('Status', invoice.status.toUpperCase()),
          const Divider(height: 32),
          _DetailRow('Subtotal', _formatCurrency(invoice.subtotal, invoice.currencyCode)),
          _DetailRow('Tax', _formatCurrency(invoice.taxAmount, invoice.currencyCode)),
          _DetailRow('Discount', '-${_formatCurrency(invoice.discountAmount, invoice.currencyCode)}'),
          _DetailRow('Total', _formatCurrency(invoice.totalAmount, invoice.currencyCode), isHighlighted: true),
          const Divider(height: 32),
          _DetailRow('Paid', _formatCurrency(invoice.amountPaid, invoice.currencyCode)),
          _DetailRow('Balance Due', _formatCurrency(invoice.balanceDue, invoice.currencyCode), isHighlighted: true),
          const SizedBox(height: 24),
          if (invoice.balanceDue > 0)
            FilledButton.icon(
              onPressed: onRecordPayment,
              icon: const Icon(Icons.payments),
              label: const Text('Record Payment'),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            label: const Text('Delete Invoice'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      )}';
    }
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _DetailRow(this.label, this.value, {this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          Text(
            value,
            style: isHighlighted
                ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InvoiceFormSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _InvoiceFormSheet({required this.onSave});

  @override
  ConsumerState<_InvoiceFormSheet> createState() => _InvoiceFormSheetState();
}

class _InvoiceFormSheetState extends ConsumerState<_InvoiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final List<Map<String, dynamic>> _items = [];
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _items.add({'description': '', 'quantity': 1.0, 'unit_price': 0.0, 'tax_percent': 18.0});
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Invoice', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'Customer *',
                prefixIcon: Icon(Icons.person),
              ),
              items: customersState.activeCustomers.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.name));
              }).toList(),
              onChanged: (value) => setState(() => _selectedCustomerId = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Invoice Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(_invoiceDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => _invoiceDate = date);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(_dueDate)),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => _dueDate = date);
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Line Items', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) => _buildItemRow(entry.key)),
            TextButton.icon(
              onPressed: () => setState(() {
                _items.add({'description': '', 'quantity': 1.0, 'unit_price': 0.0, 'tax_percent': 18.0});
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Description', isDense: true),
                    initialValue: _items[index]['description'] as String,
                    onChanged: (v) => _items[index]['description'] = v,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: _items.length > 1
                      ? () => setState(() => _items.removeAt(index))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                    initialValue: _items[index]['quantity'].toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _items[index]['quantity'] = double.tryParse(v) ?? 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Unit Price', isDense: true),
                    initialValue: _items[index]['unit_price'].toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _items[index]['unit_price'] = double.tryParse(v) ?? 0.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Tax %', isDense: true),
                    initialValue: _items[index]['tax_percent'].toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _items[index]['tax_percent'] = double.tryParse(v) ?? 0.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave({
        'customer_id': _selectedCustomerId,
        'invoice_date': _invoiceDate,
        'due_date': _dueDate,
        'items': _items,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
