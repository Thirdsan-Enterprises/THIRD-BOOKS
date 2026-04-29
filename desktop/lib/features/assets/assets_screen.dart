// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;

import '../../core/theme/app_theme.dart';
import '../../core/providers/asset_drafts_provider.dart';
import '../../core/providers/depreciation_schedules_provider.dart';
import '../../core/services/data_service.dart';
import '../../core/models/bill.dart';

/// Assets Management Screen
///
/// For managing company assets (NOT betting machines):
/// - Vehicles, Office Equipment, Furniture, Electronics, etc.
/// - Track purchase details, depreciation, and current value
/// - Assign assets to specific outlets
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Vehicle',
    'Equipment',
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Register'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAssetsToExcel,
            tooltip: 'Export to Excel',
          ),
          IconButton(
            icon: const Icon(Icons.trending_down),
            onPressed: () => Navigator.pushNamed(context, '/depreciation'),
            tooltip: 'Depreciation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummarySection(),

          // Category Filter
          _buildCategoryFilter(),

          // Assets List
          Expanded(
            child: _buildAssetsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssetDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Asset'),
      ),
    );
  }

  Widget _buildSummarySection() {
    final entries = _buildAssetEntries();
    final totalCount   = entries.length;
    final activeCount  = entries.where((e) => e.isActive).length;
    final totalValue   = entries.fold<double>(0, (s, e) => s + e.amount);
    final fmt          = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Assets',
              totalCount.toString(),
              Icons.inventory_2,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Active Assets',
              activeCount.toString(),
              Icons.check_circle_outline,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Purchase Value',
              'UGX ${fmt.format(totalValue)}',
              Icons.shopping_cart,
              AppColors.info,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Pending Confirmation',
              entries.where((e) => e.isDraft && !e.isActive).length.toString(),
              Icons.pending_outlined,
              AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
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
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Text('Category: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          ..._categories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                ),
              )),
        ],
      ),
    );
  }

  // ── Unified asset entry ─────────────────────────────────────────────────────
  // Merges AssetDraft records (manually added or created via bill dialog) with
  // Bills that have an asset category but were loaded from storage without
  // generating a draft (e.g. synced from server or added before this feature).
  List<_AssetEntry> _buildAssetEntries() {
    final drafts = ref.watch(assetDraftsProvider);
    final bills  = ref.watch(billsProvider).bills;

    final draftIds = drafts.map((d) => d.id).toSet();

    // Convert manual drafts first.
    final entries = drafts
        .map((d) => _AssetEntry.fromDraft(d))
        .toList();

    // Add bills with asset categories that do NOT already have a draft.
    for (final bill in bills) {
      if (!isAssetCategory(bill.category)) continue;
      if (draftIds.contains(bill.id)) continue; // already covered by draft
      entries.add(_AssetEntry.fromBill(bill));
    }

    // Sort: confirmed/paid first, then by date descending.
    entries.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.date.compareTo(a.date);
    });

    return entries;
  }

  Widget _buildAssetsList() {
    final schedules = ref.watch(depreciationSchedulesProvider);
    final depByAsset = {for (final s in schedules) s.assetDraftId: s};
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('dd MMM yyyy');

    final all = _buildAssetEntries();
    final filtered = all
        .where((e) => _selectedCategory == 'All' || e.category == _selectedCategory)
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No assets found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 8),
            Text(
              'Asset-type bills (Equipment, Vehicle, Furniture, Electronics,\n'
              'Machinery, Building, Land) appear here automatically when\n'
              'created in Bills, or add one manually below.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _showAddAssetDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add asset manually'),
            ),
          ],
        ),
      );
    }

    // Compute register totals
    double totalPurchase = 0, totalAccumDep = 0, totalNBV = 0;
    for (final e in filtered) {
      final accDep = depByAsset[e.id]?.accumulatedDepreciation ?? 0.0;
      totalPurchase += e.amount;
      totalAccumDep += accDep;
      totalNBV += (e.amount - accDep);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                  Theme.of(context).colorScheme.surfaceVariant),
              columnSpacing: 24,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Asset Name',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Category',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Purchase Price',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(label: Text('Purchase Date',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Accum. Depreciation',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(
                    label: Text('Net Book Value',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true),
                DataColumn(label: Text('Status',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions',
                    style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((entry) {
                final sched = depByAsset[entry.id];
                final accDep = sched?.accumulatedDepreciation ?? 0.0;
                final nbv = entry.amount - accDep;
                final statusColor = entry.isActive ? AppColors.success : AppColors.warning;
                return DataRow(cells: [
                  DataCell(Row(children: [
                    Icon(_categoryIcon(entry.category), size: 16,
                        color: statusColor),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(entry.name, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ])),
                  DataCell(Text(entry.category)),
                  DataCell(Text('${entry.currency} ${fmt.format(entry.amount)}')),
                  DataCell(Text(dateFmt.format(entry.date))),
                  DataCell(accDep > 0
                      ? Text('(${entry.currency} ${fmt.format(accDep)})',
                          style: const TextStyle(color: AppColors.error))
                      : const Text('—')),
                  DataCell(Text('${entry.currency} ${fmt.format(nbv)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: nbv < 0 ? AppColors.error : null))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      entry.isActive ? 'Active' : 'Pending',
                      style: TextStyle(color: statusColor, fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  )),
                  DataCell(entry.isDraft
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(
                            onPressed: () {
                              ref.read(assetDraftsProvider.notifier)
                                  .confirmAsset(entry.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Asset confirmed and activated'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                                minimumSize: const Size(60, 28),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8)),
                            child: const Text('Confirm'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: AppColors.error),
                            onPressed: () => ref
                                .read(assetDraftsProvider.notifier)
                                .removeDraft(entry.id),
                            tooltip: 'Remove',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ])
                      : const Icon(Icons.check_circle,
                          color: AppColors.success, size: 20)),
                ]);
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Totals row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TotalChip('Total Purchase Value',
                    'UGX ${fmt.format(totalPurchase)}', AppColors.primary),
                const SizedBox(width: 12),
                _TotalChip('Total Accumulated Dep.',
                    '(UGX ${fmt.format(totalAccumDep)})', AppColors.error),
                const SizedBox(width: 12),
                _TotalChip('Total Net Book Value',
                    'UGX ${fmt.format(totalNBV)}', AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAssetsToExcel() async {
    final schedules = ref.read(depreciationSchedulesProvider);
    final depByAsset = {for (final s in schedules) s.assetDraftId: s};
    final all = _buildAssetEntries();
    final fmt = NumberFormat('#,###');

    final excel = xl.Excel.createExcel();
    final sheetName = 'Asset Register';
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    final headers = [
      'Asset Name', 'Category', 'Purchase Price', 'Purchase Date',
      'Accum. Depreciation', 'Net Book Value', 'Status',
    ];
    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());
    for (int c = 0; c < headers.length; c++) {
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    for (final entry in all) {
      final accDep = depByAsset[entry.id]?.accumulatedDepreciation ?? 0.0;
      final nbv = entry.amount - accDep;
      sheet.appendRow([
        xl.TextCellValue(entry.name),
        xl.TextCellValue(entry.category),
        xl.DoubleCellValue(entry.amount),
        xl.TextCellValue(DateFormat('yyyy-MM-dd').format(entry.date)),
        xl.DoubleCellValue(accDep),
        xl.DoubleCellValue(nbv),
        xl.TextCellValue(entry.isActive ? 'Active' : 'Pending'),
      ]);
    }

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 22);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 10);

    final bytes = excel.save();
    if (bytes == null) return;

    try {
      final filename =
          'asset_register_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final blob = html.Blob([bytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported: $filename'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Vehicle':
        return Icons.directions_car;
      case 'Equipment':
        return Icons.build;
      case 'Furniture':
        return Icons.chair;
      case 'Electronics':
        return Icons.devices;
      default:
        return Icons.inventory_2;
    }
  }

  void _showAddAssetDialog() {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final purchasePriceController = TextEditingController();
    final supplierController = TextEditingController();
    final locationController = TextEditingController();
    DateTime purchaseDate = DateTime.now();
    String selectedCategory = 'Equipment';
    bool setupDepreciation = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Asset'),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Asset Code *',
                              hintText: 'AST-001',
                            ),
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                            ),
                            items: _categories
                                .where((c) => c != 'All')
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() => selectedCategory = value!);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Asset Name *',
                        hintText: 'Dell Laptop - Inspiron 15',
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Additional details...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: purchasePriceController,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Price *',
                              prefixText: 'UGX ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Required';
                              if (double.tryParse(v!.replaceAll(',', '')) == null) {
                                return 'Invalid amount';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: purchaseDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => purchaseDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Purchase Date *',
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(purchaseDate),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        hintText: 'Company name',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location/Outlet',
                        hintText: 'Head Office or Outlet name',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Depreciation Setup Option
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: setupDepreciation,
                            onChanged: (value) {
                              setState(() => setupDepreciation = value ?? false);
                            },
                            title: const Text('Set up depreciation schedule'),
                            subtitle: const Text('Configure depreciation after creating asset'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final purchasePrice = double.parse(
                  purchasePriceController.text.replaceAll(',', ''),
                );

                // TODO: Save asset to database
                // final asset = AssetsCompanion.insert(
                //   id: const Uuid().v4(),
                //   assetCode: codeController.text,
                //   name: nameController.text,
                //   description: Value(descriptionController.text),
                //   category: selectedCategory,
                //   purchasePrice: purchasePrice,
                //   currentValue: purchasePrice,
                //   purchaseDate: purchaseDate,
                //   supplier: Value(supplierController.text),
                //   location: Value(locationController.text),
                //   createdAt: DateTime.now(),
                //   updatedAt: DateTime.now(),
                // );
                // await ref.read(databaseProvider).insertAsset(asset);

                if (mounted) {
                  Navigator.pop(context);

                  if (setupDepreciation) {
                    // Navigate to depreciation setup
                    _showDepreciationSetupDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Asset added successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Asset'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepreciationSetupDialog() {
    // This will be implemented in the depreciation screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigate to Depreciation screen to set up schedule'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}

// ── Small totals chip shown below the register table ──────────────────────────
class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outline)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Unified asset entry ────────────────────────────────────────────────────────
// Wraps either an AssetDraft (manual / from bill dialog) or a Bill with an
// asset category so the assets list can render them from a single model.

enum _AssetSource { draft, bill }

class _AssetEntry {
  final String id;
  final String name;
  final String category;
  final double amount;
  final String currency;
  final String? vendorName;
  final String? reference;
  final String? billNumber;
  final DateTime date;
  final bool isActive;  // true = confirmed/paid
  final bool isDraft;   // true = can be confirmed / removed
  final _AssetSource source;

  const _AssetEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.currency,
    this.vendorName,
    this.reference,
    this.billNumber,
    required this.date,
    required this.isActive,
    required this.isDraft,
    required this.source,
  });

  factory _AssetEntry.fromDraft(AssetDraft d) => _AssetEntry(
        id: d.id,
        name: d.assetName,
        category: d.category,
        amount: d.amount,
        currency: d.currency,
        vendorName: d.vendorName,
        reference: d.billReference,
        date: d.date,
        isActive: d.isConfirmed,
        isDraft: !d.isConfirmed,
        source: _AssetSource.draft,
      );

  factory _AssetEntry.fromBill(Bill b) => _AssetEntry(
        id: b.id,
        name: b.category != null && (b.vendorName?.isNotEmpty ?? false)
            ? '${b.category} — ${b.vendorName}'
            : b.category ?? b.billNumber,
        category: b.category ?? 'Equipment',
        amount: b.subtotal,
        currency: b.currencyCode,
        vendorName: b.vendorName,
        reference: b.reference,
        billNumber: b.billNumber,
        date: b.date,
        isActive: b.status == BillStatus.paid,
        isDraft: false, // Bills sourced directly are not editable here
        source: _AssetSource.bill,
      );
}
