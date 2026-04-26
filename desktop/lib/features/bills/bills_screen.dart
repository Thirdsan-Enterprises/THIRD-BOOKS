// Bills Screen for ThirdBooks Desktop App
// Track and manage vendor bills and expenses
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
import '../../core/services/api_client.dart'; // retained for data_service compatibility
import '../../core/models/bill.dart';
import '../../core/models/account.dart';
import '../../core/models/payment.dart';
import '../../core/models/models.dart' show JournalEntry, JournalLine, JournalEntryStatus;
import '../../core/providers/asset_drafts_provider.dart';
import '../../core/widgets/attachment_widget.dart';
import '../../core/widgets/account_search_field.dart';
import '../banking/banking_screen.dart' show bankingProvider;
import '../../core/models/bank_transaction.dart' show BankTxType;

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  DateTimeRange? _dateRange;
  final _currencyFormat = NumberFormat('#,###');

  List<Bill> get _filteredBills {
    final billsState = ref.watch(billsProvider);
    return billsState.bills.where((bill) {
      final matchesSearch = _searchQuery.isEmpty ||
          (bill.vendorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          bill.billNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == null ||
          (_selectedStatus == 'Paid' && bill.status == BillStatus.paid) ||
          (_selectedStatus == 'Partial' && bill.status == BillStatus.partial) ||
          (_selectedStatus == 'Pending' && bill.status == BillStatus.pending) ||
          (_selectedStatus == 'Overdue' && bill.status == BillStatus.overdue) ||
          (_selectedStatus == 'Draft' && bill.status == BillStatus.draft) ||
          (_selectedStatus == 'Cancelled' && bill.status == BillStatus.cancelled);

      final matchesDate = _dateRange == null ||
          (bill.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              bill.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final billsState = ref.watch(billsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context, billsState),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(
              child: billsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBillsTable(context),
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
              'Bills',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track and manage vendor bills and expenses',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(billsProvider.notifier).loadBills(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'export') {
                  _exportBills();
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
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showCreateBillDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Bill'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, BillsState state) {
    final totalBills = state.bills.length;
    final totalAmount = state.bills.fold<double>(0, (sum, b) => sum + b.total);
    final totalPaid = state.bills.fold<double>(0, (sum, b) => sum + b.amountPaid);
    final overdueBills = state.bills.where((b) => b.status == BillStatus.overdue);
    final overdueCount = overdueBills.length;
    final overdueAmount = overdueBills.fold<double>(0, (sum, b) => sum + (b.total - b.amountPaid));

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.receipt_long,
          iconColor: AppColors.primary,
          label: 'Total Bills',
          value: totalBills.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.secondary,
          label: 'Total Billed',
          value: 'UGX ${_formatNumber(totalAmount)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.payments,
          iconColor: AppColors.income,
          label: 'Total Paid',
          value: 'UGX ${_formatNumber(totalPaid)}',
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.warning_amber,
          iconColor: AppColors.expense,
          label: 'Overdue ($overdueCount)',
          value: 'UGX ${_formatNumber(overdueAmount)}',
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
              hintText: 'Search bills...',
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
          width: 160,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              hintText: 'All Statuses',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...['Draft', 'Pending', 'Partial', 'Paid', 'Overdue', 'Cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))),
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
            if (range != null) {
              setState(() => _dateRange = range);
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(_dateRange != null
              ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
              : 'Date Range'),
        ),
        if (_dateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => setState(() => _dateRange = null),
          ),
        ],
      ],
    );
  }

  Widget _buildBillsTable(BuildContext context) {
    final bills = _filteredBills;

    if (bills.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No bills found matching "$_searchQuery"'
                      : 'No bills yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first bill to get started',
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
              DataColumn(label: Text('Bill #')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: bills.map((bill) {
              final balance = bill.total - bill.amountPaid;
              final isOverdue = bill.status == BillStatus.overdue;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      bill.billNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                    onTap: () => _showBillDetails(context, bill),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(bill.vendorName ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          'ID: ${bill.vendorId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showBillDetails(context, bill),
                  ),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(bill.date))),
                  DataCell(
                    Text(
                      DateFormat('MMM d, yyyy').format(bill.dueDate),
                      style: TextStyle(color: isOverdue ? AppColors.expense : null),
                    ),
                  ),
                  DataCell(
                    Text(
                      'UGX ${_currencyFormat.format(bill.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(
                    Text(
                      balance > 0 ? 'UGX ${_currencyFormat.format(balance)}' : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: balance > 0 ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge(_getStatusString(bill.status))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          onPressed: () => _showBillDetails(context, bill),
                          tooltip: 'View',
                        ),
                        if (bill.status != BillStatus.paid && bill.status != BillStatus.cancelled)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditBillDialog(context, bill),
                            tooltip: 'Edit Bill',
                          ),
                        if (bill.status != BillStatus.paid && bill.status != BillStatus.cancelled)
                          IconButton(
                            icon: const Icon(Icons.payment_outlined, size: 18),
                            onPressed: () => _showRecordPaymentDialog(context, bill),
                            tooltip: 'Pay Bill',
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _confirmDeleteBill(context, bill),
                          tooltip: 'Delete Bill',
                          color: AppColors.error,
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

  String _getStatusString(BillStatus status) {
    switch (status) {
      case BillStatus.draft:
        return 'Draft';
      case BillStatus.pending:
        return 'Pending';
      case BillStatus.partial:
        return 'Partial';
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.cancelled:
        return 'Cancelled';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Paid':
        color = AppColors.income;
        break;
      case 'Partial':
        color = AppColors.info;
        break;
      case 'Pending':
        color = AppColors.warning;
        break;
      case 'Overdue':
        color = AppColors.expense;
        break;
      case 'Draft':
        color = Colors.grey;
        break;
      case 'Cancelled':
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

  void _showCreateBillDialog(BuildContext context) {
    final vendorsState = ref.read(vendorsProvider);
    final accountsState = ref.read(accountsProvider);
    String selectedCurrency = 'UGX';
    String? selectedCategory;
    String? selectedVendorId;
    final referenceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final List<_BillLineData> lines = [_BillLineData()];
    DateTime billDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    // Pre-generate the bill ID so attachments can be stored immediately.
    final billId = const Uuid().v4();

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
            title: const Text('Create New Bill'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Vendor + Currency + Category
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Vendor *'),
                            value: selectedVendorId,
                            items: vendorsState.vendors
                                .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedVendorId = v),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              // Non-asset expense categories
                              'Inventory',
                              'Office Supplies',
                              'Utilities',
                              'Raw Materials',
                              'Services',
                              // Tangible asset categories (IAS 16 / PP&E)
                              'Equipment',
                              'Vehicle',
                              'Furniture',
                              'Electronics',
                              'Machinery',
                              'Building',
                              'Land',
                              // Intangible asset categories (IAS 38)
                              'Software',
                              'License',
                              'Patent',
                              'Trademark',
                              'Goodwill',
                              'Intangible',
                            ]
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedCategory = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Row 2: Dates + Reference
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Bill Date',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('MMM d, yyyy').format(billDate),
                            ),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: billDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setDialogState(() => billDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Due Date',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('MMM d, yyyy').format(dueDate),
                            ),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setDialogState(() => dueDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'Reference Number'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Line Items',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Row(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: Text('Account',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Description',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 72,
                                  child: Text('Qty',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 100,
                                  child: Text('Unit Price',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              SizedBox(
                                  width: 100,
                                  child: Text('Amount',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              const SizedBox(width: 40),
                            ],
                          ),
                          const Divider(),
                          ...lines.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            return _BillLineWidget(
                              key: ValueKey(line.id),
                              line: line,
                              accounts: accountsState.accounts,
                              currency: selectedCurrency,
                              onChanged: () => setDialogState(() {}),
                              onDelete: lines.length > 1
                                  ? () => setDialogState(
                                        () => lines.removeAt(idx),
                                      )
                                  : null,
                            );
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                setDialogState(() => lines.add(_BillLineData())),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Line'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                '$selectedCurrency Subtotal: ${fmt.format(subtotal)}'),
                            if (ref.read(appSettingsProvider).enableVAT)
                              Text(
                                '$selectedCurrency VAT (18%): ${fmt.format(vat)}'),
                            const SizedBox(height: 4),
                            Text(
                              '$selectedCurrency Total: ${fmt.format(total)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    AttachmentPanel(
                      attachableType: 'bill',
                      localRecordId: billId,
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
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill saved as draft')),
                  );
                },
                child: const Text('Save as Draft'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedVendorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a vendor.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  final validLines = lines.where((l) => l.amount > 0).toList();
                  if (validLines.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add at least one line item with an amount.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }

                  final subtotal = validLines.fold<double>(0, (s, l) => s + l.amount);
                  final taxAmount = enableVAT ? subtotal * 0.18 : 0.0;
                  final total = subtotal + taxAmount;
                  final now = DateTime.now();
                  // billId was pre-generated above so attachments are already stored under it.
                  final vendor = vendorsState.vendors.firstWhere((v) => v.id == selectedVendorId);

                  final bill = Bill(
                    id: billId,
                    billNumber: 'BILL-${now.millisecondsSinceEpoch}',
                    vendorId: selectedVendorId!,
                    vendorName: vendor.name,
                    date: billDate,
                    dueDate: dueDate,
                    subtotal: subtotal,
                    taxAmount: taxAmount,
                    total: total,
                    status: BillStatus.pending,
                    currencyCode: selectedCurrency,
                    category: selectedCategory,
                    reference: referenceCtrl.text.trim().isEmpty ? null : referenceCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    lines: validLines.map((l) => BillLine(
                      id: l.id,
                      billId: billId,
                      accountId: l.accountId,
                      description: l.description,
                      amount: l.amount,
                      taxRate: enableVAT ? 0.18 : 0.0,
                      taxAmount: enableVAT ? l.amount * 0.18 : 0.0,
                    )).toList(),
                    createdAt: now,
                    updatedAt: now,
                  );

                  ref.read(billsProvider.notifier).addBill(bill);

                  Navigator.pop(ctx);

                  // ── Path 1: explicit asset category chosen in the dropdown ──
                  if (isAssetCategory(selectedCategory)) {
                    ref.read(assetDraftsProvider.notifier).addFromBill(
                      id: billId,
                      assetName: vendor.name.isNotEmpty
                          ? '$selectedCategory — ${vendor.name}'
                          : selectedCategory!,
                      category: selectedCategory!,
                      amount: subtotal,
                      currency: selectedCurrency,
                      vendorName: vendor.name,
                      billReference: referenceCtrl.text.trim().isEmpty
                          ? bill.billNumber
                          : referenceCtrl.text.trim(),
                      date: billDate,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bill saved. "$selectedCategory" added to Assets — go to Assets to set up depreciation.',
                        ),
                        backgroundColor: AppColors.info,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  } else {
                    // ── Path 2: detect fixed-asset CoA accounts from bill lines ──
                    // When a line uses an account with type=asset (fixedAsset /
                    // otherAsset), auto-create an AssetDraft so the item appears
                    // in the Assets tab and the user can set depreciation.
                    final assetNotifier =
                        ref.read(assetDraftsProvider.notifier);
                    final assetLines = validLines.where((l) {
                      if (l.accountId.isEmpty) return false;
                      final acct = accountsState.accounts.cast<Account?>()
                          .firstWhere((a) => a?.id == l.accountId,
                              orElse: () => null);
                      return acct != null &&
                          acct.type == AccountType.asset &&
                          (acct.subType == AccountSubType.fixedAsset ||
                              acct.subType == AccountSubType.intangibleAsset ||
                              acct.subType == AccountSubType.otherAsset ||
                              acct.subType ==
                                  AccountSubType.otherCurrentAsset);
                    }).toList();

                    for (final l in assetLines) {
                      final acct = accountsState.accounts.cast<Account?>()
                          .firstWhere((a) => a?.id == l.accountId,
                              orElse: () => null);
                      if (acct == null) continue;
                      final draftId = '${billId}_${l.id}';
                      final category = _inferAssetCategory(acct);
                      final assetName = l.description.trim().isNotEmpty
                          ? l.description.trim()
                          : vendor.name.isNotEmpty
                              ? '${acct.name} — ${vendor.name}'
                              : acct.name;
                      assetNotifier.addFromBill(
                        id: draftId,
                        assetName: assetName,
                        category: category,
                        amount: l.amount,
                        currency: selectedCurrency,
                        vendorName: vendor.name,
                        billReference: referenceCtrl.text.trim().isEmpty
                            ? bill.billNumber
                            : referenceCtrl.text.trim(),
                        date: billDate,
                      );
                    }

                    if (assetLines.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Bill saved. ${assetLines.length} fixed-asset line(s) added to Assets — '
                            'go to Assets to set up depreciation.',
                          ),
                          backgroundColor: AppColors.info,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Bill saved — queued for sync')),
                      );
                    }
                  }
                },
                child: const Text('Save Bill'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteBill(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete bill ${bill.billNumber}?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.expense, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text(
                  'A reversal journal entry will be posted to undo the Accounts Payable and expense entries. This cannot be undone.',
                  style: TextStyle(fontSize: 12),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(billsProvider.notifier).deleteBill(bill.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bill ${bill.billNumber} deleted — reversal entry posted'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditBillDialog(BuildContext context, Bill bill) {
    final vendorsState  = ref.read(vendorsProvider);
    final accountsState = ref.read(accountsProvider);

    String selectedCurrency   = bill.currencyCode;
    String? selectedCategory  = bill.category;
    String? selectedVendorId  = bill.vendorId;
    final referenceCtrl = TextEditingController(text: bill.reference ?? '');
    final notesCtrl     = TextEditingController(text: bill.notes ?? '');
    DateTime billDate   = bill.date;
    DateTime dueDate    = bill.dueDate;

    // Seed line items from existing bill lines (qty=1, unitPrice=line amount)
    final List<_BillLineData> lines = bill.lines.map((l) {
      final ld = _BillLineData();
      ld.id         = l.id;       // preserve original line ID so asset draft lookups match
      ld.accountId  = l.accountId;
      ld.description = l.description;
      ld.qty       = 1;
      ld.unitPrice  = l.amount;
      return ld;
    }).toList();
    if (lines.isEmpty) lines.add(_BillLineData());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final enableVAT = ref.read(appSettingsProvider).enableVAT;
          final subtotal = lines.fold(0.0, (s, l) => s + l.amount);
          final vat      = enableVAT ? subtotal * 0.18 : 0.0;
          final total    = subtotal + vat;
          final fmt      = NumberFormat('#,###');

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Edit Bill — ${bill.billNumber}'),
                if (bill.amountPaid > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Has payments — amount changes affect balance only',
                      style: TextStyle(fontSize: 11, color: AppColors.warning),
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Vendor *'),
                            value: selectedVendorId,
                            items: vendorsState.vendors
                                .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedVendorId = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<String>(
                            value: selectedCurrency,
                            decoration: const InputDecoration(labelText: 'Currency'),
                            items: ['UGX', 'USD', 'EUR', 'GBP', 'KES', 'TZS']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedCurrency = v ?? 'UGX'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: [
                              'Inventory', 'Office Supplies', 'Utilities', 'Raw Materials',
                              'Services', 'Equipment', 'Vehicle', 'Furniture',
                              'Electronics', 'Machinery', 'Building', 'Land',
                              // Intangible asset categories (IAS 38)
                              'Software', 'License', 'Patent', 'Trademark', 'Goodwill', 'Intangible',
                            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setDialogState(() => selectedCategory = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Bill Date',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('MMM d, yyyy').format(billDate),
                            ),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: billDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setDialogState(() => billDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Due Date',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('MMM d, yyyy').format(dueDate),
                            ),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setDialogState(() => dueDate = d);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: referenceCtrl,
                            decoration: const InputDecoration(labelText: 'Reference Number'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(flex: 3, child: Text('Account', style: const TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text('Description', style: const TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 72, child: Text('Qty', style: const TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 100, child: Text('Unit Price', style: const TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 100, child: Text('Amount', style: const TextStyle(fontWeight: FontWeight.w600))),
                              const SizedBox(width: 40),
                            ],
                          ),
                          const Divider(),
                          ...lines.asMap().entries.map((entry) {
                            final idx  = entry.key;
                            final line = entry.value;
                            return _BillLineWidget(
                              key: ValueKey(line.id),
                              line: line,
                              accounts: accountsState.accounts,
                              currency: selectedCurrency,
                              onChanged: () => setDialogState(() {}),
                              onDelete: lines.length > 1
                                  ? () => setDialogState(() => lines.removeAt(idx))
                                  : null,
                            );
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setDialogState(() => lines.add(_BillLineData())),
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
                            Text('$selectedCurrency Subtotal: ${fmt.format(subtotal)}'),
                            if (enableVAT) Text('$selectedCurrency VAT (18%): ${fmt.format(vat)}'),
                            const SizedBox(height: 4),
                            Text(
                              '$selectedCurrency Total: ${fmt.format(total)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
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
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                onPressed: () {
                  if (selectedVendorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a vendor.'), backgroundColor: AppColors.warning),
                    );
                    return;
                  }
                  final validLines = lines.where((l) => l.amount > 0).toList();
                  if (validLines.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add at least one line item.'), backgroundColor: AppColors.warning),
                    );
                    return;
                  }

                  final newSubtotal  = validLines.fold<double>(0, (s, l) => s + l.amount);
                  final newTaxAmount = enableVAT ? newSubtotal * 0.18 : 0.0;
                  final newTotal     = newSubtotal + newTaxAmount;
                  final vendor       = vendorsState.vendors.firstWhere((v) => v.id == selectedVendorId);

                  // Derive status from payment state relative to new total
                  BillStatus newStatus;
                  if (bill.amountPaid <= 0) {
                    newStatus = BillStatus.pending;
                  } else if (bill.amountPaid >= newTotal) {
                    newStatus = BillStatus.paid;
                  } else {
                    newStatus = BillStatus.partial;
                  }

                  final updatedBill = Bill(
                    id: bill.id,
                    billNumber: bill.billNumber,
                    vendorId: selectedVendorId!,
                    vendorName: vendor.name,
                    date: billDate,
                    dueDate: dueDate,
                    subtotal: newSubtotal,
                    taxAmount: newTaxAmount,
                    total: newTotal,
                    amountPaid: bill.amountPaid,
                    status: newStatus,
                    currencyCode: selectedCurrency,
                    category: selectedCategory,
                    reference: referenceCtrl.text.trim().isEmpty ? null : referenceCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    lines: validLines.map((l) => BillLine(
                      id: l.id,
                      billId: bill.id,
                      accountId: l.accountId,
                      description: l.description,
                      amount: l.amount,
                      taxRate: enableVAT ? 0.18 : 0.0,
                      taxAmount: enableVAT ? l.amount * 0.18 : 0.0,
                    )).toList(),
                    createdAt: bill.createdAt,
                    updatedAt: DateTime.now(),
                  );

                  ref.read(billsProvider.notifier).updateBill(updatedBill);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill updated successfully'), backgroundColor: AppColors.success),
                  );
                },
                label: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBillDetails(BuildContext context, Bill bill) {
    final payments = ref.read(paymentsProvider).payments
        .where((p) =>
            p.paymentType == PaymentType.made &&
            p.vendorId == bill.vendorId &&
            (p.notes?.contains(bill.billNumber) ?? false))
        .toList()
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    final allAccounts = ref.read(accountsProvider).accounts;
    String _accountLabel(Payment p) {
      final Account? acct = allAccounts.cast<Account?>()
          .firstWhere((a) => a?.id == p.accountId, orElse: () => null);
      final name = (p.accountName?.isNotEmpty ?? false)
          ? p.accountName
          : acct?.name;
      return name != null ? '$name (${p.paymentMethod})' : p.paymentMethod;
    }

    final fmt = NumberFormat('#,##0', 'en_US');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bill ${bill.billNumber}'),
            _buildStatusBadge(_getStatusString(bill.status)),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header info ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: _DetailRow('Vendor', bill.vendorName ?? '-')),
                    Expanded(child: _DetailRow('Bill Date',
                        DateFormat('MMM d, yyyy').format(bill.date))),
                    Expanded(child: _DetailRow('Due Date',
                        DateFormat('MMM d, yyyy').format(bill.dueDate))),
                  ],
                ),
                if (bill.reference != null && bill.reference!.isNotEmpty)
                  _DetailRow('Reference', bill.reference!),
                if (bill.notes != null && bill.notes!.isNotEmpty)
                  _DetailRow('Notes', bill.notes!),
                const SizedBox(height: 16),

                // ── Line items ─────────────────────────────────────────────
                Text('Line Items',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(2),
                      4: FlexColumnWidth(1),
                      5: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                        children: [
                          _th('Account'),
                          _th('Description'),
                          _th('Qty'),
                          _th('Unit Price'),
                          _th('VAT%'),
                          _th('Amount', align: TextAlign.right),
                        ],
                      ),
                      ...bill.lines.map((l) => TableRow(
                        children: [
                          _td(l.accountName ?? l.accountId),
                          _td(l.description),
                          _td('1'),
                          _td('UGX ${fmt.format(l.amount)}', align: TextAlign.right),
                          _td(l.taxRate > 0 ? '${l.taxRate.toStringAsFixed(0)}%' : '-',
                              align: TextAlign.center),
                          _td('UGX ${fmt.format(l.amount + l.taxAmount)}',
                              align: TextAlign.right),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Totals summary ─────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        _DetailRow('Subtotal', 'UGX ${fmt.format(bill.subtotal)}'),
                        if (bill.taxAmount > 0)
                          _DetailRow('VAT (18%)', 'UGX ${fmt.format(bill.taxAmount)}'),
                        const Divider(height: 8),
                        _DetailRow('Total', 'UGX ${fmt.format(bill.total)}'),
                        _DetailRow('Amount Paid', 'UGX ${fmt.format(bill.amountPaid)}'),
                        _DetailRow(
                          'Balance Due',
                          'UGX ${fmt.format(bill.total - bill.amountPaid)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Payment history ────────────────────────────────────────
                Text('Payment History',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (payments.isEmpty && bill.amountPaid <= 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No payments recorded yet.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                          children: [
                            _th('Date & Time'),
                            _th('Account / Method'),
                            _th('Reference'),
                            _th('Amount', align: TextAlign.right),
                          ],
                        ),
                        if (payments.isEmpty && bill.amountPaid > 0)
                          TableRow(
                            children: [
                              _td('—'),
                              _td('Paid (no details on record)'),
                              _td('—'),
                              _td('UGX ${fmt.format(bill.amountPaid)}',
                                  align: TextAlign.right),
                            ],
                          )
                        else
                          for (final p in payments)
                            TableRow(
                              children: [
                                _td(DateFormat('MMM d, yyyy  HH:mm').format(p.paymentDate)),
                                _td(_accountLabel(p)),
                                _td(p.reference ?? p.paymentNumber),
                                _td('UGX ${fmt.format(p.amount)}',
                                    align: TextAlign.right),
                              ],
                            ),
                        TableRow(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.5),
                          ),
                          children: [
                            _td(''),
                            _td(''),
                            _td('Total Paid',
                                bold: true, align: TextAlign.right),
                            _td(
                              'UGX ${fmt.format(bill.amountPaid)}',
                              bold: true,
                              align: TextAlign.right,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                AttachmentPanel(
                  attachableType: 'bill',
                  localRecordId: bill.id,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (bill.status != BillStatus.paid && bill.status != BillStatus.cancelled)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRecordPaymentDialog(context, bill);
              },
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Pay Bill'),
            ),
        ],
      ),
    );
  }

  static Widget _th(String label, {TextAlign align = TextAlign.left}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            textAlign: align),
      );

  static Widget _td(String value,
          {TextAlign align = TextAlign.left, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
            textAlign: align),
      );

  void _showRecordPaymentDialog(BuildContext context, Bill bill) {
    final balance = bill.total - bill.amountPaid;
    final accountsState = ref.read(accountsProvider);
    final bankAccounts = accountsState.accounts.where((a) =>
        a.subType.toString().contains('bank') ||
        a.subType.toString().contains('cash')).toList();

    final amountCtrl = TextEditingController(text: balance.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    String? selectedMethod = 'Bank Transfer';
    String? selectedAccountId = bankAccounts.isNotEmpty ? bankAccounts.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Pay Bill — ${bill.billNumber}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('UGX ${_currencyFormat.format(balance)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Payment Amount', prefixText: 'UGX '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Pay From Account'),
                  value: selectedAccountId,
                  items: bankAccounts.isNotEmpty
                      ? bankAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList()
                      : const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash on Hand')),
                          DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                        ],
                  onChanged: (v) => setDialogState(() => selectedAccountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  value: selectedMethod,
                  items: ['Bank Transfer', 'Cash', 'Mobile Money', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMethod = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference (Optional)',
                    hintText: 'Cheque no. / transfer ref',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                    amountCtrl.text.replaceAll(',', '').trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter a valid payment amount.'),
                    backgroundColor: AppColors.warning,
                  ));
                  return;
                }
                if (amount > balance + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Amount exceeds balance due (UGX ${_currencyFormat.format(balance)}).'),
                    backgroundColor: AppColors.warning,
                  ));
                  return;
                }

                final now = DateTime.now();
                final Account? selectedAccount = bankAccounts.cast<Account?>()
                    .firstWhere((a) => a?.id == selectedAccountId, orElse: () => null);
                final payment = Payment(
                  id: now.millisecondsSinceEpoch.toString(),
                  paymentNumber: 'PAY-${now.millisecondsSinceEpoch}',
                  paymentDate: now,
                  amount: amount,
                  paymentType: PaymentType.made,
                  vendorId: bill.vendorId,
                  vendorName: bill.vendorName,
                  accountId: selectedAccountId,
                  accountName: selectedAccount?.name,
                  paymentMethod: selectedMethod ?? 'Bank Transfer',
                  reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                  notes: 'Payment for ${bill.billNumber}',
                  createdAt: now,
                  updatedAt: now,
                );

                ref.read(paymentsProvider.notifier).addPayment(payment);
                ref.read(billsProvider.notifier).recordPayment(bill.id, amount);

                // GL journal entry: DR Accounts Payable (164), CR Bank/Cash account
                // Reduces AP liability and reduces cash/bank asset when bill is paid.
                const uuid = Uuid();
                final jeId = uuid.v4();
                final payAccId = selectedAccountId ?? 'acct-100';
                final payAccCode = payAccId.replaceAll('acct-', '');
                final payAccName = bankAccounts
                    .cast<Account?>()
                    .firstWhere((a) => a?.id == payAccId, orElse: () => null)
                    ?.name ?? 'Bank / Cash';
                ref.read(journalsProvider.notifier).addEntry(JournalEntry(
                  id: jeId,
                  entryNumber: 'PAY-JE-${payment.paymentNumber}',
                  date: now,
                  description: 'Bill payment: ${bill.billNumber} — ${bill.vendorName ?? ''}',
                  reference: payment.reference ?? payment.paymentNumber,
                  status: JournalEntryStatus.posted,
                  lines: [
                    JournalLine(
                      id: '$jeId-ap',
                      journalEntryId: jeId,
                      accountId: 'acct-164',
                      accountCode: '164',
                      accountName: 'Accounts Payable',
                      debit: amount,
                      credit: 0,
                    ),
                    JournalLine(
                      id: '$jeId-bank',
                      journalEntryId: jeId,
                      accountId: payAccId,
                      accountCode: payAccCode,
                      accountName: payAccName,
                      debit: 0,
                      credit: amount,
                    ),
                  ],
                  createdAt: now,
                  updatedAt: now,
                ));

                // Record a bank transaction so the banking screen's
                // statement view and running balance reflect this payment.
                // payAccId is like 'acct-101' (ABSA) / 'acct-102' (MTN) /
                // 'acct-100' (Petty Cash).  We match it to the banking provider
                // accounts by CoA ID stored in the _bankCoaId mapping.
                final bankState = ref.read(bankingProvider);
                final matchedBankAccount = bankState.accounts
                    .cast<dynamic>()
                    .firstWhere(
                      (a) {
                        // _bankCoaId logic replicated here to find the account
                        final n = (a.bankName as String).toLowerCase();
                        if (payAccId == 'acct-102') {
                          return n.contains('mtn') ||
                              n.contains('mobile money') ||
                              n.contains('momo');
                        }
                        if (payAccId == 'acct-101') return n.contains('absa');
                        if (payAccId == 'acct-103') return n.contains('stanbic');
                        if (payAccId == 'acct-100') {
                          return n.contains('petty') ||
                              (n.contains('cash') && !n.contains('stancash'));
                        }
                        return false;
                      },
                      orElse: () => null,
                    );

                if (matchedBankAccount != null) {
                  // Bill payment = money leaves the bank → debit (outflow).
                  ref.read(bankingProvider.notifier).recordTransaction(
                    bankAccountId: matchedBankAccount.id as String,
                    date: now,
                    description:
                        'Bill payment: ${bill.billNumber} — ${bill.vendorName ?? ''}',
                    type: BankTxType.debit,
                    amount: amount,
                    reference: payment.reference ?? payment.paymentNumber,
                    sourceType: 'bill_payment',
                    sourceId: payment.id,
                    sourceLabel: bill.billNumber,
                  );
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Payment of UGX ${_currencyFormat.format(amount)} recorded.'),
                  backgroundColor: AppColors.success,
                ));
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBills() async {
    final billsState = ref.read(billsProvider);

    if (billsState.bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bills to export')),
      );
      return;
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Bills',
      fileName: 'bills_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('Bill #,Vendor,Date,Due Date,Subtotal,Tax,Total,Amount Paid,Status');

      for (final bill in billsState.bills) {
        buffer.writeln(
          '"${bill.billNumber}","${bill.vendorName}",'
          '"${DateFormat('yyyy-MM-dd').format(bill.date)}",'
          '"${DateFormat('yyyy-MM-dd').format(bill.dueDate)}",'
          '${bill.subtotal},${bill.taxAmount},${bill.total},'
          '${bill.amountPaid},"${_getStatusString(bill.status)}"'
        );
      }

      final file = File(result);
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${billsState.bills.length} bills to $result')),
        );
      }
    }
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: map an Account's subType to an asset register category string.
// ---------------------------------------------------------------------------
String _inferAssetCategory(Account acct) {
  final name = acct.name.toLowerCase();
  if (name.contains('vehicle') || name.contains('motor') || name.contains('car')) {
    return 'Vehicle';
  }
  if (name.contains('furniture') || name.contains('fittings')) {
    return 'Furniture';
  }
  if (name.contains('computer') || name.contains('laptop') ||
      name.contains('electronic') || name.contains('phone')) {
    return 'Electronics';
  }
  if (name.contains('building') || name.contains('premises') ||
      name.contains('property')) {
    return 'Building';
  }
  if (name.contains('land') || name.contains('plot')) {
    return 'Land';
  }
  if (name.contains('machine') || name.contains('machinery') ||
      name.contains('plant')) {
    return 'Machinery';
  }
  // Intangible assets (IAS 38)
  if (name.contains('software') || name.contains('license') || name.contains('licence')) {
    return 'Software';
  }
  if (name.contains('patent') || name.contains('trademark') || name.contains('ip ')) {
    return 'Patent';
  }
  if (name.contains('goodwill')) return 'Goodwill';
  if (name.contains('intangible')) return 'Intangible';
  // Default for generic fixed-asset accounts
  return 'Equipment';
}

// ---------------------------------------------------------------------------
// Bill Line Data Model
// ---------------------------------------------------------------------------
class _BillLineData {
  String id = DateTime.now().microsecondsSinceEpoch.toString();
  String accountId = '';
  String description = '';
  double qty = 1;
  double unitPrice = 0;
  double get amount => qty * unitPrice;
}

// ---------------------------------------------------------------------------
// Bill Line Widget — stateful for auto-calculation
// ---------------------------------------------------------------------------
class _BillLineWidget extends StatefulWidget {
  final _BillLineData line;
  final List<Account> accounts;
  final String currency;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _BillLineWidget({
    super.key,
    required this.line,
    required this.accounts,
    required this.currency,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_BillLineWidget> createState() => _BillLineWidgetState();
}

class _BillLineWidgetState extends State<_BillLineWidget> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.line.qty == 1 ? '1' : widget.line.qty.toString());
    _priceCtrl = TextEditingController(
        text: widget.line.unitPrice == 0 ? '' : widget.line.unitPrice.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Account
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
          // Description
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: 'Description',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                widget.line.description = v;
              },
            ),
          ),
          const SizedBox(width: 8),
          // Qty
          SizedBox(
            width: 72,
            child: TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                hintText: '1',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                setState(() {
                  widget.line.qty = double.tryParse(v) ?? 1;
                });
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Unit Price
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: _priceCtrl,
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '${widget.currency} ',
                prefixStyle: const TextStyle(fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                setState(() {
                  widget.line.unitPrice = double.tryParse(v) ?? 0;
                });
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Amount (auto-computed)
          SizedBox(
            width: 100,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).dividerColor),
              ),
              child: Text(
                fmt.format(widget.line.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontFamily: 'monospace'),
              ),
            ),
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: widget.onDelete,
            color: widget.onDelete != null ? AppColors.error : Colors.grey,
          ),
        ],
      ),
    );
  }
}
