// Outlet Settled Screen — shows bank settlements matched to outlets
// Displays every OutletSettlement record: outlet code, name, bank account,
// settlement amount, date, and reference.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/models/bank_transaction.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final outletSettlementsProvider =
    FutureProvider<List<OutletSettlement>>((ref) async {
  return LocalStorageService.instance.loadOutletSettlements();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OutletSettledScreen extends ConsumerStatefulWidget {
  const OutletSettledScreen({super.key});

  @override
  ConsumerState<OutletSettledScreen> createState() =>
      _OutletSettledScreenState();
}

class _OutletSettledScreenState extends ConsumerState<OutletSettledScreen> {
  final _fmt = NumberFormat('#,###');
  final _dateFmt = DateFormat('MMM d, yyyy');
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    final settlementsAsync = ref.watch(outletSettlementsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outlet Settlements',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bank receipts matched and settled against outlets',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(outletSettlementsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Filters ────────────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by outlet name or code...',
                      prefixIcon:
                          const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(_fromDate == null
                      ? 'From Date'
                      : _dateFmt.format(_fromDate!)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _fromDate = d);
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                      _toDate == null ? 'To Date' : _dateFmt.format(_toDate!)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _toDate = d);
                  },
                ),
                if (_fromDate != null || _toDate != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear'),
                    onPressed: () =>
                        setState(() => _fromDate = _toDate = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: settlementsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error loading settlements: $e')),
                data: (all) {
                  final filtered = all.where((s) {
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery;
                      if (!s.outletName.toLowerCase().contains(q) &&
                          !s.outletCode.toLowerCase().contains(q) &&
                          !(s.bankAccountName ?? '')
                              .toLowerCase()
                              .contains(q)) {
                        return false;
                      }
                    }
                    if (_fromDate != null &&
                        s.date.isBefore(_fromDate!)) return false;
                    if (_toDate != null &&
                        s.date.isAfter(
                            _toDate!.add(const Duration(days: 1)))) {
                      return false;
                    }
                    return true;
                  }).toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

                  if (filtered.isEmpty) {
                    return _buildEmptyState(all.isEmpty);
                  }

                  return _buildTable(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<OutletSettlement> rows) {
    final total =
        rows.fold<double>(0, (s, r) => s + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary strip
        Row(
          children: [
            _statChip(Icons.receipt_long_outlined, '${rows.length} settlements',
                AppColors.primary),
            const SizedBox(width: 12),
            _statChip(Icons.attach_money, 'UGX ${_fmt.format(total)}',
                AppColors.success),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(110), // Date
                    1: FixedColumnWidth(90),  // Code
                    2: FlexColumnWidth(2),    // Outlet Name
                    3: FlexColumnWidth(2),    // Bank Account
                    4: FixedColumnWidth(140), // Amount
                    5: FlexColumnWidth(1.5),  // Reference
                  },
                  children: [
                    // Header
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.5),
                      ),
                      children: [
                        _th('Date'),
                        _th('Code'),
                        _th('Outlet Name'),
                        _th('Bank Account'),
                        _th('Settlement Amount', align: TextAlign.right),
                        _th('Reference'),
                      ],
                    ),
                    // Data rows
                    for (final s in rows)
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 0.5),
                          ),
                        ),
                        children: [
                          _td(_dateFmt.format(s.date)),
                          _tdWidget(
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.outletCode,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                          _td(s.outletName),
                          _tdWidget(Row(
                            children: [
                              Icon(Icons.account_balance,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(s.bankAccountName ?? '—',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          )),
                          _tdWidget(
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              child: Text(
                                'UGX ${_fmt.format(s.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.success,
                                    fontFamily: 'monospace'),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          _td(s.reference ?? '—'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool noData) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            noData
                ? 'No outlet settlements yet'
                : 'No settlements match your filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            noData
                ? 'Settlements are created when you reconcile bank deposits\nand match them to outlets.'
                : 'Try adjusting your search or date range.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _th(String label, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.outline,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _td(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _tdWidget(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: child,
    );
  }
}
