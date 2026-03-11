import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/asset_drafts_provider.dart';

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
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Management'),
        actions: [
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
              '0',
              Icons.inventory_2,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Purchase Value',
              'UGX 0',
              Icons.shopping_cart,
              AppColors.info,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Current Value',
              'UGX 0',
              Icons.account_balance_wallet,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Depreciation',
              'UGX 0',
              Icons.trending_down,
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

  Widget _buildAssetsList() {
    final drafts = ref.watch(assetDraftsProvider);
    final fmt = _currencyFormat;

    // Filter by selected category
    final filtered = drafts.where((d) =>
        _selectedCategory == 'All' || d.category == _selectedCategory).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No assets found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asset-type bills (Equipment, Vehicle, Furniture, Electronics)\n'
              'will appear here as drafts when you create them in Bills.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final draft = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (draft.isConfirmed
                        ? AppColors.success
                        : AppColors.warning)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _categoryIcon(draft.category),
                color:
                    draft.isConfirmed ? AppColors.success : AppColors.warning,
                size: 24,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    draft.assetName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (draft.isConfirmed
                            ? AppColors.success
                            : AppColors.warning)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    draft.isConfirmed ? 'Active' : 'Draft',
                    style: TextStyle(
                      color: draft.isConfirmed
                          ? AppColors.success
                          : AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${draft.currency} ${NumberFormat('#,###').format(draft.amount)}  ·  ${draft.category}  ·  ${DateFormat('MMM d, yyyy').format(draft.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (draft.vendorName != null)
                  Text('Vendor: ${draft.vendorName}',
                      style: Theme.of(context).textTheme.bodySmall),
                if (draft.billReference != null)
                  Text('Ref: ${draft.billReference}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            trailing: draft.isConfirmed
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          ref
                              .read(assetDraftsProvider.notifier)
                              .confirmAsset(draft.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Asset confirmed and activated'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        child: const Text('Confirm'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                        onPressed: () => ref
                            .read(assetDraftsProvider.notifier)
                            .removeDraft(draft.id),
                        tooltip: 'Remove draft',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
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
