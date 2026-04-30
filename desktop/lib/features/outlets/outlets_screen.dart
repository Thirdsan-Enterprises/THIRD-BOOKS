import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../core/services/data_service.dart';

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
    final outletsAsync = ref.watch(outletsStreamProvider);
    final numberFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      body: Column(
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
                OutlinedButton.icon(
                  onPressed: _importOutletsCsv,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import CSV'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportOutletsCsv,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export CSV'),
                ),
                const SizedBox(width: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search outlets by name or code...',
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

          // Statistics Cards
          outletsAsync.when(
            data: (outlets) {
              final totalCount = outlets.length;
              final activeCount = outlets.where((o) => o.isActive).length;
              final regions = outlets.map((o) => o.region).where((r) => r != null).toSet().length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Outlets',
                        totalCount.toString(),
                        Icons.store,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Active',
                        activeCount.toString(),
                        Icons.check_circle,
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Regions',
                        regions.toString(),
                        Icons.map,
                        AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Inactive',
                        (outlets.length - activeCount).toString(),
                        Icons.store_outlined,
                        AppColors.expense,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Outlets Table
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 50, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Outlet Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Outlet Code', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Region', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  // Table Body
                  Expanded(
                    child: outletsAsync.when(
                      data: (allOutlets) {
                        var filteredOutlets = allOutlets.where((outlet) {
                          final matchesSearch = _searchQuery.isEmpty ||
                              outlet.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              outlet.outletCode.toLowerCase().contains(_searchQuery.toLowerCase());
                          final matchesRegion = _selectedRegion == 'All' || outlet.region == _selectedRegion;
                          return matchesSearch && matchesRegion;
                        }).toList();

                        // Sort by outlet code
                        filteredOutlets.sort((a, b) => a.outletCode.compareTo(b.outletCode));

                        if (filteredOutlets.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No outlets found matching "$_searchQuery"'
                                      : 'No outlets found',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _showAddOutletDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Outlet'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filteredOutlets.length,
                          itemBuilder: (context, index) {
                            final outlet = filteredOutlets[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: index.isEven
                                    ? null
                                    : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.outline,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      outlet.name,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        outlet.outletCode,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(outlet.city ?? outlet.address ?? '-'),
                                  ),
                                  Expanded(
                                    child: Text(outlet.region ?? '-'),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: outlet.isActive
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        outlet.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: outlet.isActive ? AppColors.success : AppColors.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: outlet.isActive ? 120 : 160,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () => _showEditOutletDialog(outlet),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            outlet.isActive ? Icons.block : Icons.check_circle_outline,
                                            size: 18,
                                          ),
                                          onPressed: () => _toggleOutletStatus(outlet),
                                          tooltip: outlet.isActive ? 'Deactivate' : 'Activate',
                                        ),
                                        // Delete only available when outlet is inactive
                                        if (!outlet.isActive)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18),
                                            onPressed: () => _confirmDeleteOutlet(outlet),
                                            tooltip: 'Delete permanently',
                                            color: AppColors.error,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Error: $error'),
                      ),
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

  // ── CSV Export ────────────────────────────────────────────────────────────

  Future<void> _exportOutletsCsv() async {
    final allOutlets = ref.read(outletsStreamProvider).valueOrNull ?? [];
    if (allOutlets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outlets to export.')),
      );
      return;
    }

    final rows = <List<dynamic>>[
      ['OutletCode', 'Name', 'City', 'Region', 'OwnerName', 'OwnerContact', 'CommissionRate', 'IsActive'],
      ...allOutlets.map((o) => [
            o.outletCode,
            o.name,
            o.city ?? '',
            o.region ?? '',
            o.ownerName ?? '',
            o.ownerContact ?? '',
            o.commissionRate,
            o.isActive ? 'true' : 'false',
          ]),
    ];

    final csvContent = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'outlets_export.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── CSV Import ────────────────────────────────────────────────────────────
  // Expected columns: OutletCode, Name, City, Region, OwnerName, OwnerContact
  // (CommissionRate and IsActive are optional — defaults are used if absent)

  Future<void> _importOutletsCsv() async {
    // Outlet definition CSV import — each row creates/updates an outlet on the server.
    // Expected columns: OutletCode, Name, City, Region, OwnerName, OwnerContact
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'To import outlet definitions, use the server admin panel or contact your administrator.',
          ),
        ),
      );
    }
  }

  void _showAddOutletDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    String? selectedRegion;
    final ownerController = TextEditingController();
    final contactController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                              hintText: '23103000',
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
                            value: selectedRegion,
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
                            onChanged: (value) => setDialogState(() => selectedRegion = value),
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
                Navigator.pop(context);
                try {
                  final api = ref.read(apiClientProvider);
                  await api.createOutlet({
                    'outlet_code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    if (addressController.text.trim().isNotEmpty)
                      'address': addressController.text.trim(),
                    if (cityController.text.trim().isNotEmpty)
                      'city': cityController.text.trim(),
                    if (selectedRegion != null) 'region': selectedRegion,
                    if (ownerController.text.trim().isNotEmpty)
                      'owner_name': ownerController.text.trim(),
                    if (contactController.text.trim().isNotEmpty)
                      'owner_contact': contactController.text.trim(),
                    'is_active': true,
                  });
                  ref.invalidate(outletsStreamProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Outlet created successfully.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Outlet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOutletDialog(Outlet outlet) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: outlet.name);
    final codeController = TextEditingController(text: outlet.outletCode);
    final addressController = TextEditingController(text: outlet.address ?? '');
    final cityController = TextEditingController(text: outlet.city ?? '');
    String? selectedRegion = outlet.region;
    final ownerController = TextEditingController(text: outlet.ownerName ?? '');
    final contactController = TextEditingController(text: outlet.ownerContact ?? '');
    final commissionController = TextEditingController(text: outlet.commissionRate.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Outlet - ${outlet.outletCode}'),
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
                            decoration: const InputDecoration(labelText: 'Outlet Code *'),
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Outlet Name *'),
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityController,
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedRegion,
                            decoration: const InputDecoration(labelText: 'Region'),
                            items: _regions
                                .where((r) => r != 'All')
                                .map((region) => DropdownMenuItem(
                                      value: region,
                                      child: Text(region),
                                    ))
                                .toList(),
                            onChanged: (value) => setDialogState(() => selectedRegion = value),
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
                            decoration: const InputDecoration(labelText: 'Owner Name'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: contactController,
                            decoration: const InputDecoration(labelText: 'Contact'),
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
                        if (rate == null || rate < 0 || rate > 100) return 'Invalid';
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
                Navigator.pop(context);
                try {
                  final api = ref.read(apiClientProvider);
                  await api.updateOutlet(outlet.id, {
                    'outlet_code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    'address': addressController.text.trim(),
                    'city': cityController.text.trim(),
                    if (selectedRegion != null) 'region': selectedRegion,
                    'owner_name': ownerController.text.trim(),
                    'owner_contact': contactController.text.trim(),
                    'commission_rate':
                        double.tryParse(commissionController.text) ?? 40.0,
                  });
                  ref.invalidate(outletsStreamProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Outlet updated successfully.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOutlet(Outlet outlet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Delete Outlet'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to permanently delete:'),
            const SizedBox(height: 8),
            Text(
              '${outlet.name} (${outlet.outletCode})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Text(
                'This will permanently delete the outlet AND all its revenue records, expenditures, and commission payments. This cannot be undone.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.deleteOutlet(outlet.id);
      ref.invalidate(outletsStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${outlet.name} deleted permanently.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting outlet: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleOutletStatus(Outlet outlet) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.updateOutlet(outlet.id, {'is_active': !outlet.isActive});
      ref.invalidate(outletsStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${outlet.name} ${outlet.isActive ? 'deactivated' : 'activated'}.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
