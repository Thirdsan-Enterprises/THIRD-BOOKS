import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';

class OutletExpenditureScreen extends ConsumerStatefulWidget {
  final String? outletId;
  final String? outletName;

  const OutletExpenditureScreen({
    super.key,
    this.outletId,
    this.outletName,
  });

  @override
  ConsumerState<OutletExpenditureScreen> createState() => _OutletExpenditureScreenState();
}

class _OutletExpenditureScreenState extends ConsumerState<OutletExpenditureScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  final _numberFormat = NumberFormat('#,##0', 'en_US');
  String? _selectedOutletId;
  String _selectedStatus = 'All';

  final List<String> _expenseTypes = [
    'Maintenance',
    'Repairs',
    'Supplies',
    'Utilities',
    'Security',
    'Rent',
    'Transportation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOutletId = widget.outletId;
  }

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsStreamProvider);
    final expendituresAsync = ref.watch(allOutletExpendituresProvider);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.money_off, size: 32, color: AppColors.error),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outlet Expenditures',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track expenses per outlet (maintenance, repairs, supplies, etc.)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddExpenditureDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: outletsAsync.when(
                    data: (outlets) => DropdownButtonFormField<String?>(
                      value: _selectedOutletId,
                      decoration: InputDecoration(
                        labelText: 'Filter by Outlet',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Outlets')),
                        ...outlets.map((o) => DropdownMenuItem(value: o.id, child: Text('${o.name} (${o.outletCode})'))),
                      ],
                      onChanged: (v) => setState(() => _selectedOutletId = v),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                ...['All', 'pending', 'approved', 'paid'].map((status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status == 'All' ? 'All' : status[0].toUpperCase() + status.substring(1)),
                        selected: _selectedStatus == status,
                        onSelected: (selected) => setState(() => _selectedStatus = status),
                      ),
                    )),
              ],
            ),
          ),

          // ── Commission Expense Section (40% of GGR per outlet) ────────────
          // This is the primary expense for MagicBet: 40% of adjusted GGR
          // paid to outlet location owners, with carry-forward loss adjustment.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ref.watch(outletAnalyticsProvider).when(
              data: (analytics) {
                final lifetimes = _selectedOutletId == null
                    ? analytics.lifetimeTotals
                    : analytics.lifetimeTotals.where((o) => o.outletId == _selectedOutletId).toList();
                if (lifetimes.isEmpty) return const SizedBox.shrink();
                final totalCommission = lifetimes.fold(0.0, (s, o) => s + o.totalOutletExpense);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.handshake_outlined, color: AppColors.warning, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Outlet Commission Expense (40% of GGR)',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                Text('Paid to location owners — calculated after carry-forward loss adjustment',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Total Commission', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                                Text(
                                  'UGX ${_numberFormat.format(totalCommission.round())}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.warning),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        // Per-outlet commission table
                        Row(
                          children: [
                            Expanded(flex: 3, child: Text('Outlet', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            Expanded(flex: 2, child: Text('Total GGR', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text('Commission (40%)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.warning), textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text('Net Revenue (60%)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.income), textAlign: TextAlign.right)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...lifetimes.map((o) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.outletName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    Text(o.outletCode, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                                  ],
                                )),
                                Expanded(flex: 2, child: Text(
                                  'UGX ${_numberFormat.format(o.totalGGR.round())}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                )),
                                Expanded(flex: 2, child: Text(
                                  'UGX ${_numberFormat.format(o.totalOutletExpense.round())}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppColors.warning),
                                )),
                                Expanded(flex: 2, child: Text(
                                  'UGX ${_numberFormat.format(o.netRevenue.round())}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: o.netRevenue >= 0 ? AppColors.income : AppColors.error),
                                )),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Operational Expenditure Table ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Operational Expenses',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // Expenditure Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: expendituresAsync.when(
                      data: (expenditures) {
                        final outletsData = ref.watch(outletsStreamProvider).valueOrNull ?? [];
                        final outletMap = {for (var o in outletsData) o.id: o};

                        var filtered = expenditures.toList();
                        if (_selectedOutletId != null) filtered = filtered.where((e) => e.outletId == _selectedOutletId).toList();
                        if (_selectedStatus != 'All') filtered = filtered.where((e) => e.status == _selectedStatus).toList();
                        filtered.sort((a, b) => b.date.compareTo(a.date));

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No expenditure records found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final exp = filtered[index];
                            final outlet = outletMap[exp.outletId];
                            final statusColor = exp.status == 'paid' ? AppColors.success : exp.status == 'approved' ? AppColors.info : AppColors.warning;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: index.isEven ? null : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
                                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(outlet?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
                                        Text(outlet?.outletCode ?? '', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: Text(DateFormat('MMM d, yyyy').format(exp.date))),
                                  Expanded(child: Text(exp.expenseType)),
                                  Expanded(child: Text('UGX ${_numberFormat.format(exp.amount)}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w500))),
                                  Expanded(flex: 2, child: Text(exp.description, overflow: TextOverflow.ellipsis)),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(exp.status[0].toUpperCase() + exp.status.substring(1), style: TextStyle(fontSize: 12, color: statusColor)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddExpenditureDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    final paidToController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedType = _expenseTypes.first;
    String selectedStatus = 'pending';
    String? selectedOutletId = _selectedOutletId;

    final outletsData = ref.read(outletsStreamProvider).valueOrNull ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Expenditure'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedOutletId,
                      decoration: const InputDecoration(labelText: 'Outlet *'),
                      items: outletsData.map((o) => DropdownMenuItem(value: o.id, child: Text('${o.name} (${o.outletCode})'))).toList(),
                      onChanged: (v) => setState(() => selectedOutletId = v),
                      validator: (v) => v == null ? 'Select an outlet' : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (date != null) setState(() => selectedDate = date);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Expense Type *'),
                      items: _expenseTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (value) => setState(() => selectedType = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount *', prefixText: 'UGX '),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!.replaceAll(',', '')) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description *'),
                      maxLines: 2,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(controller: paidToController, decoration: const InputDecoration(labelText: 'Paid To')),
                    const SizedBox(height: 16),
                    TextFormField(controller: referenceController, decoration: const InputDecoration(labelText: 'Reference Number')),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      ],
                      onChanged: (value) => setState(() => selectedStatus = value!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final db = ref.read(databaseProvider);
                final amount = double.parse(amountController.text.replaceAll(',', ''));

                try {
                  await db.insertOutletExpenditure(OutletExpendituresCompanion.insert(
                    id: const Uuid().v4(),
                    outletId: selectedOutletId!,
                    date: selectedDate,
                    expenseType: selectedType,
                    amount: Value(amount),
                    description: descriptionController.text,
                    reference: Value(referenceController.text.isEmpty ? null : referenceController.text),
                    paidTo: Value(paidToController.text.isEmpty ? null : paidToController.text),
                    status: Value(selectedStatus),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Expense added: ${_currencyFormat.format(amount)}'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
