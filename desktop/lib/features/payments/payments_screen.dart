import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _receivedPayments = [
    {
      'id': 'REC-001',
      'date': DateTime(2024, 1, 18),
      'customer': 'Kampala Traders Ltd',
      'invoice': 'INV-2024-001',
      'amount': 3500000.0,
      'method': 'Bank Transfer',
      'reference': 'TRF-123456',
      'account': 'Bank Account - UGX',
    },
    {
      'id': 'REC-002',
      'date': DateTime(2024, 1, 17),
      'customer': 'Jinja Hardware Supplies',
      'invoice': 'INV-2024-002',
      'amount': 9945000.0,
      'method': 'Mobile Money',
      'reference': 'MM-789012',
      'account': 'Mobile Money - MTN',
    },
    {
      'id': 'REC-003',
      'date': DateTime(2024, 1, 15),
      'customer': 'Lira Agro Products',
      'invoice': 'INV-2024-006',
      'amount': 2106000.0,
      'method': 'Cash',
      'reference': 'CASH-001',
      'account': 'Cash on Hand',
    },
  ];

  final List<Map<String, dynamic>> _madePayments = [
    {
      'id': 'PAY-001',
      'date': DateTime(2024, 1, 19),
      'vendor': 'Tech Solutions Ltd',
      'bill': 'BILL-2024-002',
      'amount': 3744000.0,
      'method': 'Bank Transfer',
      'reference': 'TRF-456789',
      'account': 'Bank Account - UGX',
    },
    {
      'id': 'PAY-002',
      'date': DateTime(2024, 1, 16),
      'vendor': 'Local Farmers Cooperative',
      'bill': 'BILL-2024-006',
      'amount': 1500000.0,
      'method': 'Cash',
      'reference': 'CASH-002',
      'account': 'Petty Cash',
    },
    {
      'id': 'PAY-003',
      'date': DateTime(2024, 1, 14),
      'vendor': 'Global Imports Ltd',
      'bill': 'BILL-2024-005',
      'amount': 15000000.0,
      'method': 'Bank Transfer',
      'reference': 'TRF-987654',
      'account': 'Bank Account - UGX',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCards(context),
            const SizedBox(height: 24),
            _buildTabBar(context),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPaymentsList(context, _receivedPayments, true),
                  _buildPaymentsList(context, _madePayments, false),
                ],
              ),
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
              'Payments',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track payments received and made',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showRecordPaymentDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Record Payment'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final totalReceived = _receivedPayments.fold<double>(
        0, (sum, p) => sum + (p['amount'] as double));
    final totalPaid =
        _madePayments.fold<double>(0, (sum, p) => sum + (p['amount'] as double));

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_downward,
            iconColor: AppColors.income,
            label: 'Total Received',
            value: 'UGX ${_formatNumber(totalReceived)}',
            subtitle: '${_receivedPayments.length} payments',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_upward,
            iconColor: AppColors.expense,
            label: 'Total Paid',
            value: 'UGX ${_formatNumber(totalPaid)}',
            subtitle: '${_madePayments.length} payments',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance,
            iconColor: AppColors.primary,
            label: 'Net Cash Flow',
            value: 'UGX ${_formatNumber(totalReceived - totalPaid)}',
            subtitle: 'This period',
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(text: 'Payments Received'),
          Tab(text: 'Payments Made'),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(
      BuildContext context, List<Map<String, dynamic>> payments, bool isReceived) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search payments...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _PaymentTile(
                  payment: payment,
                  isReceived: isReceived,
                  onTap: () => _showPaymentDetails(context, payment, isReceived),
                );
              },
            ),
          ),
        ],
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

  void _showRecordPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment Type'),
                items: ['Payment Received', 'Payment Made']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Customer/Vendor'),
                items: ['Kampala Traders Ltd', 'Tech Solutions Ltd']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Date'),
                      readOnly: true,
                      initialValue: DateFormat('MMM d, yyyy').format(DateTime.now()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      items: ['Bank Transfer', 'Cash', 'Mobile Money', 'Cheque']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: ['Bank Account - UGX', 'Cash on Hand', 'Petty Cash']
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Reference'),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(
      BuildContext context, Map<String, dynamic> payment, bool isReceived) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Payment ${payment['id']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Date', DateFormat('MMMM d, yyyy').format(payment['date'])),
              _DetailRow(isReceived ? 'Customer' : 'Vendor',
                  payment[isReceived ? 'customer' : 'vendor']),
              _DetailRow(isReceived ? 'Invoice' : 'Bill',
                  payment[isReceived ? 'invoice' : 'bill']),
              _DetailRow('Amount',
                  'UGX ${NumberFormat('#,###').format(payment['amount'])}'),
              _DetailRow('Method', payment['method']),
              _DetailRow('Reference', payment['reference']),
              _DetailRow('Account', payment['account']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
            Expanded(
              child: Column(
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Map<String, dynamic> payment;
  final bool isReceived;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.payment,
    required this.isReceived,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isReceived ? AppColors.income : AppColors.expense)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isReceived ? Icons.arrow_downward : Icons.arrow_upward,
          color: isReceived ? AppColors.income : AppColors.expense,
        ),
      ),
      title: Text(
        payment[isReceived ? 'customer' : 'vendor'],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${payment['method']} • ${payment[isReceived ? 'invoice' : 'bill']}',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'UGX ${NumberFormat('#,###').format(payment['amount'])}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isReceived ? AppColors.income : AppColors.expense,
            ),
          ),
          Text(
            DateFormat('MMM d, yyyy').format(payment['date']),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
