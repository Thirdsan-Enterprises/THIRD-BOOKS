import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/api_client.dart';
import '../../core/models/payment.dart';
import '../../core/widgets/attachment_widget.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  List<Payment> get _receivedPayments {
    final paymentsState = ref.watch(paymentsProvider);
    return paymentsState.payments
        .where((p) => p.paymentType == PaymentType.received)
        .where((p) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return p.customerName?.toLowerCase().contains(query) == true ||
              p.paymentNumber.toLowerCase().contains(query) ||
              p.reference?.toLowerCase().contains(query) == true;
        })
        .toList();
  }

  List<Payment> get _madePayments {
    final paymentsState = ref.watch(paymentsProvider);
    return paymentsState.payments
        .where((p) => p.paymentType == PaymentType.made)
        .where((p) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return p.vendorName?.toLowerCase().contains(query) == true ||
              p.paymentNumber.toLowerCase().contains(query) ||
              p.reference?.toLowerCase().contains(query) == true;
        })
        .toList();
  }

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
    final paymentsState = ref.watch(paymentsProvider);

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
              child: paymentsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : paymentsState.payments.isEmpty
                      ? _buildEmptyState(context)
                      : TabBarView(
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payments_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No payments recorded yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record your first payment to start tracking cash flow',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showRecordPaymentDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Record Payment'),
          ),
        ],
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
              onPressed: () => _exportToCSV(context),
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
    final paymentsState = ref.watch(paymentsProvider);
    final received = paymentsState.payments.where((p) => p.isReceived).toList();
    final made = paymentsState.payments.where((p) => p.isMade).toList();

    final totalReceived = received.fold<double>(0, (sum, p) => sum + p.amount);
    final totalPaid = made.fold<double>(0, (sum, p) => sum + p.amount);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_downward,
            iconColor: AppColors.income,
            label: 'Total Received',
            value: 'UGX ${_formatNumber(totalReceived)}',
            subtitle: '${received.length} payments',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_upward,
            iconColor: AppColors.expense,
            label: 'Total Paid',
            value: 'UGX ${_formatNumber(totalPaid)}',
            subtitle: '${made.length} payments',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance,
            iconColor: totalReceived - totalPaid >= 0 ? AppColors.income : AppColors.expense,
            label: 'Net Cash Flow',
            value: 'UGX ${_formatNumber((totalReceived - totalPaid).abs())}',
            subtitle: totalReceived >= totalPaid ? 'Net inflow' : 'Net outflow',
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
        tabs: [
          Tab(text: 'Received (${_receivedPayments.length})'),
          Tab(text: 'Made (${_madePayments.length})'),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(BuildContext context, List<Payment> payments, bool isReceived) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReceived ? Icons.arrow_downward : Icons.arrow_upward,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isReceived ? 'No payments received yet' : 'No payments made yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search payments...',
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _PaymentTile(
                  payment: payment,
                  onTap: () => _showPaymentDetails(context, payment),
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

  void _exportToCSV(BuildContext context) async {
    final paymentsState = ref.read(paymentsProvider);
    if (paymentsState.payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payments to export')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Payments',
        fileName: 'payments_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final buffer = StringBuffer();
        buffer.writeln('Payment Number,Type,Customer/Vendor,Date,Amount,Method,Reference,Account,Status');

        for (final payment in paymentsState.payments) {
          buffer.writeln(
            '${payment.paymentNumber},'
            '${payment.isReceived ? 'Received' : 'Made'},'
            '"${payment.isReceived ? payment.customerName ?? '' : payment.vendorName ?? ''}",'
            '${DateFormat('yyyy-MM-dd').format(payment.paymentDate)},'
            '${payment.amount},'
            '${payment.paymentMethod},'
            '"${payment.reference ?? ''}",'
            '"${payment.accountName ?? ''}",'
            '${payment.status.name}',
          );
        }

        final file = File(result);
        await file.writeAsString(buffer.toString());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${paymentsState.payments.length} payments to CSV')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showRecordPaymentDialog(BuildContext context) {
    final customersState = ref.read(customersProvider);
    final vendorsState = ref.read(vendorsProvider);
    final accountsState = ref.read(accountsProvider);

    // Filter to cash/bank accounts
    final paymentAccounts = accountsState.accounts.where((a) {
      final subType = a.subType.toString().toLowerCase();
      return subType.contains('bank') || subType.contains('cash') || subType.contains('mobile');
    }).toList();

    PaymentType selectedType = PaymentType.received;
    String? selectedCustomerId;
    String? selectedVendorId;
    String? selectedAccountId;
    String? selectedMethod;
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Record Payment'),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<PaymentType>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Payment Type *'),
                      items: const [
                        DropdownMenuItem(value: PaymentType.received, child: Text('Payment Received')),
                        DropdownMenuItem(value: PaymentType.made, child: Text('Payment Made')),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          selectedType = v ?? PaymentType.received;
                          selectedCustomerId = null;
                          selectedVendorId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedType == PaymentType.received)
                      DropdownButtonFormField<String>(
                        value: selectedCustomerId,
                        decoration: const InputDecoration(labelText: 'Customer *'),
                        items: customersState.customers
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedCustomerId = v),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedVendorId,
                        decoration: const InputDecoration(labelText: 'Vendor *'),
                        items: vendorsState.vendors
                            .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedVendorId = v),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount *',
                              prefixText: 'UGX ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('MMM d, yyyy').format(selectedDate),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (date != null) {
                                setDialogState(() => selectedDate = date);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedMethod,
                            decoration: const InputDecoration(labelText: 'Payment Method *'),
                            items: ['Bank Transfer', 'Cash', 'Mobile Money', 'Cheque', 'Credit Card']
                                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedMethod = v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedAccountId,
                            decoration: const InputDecoration(labelText: 'Account *'),
                            items: paymentAccounts
                                .map((a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedAccountId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: referenceController,
                      decoration: const InputDecoration(labelText: 'Reference (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                      maxLines: 2,
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
              FilledButton(
                onPressed: () {
                  // Validation
                  if (selectedType == PaymentType.received && selectedCustomerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a customer')),
                    );
                    return;
                  }
                  if (selectedType == PaymentType.made && selectedVendorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a vendor')),
                    );
                    return;
                  }
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }
                  if (selectedMethod == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a payment method')),
                    );
                    return;
                  }
                  if (selectedAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an account')),
                    );
                    return;
                  }

                  // Get names
                  String? customerName;
                  String? vendorName;
                  if (selectedType == PaymentType.received) {
                    customerName = customersState.customers
                        .firstWhere((c) => c.id == selectedCustomerId)
                        .name;
                  } else {
                    vendorName = vendorsState.vendors
                        .firstWhere((v) => v.id == selectedVendorId)
                        .name;
                  }
                  final account = paymentAccounts.firstWhere((a) => a.id == selectedAccountId);

                  final payment = Payment(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    paymentNumber: '${selectedType == PaymentType.received ? 'REC' : 'PAY'}-${DateFormat('yyyyMMdd').format(selectedDate)}-${DateTime.now().millisecondsSinceEpoch % 1000}',
                    paymentType: selectedType,
                    customerId: selectedCustomerId,
                    customerName: customerName,
                    vendorId: selectedVendorId,
                    vendorName: vendorName,
                    paymentDate: selectedDate,
                    amount: amount,
                    paymentMethod: selectedMethod!,
                    reference: referenceController.text.isEmpty ? null : referenceController.text,
                    notes: notesController.text.isEmpty ? null : notesController.text,
                    accountId: selectedAccountId,
                    accountName: account.name,
                    status: PaymentStatus.completed,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  ref.read(paymentsProvider.notifier).addPayment(payment);
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Payment recorded (will sync when online)'),
                      backgroundColor: AppColors.income,
                    ),
                  );
                },
                child: const Text('Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentDetails(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Payment ${payment.paymentNumber}'),
            const Spacer(),
            _buildStatusBadge(payment.status),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (payment.isReceived ? AppColors.income : AppColors.expense).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      payment.isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                      color: payment.isReceived ? AppColors.income : AppColors.expense,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.isReceived ? 'Payment Received' : 'Payment Made',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'UGX ${NumberFormat('#,###').format(payment.amount)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: payment.isReceived ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow('Date', DateFormat('MMMM d, yyyy').format(payment.paymentDate)),
              _DetailRow(
                payment.isReceived ? 'Customer' : 'Vendor',
                payment.isReceived ? (payment.customerName ?? '-') : (payment.vendorName ?? '-'),
              ),
              _DetailRow('Payment Method', payment.paymentMethod),
              _DetailRow('Reference', payment.reference ?? '-'),
              _DetailRow('Account', payment.accountName ?? '-'),
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _DetailRow('Notes', payment.notes!),
              _DetailRow('Created', DateFormat('MMM d, yyyy HH:mm').format(payment.createdAt)),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              AttachmentPanel(
                attachableType: payment.isReceived ? 'payment' : 'bill-payment',
                attachableId: payment.syncSequence,
                apiClient: ref.read(apiClientProvider),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Print functionality coming soon')),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    Color color;
    String label;
    switch (status) {
      case PaymentStatus.completed:
        color = AppColors.income;
        label = 'Completed';
        break;
      case PaymentStatus.pending:
        color = AppColors.warning;
        label = 'Pending';
        break;
      case PaymentStatus.cancelled:
        color = AppColors.expense;
        label = 'Cancelled';
        break;
      case PaymentStatus.refunded:
        color = AppColors.info;
        label = 'Refunded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
  final Payment payment;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.payment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReceived = payment.isReceived;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isReceived ? AppColors.income : AppColors.expense).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isReceived ? Icons.arrow_downward : Icons.arrow_upward,
          color: isReceived ? AppColors.income : AppColors.expense,
        ),
      ),
      title: Text(
        isReceived ? (payment.customerName ?? 'Unknown') : (payment.vendorName ?? 'Unknown'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${payment.paymentMethod} • ${payment.paymentNumber}',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'UGX ${NumberFormat('#,###').format(payment.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isReceived ? AppColors.income : AppColors.expense,
            ),
          ),
          Text(
            DateFormat('MMM d, yyyy').format(payment.paymentDate),
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
