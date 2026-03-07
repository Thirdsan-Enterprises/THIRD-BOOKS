import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/invoice.dart';
import '../../core/services/pdf_invoice_service.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  DateTimeRange? _dateRange;
  final _currencyFormat = NumberFormat('#,###');

  List<Invoice> get _filteredInvoices {
    final invoicesState = ref.watch(invoicesProvider);
    return invoicesState.invoices.where((invoice) {
      final matchesSearch = _searchQuery.isEmpty ||
          (invoice.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          invoice.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == null ||
          (_selectedStatus == 'Paid' && invoice.status == InvoiceStatus.paid) ||
          (_selectedStatus == 'Partial' && invoice.status == InvoiceStatus.partial) ||
          (_selectedStatus == 'Pending' && invoice.status == InvoiceStatus.pending) ||
          (_selectedStatus == 'Overdue' && invoice.status == InvoiceStatus.overdue) ||
          (_selectedStatus == 'Draft' && invoice.status == InvoiceStatus.draft) ||
          (_selectedStatus == 'Cancelled' && invoice.status == InvoiceStatus.cancelled);

      final matchesDate = _dateRange == null ||
          (invoice.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              invoice.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesState = ref.watch(invoicesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context, invoicesState),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(
              child: invoicesState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildInvoicesTable(context),
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
              'Invoices',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Create and manage customer invoices',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(invoicesProvider.notifier).loadInvoices(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _exportInvoices,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export CSV'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showCreateInvoiceDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Invoice'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, InvoicesState state) {
    final totalInvoices = state.invoices.length;
    final totalAmount = state.invoices.fold<double>(0, (sum, i) => sum + i.total);
    final totalPaid = state.invoices.fold<double>(0, (sum, i) => sum + i.amountPaid);
    final overdueInvoices = state.invoices.where((i) => i.status == InvoiceStatus.overdue);
    final overdueCount = overdueInvoices.length;
    final overdueAmount = overdueInvoices.fold<double>(0, (sum, i) => sum + (i.total - i.amountPaid));

    return Row(
      children: [
        _SummaryCard(icon: Icons.receipt_long, iconColor: AppColors.primary, label: 'Total Invoices', value: totalInvoices.toString()),
        const SizedBox(width: 16),
        _SummaryCard(icon: Icons.account_balance_wallet, iconColor: AppColors.secondary, label: 'Total Invoiced', value: 'UGX ${_formatNumber(totalAmount)}'),
        const SizedBox(width: 16),
        _SummaryCard(icon: Icons.payments, iconColor: AppColors.income, label: 'Total Collected', value: 'UGX ${_formatNumber(totalPaid)}'),
        const SizedBox(width: 16),
        _SummaryCard(icon: Icons.warning_amber, iconColor: AppColors.expense, label: 'Overdue ($overdueCount)', value: 'UGX ${_formatNumber(overdueAmount)}'),
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
              hintText: 'Search invoices...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(hintText: 'All Statuses', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...['Draft', 'Pending', 'Partial', 'Paid', 'Overdue', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRange,
            );
            if (range != null) setState(() => _dateRange = range);
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(_dateRange != null
              ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
              : 'Date Range'),
        ),
        if (_dateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _dateRange = null)),
        ],
      ],
    );
  }

  Widget _buildInvoicesTable(BuildContext context) {
    final invoices = _filteredInvoices;

    if (invoices.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ? 'No invoices found matching "$_searchQuery"' : 'No invoices yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Create your first invoice to get started', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
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
            headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
            columns: const [
              DataColumn(label: Text('Invoice #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: invoices.map((invoice) {
              final balance = invoice.total - invoice.amountPaid;
              final isOverdue = invoice.status == InvoiceStatus.overdue;

              return DataRow(
                cells: [
                  DataCell(
                    Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                    onTap: () => _showInvoiceDetails(context, invoice),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(invoice.customerName ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    onTap: () => _showInvoiceDetails(context, invoice),
                  ),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(invoice.date))),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(invoice.dueDate), style: TextStyle(color: isOverdue ? AppColors.expense : null))),
                  DataCell(Text('UGX ${_currencyFormat.format(invoice.total)}', style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
                  DataCell(Text(
                    balance > 0 ? 'UGX ${_currencyFormat.format(balance)}' : '-',
                    style: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace', color: balance > 0 ? AppColors.expense : AppColors.income),
                  )),
                  DataCell(_buildStatusBadge(_getStatusString(invoice.status))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        onPressed: () => _showInvoiceDetails(context, invoice),
                        tooltip: 'View',
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 18),
                        onPressed: () => PdfInvoiceService.printInvoice(invoice),
                        tooltip: 'Print PDF',
                      ),
                      if (invoice.status != InvoiceStatus.paid && invoice.status != InvoiceStatus.cancelled)
                        IconButton(
                          icon: const Icon(Icons.payment_outlined, size: 18),
                          onPressed: () => _showRecordPaymentDialog(context, invoice),
                          tooltip: 'Record Payment',
                        ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _getStatusString(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Draft';
      case InvoiceStatus.sent: return 'Sent';
      case InvoiceStatus.pending: return 'Pending';
      case InvoiceStatus.partial: return 'Partial';
      case InvoiceStatus.paid: return 'Paid';
      case InvoiceStatus.overdue: return 'Overdue';
      case InvoiceStatus.cancelled: return 'Cancelled';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Paid': color = AppColors.income; break;
      case 'Partial': color = AppColors.info; break;
      case 'Pending': color = AppColors.warning; break;
      case 'Overdue': color = AppColors.expense; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(0)}K';
    return number.toStringAsFixed(0);
  }

  void _showCreateInvoiceDialog(BuildContext context) {
    final customersState = ref.read(customersProvider);
    String? selectedCustomerId;
    String? selectedCustomerName;
    DateTime invoiceDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    final lines = <_LineItem>[_LineItem()];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double subtotal = lines.fold(0, (s, l) => s + l.amount);
          double taxAmount = subtotal * 0.18;
          double total = subtotal + taxAmount;

          return AlertDialog(
            title: const Text('Create New Invoice'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Customer *'),
                            items: customersState.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (v) {
                              setDialogState(() {
                                selectedCustomerId = v;
                                selectedCustomerName = customersState.customers.firstWhere((c) => c.id == v).name;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: invoiceDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (date != null) setDialogState(() => invoiceDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Invoice Date'),
                              child: Text(DateFormat('MMM d, yyyy').format(invoiceDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (date != null) setDialogState(() => dueDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Due Date'),
                              child: Text(DateFormat('MMM d, yyyy').format(dueDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 40),
                            ],
                          ),
                          const Divider(),
                          ...lines.asMap().entries.map((entry) {
                            final i = entry.key;
                            final line = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: line.description,
                                      decoration: const InputDecoration(hintText: 'Item description', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      onChanged: (v) => line.description = v,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: line.qty.toString(),
                                      decoration: const InputDecoration(hintText: '1', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        line.qty = double.tryParse(v) ?? 1;
                                        line.amount = line.qty * line.price;
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: line.price > 0 ? line.price.toStringAsFixed(0) : '',
                                      decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        line.price = double.tryParse(v.replaceAll(',', '')) ?? 0;
                                        line.amount = line.qty * line.price;
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text('UGX ${_currencyFormat.format(line.amount)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: lines.length > 1 ? () => setDialogState(() => lines.removeAt(i)) : null,
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setDialogState(() => lines.add(_LineItem())),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Line'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Subtotal: UGX ${_currencyFormat.format(subtotal)}'),
                            Text('VAT (18%): UGX ${_currencyFormat.format(taxAmount)}'),
                            const SizedBox(height: 4),
                            Text('Total: UGX ${_currencyFormat.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              OutlinedButton(
                onPressed: () => _createInvoice(ctx, selectedCustomerId, selectedCustomerName, invoiceDate, dueDate, lines, InvoiceStatus.draft),
                child: const Text('Save as Draft'),
              ),
              FilledButton(
                onPressed: () => _createInvoice(ctx, selectedCustomerId, selectedCustomerName, invoiceDate, dueDate, lines, InvoiceStatus.pending),
                child: const Text('Create Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _createInvoice(BuildContext ctx, String? customerId, String? customerName, DateTime invoiceDate, DateTime dueDate, List<_LineItem> lines, InvoiceStatus status) {
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    if (lines.every((l) => l.description.isEmpty || l.amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one line item')));
      return;
    }

    final id = const Uuid().v4();
    final invoiceNumber = 'INV-${DateFormat('yyyyMM').format(invoiceDate)}-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final subtotal = lines.fold<double>(0, (s, l) => s + l.amount);
    final taxAmount = subtotal * 0.18;
    final total = subtotal + taxAmount;

    final invoiceLines = lines.where((l) => l.description.isNotEmpty && l.amount > 0).map((l) {
      return InvoiceLine(
        id: const Uuid().v4(),
        invoiceId: id,
        description: l.description,
        quantity: l.qty,
        unitPrice: l.price,
        taxRate: 18.0,
        taxAmount: l.amount * 0.18,
        amount: l.amount,
      );
    }).toList();

    final invoice = Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      date: invoiceDate,
      dueDate: dueDate,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      amountPaid: 0,
      status: status,
      lines: invoiceLines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(invoicesProvider.notifier).addInvoice(invoice);
    Navigator.pop(ctx);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice $invoiceNumber created (${status == InvoiceStatus.draft ? "Draft" : "Pending"})'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Invoice ${invoice.invoiceNumber}'),
            _buildStatusBadge(_getStatusString(invoice.status)),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('Customer', invoice.customerName ?? '-'),
                _DetailRow('Invoice Date', DateFormat('MMMM d, yyyy').format(invoice.date)),
                _DetailRow('Due Date', DateFormat('MMMM d, yyyy').format(invoice.dueDate)),
                _DetailRow('Items', '${invoice.lines.length} items'),
                const Divider(),
                if (invoice.lines.isNotEmpty) ...[
                  const Text('Line Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...invoice.lines.map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(line.description)),
                            Expanded(child: Text('x${line.quantity.toStringAsFixed(0)}', textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('UGX ${_currencyFormat.format(line.amount)}', textAlign: TextAlign.right)),
                          ],
                        ),
                      )),
                  const Divider(),
                ],
                _DetailRow('Subtotal', 'UGX ${_currencyFormat.format(invoice.subtotal)}'),
                _DetailRow('Tax (18%)', 'UGX ${_currencyFormat.format(invoice.taxAmount)}'),
                _DetailRow('Total', 'UGX ${_currencyFormat.format(invoice.total)}'),
                _DetailRow('Amount Paid', 'UGX ${_currencyFormat.format(invoice.amountPaid)}'),
                _DetailRow('Balance Due', 'UGX ${_currencyFormat.format(invoice.total - invoice.amountPaid)}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              PdfInvoiceService.printInvoice(invoice);
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              PdfInvoiceService.sharePdf(invoice);
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share PDF'),
          ),
          if (invoice.status != InvoiceStatus.paid && invoice.status != InvoiceStatus.cancelled)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRecordPaymentDialog(context, invoice);
              },
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Record Payment'),
            ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Invoice invoice) {
    final balance = invoice.total - invoice.amountPaid;
    final amountController = TextEditingController(text: balance.toStringAsFixed(0));
    String? selectedMethod;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Record Payment - ${invoice.invoiceNumber}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Balance Due: UGX ${_currencyFormat.format(balance)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Payment Amount', prefixText: 'UGX '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: ['Bank Transfer', 'Cash', 'Mobile Money', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setDialogState(() => selectedMethod = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final paymentAmount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                if (paymentAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                  return;
                }

                final newAmountPaid = invoice.amountPaid + paymentAmount;
                InvoiceStatus newStatus;
                if (newAmountPaid >= invoice.total) {
                  newStatus = InvoiceStatus.paid;
                } else if (newAmountPaid > 0) {
                  newStatus = InvoiceStatus.partial;
                } else {
                  newStatus = invoice.status;
                }

                final updated = invoice.copyWith(
                  amountPaid: newAmountPaid,
                  status: newStatus,
                  updatedAt: DateTime.now(),
                );
                ref.read(invoicesProvider.notifier).updateInvoice(updated);

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment of UGX ${_currencyFormat.format(paymentAmount)} recorded'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInvoices() async {
    final invoicesState = ref.read(invoicesProvider);
    if (invoicesState.invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoices to export')));
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Invoices',
      fileName: 'invoices_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('Invoice #,Customer,Date,Due Date,Subtotal,Tax,Total,Amount Paid,Status');
      for (final invoice in invoicesState.invoices) {
        buffer.writeln(
          '"${invoice.invoiceNumber}","${invoice.customerName}",'
          '"${DateFormat('yyyy-MM-dd').format(invoice.date)}",'
          '"${DateFormat('yyyy-MM-dd').format(invoice.dueDate)}",'
          '${invoice.subtotal},${invoice.taxAmount},${invoice.total},'
          '${invoice.amountPaid},"${_getStatusString(invoice.status)}"',
        );
      }

      final file = File(result);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${invoicesState.invoices.length} invoices to $result')),
        );
      }
    }
  }
}

class _LineItem {
  String description = '';
  double qty = 1;
  double price = 0;
  double amount = 0;
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryCard({required this.icon, required this.iconColor, required this.label, required this.value});

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
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
