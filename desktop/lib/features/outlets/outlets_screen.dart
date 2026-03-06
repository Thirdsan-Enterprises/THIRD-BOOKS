import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import 'csv_upload_widget.dart';

class OutletsScreen extends ConsumerStatefulWidget {
  const OutletsScreen({super.key});

  @override
  ConsumerState<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends ConsumerState<OutletsScreen> {
  String _searchQuery = '';
  String _selectedRegion = 'All';

  final List<String> _regions = [
    'All',
    'CENTRAL',
    'NORTH',
    'WEST',
    'EAST',
    'WEST NILE',
    'SOUTH WEST',
  ];

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual database provider
    // final outletsStream = ref.watch(outletsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Page Title Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store_mall_directory,
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outlet Management',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage all betting machine locations',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddOutletDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Outlet'),
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search outlets...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    decoration: InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _regions.map((region) {
                      return DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedRegion = value!);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Statistics Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Outlets',
                    '74',
                    Icons.store,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Active',
                    '74',
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'This Month Revenue',
                    'UGX 0',
                    Icons.trending_up,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Pending Commissions',
                    'UGX 0',
                    Icons.payment,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Outlets Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(flex: 2, child: Text('Outlet Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(flex: 2, child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Region', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Commission', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  // Table Body - will be populated with actual data
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No outlets found',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _showAddOutletDialog(),
                            child: const Text('Add your first outlet'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CSV Upload Section
          const CSVUploadWidget(),
        ],
      );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOutletDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final regionController = TextEditingController();
    final ownerController = TextEditingController();
    final contactController = TextEditingController();
    final commissionController = TextEditingController(text: '40.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Outlet'),
        content: SizedBox(
          width: 600,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'Outlet Code *',
                            hintText: '3000',
                          ),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Outlet Name *',
                            hintText: 'MAGIC BET YUMBE',
                          ),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Region',
                          ),
                          items: _regions
                              .where((r) => r != 'All')
                              .map((region) => DropdownMenuItem(
                                    value: region,
                                    child: Text(region),
                                  ))
                              .toList(),
                          onChanged: (value) => regionController.text = value ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ownerController,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact',
                            hintText: '+256 7XX XXX XXX',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: commissionController,
                    decoration: const InputDecoration(
                      labelText: 'Commission Rate (%)',
                      suffix: Text('%'),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      final rate = double.tryParse(v!);
                      if (rate == null || rate < 0 || rate > 100) {
                        return 'Enter a valid percentage (0-100)';
                      }
                      return null;
                    },
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

              // TODO: Save to database
              // final outlet = OutletsCompanion.insert(
              //   id: const Uuid().v4(),
              //   outletCode: codeController.text,
              //   name: nameController.text,
              //   ...
              // );
              // await ref.read(databaseProvider).insertOutlet(outlet);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Outlet added successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Add Outlet'),
          ),
        ],
      ),
    );
  }
}
