import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/vendors_provider.dart';

class VendorsListScreen extends ConsumerStatefulWidget {
  const VendorsListScreen({super.key});

  @override
  ConsumerState<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends ConsumerState<VendorsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsState = ref.watch(vendorsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search vendors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(vendorsProvider.notifier).setSearchQuery(null);
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                ref.read(vendorsProvider.notifier).setSearchQuery(value);
              },
            ),
          ),
        ),
      ),
      body: vendorsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vendorsState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${vendorsState.error}'),
                      ElevatedButton(
                        onPressed: () => ref.read(vendorsProvider.notifier).loadVendors(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : vendorsState.filteredVendors.isEmpty
                  ? _buildEmptyState(context)
                  : _buildVendorsList(context, vendorsState.filteredVendors),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateVendorDialog(context),
        icon: const Icon(Icons.store_mall_directory),
        label: const Text('Add Vendor'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No vendors yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first vendor to get started',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildVendorsList(BuildContext context, List<Vendor> vendors) {
    return RefreshIndicator(
      onRefresh: () => ref.read(vendorsProvider.notifier).loadVendors(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: vendors.length,
        itemBuilder: (context, index) {
          final vendor = vendors[index];
          return _buildVendorTile(context, vendor);
        },
      ),
    );
  }

  Widget _buildVendorTile(BuildContext context, Vendor vendor) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Text(
            vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(vendor.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor.code),
            if (vendor.phone != null)
              Text(
                vendor.phone!,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(vendor.balance, vendor.currencyCode),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: vendor.balance > 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (!vendor.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _showVendorDetails(context, vendor),
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

  void _showVendorDetails(BuildContext context, Vendor vendor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _VendorDetailsSheet(
          vendor: vendor,
          scrollController: scrollController,
          onEdit: () {
            Navigator.pop(context);
            _showEditVendorDialog(context, vendor);
          },
          onDelete: () async {
            Navigator.pop(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Vendor'),
                content: Text('Are you sure you want to delete "${vendor.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(vendorsProvider.notifier).deleteVendor(vendor.id);
            }
          },
        ),
      ),
    );
  }

  void _showCreateVendorDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _VendorFormSheet(
          title: 'Add Vendor',
          onSave: (data) async {
            await ref.read(vendorsProvider.notifier).createVendor(
              name: data['name'] as String,
              email: data['email'] as String?,
              phone: data['phone'] as String?,
              address: data['address'] as String?,
              city: data['city'] as String?,
              taxId: data['tax_id'] as String?,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vendor created')),
              );
            }
          },
        ),
      ),
    );
  }

  void _showEditVendorDialog(BuildContext context, Vendor vendor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _VendorFormSheet(
          title: 'Edit Vendor',
          initialData: {
            'name': vendor.name,
            'email': vendor.email,
            'phone': vendor.phone,
            'address': vendor.address,
            'city': vendor.city,
            'tax_id': vendor.taxId,
          },
          onSave: (data) async {
            await ref.read(vendorsProvider.notifier).updateVendor(
              vendor.id,
              name: data['name'] as String?,
              email: data['email'] as String?,
              phone: data['phone'] as String?,
              address: data['address'] as String?,
              city: data['city'] as String?,
              taxId: data['tax_id'] as String?,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vendor updated')),
              );
            }
          },
        ),
      ),
    );
  }
}

class _VendorDetailsSheet extends StatelessWidget {
  final Vendor vendor;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VendorDetailsSheet({
    required this.vendor,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(
                      vendor.code,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (vendor.email != null)
            _DetailRow(icon: Icons.email, label: 'Email', value: vendor.email!),
          if (vendor.phone != null)
            _DetailRow(icon: Icons.phone, label: 'Phone', value: vendor.phone!),
          if (vendor.address != null)
            _DetailRow(icon: Icons.location_on, label: 'Address', value: vendor.address!),
          if (vendor.city != null)
            _DetailRow(icon: Icons.location_city, label: 'City', value: vendor.city!),
          _DetailRow(icon: Icons.flag, label: 'Country', value: vendor.country),
          if (vendor.taxId != null)
            _DetailRow(icon: Icons.receipt, label: 'TIN', value: vendor.taxId!),
          _DetailRow(
            icon: Icons.account_balance_wallet,
            label: 'Balance',
            value: '${vendor.currencyCode} ${vendor.balance.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isHighlighted;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  value,
                  style: isHighlighted
                      ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                      : theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorFormSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _VendorFormSheet({
    required this.title,
    this.initialData,
    required this.onSave,
  });

  @override
  State<_VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends State<_VendorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _taxIdController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _emailController = TextEditingController(text: widget.initialData?['email'] ?? '');
    _phoneController = TextEditingController(text: widget.initialData?['phone'] ?? '');
    _addressController = TextEditingController(text: widget.initialData?['address'] ?? '');
    _cityController = TextEditingController(text: widget.initialData?['city'] ?? '');
    _taxIdController = TextEditingController(text: widget.initialData?['tax_id'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.store),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _taxIdController,
              decoration: const InputDecoration(
                labelText: 'TIN (Tax ID)',
                prefixIcon: Icon(Icons.receipt),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.onSave({
        'name': _nameController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
        'address': _addressController.text.isEmpty ? null : _addressController.text,
        'city': _cityController.text.isEmpty ? null : _cityController.text,
        'tax_id': _taxIdController.text.isEmpty ? null : _taxIdController.text,
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
