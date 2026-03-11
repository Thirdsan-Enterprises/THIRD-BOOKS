import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';

class OutletRevenueScreen extends ConsumerStatefulWidget {
  final String? outletId;
  final String? outletName;

  const OutletRevenueScreen({
    super.key,
    this.outletId,
    this.outletName,
  });

  @override
  ConsumerState<OutletRevenueScreen> createState() => _OutletRevenueScreenState();
}

class _OutletRevenueScreenState extends ConsumerState<OutletRevenueScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  final _numberFormat = NumberFormat('#,##0', 'en_US');
  String? _selectedOutletId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedOutletId = widget.outletId;
  }

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsStreamProvider);
    final revenuesAsync = ref.watch(allOutletRevenuesProvider);

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
                Icon(Icons.attach_money, size: 32, color: AppColors.success),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outlet Revenue',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track revenue collected from each outlet (Total In / Total Out / GGR)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddRevenueDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Record Revenue'),
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
                        ...outlets.map((o) => DropdownMenuItem(
                              value: o.id,
                              child: Text('${o.name} (${o.outletCode})'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedOutletId = v),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ],
            ),
          ),

          // Summary Cards
          revenuesAsync.when(
            data: (revenues) {
              final filtered = _selectedOutletId != null
                  ? revenues.where((r) => r.outletId == _selectedOutletId).toList()
                  : revenues;
              final totalIn = filtered.fold<double>(0, (s, r) => s + r.amount);
              final totalOut = filtered.fold<double>(0, (s, r) => s + r.commissionAmount);
              final totalGGR = filtered.fold<double>(0, (s, r) => s + r.netAmount);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildSummaryCard('Total Cash In', 'UGX ${_numberFormat.format(totalIn)}', Icons.arrow_downward, AppColors.success),
                    const SizedBox(width: 16),
                    _buildSummaryCard('Total Cash Out', 'UGX ${_numberFormat.format(totalOut)}', Icons.arrow_upward, AppColors.warning),
                    const SizedBox(width: 16),
                    _buildSummaryCard('Total GGR', 'UGX ${_numberFormat.format(totalGGR)}', Icons.trending_up, AppColors.primary),
                    const SizedBox(width: 16),
                    _buildSummaryCard('Records', filtered.length.toString(), Icons.receipt_long, AppColors.info),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Revenue Table
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
                        Expanded(child: Text('Cash In', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Expanded(child: Text('Cash Out', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Expanded(child: Text('GGR', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: revenuesAsync.when(
                      data: (revenues) {
                        final outletsData = ref.watch(outletsStreamProvider).valueOrNull ?? [];
                        final outletMap = {for (var o in outletsData) o.id: o};

                        var filtered = revenues.toList();
                        if (_selectedOutletId != null) {
                          filtered = filtered.where((r) => r.outletId == _selectedOutletId).toList();
                        }
                        if (_searchQuery.isNotEmpty) {
                          filtered = filtered.where((r) {
                            final outlet = outletMap[r.outletId];
                            return outlet?.name.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
                                outlet?.outletCode.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
                                (r.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                          }).toList();
                        }
                        filtered.sort((a, b) => b.date.compareTo(a.date));

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No revenue records found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                                const SizedBox(height: 8),
                                Text('Import CSV data or record revenue manually', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final rev = filtered[index];
                            final outlet = outletMap[rev.outletId];
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
                                  Expanded(child: Text(DateFormat('MMM d, yyyy').format(rev.date))),
                                  Expanded(child: Text('UGX ${_numberFormat.format(rev.amount)}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace'))),
                                  Expanded(child: Text('UGX ${_numberFormat.format(rev.commissionAmount)}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace'))),
                                  Expanded(
                                    child: Text(
                                      'UGX ${_numberFormat.format(rev.netAmount)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, color: rev.netAmount >= 0 ? AppColors.success : AppColors.error),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: rev.status == 'recorded' ? AppColors.info.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        rev.status,
                                        style: TextStyle(fontSize: 12, color: rev.status == 'recorded' ? AppColors.info : AppColors.success),
                                      ),
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showAddRevenueDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final cashOutController = TextEditingController();
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedOutletId = _selectedOutletId;
    double ggrAmount = 0;

    final outletsData = ref.read(outletsStreamProvider).valueOrNull ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record Revenue'),
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
                      items: outletsData.map((o) => DropdownMenuItem(
                            value: o.id,
                            child: Text('${o.name} (${o.outletCode})'),
                          )).toList(),
                      onChanged: (v) => setState(() => selectedOutletId = v),
                      validator: (v) => v == null ? 'Select an outlet' : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) setState(() => selectedDate = date);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Total Cash In (Stakes) *', prefixText: 'UGX '),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!.replaceAll(',', '')) == null) return 'Invalid number';
                        return null;
                      },
                      onChanged: (v) {
                        final cashIn = double.tryParse(v.replaceAll(',', '')) ?? 0;
                        final cashOut = double.tryParse(cashOutController.text.replaceAll(',', '')) ?? 0;
                        setState(() => ggrAmount = cashIn - cashOut);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: cashOutController,
                      decoration: const InputDecoration(labelText: 'Total Cash Out (Payouts) *', prefixText: 'UGX '),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!.replaceAll(',', '')) == null) return 'Invalid number';
                        return null;
                      },
                      onChanged: (v) {
                        final cashIn = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                        final cashOut = double.tryParse(v.replaceAll(',', '')) ?? 0;
                        setState(() => ggrAmount = cashIn - cashOut);
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ggrAmount >= 0 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GGR (Cash In - Cash Out):', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            _currencyFormat.format(ggrAmount),
                            style: TextStyle(fontWeight: FontWeight.bold, color: ggrAmount >= 0 ? AppColors.success : AppColors.error),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: referenceController,
                      decoration: const InputDecoration(labelText: 'Reference'),
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
                final cashIn = double.parse(amountController.text.replaceAll(',', ''));
                final cashOut = double.parse(cashOutController.text.replaceAll(',', ''));
                final ggr = cashIn - cashOut;
                final outlet = outletsData.firstWhere((o) => o.id == selectedOutletId);

                try {
                  await db.insertOutletRevenue(OutletRevenuesCompanion.insert(
                    id: const Uuid().v4(),
                    outletId: selectedOutletId!,
                    date: selectedDate,
                    amount: Value(cashIn),
                    commissionAmount: Value(cashOut),
                    netAmount: Value(ggr),
                    description: Value(descriptionController.text.isEmpty
                        ? '${outlet.name} - ${DateFormat('MMM d, yyyy').format(selectedDate)}'
                        : descriptionController.text),
                    reference: Value(referenceController.text.isEmpty ? null : referenceController.text),
                    status: const Value('recorded'),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Revenue recorded: ${_currencyFormat.format(ggr)} GGR'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Record Revenue'),
            ),
          ],
        ),
      ),
    );
  }
}
