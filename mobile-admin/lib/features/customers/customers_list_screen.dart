import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/customers_provider.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(customersProvider.notifier).setSearchQuery(null);
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
                ref.read(customersProvider.notifier).setSearchQuery(value);
              },
            ),
          ),
        ),
      ),
      body: customersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : customersState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${customersState.error}'),
                      ElevatedButton(
                        onPressed: () => ref.read(customersProvider.notifier).loadCustomers(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : customersState.filteredCustomers.isEmpty
                  ? _buildEmptyState(context)
                  : _buildCustomersList(context, customersState.filteredCustomers),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCustomerDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No customers yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first customer to get started',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList(BuildContext context, List<Customer> customers) {
    return RefreshIndicator(
      onRefresh: () => ref.read(customersProvider.notifier).loadCustomers(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return _buildCustomerTile(context, customer);
        },
      ),
    );
  }

  Widget _buildCustomerTile(BuildContext context, Customer customer) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(customer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer.code),
            if (customer.phone != null)
              Text(
                customer.phone!,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(customer.balance, customer.currencyCode),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: customer.balance > 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (!customer.isActive)
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
        onTap: () => _showCustomerDetails(context, customer),
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

  void _showCustomerDetails(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _CustomerDetailsSheet(
          customer: customer,
          scrollController: scrollController,
          onEdit: () {
            Navigator.pop(context);
            _showEditCustomerDialog(context, customer);
          },
          onDelete: () async {
            Navigator.pop(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Customer'),
                content: Text('Are you sure you want to delete "${customer.name}"?'),
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
              await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
            }
          },
        ),
      ),
    );
  }

  void _showCreateCustomerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _CustomerFormSheet(
          title: 'Add Customer',
          onSave: (data) async {
            await ref.read(customersProvider.notifier).createCustomer(
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
                const SnackBar(content: Text('Customer created')),
              );
            }
          },
        ),
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _CustomerFormSheet(
          title: 'Edit Customer',
          initialData: {
            'name': customer.name,
            'email': customer.email,
            'phone': customer.phone,
            'address': customer.address,
            'city': customer.city,
            'tax_id': customer.taxId,
          },
          onSave: (data) async {
            await ref.read(customersProvider.notifier).updateCustomer(
              customer.id,
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
                const SnackBar(content: Text('Customer updated')),
              );
            }
          },
        ),
      ),
    );
  }
}

class _CustomerDetailsSheet extends StatelessWidget {
  final Customer customer;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerDetailsSheet({
    required this.customer,
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
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    color: theme.colorScheme.onPrimaryContainer,
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
                      customer.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text(
                      customer.code,
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
          if (customer.email != null)
            _DetailRow(
              icon: Icons.email,
              label: 'Email',
              value: customer.email!,
            ),
          if (customer.phone != null)
            _DetailRow(
              icon: Icons.phone,
              label: 'Phone',
              value: customer.phone!,
            ),
          if (customer.address != null)
            _DetailRow(
              icon: Icons.location_on,
              label: 'Address',
              value: customer.address!,
            ),
          if (customer.city != null)
            _DetailRow(
              icon: Icons.location_city,
              label: 'City',
              value: customer.city!,
            ),
          _DetailRow(
            icon: Icons.flag,
            label: 'Country',
            value: customer.country,
          ),
          if (customer.taxId != null)
            _DetailRow(
              icon: Icons.receipt,
              label: 'TIN',
              value: customer.taxId!,
            ),
          _DetailRow(
            icon: Icons.account_balance_wallet,
            label: 'Balance',
            value: '${customer.currencyCode} ${customer.balance.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
          _DetailRow(
            icon: Icons.credit_card,
            label: 'Credit Limit',
            value: '${customer.currencyCode} ${customer.creditLimit.toStringAsFixed(2)}',
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
                      ? theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )
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

class _CustomerFormSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _CustomerFormSheet({
    required this.title,
    this.initialData,
    required this.onSave,
  });

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
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
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
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
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
