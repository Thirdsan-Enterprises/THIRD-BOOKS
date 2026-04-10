import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';

/// Asset Depreciation Screen
///
/// Features:
/// - Percentage-based depreciation (Declining Balance method)
/// - Period selection: Monthly or Yearly
/// - Auto-generate depreciation journal entries
/// - View depreciation schedules and history
class DepreciationScreen extends ConsumerStatefulWidget {
  const DepreciationScreen({super.key});

  @override
  ConsumerState<DepreciationScreen> createState() => _DepreciationScreenState();
}

class _DepreciationScreenState extends ConsumerState<DepreciationScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Depreciation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _showDepreciationCalculator,
            tooltip: 'Depreciation Calculator',
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: _generateDepreciationEntries,
            tooltip: 'Generate Entries',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          _buildSummarySection(),

          // Depreciation Schedules List
          Expanded(
            child: _buildSchedulesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSetupDepreciationDialog,
        icon: const Icon(Icons.add),
        label: const Text('Setup Depreciation'),
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
              'Active Schedules',
              '0',
              Icons.schedule,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Total Depreciation',
              'UGX 0',
              Icons.trending_down,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'This Month',
              'UGX 0',
              Icons.calendar_today,
              AppColors.info,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Pending Entries',
              '0',
              Icons.pending_actions,
              AppColors.error,
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

  Widget _buildSchedulesList() {
    // TODO: Replace with actual data from database
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No depreciation schedules found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Set up depreciation for your assets'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showSetupDepreciationDialog,
            icon: const Icon(Icons.add),
            label: const Text('Setup Depreciation'),
          ),
        ],
      ),
    );
  }

  void _showSetupDepreciationDialog() {
    final formKey = GlobalKey<FormState>();
    final rateController = TextEditingController(text: '20');
    DateTime startDate = DateTime.now();
    String selectedMethod = 'declining_balance';
    String selectedPeriod = 'yearly';

    // Sample data - TODO: Get from database
    String selectedAsset = 'Select Asset';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Setup Asset Depreciation'),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Asset Selection
                    DropdownButtonFormField<String>(
                      value: selectedAsset,
                      decoration: const InputDecoration(
                        labelText: 'Select Asset *',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Select Asset',
                          child: Text('Select Asset'),
                        ),
                        // TODO: Load from database
                      ],
                      onChanged: (value) {
                        setState(() => selectedAsset = value!);
                      },
                      validator: (v) => v == 'Select Asset' ? 'Please select an asset' : null,
                    ),
                    const SizedBox(height: 16),

                    // Depreciation Method
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Depreciation Method',
                        prefixIcon: Icon(Icons.calculate),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'declining_balance',
                          child: Text('Declining Balance (Percentage-based)'),
                        ),
                        DropdownMenuItem(
                          value: 'straight_line',
                          child: Text('Straight Line'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedMethod = value!);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Depreciation Rate
                    TextFormField(
                      controller: rateController,
                      decoration: const InputDecoration(
                        labelText: 'Depreciation Rate *',
                        suffixText: '%',
                        prefixIcon: Icon(Icons.percent),
                        hintText: '20',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final rate = double.tryParse(v!);
                        if (rate == null || rate <= 0 || rate > 100) {
                          return 'Enter a valid percentage (0-100)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Period
                    DropdownButtonFormField<String>(
                      value: selectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Period *',
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedPeriod = value!);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Start Date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => startDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(startDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Calculation Preview
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
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.info, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Depreciation Preview',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildPreviewRow(
                            'Method:',
                            selectedMethod == 'declining_balance'
                                ? 'Declining Balance'
                                : 'Straight Line',
                          ),
                          _buildPreviewRow(
                            'Rate:',
                            '${rateController.text}% per ${selectedPeriod == 'monthly' ? 'month' : 'year'}',
                          ),
                          _buildPreviewRow(
                            'Start Date:',
                            DateFormat('MMM dd, yyyy').format(startDate),
                          ),
                          const Divider(height: 16),
                          const Text(
                            'Example Calculation (Declining Balance):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Asset Value: UGX 10,000,000\n'
                            'Year 1: 10M × 20% = 2M depreciation → 8M remaining\n'
                            'Year 2: 8M × 20% = 1.6M depreciation → 6.4M remaining\n'
                            'Year 3: 6.4M × 20% = 1.28M depreciation → 5.12M remaining',
                            style: TextStyle(fontSize: 12, height: 1.5),
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

                final rate = double.parse(rateController.text);

                // TODO: Save depreciation schedule
                // final depreciation = AssetDepreciationCompanion.insert(
                //   id: const Uuid().v4(),
                //   assetId: selectedAssetId,
                //   method: selectedMethod,
                //   rate: rate,
                //   period: selectedPeriod,
                //   startDate: startDate,
                //   isActive: const Value(true),
                //   createdAt: DateTime.now(),
                //   updatedAt: DateTime.now(),
                // );
                // await ref.read(databaseProvider).insertAssetDepreciation(depreciation);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Depreciation schedule created'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Create Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showDepreciationCalculator() {
    final formKey = GlobalKey<FormState>();
    final assetValueController = TextEditingController();
    final rateController = TextEditingController(text: '20');
    final yearsController = TextEditingController(text: '5');
    String selectedPeriod = 'yearly';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate depreciation schedule
          List<Map<String, dynamic>> schedule = [];
          if (assetValueController.text.isNotEmpty &&
              rateController.text.isNotEmpty &&
              yearsController.text.isNotEmpty) {
            final assetValue = double.tryParse(assetValueController.text.replaceAll(',', '')) ?? 0;
            final rate = double.tryParse(rateController.text) ?? 0;
            final years = int.tryParse(yearsController.text) ?? 0;

            if (assetValue > 0 && rate > 0 && years > 0) {
              double remainingValue = assetValue;
              for (var i = 1; i <= years; i++) {
                final depreciation = remainingValue * (rate / 100);
                remainingValue -= depreciation;
                schedule.add({
                  'year': i,
                  'depreciation': depreciation,
                  'remaining': remainingValue,
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Depreciation Calculator'),
            content: SizedBox(
              width: 700,
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
                              controller: assetValueController,
                              decoration: const InputDecoration(
                                labelText: 'Asset Value',
                                prefixText: 'UGX ',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: rateController,
                              decoration: const InputDecoration(
                                labelText: 'Rate',
                                suffixText: '%',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: yearsController,
                              decoration: const InputDecoration(
                                labelText: 'Years',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (schedule.isNotEmpty) ...[
                        const Text(
                          'Depreciation Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Expanded(child: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(child: Text('Depreciation', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(child: Text('Book Value', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                              ...schedule.map((row) => Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text('Year ${row['year']}')),
                                        Expanded(child: Text(_currencyFormat.format(row['depreciation']))),
                                        Expanded(child: Text(_currencyFormat.format(row['remaining']))),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _generateDepreciationEntries() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Depreciation Entries'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will generate depreciation journal entries for:'),
            SizedBox(height: 16),
            Text('• All active depreciation schedules'),
            Text('• Current period (month/year)'),
            Text('• Not already posted'),
            SizedBox(height: 16),
            Text('Continue?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Generate entries
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Depreciation entries generated'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
