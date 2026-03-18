// Outlet Settled Screen — shows bank settlements matched to outlets
// Two tabs:
//   1. Outlet Summary — per-outlet Net Revenue, Total Settled, Unsettled
//   2. All Settlements — individual settlement records
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/data_service.dart';
import '../../core/models/bank_transaction.dart';

// ---------------------------------------------------------------------------
// Providers
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

class _OutletSettledScreenState extends ConsumerState<OutletSettledScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat('#,###');
  final _dateFmt = DateFormat('MMM d, yyyy');
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  late TabController _tabController;

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
    final settlementsAsync = ref.watch(outletSettlementsProvider);
    final analyticsAsync = ref.watch(outletAnalyticsProvider);

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
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Net Revenue vs Settled amounts per outlet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  tooltip: 'Export settlements to CSV',
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: () => _exportCsv(settlementsAsync.valueOrNull ?? []),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.invalidate(outletSettlementsProvider);
                    ref.invalidate(outletAnalyticsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Tabs ───────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.store_outlined, size: 16),
                    text: 'Outlet Summary',
                  ),
                  Tab(
                    icon: Icon(Icons.receipt_long_outlined, size: 16),
                    text: 'All Settlements',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Filters (for settlements tab) ──────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by outlet name or code...',
                      prefixIcon: const Icon(Icons.search, size: 18),
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
            const SizedBox(height: 16),

            // ── Tab Content ────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Outlet Summary
                  _buildOutletSummaryTab(settlementsAsync, analyticsAsync),
                  // Tab 2: All Settlements
                  _buildAllSettlementsTab(settlementsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Outlet Summary ─────────────────────────────────────────────────

  Widget _buildOutletSummaryTab(
      AsyncValue<List<OutletSettlement>> settlementsAsync,
      AsyncValue<OutletAnalyticsData> analyticsAsync) {
    return settlementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading settlements: $e')),
      data: (settlements) => analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildOutletSummaryFallback(settlements),
        data: (analytics) =>
            _buildOutletSummaryTable(settlements, analytics),
      ),
    );
  }

  Widget _buildOutletSummaryTable(
      List<OutletSettlement> settlements, OutletAnalyticsData analytics) {
    // Build per-outlet net revenue map from analytics engine
    final netRevenueMap = <String, double>{};
    for (final lt in analytics.lifetimeTotals) {
      netRevenueMap[lt.outletId] = lt.netRevenue;
    }

    // Build per-outlet settled total map from settlements
    final settledMap = <String, double>{};
    final outletCodeMap = <String, String>{};
    final outletNameMap = <String, String>{};
    for (final s in settlements) {
      settledMap[s.outletId] = (settledMap[s.outletId] ?? 0) + s.amount;
      outletCodeMap[s.outletId] = s.outletCode;
      outletNameMap[s.outletId] = s.outletName;
    }

    // Merge: include all outlets that appear in either analytics or settlements
    final allOutletIds = <String>{
      ...netRevenueMap.keys,
      ...settledMap.keys,
    };

    // Populate outlet name/code from analytics if not in settlements
    for (final lt in analytics.lifetimeTotals) {
      outletCodeMap.putIfAbsent(lt.outletId, () => lt.outletCode);
      outletNameMap.putIfAbsent(lt.outletId, () => lt.outletName);
    }

    var rows = allOutletIds
        .where((id) {
          if (_searchQuery.isEmpty) return true;
          final name = (outletNameMap[id] ?? '').toLowerCase();
          final code = (outletCodeMap[id] ?? '').toLowerCase();
          return name.contains(_searchQuery) || code.contains(_searchQuery);
        })
        .map((id) {
          final net = netRevenueMap[id] ?? 0;
          final settled = settledMap[id] ?? 0;
          final unsettled = net - settled;
          return _OutletSummaryRow(
            outletId: id,
            outletCode: outletCodeMap[id] ?? '',
            outletName: outletNameMap[id] ?? id,
            netRevenue: net,
            settled: settled,
            unsettled: unsettled,
          );
        })
        .toList()
      ..sort((a, b) => b.unsettled.compareTo(a.unsettled));

    if (rows.isEmpty) {
      return _buildEmptyState(true);
    }

    final totalNet = rows.fold(0.0, (s, r) => s + r.netRevenue);
    final totalSettled = rows.fold(0.0, (s, r) => s + r.settled);
    final totalUnsettled = rows.fold(0.0, (s, r) => s + r.unsettled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary chips
        Row(
          children: [
            _statChip(Icons.store_outlined,
                '${rows.length} outlets', AppColors.primary),
            const SizedBox(width: 10),
            _statChip(Icons.trending_up,
                'Net Rev: UGX ${_fmt.format(totalNet)}', AppColors.income),
            const SizedBox(width: 10),
            _statChip(Icons.check_circle_outline,
                'Settled: UGX ${_fmt.format(totalSettled)}',
                AppColors.success),
            const SizedBox(width: 10),
            _statChip(Icons.hourglass_bottom_outlined,
                'Unsettled: UGX ${_fmt.format(totalUnsettled)}',
                totalUnsettled > 0 ? AppColors.warning : AppColors.success),
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
                    0: FixedColumnWidth(80),  // Code
                    1: FlexColumnWidth(2.5),  // Outlet Name
                    2: FixedColumnWidth(160), // Net Revenue
                    3: FixedColumnWidth(160), // Settled
                    4: FixedColumnWidth(160), // Unsettled
                    5: FixedColumnWidth(120), // Status
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
                        _th('Code'),
                        _th('Outlet Name'),
                        _th('Net Revenue', align: TextAlign.right),
                        _th('Settled', align: TextAlign.right),
                        _th('Unsettled', align: TextAlign.right),
                        _th('Status'),
                      ],
                    ),
                    // Data rows
                    for (final row in rows)
                      TableRow(
                        decoration: BoxDecoration(
                          color: row.unsettled > 0
                              ? Colors.transparent
                              : AppColors.success.withOpacity(0.03),
                          border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 0.5),
                          ),
                        ),
                        children: [
                          _tdWidget(Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              row.outletCode,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                          )),
                          _td(row.outletName),
                          _tdRight('UGX ${_fmt.format(row.netRevenue)}',
                              color: row.netRevenue >= 0
                                  ? AppColors.income
                                  : AppColors.expense),
                          _tdRight('UGX ${_fmt.format(row.settled)}',
                              color: AppColors.success),
                          _tdRight(
                            row.unsettled == 0
                                ? '—'
                                : 'UGX ${_fmt.format(row.unsettled.abs())}',
                            color: row.unsettled > 0
                                ? AppColors.warning
                                : (row.unsettled < 0
                                    ? AppColors.expense
                                    : Theme.of(context).colorScheme.outline),
                          ),
                          _tdWidget(Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 10),
                            child: _settlementStatusChip(row.unsettled),
                          )),
                        ],
                      ),
                    // Totals row
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                      ),
                      children: [
                        _th(''),
                        _th('TOTALS'),
                        _thRight('UGX ${_fmt.format(totalNet)}'),
                        _thRight('UGX ${_fmt.format(totalSettled)}'),
                        _thRight(totalUnsettled == 0
                            ? '—'
                            : 'UGX ${_fmt.format(totalUnsettled.abs())}'),
                        _th(''),
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

  Widget _buildOutletSummaryFallback(List<OutletSettlement> settlements) {
    // Fallback: just group by outlet from settlements alone
    final settledMap = <String, double>{};
    final outletCodeMap = <String, String>{};
    final outletNameMap = <String, String>{};
    for (final s in settlements) {
      settledMap[s.outletId] = (settledMap[s.outletId] ?? 0) + s.amount;
      outletCodeMap[s.outletId] = s.outletCode;
      outletNameMap[s.outletId] = s.outletName;
    }
    if (settledMap.isEmpty) return _buildEmptyState(true);
    final rows = settledMap.entries.map((e) => _OutletSummaryRow(
          outletId: e.key,
          outletCode: outletCodeMap[e.key] ?? '',
          outletName: outletNameMap[e.key] ?? e.key,
          netRevenue: 0,
          settled: e.value,
          unsettled: 0,
        )).toList()
      ..sort((a, b) => b.settled.compareTo(a.settled));

    return Column(children: [
      _statChip(Icons.receipt_long_outlined,
          '${rows.length} outlets settled', AppColors.success),
      const SizedBox(height: 16),
      Text('Net Revenue data unavailable — import CSV first',
          style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontStyle: FontStyle.italic)),
    ]);
  }

  // ── Tab 2: All Settlements ────────────────────────────────────────────────

  Widget _buildAllSettlementsTab(
      AsyncValue<List<OutletSettlement>> settlementsAsync) {
    return settlementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Error loading settlements: $e')),
      data: (all) {
        final filtered = all.where((s) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery;
            if (!s.outletName.toLowerCase().contains(q) &&
                !s.outletCode.toLowerCase().contains(q) &&
                !(s.bankAccountName ?? '').toLowerCase().contains(q)) {
              return false;
            }
          }
          if (_fromDate != null && s.date.isBefore(_fromDate!)) return false;
          if (_toDate != null &&
              s.date
                  .isAfter(_toDate!.add(const Duration(days: 1)))) return false;
          return true;
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        if (filtered.isEmpty) return _buildEmptyState(all.isEmpty);
        return _buildSettlementsTable(filtered);
      },
    );
  }

  Widget _buildSettlementsTable(List<OutletSettlement> rows) {
    final total = rows.fold<double>(0, (s, r) => s + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statChip(Icons.receipt_long_outlined,
                '${rows.length} settlements', AppColors.primary),
            const SizedBox(width: 12),
            _statChip(Icons.attach_money,
                'UGX ${_fmt.format(total)}', AppColors.success),
          ],
        ),
        const SizedBox(height: 16),
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
                    0: FixedColumnWidth(110),
                    1: FixedColumnWidth(90),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                    4: FixedColumnWidth(150),
                    5: FlexColumnWidth(1.5),
                  },
                  children: [
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
                          _tdWidget(Container(
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
                          )),
                          _td(s.outletName),
                          _tdWidget(Row(
                            children: [
                              Icon(Icons.account_balance,
                                  size: 13,
                                  color:
                                      Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(s.bankAccountName ?? '—',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          )),
                          _tdWidget(Padding(
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
                          )),
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

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportCsv(List<OutletSettlement> settlements) async {
    try {
      final rows = [
        ['Date', 'Outlet Code', 'Outlet Name', 'Bank Account', 'Amount (UGX)', 'Reference'],
        ...settlements.map((s) => [
              _dateFmt.format(s.date),
              s.outletCode,
              s.outletName,
              s.bankAccountName ?? '',
              s.amount.toStringAsFixed(0),
              s.reference ?? '',
            ]),
      ];
      final csv = const ListToCsvConverter().convert(rows);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settlements',
        fileName:
            'outlet_settlements_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (path != null) {
        await File(path).writeAsString(csv);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Exported to $path'),
            backgroundColor: AppColors.success,
          ));
        }
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

  // ── Empty state ───────────────────────────────────────────────────────────

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

  // ── Settlement status chip ─────────────────────────────────────────────────

  Widget _settlementStatusChip(double unsettled) {
    if (unsettled <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Text('Fully Settled',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.success,
                fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Text('Pending',
          style: TextStyle(
              fontSize: 11,
              color: AppColors.warning,
              fontWeight: FontWeight.w600)),
    );
  }

  // ── Table helpers ─────────────────────────────────────────────────────────

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

  Widget _thRight(String label) => _th(label, align: TextAlign.right);

  Widget _td(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _tdRight(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: color),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _tdWidget(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Data model for outlet summary row
// ---------------------------------------------------------------------------

class _OutletSummaryRow {
  final String outletId;
  final String outletCode;
  final String outletName;
  final double netRevenue;
  final double settled;
  final double unsettled;

  _OutletSummaryRow({
    required this.outletId,
    required this.outletCode,
    required this.outletName,
    required this.netRevenue,
    required this.settled,
    required this.unsettled,
  });
}
