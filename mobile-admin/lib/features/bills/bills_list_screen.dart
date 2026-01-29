import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/bills_provider.dart';
import '../../core/providers/vendors_provider.dart';

class BillsListScreen extends ConsumerStatefulWidget {
  const BillsListScreen({super.key});

  @override
  ConsumerState<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends ConsumerState<BillsListScreen> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final billsState = ref.watch(billsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedStatus = value == 'all' ? null : value);
              ref.read(billsProvider.notifier).setStatusFilter(_selectedStatus);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'draft', child: Text('Draft')),
              const PopupMenuItem(value: 'approved', child: Text('Approved')),
              const PopupMenuItem(value: 'paid', child: Text('Paid')),
              const PopupMenuItem(value: 'partial', child: Text('Partial')),
              const PopupMenuItem(value: 'overdue', child: Text('Overdue')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(context, billsState),
          Expanded(
            child: billsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : billsState.error != null
                    ? Center(child: Text('Error: ${billsState.error}'))
                    : billsState.filteredBills.isEmpty
                        ? _buildEmptyState(context)
                        : _buildBillsList(context, billsState.filteredBills),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBillDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, BillsState state) {
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
                  Text('Payable', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  Text(
                    _formatCurrency(state.totalOutstanding, 'UGX'),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: theme.colorScheme.outline.withOpacity(0.3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Overdue', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  Text(
                    '${state.overdueCount}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: state.overdueCount > 0 ? theme.colorScheme.error : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: theme.colorScheme.outline.withOpacity(0.3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  Text('${state.bills.length}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
          Icon(Icons.receipt_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No bills yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Record your first bill to track expenses', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildBillsList(BuildContext context, List<Bill> bills) {
    return RefreshIndicator(
      onRefresh: () => ref.read(billsProvider.notifier).loadBills(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: bills.length,
        itemBuilder: (context, index) => _buildBillTile(context, bills[index]),
      ),
    );
  }

  Widget _buildBillTile(BuildContext context, Bill bill) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final statusColor = _getStatusColor(bill.status, theme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showBillDetails(context, bill),
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
                      bill.status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(bill.billNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    _formatCurrency(bill.totalAmount, bill.currencyCode),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.error),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (bill.vendorInvoiceNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Vendor Ref: ${bill.vendorInvoiceNumber}', style: theme.textTheme.bodySmall),
                ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(dateFormat.format(bill.billDate), style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                  Icon(Icons.event, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${dateFormat.format(bill.dueDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bill.dueDate.isBefore(DateTime.now()) && bill.balanceDue > 0 ? theme.colorScheme.error : null,
                    ),
                  ),
                ],
              ),
              if (bill.balanceDue > 0 && bill.balanceDue < bill.totalAmount)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    value: bill.amountPaid / bill.totalAmount,
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
      case 'draft': return Colors.grey;
      case 'approved': return Colors.blue;
      case 'paid': return Colors.green;
      case 'partial': return Colors.orange;
      case 'overdue': return Colors.red;
      case 'void': return Colors.grey;
      default: return theme.colorScheme.primary;
    }
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }

  void _showBillDetails(BuildContext context, Bill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _BillDetailsSheet(
          bill: bill,
          scrollController: scrollController,
          onRecordPayment: () {
            Navigator.pop(context);
            _showRecordPaymentDialog(context, bill);
          },
          onDelete: () async {
            Navigator.pop(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Bill'),
                content: Text('Are you sure you want to delete ${bill.billNumber}?'),
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
              await ref.read(billsProvider.notifier).deleteBill(bill.id);
            }
          },
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Bill bill) {
    final controller = TextEditingController(text: bill.balanceDue.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill: ${bill.billNumber}'),
            Text('Balance Due: ${_formatCurrency(bill.balanceDue, bill.currencyCode)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Payment Amount', prefixIcon: Icon(Icons.payments)),
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
                await ref.read(billsProvider.notifier).recordPayment(bill.id, amount);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _showCreateBillDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BillFormSheet(
          onSave: (data) async {
            await ref.read(billsProvider.notifier).createBill(
              vendorId: data['vendor_id'] as String,
              billDate: data['bill_date'] as DateTime,
              dueDate: data['due_date'] as DateTime,
              vendorInvoiceNumber: data['vendor_invoice_number'] as String?,
              items: data['items'] as List<Map<String, dynamic>>,
              notes: data['notes'] as String?,
              createdBy: 'user',
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill created')));
            }
          },
        ),
      ),
    );
  }
}

class _BillDetailsSheet extends StatelessWidget {
  final Bill bill;
  final ScrollController scrollController;
  final VoidCallback onRecordPayment;
  final VoidCallback onDelete;

  const _BillDetailsSheet({
    required this.bill,
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
              decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(bill.billNumber, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          _DetailRow('Bill Date', dateFormat.format(bill.billDate)),
          _DetailRow('Due Date', dateFormat.format(bill.dueDate)),
          _DetailRow('Status', bill.status.toUpperCase()),
          if (bill.vendorInvoiceNumber != null) _DetailRow('Vendor Invoice', bill.vendorInvoiceNumber!),
          const Divider(height: 32),
          _DetailRow('Subtotal', _formatCurrency(bill.subtotal, bill.currencyCode)),
          _DetailRow('Tax', _formatCurrency(bill.taxAmount, bill.currencyCode)),
          _DetailRow('Discount', '-${_formatCurrency(bill.discountAmount, bill.currencyCode)}'),
          _DetailRow('Total', _formatCurrency(bill.totalAmount, bill.currencyCode), isHighlighted: true),
          const Divider(height: 32),
          _DetailRow('Paid', _formatCurrency(bill.amountPaid, bill.currencyCode)),
          _DetailRow('Balance Due', _formatCurrency(bill.balanceDue, bill.currencyCode), isHighlighted: true),
          const SizedBox(height: 24),
          if (bill.balanceDue > 0)
            FilledButton.icon(onPressed: onRecordPayment, icon: const Icon(Icons.payments), label: const Text('Record Payment')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            label: const Text('Delete Bill'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
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
          Text(value, style: isHighlighted ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) : theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _BillFormSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _BillFormSheet({required this.onSave});

  @override
  ConsumerState<_BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends ConsumerState<_BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVendorId;
  DateTime _billDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _vendorInvoiceController = TextEditingController();
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
    _vendorInvoiceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsState = ref.watch(vendorsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Bill', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedVendorId,
              decoration: const InputDecoration(labelText: 'Vendor *', prefixIcon: Icon(Icons.business)),
              items: vendorsState.activeVendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))).toList(),
              onChanged: (value) => setState(() => _selectedVendorId = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vendorInvoiceController,
              decoration: const InputDecoration(labelText: 'Vendor Invoice #', prefixIcon: Icon(Icons.tag)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bill Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(_billDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: _billDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (date != null) setState(() => _billDate = date);
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
                      final date = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
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
              onPressed: () => setState(() => _items.add({'description': '', 'quantity': 1.0, 'unit_price': 0.0, 'tax_percent': 18.0})),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)), maxLines: 2),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Bill'),
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
                  onPressed: _items.length > 1 ? () => setState(() => _items.removeAt(index)) : null,
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
    if (_selectedVendorId == null) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave({
        'vendor_id': _selectedVendorId,
        'bill_date': _billDate,
        'due_date': _dueDate,
        'vendor_invoice_number': _vendorInvoiceController.text.isEmpty ? null : _vendorInvoiceController.text,
        'items': _items,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
