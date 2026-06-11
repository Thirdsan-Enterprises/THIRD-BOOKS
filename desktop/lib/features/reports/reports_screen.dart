import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/models.dart';
import '../../core/database/app_database.dart' hide Account, Customer, Vendor, Invoice, Bill, JournalEntry, JournalLine;
import '../outlets/outlet_settled_screen.dart' show outletSettlementsProvider;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedPeriod = 'This Month';
  String _selectedReportType = 'all';
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  DateTime? _customFrom;
  DateTime? _customTo;

  final List<Map<String, dynamic>> _reportCategories = [
    {
      'category': 'Financial Statements',
      'icon': Icons.account_balance,
      'color': AppColors.primary,
      'reports': [
        {'name': 'Balance Sheet', 'description': 'Assets, liabilities and equity at a point in time', 'icon': Icons.balance},
        {'name': 'Income Statement', 'description': 'Revenue and expenses over a period', 'icon': Icons.trending_up},
        {'name': 'Cash Flow Statement', 'description': 'Cash inflows and outflows', 'icon': Icons.water_drop},
        {'name': 'Trial Balance', 'description': 'All account balances', 'icon': Icons.list_alt},
      ],
    },
    {
      'category': 'Outlet Performance',
      'icon': Icons.store,
      'color': AppColors.debit,
      'reports': [
        {'name': 'GGR by Outlet', 'description': 'Gross Gaming Revenue per outlet', 'icon': Icons.bar_chart},
        {'name': 'Outlet Revenue Summary', 'description': 'Total In / Out / GGR summary', 'icon': Icons.summarize},
        {'name': 'Daily Performance', 'description': 'Day-by-day outlet performance', 'icon': Icons.calendar_month},
        {'name': 'Top Performers', 'description': 'Highest revenue outlets', 'icon': Icons.emoji_events},
      ],
    },
    {
      'category': 'Tax Reports',
      'icon': Icons.calculate,
      'color': AppColors.warning,
      'reports': [
        {'name': 'GGR Tax Report', 'description': 'Gaming revenue tax summary', 'icon': Icons.receipt},
        {'name': 'Tax Summary', 'description': 'Tax obligations summary', 'icon': Icons.summarize},
        {'name': 'Withholding Tax', 'description': 'WHT deducted and remitted', 'icon': Icons.remove_circle_outline},
      ],
    },
    {
      'category': 'Management Reports',
      'icon': Icons.insights,
      'color': AppColors.secondary,
      'reports': [
        {'name': 'GGR by Month', 'description': 'Monthly GGR comparison', 'icon': Icons.calendar_month},
        {'name': 'Payout Ratio Analysis', 'description': 'Total Out vs Total In ratio', 'icon': Icons.pie_chart},
        {'name': 'Revenue Trend', 'description': 'Revenue trend over time', 'icon': Icons.show_chart},
      ],
    },
    {
      'category': 'Receivables & Payables',
      'icon': Icons.account_balance_wallet,
      'color': Colors.teal,
      'reports': [
        {'name': 'AR Schedule',    'description': 'Outstanding receivables by outlet (60% of weekly GGR)', 'icon': Icons.arrow_downward},
        {'name': 'AP Schedule',    'description': 'Outstanding payables by vendor',                        'icon': Icons.arrow_upward},
        {'name': 'AR Ageing',      'description': 'Receivables aged by days outstanding',                  'icon': Icons.hourglass_bottom},
        {'name': 'AP Ageing',      'description': 'Payables aged by days outstanding',                     'icon': Icons.hourglass_top},
      ],
    },
  ];

  // ---------------------------------------------------------------------------
  // Ledger helpers — compute real account balances from posted journal entries
  // ---------------------------------------------------------------------------

  /// Returns {accountKey → (totalDebits − totalCredits)} for the given entries.
  /// Keys are normalised to 'acct-{code}' when accountCode is stored on the
  /// journal line; otherwise the raw accountId is used as the key.
  Map<String, double> _computeLedgerBalances(List<JournalEntry> entries) {
    final raw = <String, double>{};
    for (final entry in entries) {
      if (entry.status != JournalEntryStatus.posted) continue;
      for (final line in entry.lines) {
        final key = line.accountCode != null ? 'acct-${line.accountCode}' : line.accountId;
        raw[key] = (raw[key] ?? 0) + line.debit - line.credit;
      }
    }
    return raw;
  }

  /// Presentational balance for [account] — positive means normal direction.
  /// Tries 'acct-{code}' first (normalised key), then raw account.id as fallback.
  double _acctBal(Account account, Map<String, double> raw) {
    final r = raw['acct-${account.code}'] ?? raw[account.id] ?? 0.0;
    return account.isDebitNormal ? r : -r;
  }

  // ── Account ordering helpers ───────────────────────────────────────────────

  /// Sorts revenue accounts: Stakes (103) first, Payouts (107) second, rest by code.
  void _sortRevenueAccts(List<Account> list) {
    list.sort((a, b) {
      int order(String code) {
        if (code == '103') return 0;
        if (code == '107') return 1;
        return 2;
      }
      final oa = order(a.code), ob = order(b.code);
      return oa != ob ? oa.compareTo(ob) : a.code.compareTo(b.code);
    });
  }

  /// Sorts current asset accounts: Cash → Bank+BG(167) → AR → SCR(173) → other OCA.
  void _sortCurrentAssets(List<Account> list) {
    list.sort((a, b) {
      int order(Account ac) {
        if (ac.subType == AccountSubType.cash) return 0;
        if (ac.subType == AccountSubType.bank || ac.code == '167') return 1;
        if (ac.subType == AccountSubType.accountsReceivable) return 2;
        if (ac.code == '173') return 3;
        if (ac.subType == AccountSubType.otherCurrentAsset) return 4;
        return 5;
      }
      final cmp = order(a).compareTo(order(b));
      return cmp != 0 ? cmp : a.code.compareTo(b.code);
    });
  }


  /// Converts [_selectedPeriod] to (start, end) using a July–June fiscal year.
  (DateTime, DateTime) _getPeriodDates() {
    final now = DateTime.now();
    // Fiscal year: Jul 1 → Jun 30
    final fyStart = now.month >= 7
        ? DateTime(now.year, 7, 1)
        : DateTime(now.year - 1, 7, 1);
    final fyEnd = DateTime(fyStart.year + 1, 6, 30, 23, 59, 59);

    DateTime monthStart(int year, int month) => DateTime(year, month, 1);
    DateTime monthEnd(int year, int month) =>
        DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));

    switch (_selectedPeriod) {
      case 'Today':
        final d = DateTime(now.year, now.month, now.day);
        return (d, d.add(const Duration(hours: 23, minutes: 59, seconds: 59)));
      case 'This Week':
        final ws = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(ws.year, ws.month, ws.day),
                DateTime(now.year, now.month, now.day, 23, 59, 59));
      case 'This Month':
        return (monthStart(now.year, now.month), monthEnd(now.year, now.month));
      case 'Last Month':
        final lm = now.month == 1
            ? DateTime(now.year - 1, 12)
            : DateTime(now.year, now.month - 1);
        return (monthStart(lm.year, lm.month), monthEnd(lm.year, lm.month));
      case 'This Quarter':
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(now.year, qStart, 1), monthEnd(now.year, qStart + 2));
      case 'Last Quarter':
        final cqStart = ((now.month - 1) ~/ 3) * 3 + 1;
        final lqEnd   = DateTime(now.year, cqStart, 1).subtract(const Duration(seconds: 1));
        final lqStart = ((lqEnd.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(lqEnd.year, lqStart, 1), lqEnd);
      case 'Last Year':
        return (DateTime(fyStart.year - 1, 7, 1),
                DateTime(fyStart.year, 6, 30, 23, 59, 59));
      case 'Custom':
        final s = _customFrom ?? fyStart;
        final e = _customTo != null
            ? DateTime(_customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59)
            : fyEnd;
        return (s, e);
      case 'This Year':
      default:
        return (fyStart, fyEnd);
    }
  }

  /// Entries that fall within the selected period (for P&L / Cash Flow flows).
  List<JournalEntry> _filterEntries(List<JournalEntry> entries) {
    final (start, end) = _getPeriodDates();
    return entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList();
  }

  /// All entries up to and including the period end date (for Trial Balance /
  /// Balance Sheet — cumulative balances as of that date).
  List<JournalEntry> _cumulativeEntries(List<JournalEntry> entries) {
    final (_, end) = _getPeriodDates();
    return entries.where((e) => !e.date.isAfter(end)).toList();
  }

  // ---------------------------------------------------------------------------
  // Cash Flow computation (indirect method — matches client's Excel sample)
  // ---------------------------------------------------------------------------

  /// Derives all cash flow line items from the ledger and dashboard.
  ///
  /// Uses the indirect method:
  ///   Operating = Operating Profit + non-cash add-backs + WC movements
  ///   Investing  = asset acquisitions / disposals
  ///   Financing  = loan proceeds / repayments / dividends
  Map<String, double> _computeCashFlowFigures() {
    final accounts   = ref.read(accountsProvider).accounts;
    final allEntries = ref.read(journalsProvider).entries;

    // P&L items use period-filtered entries; balance sheet items use cumulative.
    final periodRaw = _computeLedgerBalances(_filterEntries(allEntries));
    final cumRaw    = _computeLedgerBalances(_cumulativeEntries(allEntries));

    double sumCum(Iterable<Account> accts) =>
        accts.fold(0.0, (s, a) => s + (cumRaw['acct-${a.code}'] ?? cumRaw[a.id] ?? 0.0));

    // ── Cash & Bank (cumulative as of period end — includes Bank Guarantee 167) ─
    final closingCash = sumCum(accounts.where(
      (a) => a.subType == AccountSubType.cash ||
             a.subType == AccountSubType.bank ||
             a.code == '167'));

    // ── Working Capital (cumulative snapshot at period end) ──────────────────
    final arRaw = sumCum(accounts.where(
      (a) => a.subType == AccountSubType.accountsReceivable));
    final apRaw = sumCum(accounts.where(
      (a) => a.subType == AccountSubType.accountsPayable));
    final receivablesImpact = -arRaw;
    final payablesImpact    = -apRaw;

    // ── Depreciation & Amortization add-back (period, non-cash) ─────────────
    final depAccts = accounts.where(
      (a) => a.type == AccountType.expense &&
             (a.name.toLowerCase().contains('depreciation') ||
              a.name.toLowerCase().contains('amortization') ||
              a.name.toLowerCase().contains('amortisation'))).toList();
    double depreciationAddBack = depAccts.fold(
        0.0, (s, a) => s + (periodRaw['acct-${a.code}'] ?? periodRaw[a.id] ?? 0.0));
    if (depAccts.every((a) => a.code != '143')) {
      depreciationAddBack += periodRaw['acct-143'] ?? 0.0;
    }

    // ── Investing (cumulative) ────────────────────────────────────────────────
    final assetAcquisitions = sumCum(accounts.where(
      (a) => (a.subType == AccountSubType.fixedAsset ||
               a.subType == AccountSubType.intangibleAsset) &&
             !a.name.toLowerCase().contains('depreciation') &&
             !a.name.toLowerCase().contains('amortization') &&
             !a.name.toLowerCase().contains('amortisation') &&
             !a.name.toLowerCase().contains('accumulated')));

    // ── Financing (cumulative) ────────────────────────────────────────────────
    final loanRaw = sumCum(accounts.where(
      (a) => a.subType == AccountSubType.longTermLiability));
    final loanProceeds  = loanRaw < 0 ? -loanRaw : 0.0;
    final loanRepayment = loanRaw > 0 ? loanRaw  : 0.0;

    final dividendsPaid = sumCum(accounts.where(
      (a) => a.name.toLowerCase().contains('dividend') &&
             a.type == AccountType.equity));

    // ── Operating profit from income statement (period-filtered) ─────────────
    const cfCorCodes = {'107', '178'};
    const cfTaxCodes = {'108'};
    final cfRevAccts  = accounts.where((a) => a.type == AccountType.revenue).toList();
    final cfExpAccts  = accounts.where((a) => a.type == AccountType.expense).toList();
    final cfCorAccts  = cfExpAccts.where((a) => cfCorCodes.contains(a.code)).toList();
    final cfTaxAccts  = cfExpAccts.where((a) => cfTaxCodes.contains(a.code)).toList();
    final cfOpexAccts = cfExpAccts
        .where((a) => !cfCorCodes.contains(a.code) && !cfTaxCodes.contains(a.code))
        .toList();

    double cfBal(Account a) {
      final b = periodRaw['acct-${a.code}'] ?? periodRaw[a.id] ?? 0.0;
      return a.isDebitNormal ? b : -b;
    }
    double cfSum(List<Account> list) => list.fold(0.0, (s, a) => s + cfBal(a));

    final cfRevenue = cfSum(cfRevAccts);
    final cfCoR     = cfSum(cfCorAccts);
    final cfTax     = cfSum(cfTaxAccts);
    final cfOpex    = cfSum(cfOpexAccts);
    final operatingProfit = cfRevenue - cfCoR - cfTax - cfOpex;

    // ── Net totals ───────────────────────────────────────────────────────────
    final netOperating = operatingProfit + depreciationAddBack +
                         receivablesImpact + payablesImpact;
    final netInvesting = -assetAcquisitions;
    final netFinancing = loanProceeds - loanRepayment - dividendsPaid;
    final netIncrease  = netOperating + netInvesting + netFinancing;
    final openingCash  = closingCash - netIncrease;

    return {
      'operatingProfit'     : operatingProfit,
      'depreciationAddBack' : depreciationAddBack,
      'receivablesImpact'   : receivablesImpact,
      'payablesImpact'      : payablesImpact,
      'netOperating'        : netOperating,
      'assetAcquisitions'   : assetAcquisitions,
      'netInvesting'        : netInvesting,
      'loanProceeds'        : loanProceeds,
      'loanRepayment'       : loanRepayment,
      'dividendsPaid'       : dividendsPaid,
      'netFinancing'        : netFinancing,
      'openingCash'         : openingCash,
      'netIncrease'         : netIncrease,
      'closingCash'         : closingCash,
    };
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
            _buildQuickStats(context),
            const SizedBox(height: 24),
            _buildFilters(context),
            const SizedBox(height: 16),
            Expanded(child: _buildReportsGrid(context)),
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
              'Financial Reports',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate and analyze financial reports',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  items: ['Today', 'This Week', 'This Month', 'This Quarter', 'This Year', 'Last Month', 'Last Quarter', 'Last Year', 'Custom']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) async {
                    if (value == 'Custom') {
                      final now = DateTime.now();
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: _customFrom != null && _customTo != null
                            ? DateTimeRange(start: _customFrom!, end: _customTo!)
                            : DateTimeRange(
                                start: DateTime(now.year, now.month, 1),
                                end: now,
                              ),
                      );
                      if (range != null && mounted) {
                        setState(() {
                          _customFrom = range.start;
                          _customTo = range.end;
                          _selectedPeriod = 'Custom';
                        });
                      }
                    } else {
                      setState(() {
                        _selectedPeriod = value!;
                        _customFrom = null;
                        _customTo = null;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(journalsProvider);
                ref.invalidate(accountsProvider);
                ref.invalidate(dashboardDataProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports refreshed'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _exportAllReports,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export All'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return dashboardAsync.when(
      data: (data) => Row(
        children: [
          Expanded(
            child: _QuickStatCard(
              title: 'Gross Gaming Revenue',
              value: _currencyFormat.format(data.totalRevenue),
              change: 'Total GGR',
              isPositive: true,
              icon: Icons.trending_up,
              color: AppColors.income,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _QuickStatCard(
              title: 'Total Cash In (Stakes)',
              value: _currencyFormat.format(data.cashIn),
              change: 'All outlets',
              isPositive: true,
              icon: Icons.attach_money,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _QuickStatCard(
              title: 'Total Payouts',
              value: _currencyFormat.format(data.cashOut),
              change: 'Customer winnings',
              isPositive: false,
              icon: Icons.money_off,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _QuickStatCard(
              title: 'Payout Ratio',
              value: data.cashIn > 0
                  ? '${(data.cashOut / data.cashIn * 100).toStringAsFixed(1)}%'
                  : '0%',
              change: 'Out/In ratio',
              isPositive: data.cashIn > 0 && (data.cashOut / data.cashIn) < 0.85,
              icon: Icons.pie_chart,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 100, child: Center(child: Text('Error loading data'))),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        FilterChip(
          label: const Text('All Reports'),
          selected: _selectedReportType == 'all',
          onSelected: (selected) => setState(() => _selectedReportType = 'all'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Financial'),
          selected: _selectedReportType == 'financial',
          onSelected: (selected) => setState(() => _selectedReportType = 'financial'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Outlet Performance'),
          selected: _selectedReportType == 'outlets',
          onSelected: (selected) => setState(() => _selectedReportType = 'outlets'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Tax'),
          selected: _selectedReportType == 'tax',
          onSelected: (selected) => setState(() => _selectedReportType = 'tax'),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Management'),
          selected: _selectedReportType == 'management',
          onSelected: (selected) => setState(() => _selectedReportType = 'management'),
        ),
      ],
    );
  }

  Widget _buildReportsGrid(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _reportCategories.map((category) {
          return _ReportCategorySection(
            category: category['category'],
            icon: category['icon'],
            color: category['color'],
            reports: List<Map<String, dynamic>>.from(category['reports']),
            onReportTap: (report) => _showReportPreview(context, report, category['category']),
          );
        }).toList(),
      ),
    );
  }

  void _showReportPreview(BuildContext context, Map<String, dynamic> report, String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(report['icon'], color: AppColors.primary),
            const SizedBox(width: 12),
            Text(report['name']),
          ],
        ),
        content: SizedBox(
          width: 800,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report['description'],
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Period: $_selectedPeriod', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: _buildReportContent(context, report['name']),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _printReport(report['name'] as String);
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportCsv(report['name'] as String);
            },
            icon: const Icon(Icons.table_chart, size: 18),
            label: const Text('Export CSV'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportExcel(report['name'] as String);
            },
            icon: const Icon(Icons.grid_on, size: 18),
            label: const Text('Export Excel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _exportReportPdf(report['name'] as String);
            },
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }

  // ── PDF Generation Helpers ─────────────────────────────────────────────────

  static pw.Widget _pdfRow(String label, String value, {bool bold = false, double size = 11}) {
    final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: size);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
      ),
    );
  }

  static pw.Widget _pdfDivider() => pw.Divider(thickness: 0.5, color: PdfColors.grey400);

  Future<pw.Document> _buildPdfDocument(String reportName) async {
    final numFmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('MMM d, yyyy HH:mm');
    final pdf = pw.Document();

    final dashData = ref.read(dashboardDataProvider).valueOrNull;
    final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
    final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

    // Replace Unicode chars unsupported by the default PDF font (e.g., em-dash in account names).
    String pdfSafe(String t) => t
        .replaceAll('—', '-').replaceAll('–', '-')
        .replaceAll('—', '-').replaceAll('–', '-')
        .replaceAll(''', "'").replaceAll(''', "'")
        .replaceAll('"', '"').replaceAll('"', '"');

    pw.Widget buildHeader(String title) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MAGIC BET LTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
            pw.SizedBox(height: 4),
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
            pw.SizedBox(height: 4),
            pw.Text('Period: $_selectedPeriod   |   Generated: ${dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            _pdfDivider(),
            pw.SizedBox(height: 8),
          ],
        );

    if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
      final isAcctsPdf   = ref.read(accountsProvider).accounts;
      final isEntriesPdf = ref.read(journalsProvider).entries;
      final isMonthlyPdf = _computeMonthlyLedgerFull(_filterEntries(isEntriesPdf));
      final (isStartPdf, isEndPdf) = _getPeriodDates();
      final isMonthsPdf = <int>[];
      for (var _d = DateTime(isStartPdf.year, isStartPdf.month);
           !_d.isAfter(DateTime(isEndPdf.year, isEndPdf.month));
           _d = DateTime(_d.year, _d.month + 1)) {
        isMonthsPdf.add(_d.year * 100 + _d.month);
      }
      final _isPdfCrossYear = isStartPdf.year != isEndPdf.year;

      const corCodesPdf    = {'107', '178'};
      const dirTaxCodesPdf = {'108'};
      final allExpPdf      = isAcctsPdf.where((a) => a.type == AccountType.expense).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final revAcctsPdf    = isAcctsPdf.where((a) => a.type == AccountType.revenue).toList();
      _sortRevenueAccts(revAcctsPdf);
      final corAcctsPdf    = allExpPdf.where((a) => corCodesPdf.contains(a.code)).toList();
      final taxAcctsPdf    = allExpPdf.where((a) => dirTaxCodesPdf.contains(a.code)).toList();
      final opexAcctsPdf   = allExpPdf
          .where((a) => !corCodesPdf.contains(a.code) && !dirTaxCodesPdf.contains(a.code))
          .toList();

      String fcPdf(double val, {bool br = false}) {
        if (val == 0) return '0';
        return br ? '(${numFmt.format(val)})' : numFmt.format(val);
      }

      List<String> acctRowPdf(String label, List<Account> accts, {bool br = false}) {
        final row = <String>[label];
        double ytd = 0;
        for (final m in isMonthsPdf) {
          final v = _monthSumFull(accts, isMonthlyPdf, m);
          ytd += v;
          row.add(fcPdf(v, br: br));
        }
        row.add(fcPdf(ytd, br: br));
        return row;
      }

      List<String> derivedRowPdf(String label, double Function(int) fn) {
        final row = <String>[label];
        double ytd = 0;
        for (final m in isMonthsPdf) {
          final v = fn(m);
          ytd += v;
          row.add(fcPdf(v));
        }
        row.add(fcPdf(ytd));
        return row;
      }

      final revMPdf  = {for (final m in isMonthsPdf) m: _monthSumFull(revAcctsPdf,  isMonthlyPdf, m)};
      final corMPdf  = {for (final m in isMonthsPdf) m: _monthSumFull(corAcctsPdf,  isMonthlyPdf, m)};
      final taxMPdf  = {for (final m in isMonthsPdf) m: _monthSumFull(taxAcctsPdf,  isMonthlyPdf, m)};
      final opexMPdf = {for (final m in isMonthsPdf) m: _monthSumFull(opexAcctsPdf, isMonthlyPdf, m)};

      // Build rows as pw.Widget lists so we can bold specific rows reliably.
      pw.Widget isCell(String v,
          {bool bold = false,
          bool rightAlign = false,
          PdfColor? bg}) {
        final widget = pw.Text(
          v,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 8,
          ),
          textAlign: rightAlign ? pw.TextAlign.right : pw.TextAlign.left,
        );
        if (bg != null) {
          return pw.Container(
              color: bg,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: widget);
        }
        return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: widget);
      }

      final int numMonths = isMonthsPdf.length;
      final int numCols   = numMonths + 2; // label + months + YTD

      List<pw.Widget> sectionRow(String label) {
        return [
          isCell(label, bold: true, bg: PdfColors.blueGrey50),
          ...List.generate(numCols - 1,
              (_) => isCell('', bold: true, bg: PdfColors.blueGrey50)),
        ];
      }

      List<pw.Widget> dataRowWidgets(List<String> strings,
          {bool bold = false}) {
        return strings.asMap().entries.map((e) {
          final isNum = e.key > 0;
          return isCell(e.value, bold: bold, rightAlign: isNum);
        }).toList();
      }

      final tableRows = <List<pw.Widget>>[];

      tableRows.add(sectionRow('REVENUE'));
      for (final a in revAcctsPdf) {
        tableRows.add(dataRowWidgets(acctRowPdf(a.name, [a])));
      }
      tableRows.add(dataRowWidgets(acctRowPdf('Total Revenue', revAcctsPdf), bold: true));

      tableRows.add(sectionRow('COST OF REVENUE'));
      for (final a in corAcctsPdf) {
        tableRows.add(dataRowWidgets(acctRowPdf(a.name, [a], br: true)));
      }
      tableRows.add(dataRowWidgets(
          acctRowPdf('Total Cost of Revenue', corAcctsPdf, br: true),
          bold: true));
      tableRows.add(dataRowWidgets(
          derivedRowPdf('Gross Gaming Revenue (GGR)',
              (m) => (revMPdf[m] ?? 0) - (corMPdf[m] ?? 0)),
          bold: true));

      if (taxAcctsPdf.isNotEmpty) {
        tableRows.add(sectionRow('DIRECT TAXES'));
        for (final a in taxAcctsPdf) {
          tableRows.add(dataRowWidgets(acctRowPdf(a.name, [a], br: true)));
        }
        tableRows.add(dataRowWidgets(
            derivedRowPdf('Net Gaming Revenue (NGR)',
                (m) => (revMPdf[m] ?? 0) - (corMPdf[m] ?? 0) - (taxMPdf[m] ?? 0)),
            bold: true));
      }

      tableRows.add(sectionRow('OPERATING EXPENSES'));
      for (final a in opexAcctsPdf) {
        tableRows.add(dataRowWidgets(acctRowPdf(a.name, [a], br: true)));
      }
      tableRows.add(dataRowWidgets(
          acctRowPdf('Total Operating Expenses', opexAcctsPdf, br: true),
          bold: true));
      tableRows.add(dataRowWidgets(
          derivedRowPdf('Net Profit', (m) {
            final ggr = (revMPdf[m] ?? 0) - (corMPdf[m] ?? 0);
            return ggr - (taxMPdf[m] ?? 0) - (opexMPdf[m] ?? 0);
          }),
          bold: true));

      final _isPdfMFmt = _isPdfCrossYear ? DateFormat("MMM ''yy") : DateFormat('MMM');
      final isHeadersPdf = <String>[
        'Line Item',
        ...isMonthsPdf.map((m) => _isPdfMFmt.format(DateTime(m ~/ 100, m % 100))),
        'YTD',
      ];

      // Build column-width map: label column is 3x wider than month columns.
      final Map<int, pw.TableColumnWidth> isColWidths = {
        0: const pw.FlexColumnWidth(3),
      };
      for (int i = 1; i < numCols; i++) {
        isColWidths[i] = const pw.FlexColumnWidth(1);
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (pw.Context ctx) => [
          buildHeader('INCOME STATEMENT — $_selectedPeriod'),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: isColWidths,
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                children: isHeadersPdf
                    .asMap()
                    .entries
                    .map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: pw.Text(
                            e.value,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: e.key > 0
                                ? pw.TextAlign.right
                                : pw.TextAlign.left,
                          ),
                        ))
                    .toList(),
              ),
              // Data rows
              ...tableRows.map((cells) => pw.TableRow(children: cells)),
            ],
          ),
        ],
      ));
    } else if (reportName == 'Balance Sheet') {
      final bsAccounts = ref.read(accountsProvider).accounts;
      final bsEntries = ref.read(journalsProvider).entries;
      final bsRaw = _computeLedgerBalances(_cumulativeEntries(bsEntries));

      final bsAssets = bsAccounts.where((a) => a.type == AccountType.asset).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final bsLiabilities = bsAccounts.where((a) => a.type == AccountType.liability).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final bsEquity = bsAccounts.where((a) => a.type == AccountType.equity).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
      final bsRevenue = bsAccounts.where((a) => a.type == AccountType.revenue).toList();
      final bsExpenses = bsAccounts.where((a) => a.type == AccountType.expense).toList();

      final bsTotalAssets = bsAssets.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsTotalLiabilities = bsLiabilities.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsPermEquity = bsEquity.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsCYE = bsRevenue.fold(0.0, (s, a) => s + _acctBal(a, bsRaw))
          - bsExpenses.fold(0.0, (s, a) => s + _acctBal(a, bsRaw));
      final bsTotalEquity = bsPermEquity + bsCYE;

      final bsAssetRows = bsAssets.where((a) => _acctBal(a, bsRaw) != 0).toList();
      final bsLiabRows = bsLiabilities.where((a) => _acctBal(a, bsRaw) != 0).toList();
      final bsEquityRows = bsEquity.where((a) => _acctBal(a, bsRaw) != 0).toList();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('BALANCE SHEET'),
            pw.Text('ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...bsAssetRows.map((a) => _pdfRow('  ${a.code}  ${pdfSafe(a.name)}', 'UGX ${numFmt.format(_acctBal(a, bsRaw))}'))
                .toList(),
            _pdfDivider(),
            _pdfRow('TOTAL ASSETS', 'UGX ${numFmt.format(bsTotalAssets)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...bsLiabRows.map((a) => _pdfRow('  ${a.code}  ${pdfSafe(a.name)}', 'UGX ${numFmt.format(_acctBal(a, bsRaw))}'))
                .toList(),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES', 'UGX ${numFmt.format(bsTotalLiabilities)}', bold: true),
            pw.SizedBox(height: 16),
            pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            ...bsEquityRows.map((a) => _pdfRow('  ${a.code}  ${pdfSafe(a.name)}', 'UGX ${numFmt.format(_acctBal(a, bsRaw))}'))
                .toList(),
            _pdfRow('  Current Year Earnings', 'UGX ${numFmt.format(bsCYE)}'),
            _pdfDivider(),
            _pdfRow('TOTAL LIABILITIES & EQUITY', 'UGX ${numFmt.format(bsTotalLiabilities + bsTotalEquity)}',
                bold: true, size: 13),
          ],
        ),
      ));
    } else if (reportName == 'Trial Balance') {
      final tbAccounts = ref.read(accountsProvider).accounts;
      final tbEntries = ref.read(journalsProvider).entries;
      final tbRaw = _computeLedgerBalances(_cumulativeEntries(tbEntries));

      final tbRows = <List<String>>[];
      double tbTotalDr = 0;
      double tbTotalCr = 0;
      final tbSorted = List<Account>.from(tbAccounts)..sort((a, b) => a.code.compareTo(b.code));
      for (final acct in tbSorted) {
        final net = tbRaw['acct-${acct.code}'] ?? 0.0;
        if (net == 0.0) continue;
        final typeName = acct.type.name[0].toUpperCase() + acct.type.name.substring(1);
        if (net > 0) {
          tbRows.add([acct.code, pdfSafe(acct.name), typeName, numFmt.format(net), '-']);
          tbTotalDr += net;
        } else {
          tbRows.add([acct.code, pdfSafe(acct.name), typeName, '-', numFmt.format(-net)]);
          tbTotalCr += -net;
        }
      }
      tbRows.add(['', 'TOTALS', '', numFmt.format(tbTotalDr), numFmt.format(tbTotalCr)]);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (pw.Context ctx) => [
          buildHeader('TRIAL BALANCE'),
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            data: tbRows,
          ),
        ],
      ));
    } else if (reportName == 'Cash Flow Statement') {
      final cf = _computeCashFlowFigures();
      String fmt(double v) => v == 0 ? 'UGX 0'
          : v < 0 ? '(UGX ${numFmt.format(v.abs())})'
          : 'UGX ${numFmt.format(v)}';

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('STATEMENT OF CASH FLOWS'),

            // ── OPERATING ACTIVITIES ──────────────────────────────────────
            pw.Text('OPERATING ACTIVITIES',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            _pdfRow('  Net Profit (from Income Statement)',        fmt(cf['operatingProfit']!), bold: true),
            pw.SizedBox(height: 6),
            pw.Text('  Changes in Net Working Capital',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            _pdfRow('  (Increase)/Decrease in Accounts Receivables & Prepayments',
                fmt(cf['receivablesImpact']!)),
            _pdfRow('  Increase/(Decrease) in Accounts Payables',
                fmt(cf['payablesImpact']!)),
            if (cf['depreciationAddBack']! > 0)
              _pdfRow('  Add: Depreciation & Amortization (non-cash)', fmt(cf['depreciationAddBack']!)),
            _pdfDivider(),
            _pdfRow('NET CASH FROM OPERATING ACTIVITIES', fmt(cf['netOperating']!), bold: true, size: 12),
            pw.SizedBox(height: 12),

            // ── INVESTING ACTIVITIES ──────────────────────────────────────
            pw.Text('INVESTING ACTIVITIES',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            _pdfRow('  Acquisition of Assets',          fmt(-cf['assetAcquisitions']!)),
            _pdfRow('  Sale of Assets',                    '-'),
            _pdfRow('  Acquisition of Securities (Bonds)', '-'),
            _pdfRow('  Receipt of Interest on Bonds',      '-'),
            _pdfDivider(),
            _pdfRow('NET CASH FROM INVESTING ACTIVITIES', fmt(cf['netInvesting']!), bold: true),
            pw.SizedBox(height: 12),

            // ── FINANCING ACTIVITIES ──────────────────────────────────────
            pw.Text('FINANCING ACTIVITIES',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            _pdfRow('  Acquisition of Loans', fmt(cf['loanProceeds']!)),
            _pdfRow('  Loan Repayment',       fmt(-cf['loanRepayment']!)),
            _pdfRow('  Dividends Paid',       fmt(-cf['dividendsPaid']!)),
            _pdfDivider(),
            _pdfRow('NET CASH FROM FINANCING ACTIVITIES', fmt(cf['netFinancing']!), bold: true),
            pw.SizedBox(height: 16),

            // ── SUMMARY ───────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                _pdfRow('Opening Cash Balance  (Opening Cash + Bank Balances)',
                    fmt(cf['openingCash']!)),
                _pdfRow('Net Increase/(Decrease) in Cash',
                    fmt(cf['netIncrease']!), bold: true),
                _pdfDivider(),
                pw.SizedBox(height: 4),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Flexible(
                        child: pw.Text(
                          'CLOSING CASH BALANCE  (Closing Bank & Cash accounts)',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(fmt(cf['closingCash']!),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ));
    } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
      final ggr = dashData?.totalRevenue ?? 0;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('GGR REVENUE REPORT'),
            pw.Text('GAMING REVENUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Total Stakes (Cash In)', 'UGX ${numFmt.format(dashData?.cashIn ?? 0)}'),
            _pdfRow('  Less: Customer Winnings', '(UGX ${numFmt.format(dashData?.cashOut ?? 0)})'),
            _pdfDivider(),
            _pdfRow('Gross Gaming Revenue (GGR)', 'UGX ${numFmt.format(ggr)}', bold: true),
            pw.SizedBox(height: 12),
            pw.Text('REVENUE DISTRIBUTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            _pdfRow('  Operator Fee (40%)', '(UGX ${numFmt.format(dashData?.totalExpenses ?? 0)})'),
            _pdfDivider(),
            _pdfRow('NET REVENUE AFTER OPERATOR FEE', 'UGX ${numFmt.format(ggr - (dashData?.totalExpenses ?? 0))}', bold: true, size: 13),
          ],
        ),
      ));
    } else if (reportName == 'GGR by Outlet' || reportName == 'Top Performers' || reportName == 'Outlet Revenue Summary') {
      final sortedEntries = (summary?.entries.toList() ?? [])
        ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('OUTLET PERFORMANCE REPORT'),
            pw.TableHelper.fromTextArray(
              headers: ['Outlet', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              data: sortedEntries.map((entry) {
                final outlet = outlets.where((o) => o.outletCode == entry.key).firstOrNull;
                final d = entry.value;
                return [
                  outlet?.name ?? 'Outlet ${entry.key}',
                  numFmt.format(d['totalIn'] ?? 0),
                  numFmt.format(d['totalOut'] ?? 0),
                  numFmt.format(d['totalGGR'] ?? 0),
                  '${(d['days'] ?? 0).toInt()}',
                ];
              }).toList(),
            ),
          ],
        ),
      ));
    } else if (reportName == 'AR Schedule') {
      await _buildARSchedulePdf(pdf, numFmt, buildHeader);
    } else if (reportName == 'AP Schedule') {
      await _buildAPSchedulePdf(pdf, numFmt, buildHeader);
    } else if (reportName == 'AR Ageing') {
      await _buildARAgeingPdf(pdf, numFmt, buildHeader);
    } else if (reportName == 'AP Ageing') {
      await _buildAPAgeingPdf(pdf, numFmt, buildHeader);
    } else {
      // Generic placeholder page for reports without detailed preview
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader(reportName.toUpperCase()),
            pw.Center(
              child: pw.Text(
                'Report data will be available once CSV data has been imported.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      ));
    }

    return pdf;
  }

  Future<void> _printReport(String reportName) async {
    try {
      final pdf = await _buildPdfDocument(reportName);
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportReportPdf(String reportName) async {
    try {
      final pdf = await _buildPdfDocument(reportName);
      final bytes = await pdf.save();
      final filename = '${reportName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export $reportName as PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (path != null) {
        await File(path).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF exported: $path'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportAllReports() async {
    try {
      final numFmt = NumberFormat('#,##0', 'en_US');
      final dateFmt = DateFormat('MMM d, yyyy HH:mm');
      final dashData = ref.read(dashboardDataProvider).valueOrNull;
      final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
      final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

      final pdf = pw.Document();

      pw.Widget buildHeader(String title) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MAGIC BET LTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 4),
              pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
              pw.SizedBox(height: 4),
              pw.Text('Period: $_selectedPeriod   |   Generated: ${dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              _pdfDivider(),
              pw.SizedBox(height: 8),
            ],
          );

      final totalIn = dashData?.cashIn ?? 0;
      final totalOut = dashData?.cashOut ?? 0;
      final ggr = dashData?.totalRevenue ?? 0;
      final commission = dashData?.totalExpenses ?? 0;
      final netRevenue = dashData?.netIncome ?? 0;

      // Page 1: Income Statement — monthly pivot table (rows=accounts, cols=months+YTD)
      {
        final isAccts  = ref.read(accountsProvider).accounts;
        final isEntries2 = ref.read(journalsProvider).entries;
        final isMonthly  = _computeMonthlyLedgerFull(_filterEntries(isEntries2));
        final (isStart2, isEnd2) = _getPeriodDates();
        final isMonths = <int>[];
        for (var _d = DateTime(isStart2.year, isStart2.month);
             !_d.isAfter(DateTime(isEnd2.year, isEnd2.month));
             _d = DateTime(_d.year, _d.month + 1)) {
          isMonths.add(_d.year * 100 + _d.month);
        }
        final _isAllCrossYear = isStart2.year != isEnd2.year;

        const corCodes = {'107', '178'};
        const dirTaxCodes = {'108'};
        final allExp = isAccts.where((a) => a.type == AccountType.expense).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final revAccts2 = isAccts.where((a) => a.type == AccountType.revenue).toList();
        _sortRevenueAccts(revAccts2);
        final corAccts2  = allExp.where((a) => corCodes.contains(a.code)).toList();
        final taxAccts2  = allExp.where((a) => dirTaxCodes.contains(a.code)).toList();
        final opexAccts2 = allExp.where((a) => !corCodes.contains(a.code) && !dirTaxCodes.contains(a.code)).toList();

        String fc(double val, {bool br = false}) {
          if (val == 0) return '0';
          return br ? '(${numFmt.format(val)})' : numFmt.format(val);
        }

        List<String> acctRow(String label, List<Account> accts, {bool br = false}) {
          final row = <String>[label];
          double ytd = 0;
          for (final m in isMonths) {
            final v = _monthSumFull(accts, isMonthly, m);
            ytd += v;
            row.add(fc(v, br: br));
          }
          row.add(fc(ytd, br: br));
          return row;
        }

        List<String> derivedRow(String label, double Function(int) fn) {
          final row = <String>[label];
          double ytd = 0;
          for (final m in isMonths) {
            final v = fn(m);
            ytd += v;
            row.add(fc(v));
          }
          row.add(fc(ytd));
          return row;
        }

        final revM  = {for (final m in isMonths) m: _monthSumFull(revAccts2,  isMonthly, m)};
        final corM  = {for (final m in isMonths) m: _monthSumFull(corAccts2,  isMonthly, m)};
        final taxM  = {for (final m in isMonths) m: _monthSumFull(taxAccts2,  isMonthly, m)};
        final opexM = {for (final m in isMonths) m: _monthSumFull(opexAccts2, isMonthly, m)};

        final tableData = <List<String>>[];
        for (final a in revAccts2) tableData.add(acctRow(a.name, [a]));
        tableData.add(acctRow('Total Revenue', revAccts2));
        for (final a in corAccts2) tableData.add(acctRow(a.name, [a], br: true));
        tableData.add(acctRow('Total Cost of Revenue', corAccts2, br: true));
        tableData.add(derivedRow('Gross Gaming Revenue (GGR)',
            (m) => (revM[m] ?? 0) - (corM[m] ?? 0)));
        if (taxAccts2.isNotEmpty) {
          for (final a in taxAccts2) tableData.add(acctRow(a.name, [a], br: true));
          tableData.add(derivedRow('Net Gaming Revenue (NGR)',
              (m) => (revM[m] ?? 0) - (corM[m] ?? 0) - (taxM[m] ?? 0)));
        }
        for (final a in opexAccts2) tableData.add(acctRow(a.name, [a], br: true));
        tableData.add(acctRow('Total Operating Expenses', opexAccts2, br: true));
        tableData.add(derivedRow('Net Profit', (m) {
          final ggr = (revM[m] ?? 0) - (corM[m] ?? 0);
          final ngr = ggr - (taxM[m] ?? 0);
          return ngr - (opexM[m] ?? 0);
        }));

        final _isAllMFmt = _isAllCrossYear ? DateFormat("MMM ''yy") : DateFormat('MMM');
        final isHeaders = <String>[
          'Line Item',
          ...isMonths.map((m) => _isAllMFmt.format(DateTime(m ~/ 100, m % 100))),
          'YTD',
        ];

        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader('INCOME STATEMENT — $_selectedPeriod'),
              pw.Expanded(
                child: pw.TableHelper.fromTextArray(
                  headers: isHeaders,
                  data: tableData,
                  headerStyle:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.blueGrey100),
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    for (int i = 1; i <= isMonths.length + 1; i++)
                      i: pw.Alignment.centerRight,
                  },
                ),
              ),
            ],
          ),
        ));
      }

      // Page 2: Balance Sheet (ledger-driven)
      {
        final bsAccounts2 = ref.read(accountsProvider).accounts;
        final bsEntries2 = ref.read(journalsProvider).entries;
        final bsRaw2 = _computeLedgerBalances(_cumulativeEntries(bsEntries2));

        final bsAssets2 = bsAccounts2.where((a) => a.type == AccountType.asset).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsLiabs2 = bsAccounts2.where((a) => a.type == AccountType.liability).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsEq2 = bsAccounts2.where((a) => a.type == AccountType.equity).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsRev2 = bsAccounts2.where((a) => a.type == AccountType.revenue).toList();
        final bsExp2 = bsAccounts2.where((a) => a.type == AccountType.expense).toList();

        final bsTotalA2 = bsAssets2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsTotalL2 = bsLiabs2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsPermEq2 = bsEq2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsCYE2 = bsRev2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2))
            - bsExp2.fold(0.0, (s, a) => s + _acctBal(a, bsRaw2));
        final bsTotalEq2 = bsPermEq2 + bsCYE2;

        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader('BALANCE SHEET'),
              pw.Text('ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...bsAssets2.where((a) => _acctBal(a, bsRaw2) != 0)
                  .map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw2))}')),
              _pdfDivider(),
              _pdfRow('TOTAL ASSETS', 'UGX ${numFmt.format(bsTotalA2)}', bold: true),
              pw.SizedBox(height: 16),
              pw.Text('LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...bsLiabs2.where((a) => _acctBal(a, bsRaw2) != 0)
                  .map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw2))}')),
              _pdfDivider(),
              _pdfRow('TOTAL LIABILITIES', 'UGX ${numFmt.format(bsTotalL2)}', bold: true),
              pw.SizedBox(height: 16),
              pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...bsEq2.where((a) => _acctBal(a, bsRaw2) != 0)
                  .map((a) => _pdfRow('  ${a.code}  ${a.name}', 'UGX ${numFmt.format(_acctBal(a, bsRaw2))}')),
              _pdfRow('  Current Year Earnings', 'UGX ${numFmt.format(bsCYE2)}'),
              _pdfDivider(),
              _pdfRow('TOTAL LIABILITIES & EQUITY', 'UGX ${numFmt.format(bsTotalL2 + bsTotalEq2)}',
                  bold: true, size: 13),
            ],
          ),
        ));
      }

      // Page 3: Outlet Performance
      final sortedEntries = (summary?.entries.toList() ?? [])
        ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildHeader('OUTLET PERFORMANCE REPORT'),
            if (sortedEntries.isEmpty)
              pw.Text('No outlet data yet. Import CSV data to see outlet performance.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Outlet', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                data: sortedEntries.map((entry) {
                  final outlet = outlets.where((o) => o.outletCode == entry.key).firstOrNull;
                  final d = entry.value;
                  return [
                    outlet?.name ?? 'Outlet ${entry.key}',
                    numFmt.format(d['totalIn'] ?? 0),
                    numFmt.format(d['totalOut'] ?? 0),
                    numFmt.format(d['totalGGR'] ?? 0),
                    '${(d['days'] ?? 0).toInt()}',
                  ];
                }).toList(),
              ),
          ],
        ),
      ));

      final bytes = await pdf.save();
      final filename = 'MagicBet_All_Reports_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildReportContent(BuildContext context, String reportName) {
    if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
      return _buildIncomeStatementPreview(context);
    } else if (reportName == 'Balance Sheet') {
      return _buildBalanceSheetPreview(context);
    } else if (reportName == 'Trial Balance') {
      return _buildTrialBalancePreview(context);
    } else if (reportName == 'Cash Flow Statement') {
      return _buildCashFlowPreview(context);
    } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
      return _buildGGRTaxPreview(context);
    } else if (reportName == 'GGR by Outlet' || reportName == 'Outlet Revenue Summary') {
      return _buildOutletPerformancePreview(context);
    } else if (reportName == 'Top Performers') {
      return _buildTopPerformersPreview(context);
    } else if (reportName == 'Daily Performance') {
      return _buildDailyPerformancePreview(context);
    } else if (reportName == 'Payout Ratio Analysis') {
      return _buildPayoutRatioPreview(context);
    } else if (reportName == 'AR Schedule') {
      return _buildARSchedulePreview(context);
    } else if (reportName == 'AP Schedule') {
      return _buildAPSchedulePreview(context);
    } else if (reportName == 'AR Ageing') {
      return _buildARAgeingPreview(context);
    } else if (reportName == 'AP Ageing') {
      return _buildAPAgeingPreview(context);
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Report Preview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Click Export to generate the full report',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }
  }

  Widget _buildIncomeStatementPreview(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final accountsState = ref.watch(accountsProvider);

    final entries = journalsState.entries;
    final accounts = accountsState.accounts;
    final raw = _computeLedgerBalances(_filterEntries(entries));

    // Group accounts by type — Stakes (103) first, Payouts (107) second in revenue
    final revenueAccts = accounts.where((a) => a.type == AccountType.revenue).toList();
    _sortRevenueAccts(revenueAccts);
    final expenseAccts = accounts.where((a) => a.type == AccountType.expense).toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    // Identify specific expense sub-groups by account code
    const corCodes = {'107', '178'}; // Customer Winnings/Payouts + Outlet Commission Expense
    const directTaxCodes = {'108'}; // Gaming Tax Expense

    final corAccts = expenseAccts.where((a) => corCodes.contains(a.code)).toList();
    final directTaxAccts = expenseAccts.where((a) => directTaxCodes.contains(a.code)).toList();
    final opexAccts = expenseAccts
        .where((a) => !corCodes.contains(a.code) && !directTaxCodes.contains(a.code))
        .toList();

    double _sum(List<Account> list) => list.fold(0.0, (s, a) => s + _acctBal(a, raw));

    final totalRevenue = _sum(revenueAccts);
    final totalCoR = _sum(corAccts);
    final ggr = totalRevenue - totalCoR;
    final totalDirectTax = _sum(directTaxAccts);
    final netGamingRevenue = ggr - totalDirectTax;
    final totalOpex = _sum(opexAccts);
    final netIncome = netGamingRevenue - totalOpex;

    if (raw.isEmpty) {
      return Center(
        child: Text(
          'No data yet. Import CSV data to see the income statement.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAGIC BET LTD — INCOME STATEMENT',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('For the period ended ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
          const SizedBox(height: 16),

          // Revenue
          _ReportSection(
            title: 'Revenue',
            items: revenueAccts
                .where((a) => _acctBal(a, raw) != 0)
                .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                .toList(),
            total: totalRevenue,
            isPositive: true,
            onItemTap: (item) => _showLedgerDrillDown(context, item),
          ),
          const SizedBox(height: 8),

          // Cost of Revenue — Payouts (107) + Outlet Commission Expense (178)
          _ReportSection(
            title: 'Cost of Revenue',
            items: corAccts
                .where((a) => _acctBal(a, raw) != 0)
                .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                .toList(),
            total: totalCoR,
            isPositive: false,
            onItemTap: (item) => _showLedgerDrillDown(context, item),
          ),
          const Divider(),
          _ReportTotalRow(label: 'Gross Gaming Revenue (GGR)', amount: ggr, isHighlight: true),
          const SizedBox(height: 12),

          // Direct Taxes (Gaming Tax)
          if (directTaxAccts.any((a) => _acctBal(a, raw) != 0)) ...[
            _ReportSection(
              title: 'Direct Taxes',
              items: directTaxAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalDirectTax,
              isPositive: false,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
            const Divider(),
            _ReportTotalRow(label: 'Net Gaming Revenue', amount: netGamingRevenue, isHighlight: true),
            const SizedBox(height: 12),
          ],

          // Operating Expenses
          if (opexAccts.any((a) => _acctBal(a, raw) != 0)) ...[
            _ReportSection(
              title: 'Operating Expenses',
              items: opexAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalOpex,
              isPositive: false,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
          ],

          const Divider(height: 32),
          _ReportTotalRow(
            label: 'Net Profit',
            amount: netIncome,
            isHighlight: true,
            isFinal: true,
          ),

          // ── Year-to-Date Monthly Breakdown ──────────────────────────────
          _buildMonthlyBreakdown(entries, revenueAccts, corAccts, directTaxAccts, opexAccts),
        ],
      ),
    );
  }

  /// Returns { accountKey → { month (1–12) → balance } } for posted JEs in [year].
  /// Keys normalised to 'acct-{code}' when accountCode is present on the line.
  Map<String, Map<int, double>> _computeMonthlyLedger(
      List<JournalEntry> entries, int year) {
    final result = <String, Map<int, double>>{};
    for (final entry in entries) {
      if (entry.status != JournalEntryStatus.posted) continue;
      if (entry.date.year != year) continue;
      final m = entry.date.month;
      for (final line in entry.lines) {
        final key = line.accountCode != null ? 'acct-${line.accountCode}' : line.accountId;
        (result[key] ??= {})[m] = (result[key]![m] ?? 0) + line.debit - line.credit;
      }
    }
    return result;
  }

  double _monthSum(List<Account> accts, Map<String, Map<int, double>> monthly, int m) =>
      accts.fold(0.0, (s, a) {
        final b = monthly['acct-${a.code}']?[m] ?? monthly[a.id]?[m] ?? 0.0;
        return s + (a.isDebitNormal ? b : -b);
      });

  /// Returns { accountKey → { yyyyMM → balance } } for posted JEs — no year filter.
  /// Use for cross-year custom periods.
  Map<String, Map<int, double>> _computeMonthlyLedgerFull(List<JournalEntry> entries) {
    final result = <String, Map<int, double>>{};
    for (final entry in entries) {
      if (entry.status != JournalEntryStatus.posted) continue;
      final ym = entry.date.year * 100 + entry.date.month;
      for (final line in entry.lines) {
        final key = line.accountCode != null ? 'acct-${line.accountCode}' : line.accountId;
        (result[key] ??= {})[ym] = (result[key]![ym] ?? 0) + line.debit - line.credit;
      }
    }
    return result;
  }

  double _monthSumFull(List<Account> accts, Map<String, Map<int, double>> monthly, int ym) =>
      accts.fold(0.0, (s, a) {
        final b = monthly['acct-${a.code}']?[ym] ?? monthly[a.id]?[ym] ?? 0.0;
        return s + (a.isDebitNormal ? b : -b);
      });

  Widget _buildMonthlyBreakdown(
      List<JournalEntry> entries,
      List<Account> revenueAccts,
      List<Account> corAccts,
      List<Account> directTaxAccts,
      List<Account> opexAccts) {
    // Filter entries to the selected period and build full monthly ledger (yyyyMM keys).
    final filtered = _filterEntries(entries);
    final monthly  = _computeMonthlyLedgerFull(filtered);
    // Ensure Stakes (103) → Payouts (107) ordering within monthly table.
    _sortRevenueAccts(revenueAccts);
    final fmt = NumberFormat('#,###');

    // Build the list of (year, month) pairs covering the selected period.
    final (start, end) = _getPeriodDates();
    final periodMonths = <DateTime>[];
    var d = DateTime(start.year, start.month, 1);
    while (!d.isAfter(DateTime(end.year, end.month))) {
      periodMonths.add(d);
      d = DateTime(d.year, d.month + 1, 1);
    }
    if (periodMonths.isEmpty) return const SizedBox.shrink();

    int ym(DateTime dt) => dt.year * 100 + dt.month;

    final periodLabel = periodMonths.length == 1
        ? DateFormat('MMMM yyyy').format(periodMonths.first)
        : '${DateFormat('MMM yyyy').format(periodMonths.first)} – ${DateFormat('MMM yyyy').format(periodMonths.last)}';

    // ── cell helpers ─────────────────────────────────────────────────────────
    const hdrStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    const sectionColor = AppColors.primary;

    String fmtAmt(double val) => val == 0 ? '0' : fmt.format(val);
    String fmtBracket(double val) => val == 0 ? '0' : '(${fmt.format(val)})';

    Widget amtCell(double val, {bool bold = false, bool bracket = false}) {
      final str = bracket ? fmtBracket(val) : fmtAmt(val);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(str, textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
              color: val < 0 && !bracket ? AppColors.error : null,
            )),
      );
    }

    Widget netCell(double val) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(fmtAmt(val), textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
              color: val >= 0 ? AppColors.success : AppColors.error)),
    );

    // Pre-compute monthly values using yyyyMM keys
    final revByM  = {for (final dt in periodMonths) ym(dt): _monthSumFull(revenueAccts,  monthly, ym(dt))};
    final corByM  = {for (final dt in periodMonths) ym(dt): _monthSumFull(corAccts,       monthly, ym(dt))};
    final taxByM  = {for (final dt in periodMonths) ym(dt): _monthSumFull(directTaxAccts, monthly, ym(dt))};
    final opexByM = {for (final dt in periodMonths) ym(dt): _monthSumFull(opexAccts,      monthly, ym(dt))};

    double ytdRev = 0, ytdCor = 0, ytdTax = 0, ytdOpex = 0;
    for (final dt in periodMonths) {
      ytdRev  += revByM[ym(dt)]!;
      ytdCor  += corByM[ym(dt)]!;
      ytdTax  += taxByM[ym(dt)]!;
      ytdOpex += opexByM[ym(dt)]!;
    }

    const labelW = 220.0;
    const colW   = 88.0;

    TableRow sectionHeaderRow(String title) => TableRow(
      decoration: BoxDecoration(color: sectionColor.withOpacity(0.10)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11,
                  color: sectionColor, letterSpacing: 0.5)),
        ),
        for (int _ = 0; _ < periodMonths.length + 1; _++) const SizedBox(),
      ],
    );

    TableRow dataRow(String label, Map<int, double> byM, double ytd,
        {bool bracket = false, bool bold = false}) =>
        TableRow(children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6, right: 8),
            child: Text(label, style: TextStyle(fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          for (final dt in periodMonths) amtCell(byM[ym(dt)] ?? 0, bracket: bracket, bold: bold),
          amtCell(ytd, bracket: bracket, bold: bold),
        ]);

    TableRow subtotalRow(String label, Map<int, double> byM, double ytd,
        {bool isNet = false}) =>
        TableRow(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text(label, style: hdrStyle),
            ),
            for (final dt in periodMonths)
              isNet ? netCell(byM[ym(dt)] ?? 0) : amtCell(byM[ym(dt)] ?? 0, bold: true),
            isNet ? netCell(ytd) : amtCell(ytd, bold: true),
          ],
        );

    TableRow dividerRow() => TableRow(children: [
      Divider(height: 1, color: Theme.of(context).dividerColor),
      for (int _ = 0; _ < periodMonths.length + 1; _++)
        Divider(height: 1, color: Theme.of(context).dividerColor),
    ]);

    final ggrByM  = {for (final dt in periodMonths) ym(dt): revByM[ym(dt)]! - corByM[ym(dt)]!};
    final ngrByM  = {for (final dt in periodMonths) ym(dt): ggrByM[ym(dt)]! - taxByM[ym(dt)]!};
    final netByM  = {for (final dt in periodMonths) ym(dt): ngrByM[ym(dt)]! - opexByM[ym(dt)]!};
    final ytdGgr  = ytdRev - ytdCor;
    final ytdNgr  = ytdGgr - ytdTax;
    final ytdNet  = ytdNgr - ytdOpex;

    List<TableRow> opexAccountRows() {
      final rows = <TableRow>[];
      for (final acct in opexAccts) {
        final byM = {for (final dt in periodMonths) ym(dt): _monthSumFull([acct], monthly, ym(dt))};
        final ytd = byM.values.fold(0.0, (s, v) => s + v);
        if (byM.values.any((v) => v != 0)) {
          rows.add(dataRow(acct.name, byM, ytd, bracket: true));
        }
      }
      return rows;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Row(children: [
          Icon(Icons.calendar_month, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Income Statement — Month-by-Month ($periodLabel)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: labelW + (periodMonths.length + 1) * colW,
            child: Table(
              columnWidths: {
                0: const FixedColumnWidth(labelW),
                for (int i = 1; i <= periodMonths.length + 1; i++)
                  i: const FixedColumnWidth(colW),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
              children: [
                // ── Header row ──────────────────────────────────────────────
                TableRow(
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text('', style: hdrStyle),
                    ),
                    for (final dt in periodMonths)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Text(
                          DateFormat('MMM yy').format(dt),
                          textAlign: TextAlign.right,
                          style: hdrStyle,
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text('Total', textAlign: TextAlign.right, style: hdrStyle),
                    ),
                  ],
                ),

                // ── Revenue ─────────────────────────────────────────────────
                sectionHeaderRow('Revenue'),
                ...revenueAccts
                    .where((a) => periodMonths.any((dt) => _monthSumFull([a], monthly, ym(dt)) != 0))
                    .map((acct) {
                  final byM = {for (final dt in periodMonths) ym(dt): _monthSumFull([acct], monthly, ym(dt))};
                  final ytd = byM.values.fold(0.0, (s, v) => s + v);
                  return dataRow(acct.name, byM, ytd);
                }),
                subtotalRow('Total Revenue', revByM, ytdRev),

                // ── Cost of Revenue ──────────────────────────────────────────
                sectionHeaderRow('Cost of Revenue'),
                ...corAccts
                    .where((a) => periodMonths.any((dt) => _monthSumFull([a], monthly, ym(dt)) != 0))
                    .map((acct) {
                  final byM = {for (final dt in periodMonths) ym(dt): _monthSumFull([acct], monthly, ym(dt))};
                  final ytd = byM.values.fold(0.0, (s, v) => s + v);
                  return dataRow(acct.name, byM, ytd, bracket: true);
                }),
                subtotalRow('Total Cost of Revenue', corByM, ytdCor),

                // ── GGR ──────────────────────────────────────────────────────
                subtotalRow('Gross Gaming Revenue (GGR)', ggrByM, ytdGgr, isNet: true),

                // ── Direct Taxes ─────────────────────────────────────────────
                if (directTaxAccts.isNotEmpty) ...[
                  sectionHeaderRow('Direct Taxes'),
                  ...directTaxAccts
                      .where((a) => periodMonths.any((dt) => _monthSumFull([a], monthly, ym(dt)) != 0))
                      .map((acct) {
                    final byM = {for (final dt in periodMonths) ym(dt): _monthSumFull([acct], monthly, ym(dt))};
                    final ytd = byM.values.fold(0.0, (s, v) => s + v);
                    return dataRow(acct.name, byM, ytd, bracket: true);
                  }),
                  subtotalRow('Net Gaming Revenue (NGR)', ngrByM, ytdNgr, isNet: true),
                ],

                // ── Operating Expenses ───────────────────────────────────────
                sectionHeaderRow('Operating Expenses'),
                ...opexAccountRows(),
                subtotalRow('Total Operating Expenses', opexByM, ytdOpex),

                // ── Net Profit ───────────────────────────────────────────────
                dividerRow(),
                subtotalRow('Net Profit', netByM, ytdNet, isNet: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Shows a modal ledger drill-down: all journal entry lines for [item]'s account.
  void _showLedgerDrillDown(BuildContext context, Map<String, dynamic> item) {
    final accountId = item['accountId'] as String?;
    if (accountId == null) return;
    final accountName = item['name'] as String? ?? accountId;
    final entries = ref.read(journalsProvider).entries;
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('dd MMM yyyy');

    // Collect all journal lines for this account
    final lines = <Map<String, dynamic>>[];
    for (final entry in entries) {
      if (entry.status != JournalEntryStatus.posted) continue;
      for (final line in entry.lines) {
        if (line.accountId == accountId) {
          lines.add({
            'date': entry.date,
            'entryNumber': entry.entryNumber,
            'description': entry.description,
            'reference': entry.reference,
            'debit': line.debit,
            'credit': line.credit,
          });
        }
      }
    }
    lines.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final totalDebit = lines.fold<double>(0, (s, l) => s + (l['debit'] as double));
    final totalCredit = lines.fold<double>(0, (s, l) => s + (l['credit'] as double));
    final netBalance = totalDebit - totalCredit;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ledger: $accountName',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const Divider(),
                // Summary row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _drillChip('Total Debits', fmt.format(totalDebit), Colors.red.shade700),
                      const SizedBox(width: 16),
                      _drillChip('Total Credits', fmt.format(totalCredit), Colors.green.shade700),
                      const SizedBox(width: 16),
                      _drillChip('Net Balance', fmt.format(netBalance.abs()), Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        netBalance >= 0 ? '(Dr)' : '(Cr)',
                        style: TextStyle(
                          fontSize: 12,
                          color: netBalance >= 0 ? Colors.red.shade700 : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (lines.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No posted journal entries for this account.'),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(90),
                          1: FixedColumnWidth(130),
                          2: FlexColumnWidth(),
                          3: FixedColumnWidth(110),
                          4: FixedColumnWidth(110),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.all(6), child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Entry #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Debit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                              Padding(padding: EdgeInsets.all(6), child: Text('Credit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.right)),
                            ],
                          ),
                          ...lines.map((l) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(dateFmt.format(l['date'] as DateTime), style: const TextStyle(fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(l['entryNumber'] as String, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(
                                      l['description'] as String,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(
                                      (l['debit'] as double) > 0 ? fmt.format(l['debit']) : '',
                                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (l['debit'] as double) > 0 ? Colors.red.shade700 : null),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Text(
                                      (l['credit'] as double) > 0 ? fmt.format(l['credit']) : '',
                                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (l['credit'] as double) > 0 ? Colors.green.shade700 : null),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drillChip(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey.shade600)),
          TextSpan(text: 'UGX $value', style: TextStyle(fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetPreview(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final accountsState = ref.watch(accountsProvider);

    final entries = journalsState.entries;
    final accounts = accountsState.accounts;
    final raw = _computeLedgerBalances(_cumulativeEntries(entries));

    final allAssetAccts = accounts.where((a) => a.type == AccountType.asset).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    // Split assets into three IAS-aligned groups
    final currentAssetAccts = allAssetAccts.where((a) =>
        a.subType == AccountSubType.cash ||
        a.subType == AccountSubType.bank ||
        a.subType == AccountSubType.accountsReceivable ||
        a.subType == AccountSubType.inventory ||
        a.subType == AccountSubType.otherCurrentAsset).toList();
    // Cash → Bank+BG(167) → AR → SCR(173) → other OCA
    _sortCurrentAssets(currentAssetAccts);
    final fixedAssetAccts = allAssetAccts.where((a) =>
        a.subType == AccountSubType.fixedAsset ||
        a.subType == AccountSubType.otherAsset ||
        (a.subType == null &&
         !a.name.toLowerCase().contains('intangible') &&
         !a.name.toLowerCase().contains('amortiz') &&
         !a.name.toLowerCase().contains('software') &&
         !a.name.toLowerCase().contains('patent') &&
         !a.name.toLowerCase().contains('goodwill'))).toList();
    final intangibleAssetAccts = allAssetAccts.where((a) =>
        a.subType == AccountSubType.intangibleAsset).toList();
    final assetAccts = allAssetAccts; // keep for total calculation
    final liabilityAccts = accounts.where((a) => a.type == AccountType.liability).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final equityAccts = accounts.where((a) => a.type == AccountType.equity).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final revenueAccts = accounts.where((a) => a.type == AccountType.revenue).toList();
    final expenseAccts = accounts.where((a) => a.type == AccountType.expense).toList();

    final totalCurrentAssets    = currentAssetAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalFixedAssets      = fixedAssetAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalIntangibleAssets = intangibleAssetAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalAssets = assetAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalLiabilities = liabilityAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalPermEquity = equityAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalRevenue = revenueAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final totalExpenses = expenseAccts.fold(0.0, (s, a) => s + _acctBal(a, raw));
    final currentYearEarnings = totalRevenue - totalExpenses;
    final totalEquity = totalPermEquity + currentYearEarnings;
    final balanced = (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAGIC BET LTD - BALANCE SHEET',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('As at ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
          const SizedBox(height: 16),
          if (raw.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No posted journal entries yet. Import CSV data to see balances.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
              ),
            )
          else ...[
            Text('ASSETS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ReportSection(
              title: 'Current Assets',
              items: currentAssetAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalCurrentAssets,
              isPositive: true,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
            const SizedBox(height: 8),
            _ReportSection(
              title: 'Property, Plant & Equipment (PP&E)',
              items: fixedAssetAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalFixedAssets,
              isPositive: true,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
            if (intangibleAssetAccts.any((a) => _acctBal(a, raw) != 0)) ...[
              const SizedBox(height: 8),
              _ReportSection(
                title: 'Intangible Assets (IAS 38)',
                items: intangibleAssetAccts
                    .where((a) => _acctBal(a, raw) != 0)
                    .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                    .toList(),
                total: totalIntangibleAssets,
                isPositive: true,
                onItemTap: (item) => _showLedgerDrillDown(context, item),
              ),
            ],
            _ReportTotalRow(label: 'Total Assets', amount: totalAssets, isHighlight: true),
            const Divider(height: 32),
            Text('LIABILITIES', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ReportSection(
              title: 'Current & Non-Current Liabilities',
              items: liabilityAccts
                  .where((a) => _acctBal(a, raw) != 0)
                  .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id})
                  .toList(),
              total: totalLiabilities,
              isPositive: false,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
            _ReportTotalRow(label: 'Total Liabilities', amount: totalLiabilities, isHighlight: true),
            const Divider(height: 32),
            Text('EQUITY', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _ReportSection(
              title: "Owner's Equity",
              items: [
                ...equityAccts
                    .where((a) => _acctBal(a, raw) != 0)
                    .map((a) => {'name': '${a.code}  ${a.name}', 'amount': _acctBal(a, raw), 'accountId': a.id}),
                {'name': 'Current Year Earnings', 'amount': currentYearEarnings},
              ],
              total: totalEquity,
              isPositive: true,
              onItemTap: (item) => _showLedgerDrillDown(context, item),
            ),
            const Divider(),
            _ReportTotalRow(
                label: 'Total Liabilities & Equity',
                amount: totalLiabilities + totalEquity,
                isHighlight: true,
                isFinal: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(balanced ? Icons.check_circle : Icons.warning,
                    color: balanced ? AppColors.success : AppColors.warning, size: 16),
                const SizedBox(width: 6),
                Text(
                  balanced ? 'Balance sheet is balanced ✓' : 'Warning: balance sheet does not balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: balanced ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutletPerformancePreview(BuildContext context) {
    final summaryAsync = ref.watch(outletRevenueSummaryProvider);
    final outletsAsync = ref.watch(outletsStreamProvider);

    return summaryAsync.when(
      data: (summary) => outletsAsync.when(
        data: (outlets) {
          if (summary.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No outlet data yet', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Import CSV data to see outlet performance',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            );
          }

          // Sort by GGR descending
          final sortedEntries = summary.entries.toList()
            ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Total In', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    Expanded(child: Text('Total Out', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    Expanded(child: Text('GGR', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    Expanded(child: Text('Days', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = sortedEntries[index];
                    final outlet = outlets.where((o) => o.outletCode == entry.key).firstOrNull;
                    final data = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(outlet?.name ?? 'Outlet ${entry.key}')),
                          Expanded(child: Text(_currencyFormat.format(data['totalIn']), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace'))),
                          Expanded(child: Text(_currencyFormat.format(data['totalOut']), textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace'))),
                          Expanded(child: Text(
                            _currencyFormat.format(data['totalGGR']),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: (data['totalGGR'] ?? 0) >= 0 ? AppColors.income : AppColors.expense,
                            ),
                          )),
                          Expanded(child: Text('${(data['days'] ?? 0).toInt()}', textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading outlets')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Top Performers ─────────────────────────────────────────────────────────
  Widget _buildTopPerformersPreview(BuildContext context) {
    final analyticsAsync = ref.watch(outletAnalyticsProvider);

    return analyticsAsync.when(
      data: (analytics) {
        final ranked = List<OutletLifetime>.from(analytics.lifetimeTotals)
          ..sort((a, b) => b.netRevenue.compareTo(a.netRevenue));

        if (ranked.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text('No outlet data yet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Import CSV data to see top performers',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          );
        }

        final maxNetRev = ranked.first.netRevenue.abs().clamp(1.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('MAGIC BET LTD — TOP PERFORMERS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(child: Text('GGR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Operator Fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Net Revenue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  SizedBox(width: 120, child: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ranked.length,
                itemBuilder: (context, index) {
                  final ol = ranked[index];
                  final rank = index + 1;
                  final barFraction = (ol.netRevenue / maxNetRev).clamp(0.0, 1.0);
                  final isPositive = ol.netRevenue >= 0;

                  Color rankColor;
                  IconData rankIcon;
                  if (rank == 1) { rankColor = const Color(0xFFFFD700); rankIcon = Icons.looks_one; }
                  else if (rank == 2) { rankColor = const Color(0xFFC0C0C0); rankIcon = Icons.looks_two; }
                  else if (rank == 3) { rankColor = const Color(0xFFCD7F32); rankIcon = Icons.looks_3; }
                  else { rankColor = Theme.of(context).colorScheme.outline; rankIcon = Icons.circle; }

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4))),
                      color: rank <= 3 ? rankColor.withOpacity(0.04) : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Icon(rankIcon, size: 18, color: rankColor),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ol.outletName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(ol.outletCode, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormat('#,##0').format(ol.totalGGR),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormat('#,##0').format(ol.totalOutletExpense),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormat('#,##0').format(ol.netRevenue),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPositive ? AppColors.income : AppColors.expense,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: barFraction,
                                minHeight: 10,
                                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isPositive ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading analytics')),
    );
  }

  // ── Trial Balance ──────────────────────────────────────────────────────────
  Widget _buildTrialBalancePreview(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final accountsState = ref.watch(accountsProvider);

    final entries = journalsState.entries;
    final accounts = accountsState.accounts;
    final raw = _computeLedgerBalances(_cumulativeEntries(entries));

    final sortedAccounts = List<Account>.from(accounts)
      ..sort((a, b) => a.code.compareTo(b.code));

    final rows = <Map<String, dynamic>>[];
    double totalDebits = 0;
    double totalCredits = 0;

    for (final account in sortedAccounts) {
      final netRaw = raw['acct-${account.code}'] ?? 0.0;
      if (netRaw == 0.0) continue;
      double debit = 0;
      double credit = 0;
      if (netRaw > 0) {
        debit = netRaw;
        totalDebits += netRaw;
      } else {
        credit = -netRaw;
        totalCredits += -netRaw;
      }
      rows.add({
        'accountId': 'acct-${account.code}',
        'code': account.code,
        'account': account.name,
        'type': account.type.name[0].toUpperCase() + account.type.name.substring(1),
        'debit': debit,
        'credit': credit,
      });
    }

    if (rows.isEmpty) {
      return Center(child: Text('No data yet. Import CSV data to see the trial balance.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
    }

    return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — TRIAL BALANCE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('As at ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 16),
              // Header row
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Row(
                  children: const [
                    SizedBox(width: 56, child: Padding(padding: EdgeInsets.all(8), child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    Expanded(flex: 3, child: Padding(padding: EdgeInsets.all(8), child: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    Expanded(flex: 2, child: Padding(padding: EdgeInsets.all(8), child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    Expanded(flex: 2, child: Padding(padding: EdgeInsets.all(8), child: Text('Debit (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right))),
                    Expanded(flex: 2, child: Padding(padding: EdgeInsets.all(8), child: Text('Credit (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right))),
                  ],
                ),
              ),
              // Data rows — tappable to open ledger drill-down
              ...rows.map((row) => InkWell(
                onTap: () => _showLedgerDrillDown(context, {
                  'accountId': row['accountId'],
                  'name': row['account'],
                }),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4))),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 56, child: Padding(padding: const EdgeInsets.all(8), child: Text(row['code'] as String, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))),
                      Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(8), child: Text(row['account'] as String, style: const TextStyle(fontSize: 12)))),
                      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Text(row['type'] as String, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)))),
                      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Text(
                        (row['debit'] as double) > 0 ? NumberFormat('#,##0').format(row['debit']) : '0',
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (row['debit'] as double) > 0 ? AppColors.debit : Theme.of(context).colorScheme.outline),
                        textAlign: TextAlign.right,
                      ))),
                      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Text(
                        (row['credit'] as double) > 0 ? NumberFormat('#,##0').format(row['credit']) : '0',
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: (row['credit'] as double) > 0 ? AppColors.income : Theme.of(context).colorScheme.outline),
                        textAlign: TextAlign.right,
                      ))),
                    ],
                  ),
                ),
              )),
              // Totals row
              Container(
                color: AppColors.primary.withOpacity(0.08),
                child: Row(
                  children: [
                    const SizedBox(width: 56, child: SizedBox.shrink()),
                    const Expanded(flex: 3, child: Padding(padding: EdgeInsets.all(8), child: Text('TOTALS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                    Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Text(
                      NumberFormat('#,##0').format(totalDebits),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace', color: AppColors.primary),
                      textAlign: TextAlign.right,
                    ))),
                    Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Text(
                      NumberFormat('#,##0').format(totalCredits),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace', color: AppColors.primary),
                      textAlign: TextAlign.right,
                    ))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(totalDebits == totalCredits ? Icons.check_circle : Icons.warning,
                      color: totalDebits == totalCredits ? AppColors.success : AppColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    totalDebits == totalCredits ? 'Trial balance is balanced ✓' : 'Warning: trial balance does not balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: totalDebits == totalCredits ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  // ── Cash Flow Statement ────────────────────────────────────────────────────
  Widget _buildCashFlowPreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    // Watch journals so the report rebuilds whenever entries change.
    ref.watch(journalsProvider);
    return dashboardAsync.when(
      data: (_) {
        final cf = _computeCashFlowFigures();
        final numFmt = NumberFormat('#,##0', 'en_US');

        if (cf['operatingProfit'] == 0 && cf['closingCash'] == 0) {
          return Center(
            child: Text(
              'No data yet. Post journal entries to see the cash flow statement.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic),
            ),
          );
        }

        Widget cfRow(String label, double amount,
            {bool bold = false, bool isFinal = false, bool isSection = false, bool indent = false}) {
          final isNeg = amount < 0;
          final display = amount == 0
              ? 'UGX 0'
              : isNeg
                  ? '(UGX ${numFmt.format(amount.abs())})'
                  : 'UGX ${numFmt.format(amount)}';
          if (isSection) {
            return Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            );
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: isFinal ? 5 : 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    indent ? '    $label' : label,
                    style: TextStyle(
                      fontWeight: bold || isFinal ? FontWeight.bold : FontWeight.normal,
                      fontSize: isFinal ? 13.5 : 13,
                    ),
                  ),
                ),
                Text(
                  display,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: bold || isFinal ? FontWeight.bold : FontWeight.normal,
                    fontSize: isFinal ? 13.5 : 13,
                    color: isNeg
                        ? AppColors.expense
                        : (isFinal || bold ? AppColors.primary : null),
                  ),
                ),
              ],
            ),
          );
        }

        Widget sectionDivider() => const Divider(height: 10, thickness: 0.5);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — STATEMENT OF CASH FLOWS',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'Period: $_selectedPeriod  |  Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // ── OPERATING ACTIVITIES ─────────────────────────────────────
              cfRow('OPERATING ACTIVITIES', 0, isSection: true),
              sectionDivider(),
              cfRow('Net Profit (from Income Statement)', cf['operatingProfit']!, bold: true),
              const SizedBox(height: 6),
              Text('  Changes in Net Working Capital',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                      fontStyle: FontStyle.italic)),
              cfRow('(Increase)/Decrease in Accounts Receivables & Prepayments',
                  cf['receivablesImpact']!, indent: true),
              cfRow('Increase/(Decrease) in Accounts Payables',
                  cf['payablesImpact']!, indent: true),
              if (cf['depreciationAddBack']! > 0)
                cfRow('Add: Depreciation & Amortization (non-cash)',
                    cf['depreciationAddBack']!, indent: true),
              sectionDivider(),
              cfRow('NET CASH FROM OPERATING ACTIVITIES', cf['netOperating']!, isFinal: true),

              // ── INVESTING ACTIVITIES ─────────────────────────────────────
              cfRow('INVESTING ACTIVITIES', 0, isSection: true),
              sectionDivider(),
              cfRow('Acquisition of Assets', -cf['assetAcquisitions']!, indent: true),
              cfRow('Sale of Assets', 0, indent: true),
              cfRow('Acquisition of Securities (Bonds)', 0, indent: true),
              cfRow('Receipt of Interest on Bonds', 0, indent: true),
              sectionDivider(),
              cfRow('NET CASH FROM INVESTING ACTIVITIES', cf['netInvesting']!, isFinal: true),

              // ── FINANCING ACTIVITIES ─────────────────────────────────────
              cfRow('FINANCING ACTIVITIES', 0, isSection: true),
              sectionDivider(),
              cfRow('Acquisition of Loans', cf['loanProceeds']!, indent: true),
              cfRow('Loan Repayment', -cf['loanRepayment']!, indent: true),
              cfRow('Dividends Paid', -cf['dividendsPaid']!, indent: true),
              sectionDivider(),
              cfRow('NET CASH FROM FINANCING ACTIVITIES', cf['netFinancing']!, isFinal: true),

              // ── SUMMARY ──────────────────────────────────────────────────
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    cfRow('Opening Cash Balance  (Cash + Bank accounts)',
                        cf['openingCash']!),
                    cfRow('Net Increase/(Decrease) in Cash', cf['netIncrease']!, bold: true),
                    sectionDivider(),
                    cfRow('CLOSING CASH BALANCE  (Closing Bank & Cash total)',
                        cf['closingCash']!, isFinal: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── GGR Tax Report ─────────────────────────────────────────────────────────
  Widget _buildGGRTaxPreview(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    return dashboardAsync.when(
      data: (data) {
        final ggr = data.totalRevenue;

        if (ggr == 0) {
          return Center(child: Text('No data yet. Import CSV data to see the revenue report.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAGIC BET LTD — GGR REVENUE REPORT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Gross Gaming Revenue and Distribution Summary',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              const SizedBox(height: 16),
              _ReportSection(title: 'Gross Gaming Revenue', items: [
                {'name': 'Total Stakes (Cash In)', 'amount': data.cashIn},
                {'name': 'Less: Customer Winnings (Payouts)', 'amount': -data.cashOut},
              ], total: ggr, isPositive: true),
              const Divider(height: 24),
              _ReportTotalRow(label: 'Gross Gaming Revenue (GGR)', amount: ggr, isHighlight: true),
              const SizedBox(height: 8),
              _ReportTotalRow(label: 'Less: Operator Fee (40% of GGR)', amount: -data.totalExpenses, isHighlight: false),
              const Divider(height: 16),
              _ReportTotalRow(label: 'NET REVENUE AFTER OPERATOR FEE', amount: ggr - data.totalExpenses, isHighlight: true, isFinal: true),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Daily Performance ──────────────────────────────────────────────────────
  Widget _buildDailyPerformancePreview(BuildContext context) {
    final analyticsAsync = ref.watch(outletAnalyticsProvider);
    return analyticsAsync.when(
      data: (analytics) {
        if (analytics.allWeeks.isEmpty) {
          return Center(child: Text('No data yet. Import CSV data to see daily performance.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }
        // Aggregate weekly data as proxy for period performance
        final weeks = analytics.allWeeks;
        final grouped = <String, Map<String, double>>{};
        for (final w in weeks) {
          final key = '${w.year}-W${w.weekNumber.toString().padLeft(2, '0')}';
          grouped[key] = (grouped[key] ?? {});
          grouped[key]!['ggr'] = (grouped[key]!['ggr'] ?? 0) + w.adjustedGGR;
          grouped[key]!['commission'] = (grouped[key]!['commission'] ?? 0) + w.outletExpense;
          grouped[key]!['net'] = (grouped[key]!['net'] ?? 0) + w.netRevenue;
        }
        final sortedWeeks = grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(child: Text('Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(child: Text('GGR (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Operator Fee (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Net Revenue (UGX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sortedWeeks.length,
                itemBuilder: (context, i) {
                  final e = sortedWeeks[i];
                  final net = e.value['net'] ?? 0.0;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)))),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text(NumberFormat('#,##0').format(e.value['ggr'] ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text(NumberFormat('#,##0').format(e.value['commission'] ?? 0), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.warning))),
                        Expanded(child: Text(NumberFormat('#,##0').format(net), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: net >= 0 ? AppColors.income : AppColors.error))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── Payout Ratio Analysis ──────────────────────────────────────────────────
  Widget _buildPayoutRatioPreview(BuildContext context) {
    final summaryAsync = ref.watch(outletRevenueSummaryProvider);
    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) {
          return Center(child: Text('No data yet. Import CSV data to see payout ratios.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)));
        }
        final sorted = summary.entries.toList()
          ..sort((a, b) {
            final ratioA = (a.value['totalIn'] ?? 0) > 0 ? (a.value['totalOut'] ?? 0) / (a.value['totalIn'] ?? 1) : 0.0;
            final ratioB = (b.value['totalIn'] ?? 0) > 0 ? (b.value['totalOut'] ?? 0) / (b.value['totalIn'] ?? 1) : 0.0;
            return ratioB.compareTo(ratioA);
          });
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Outlet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(child: Text('Total In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Total Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('Payout %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final e = sorted[i];
                  final totalIn = e.value['totalIn'] ?? 0.0;
                  final totalOut = e.value['totalOut'] ?? 0.0;
                  final ratio = totalIn > 0 ? totalOut / totalIn * 100 : 0.0;
                  final ratioColor = ratio > 90 ? AppColors.error : ratio > 80 ? AppColors.warning : AppColors.success;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)))),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(e.key, style: const TextStyle(fontSize: 12))),
                        Expanded(child: Text(NumberFormat('#,##0').format(totalIn), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text(NumberFormat('#,##0').format(totalOut), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                        Expanded(child: Text('${ratio.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ratioColor))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  // ── CSV Export ─────────────────────────────────────────────────────────────
  Future<void> _exportReportCsv(String reportName) async {
    try {
      final numFmt = NumberFormat('#,##0', 'en_US');
      final dashData = ref.read(dashboardDataProvider).valueOrNull;
      final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
      final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

      List<List<dynamic>> csvRows = [];

      if (reportName == 'Trial Balance') {
        final tbAccounts2 = ref.read(accountsProvider).accounts;
        final tbEntries2 = ref.read(journalsProvider).entries;
        final tbRaw2 = _computeLedgerBalances(_cumulativeEntries(tbEntries2));
        final tbSorted2 = List<Account>.from(tbAccounts2)..sort((a, b) => a.code.compareTo(b.code));
        double tbDr2 = 0;
        double tbCr2 = 0;
        final tbDataRows = <List<dynamic>>[];
        for (final acct in tbSorted2) {
          final net = tbRaw2['acct-${acct.code}'] ?? 0.0;
          if (net == 0.0) continue;
          final typeName = acct.type.name[0].toUpperCase() + acct.type.name.substring(1);
          if (net > 0) {
            tbDataRows.add([acct.code, acct.name, typeName, numFmt.format(net), '']);
            tbDr2 += net;
          } else {
            tbDataRows.add([acct.code, acct.name, typeName, '', numFmt.format(-net)]);
            tbCr2 += -net;
          }
        }
        csvRows = [
          ['MAGIC BET LTD — TRIAL BALANCE'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Account Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)'],
          ...tbDataRows,
          [],
          ['', 'TOTALS', '', numFmt.format(tbDr2), numFmt.format(tbCr2)],
        ];
      } else if (reportName == 'Cash Flow Statement') {
        final cf = _computeCashFlowFigures();
        String fmtCsv(double v) => v == 0 ? '0'
            : v < 0 ? '(${numFmt.format(v.abs())})'
            : numFmt.format(v);
        csvRows = [
          ['MAGIC BET LTD — STATEMENT OF CASH FLOWS'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Section', 'Description', 'Amount (UGX)'],
          ['Operating', 'Net Profit (from Income Statement)',                            fmtCsv(cf['operatingProfit']!)],
          ['Operating', '(Increase)/Decrease in Accounts Receivables & Prepayments',   fmtCsv(cf['receivablesImpact']!)],
          ['Operating', 'Increase/(Decrease) in Accounts Payables',                    fmtCsv(cf['payablesImpact']!)],
          ['Operating', 'Add: Depreciation & Amortization (non-cash)',                  fmtCsv(cf['depreciationAddBack']!)],
          ['Operating', 'NET CASH FROM OPERATING ACTIVITIES',                          fmtCsv(cf['netOperating']!)],
          [],
          ['Investing', 'Acquisition of Assets',                                       fmtCsv(-cf['assetAcquisitions']!)],
          ['Investing', 'Sale of Assets',                                               '-'],
          ['Investing', 'Acquisition of Securities (Bonds)',                           '-'],
          ['Investing', 'Receipt of Interest on Bonds',                                '-'],
          ['Investing', 'NET CASH FROM INVESTING ACTIVITIES',                          fmtCsv(cf['netInvesting']!)],
          [],
          ['Financing', 'Acquisition of Loans',                                        fmtCsv(cf['loanProceeds']!)],
          ['Financing', 'Loan Repayment',                                              fmtCsv(-cf['loanRepayment']!)],
          ['Financing', 'Dividends Paid',                                              fmtCsv(-cf['dividendsPaid']!)],
          ['Financing', 'NET CASH FROM FINANCING ACTIVITIES',                          fmtCsv(cf['netFinancing']!)],
          [],
          ['Summary', 'Opening Cash Balance (Cash + Bank accounts)',                   fmtCsv(cf['openingCash']!)],
          ['Summary', 'Net Increase/(Decrease) in Cash',                              fmtCsv(cf['netIncrease']!)],
          ['Summary', 'CLOSING CASH BALANCE (Closing Bank & Cash total)',              fmtCsv(cf['closingCash']!)],
        ];
      } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
        final ggr = dashData?.totalRevenue ?? 0;
        csvRows = [
          ['MAGIC BET LTD — GGR REVENUE REPORT'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Item', 'Amount (UGX)'],
          ['Total Stakes (Cash In)', numFmt.format(dashData?.cashIn ?? 0)],
          ['Less: Customer Winnings', '(${numFmt.format(dashData?.cashOut ?? 0)})'],
          ['Gross Gaming Revenue (GGR)', numFmt.format(ggr)],
          ['Outlet Commission (40% of GGR)', '(${numFmt.format(dashData?.totalExpenses ?? 0)})'],
          ['Net Revenue After Commission', numFmt.format(ggr - (dashData?.totalExpenses ?? 0))],
        ];
      } else if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
        final isAccts3   = ref.read(accountsProvider).accounts;
        final isEntries3 = ref.read(journalsProvider).entries;
        final isMonthly3 = _computeMonthlyLedgerFull(_filterEntries(isEntries3));
        final (isStart3, isEnd3) = _getPeriodDates();
        final isMonths3  = <int>[];
        for (var _d = DateTime(isStart3.year, isStart3.month);
             !_d.isAfter(DateTime(isEnd3.year, isEnd3.month));
             _d = DateTime(_d.year, _d.month + 1)) {
          isMonths3.add(_d.year * 100 + _d.month);
        }
        final _isCsvCrossYear = isStart3.year != isEnd3.year;

        const cCorCodes3  = {'107', '178'};
        const cTaxCodes3  = {'108'};
        final allExp3     = isAccts3.where((a) => a.type == AccountType.expense).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final revAccts3   = isAccts3.where((a) => a.type == AccountType.revenue).toList();
        _sortRevenueAccts(revAccts3);
        final corAccts3   = allExp3.where((a) => cCorCodes3.contains(a.code)).toList();
        final taxAccts3   = allExp3.where((a) => cTaxCodes3.contains(a.code)).toList();
        final opexAccts3  = allExp3
            .where((a) => !cCorCodes3.contains(a.code) && !cTaxCodes3.contains(a.code))
            .toList();

        String fmtIs3(double v) => v == 0 ? '0' : numFmt.format(v);

        List<dynamic> pivotRow3(String label, List<Account> accts) {
          final row = <dynamic>[label];
          double ytd = 0;
          for (final m in isMonths3) {
            final v = _monthSumFull(accts, isMonthly3, m);
            ytd += v;
            row.add(fmtIs3(v));
          }
          row.add(fmtIs3(ytd));
          return row;
        }

        List<dynamic> derivedRow3(String label, double Function(int) fn) {
          final row = <dynamic>[label];
          double ytd = 0;
          for (final m in isMonths3) {
            final v = fn(m);
            ytd += v;
            row.add(fmtIs3(v));
          }
          row.add(fmtIs3(ytd));
          return row;
        }

        final revM3  = {for (final m in isMonths3) m: _monthSumFull(revAccts3,  isMonthly3, m)};
        final corM3  = {for (final m in isMonths3) m: _monthSumFull(corAccts3,  isMonthly3, m)};
        final taxM3  = {for (final m in isMonths3) m: _monthSumFull(taxAccts3,  isMonthly3, m)};
        final opexM3 = {for (final m in isMonths3) m: _monthSumFull(opexAccts3, isMonthly3, m)};

        final _isCsvMFmt = _isCsvCrossYear ? DateFormat("MMM ''yy") : DateFormat('MMM');
        final hdrs3 = <dynamic>[
          'Line Item',
          ...isMonths3.map((m) => _isCsvMFmt.format(DateTime(m ~/ 100, m % 100))),
          'YTD',
        ];

        csvRows = [
          ['MAGIC BET LTD — INCOME STATEMENT ($_selectedPeriod)'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          hdrs3,
          ['--- REVENUE ---'],
          ...revAccts3.map((a) => pivotRow3(a.name, [a])),
          pivotRow3('Total Revenue', revAccts3),
          [],
          ['--- COST OF REVENUE ---'],
          ...corAccts3.map((a) => pivotRow3(a.name, [a])),
          pivotRow3('Total Cost of Revenue', corAccts3),
          [],
          derivedRow3('Gross Gaming Revenue (GGR)',
              (m) => (revM3[m] ?? 0) - (corM3[m] ?? 0)),
          if (taxAccts3.isNotEmpty) ...[
            [],
            ['--- DIRECT TAXES ---'],
            ...taxAccts3.map((a) => pivotRow3(a.name, [a])),
            derivedRow3('Net Gaming Revenue (NGR)',
                (m) => (revM3[m] ?? 0) - (corM3[m] ?? 0) - (taxM3[m] ?? 0)),
          ],
          [],
          ['--- OPERATING EXPENSES ---'],
          ...opexAccts3.map((a) => pivotRow3(a.name, [a])),
          pivotRow3('Total Operating Expenses', opexAccts3),
          [],
          derivedRow3('Net Profit', (m) {
            final ggr = (revM3[m] ?? 0) - (corM3[m] ?? 0);
            return ggr - (taxM3[m] ?? 0) - (opexM3[m] ?? 0);
          }),
        ];
      } else if (reportName == 'Balance Sheet') {
        final bsAccts2   = ref.read(accountsProvider).accounts;
        final bsEntries2 = ref.read(journalsProvider).entries;
        final bsRaw2     = _computeLedgerBalances(_cumulativeEntries(bsEntries2));

        double bsBal2(Account a) {
          final b = bsRaw2['acct-${a.code}'] ?? bsRaw2[a.id] ?? 0.0;
          return a.isDebitNormal ? b : -b;
        }

        final bsAssets2 = bsAccts2.where((a) => a.type == AccountType.asset).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsLiabs2 = bsAccts2.where((a) => a.type == AccountType.liability).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsEq2 = bsAccts2.where((a) => a.type == AccountType.equity).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsRevAccts2 = bsAccts2.where((a) => a.type == AccountType.revenue).toList();
        final bsExpAccts2 = bsAccts2.where((a) => a.type == AccountType.expense).toList();

        final totalAssets2  = bsAssets2.fold(0.0, (s, a) => s + bsBal2(a));
        final totalLiabs2   = bsLiabs2.fold(0.0, (s, a) => s + bsBal2(a));
        final permEquity2   = bsEq2.fold(0.0, (s, a) => s + bsBal2(a));
        final netEarnings2  = bsRevAccts2.fold(0.0, (s, a) => s + bsBal2(a))
            - bsExpAccts2.fold(0.0, (s, a) => s + bsBal2(a));
        final totalEquity2  = permEquity2 + netEarnings2;

        csvRows = [
          ['MAGIC BET LTD — BALANCE SHEET'],
          ['As at ${DateFormat('MMMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Section', 'Code', 'Account Name', 'Amount (UGX)'],
          ['ASSETS', '', '', ''],
          ...bsAssets2.where((a) => bsBal2(a) != 0).map((a) =>
              ['', a.code, a.name, numFmt.format(bsBal2(a))]),
          ['', '', 'TOTAL ASSETS', numFmt.format(totalAssets2)],
          [],
          ['LIABILITIES', '', '', ''],
          ...bsLiabs2.where((a) => bsBal2(a) != 0).map((a) =>
              ['', a.code, a.name, numFmt.format(bsBal2(a))]),
          ['', '', 'TOTAL LIABILITIES', numFmt.format(totalLiabs2)],
          [],
          ['EQUITY', '', '', ''],
          ...bsEq2.where((a) => bsBal2(a) != 0).map((a) =>
              ['', a.code, a.name, numFmt.format(bsBal2(a))]),
          ['', '', 'Current Year Earnings', numFmt.format(netEarnings2)],
          ['', '', 'TOTAL EQUITY', numFmt.format(totalEquity2)],
          [],
          ['', '', 'TOTAL LIABILITIES + EQUITY', numFmt.format(totalLiabs2 + totalEquity2)],
        ];
      } else if (reportName == 'AR Schedule') {
        csvRows = _buildARScheduleCsvRows(numFmt);
      } else if (reportName == 'AP Schedule') {
        csvRows = _buildAPScheduleCsvRows(numFmt);
      } else if (reportName == 'AR Ageing') {
        csvRows = _buildARAgeingCsvRows(numFmt);
      } else if (reportName == 'AP Ageing') {
        csvRows = _buildAPAgeingCsvRows(numFmt);
      } else {
        // Outlet performance for all other reports
        final sortedEntries = (summary?.entries.toList() ?? [])
          ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));
        csvRows = [
          ['MAGIC BET LTD — ${reportName.toUpperCase()}'],
          ['Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}'],
          [],
          ['Outlet Code', 'Outlet Name', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days'],
          ...sortedEntries.map((e) {
            final outlet = outlets.where((o) => o.outletCode == e.key).firstOrNull;
            return [
              e.key,
              outlet?.name ?? 'Outlet ${e.key}',
              numFmt.format(e.value['totalIn'] ?? 0),
              numFmt.format(e.value['totalOut'] ?? 0),
              numFmt.format(e.value['totalGGR'] ?? 0),
              '${(e.value['days'] ?? 0).toInt()}',
            ];
          }),
        ];
      }

      final csv = const ListToCsvConverter().convert(csvRows);
      final filename = '${reportName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export $reportName as CSV',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (path != null) {
        await File(path).writeAsString(csv);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSV exported: $path'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Excel Export ───────────────────────────────────────────────────────────
  Future<void> _exportReportExcel(String reportName) async {
    try {
      final numFmt = NumberFormat('#,##0', 'en_US');
      final dashData = ref.read(dashboardDataProvider).valueOrNull;
      final summary = ref.read(outletRevenueSummaryProvider).valueOrNull;
      final outlets = ref.read(outletsStreamProvider).valueOrNull ?? [];

      final excel = xl.Excel.createExcel();
      final sheetName = reportName.length > 31 ? reportName.substring(0, 31) : reportName;
      final sheet = excel[sheetName];
      // Remove default Sheet1 if it exists and is different
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      void addHeader(List<String> headers) {
        final row = headers.map((h) => xl.TextCellValue(h)).toList();
        sheet.appendRow(row);
        // Bold the header row
        for (int c = 0; c < headers.length; c++) {
          final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sheet.maxRows - 1));
          cell.cellStyle = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'), fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'));
        }
      }

      void addTitle(String title) {
        sheet.appendRow([xl.TextCellValue(title)]);
        sheet.appendRow([xl.TextCellValue('Generated: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}')]);
        sheet.appendRow([xl.TextCellValue('')]);
      }

      if (reportName == 'Trial Balance') {
        final tbAcc3 = ref.read(accountsProvider).accounts;
        final tbEnt3 = ref.read(journalsProvider).entries;
        final tbRaw3 = _computeLedgerBalances(_cumulativeEntries(tbEnt3));
        final tbSorted3 = List<Account>.from(tbAcc3)..sort((a, b) => a.code.compareTo(b.code));
        double tbDr3 = 0;
        double tbCr3 = 0;
        addTitle('MAGIC BET LTD — TRIAL BALANCE');
        addHeader(['Account Code', 'Account Name', 'Type', 'Debit (UGX)', 'Credit (UGX)']);
        for (final acct in tbSorted3) {
          final net = tbRaw3['acct-${acct.code}'] ?? 0.0;
          if (net == 0.0) continue;
          final typeName = acct.type.name[0].toUpperCase() + acct.type.name.substring(1);
          if (net > 0) {
            sheet.appendRow([xl.TextCellValue(acct.code), xl.TextCellValue(acct.name), xl.TextCellValue(typeName),
              xl.DoubleCellValue(net), xl.DoubleCellValue(0)]);
            tbDr3 += net;
          } else {
            sheet.appendRow([xl.TextCellValue(acct.code), xl.TextCellValue(acct.name), xl.TextCellValue(typeName),
              xl.DoubleCellValue(0), xl.DoubleCellValue(-net)]);
            tbCr3 += -net;
          }
        }
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue('TOTALS'), xl.TextCellValue(''),
          xl.DoubleCellValue(tbDr3), xl.DoubleCellValue(tbCr3)]);
        final tbTotRow3 = sheet.maxRows - 1;
        for (int c = 0; c < 5; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: tbTotRow3))
              .cellStyle = xl.CellStyle(bold: true);
        }
      } else if (reportName == 'Cash Flow Statement') {
        final cf = _computeCashFlowFigures();
        addTitle('MAGIC BET LTD — STATEMENT OF CASH FLOWS');
        addHeader(['Section', 'Description', 'Amount (UGX)']);
        final cfSectionStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#E8EEF7'),
        );
        void xRow(String section, String desc, double val, {bool bold = false}) {
          sheet.appendRow([xl.TextCellValue(section), xl.TextCellValue(desc), xl.DoubleCellValue(val)]);
          if (bold) {
            final r = sheet.maxRows - 1;
            for (int c = 0; c < 3; c++) {
              sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                  .cellStyle = xl.CellStyle(bold: true);
            }
          }
        }
        void xSection(String label) {
          sheet.appendRow([xl.TextCellValue(label), xl.TextCellValue(''), xl.TextCellValue('')]);
          final r = sheet.maxRows - 1;
          for (int c = 0; c < 3; c++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                .cellStyle = cfSectionStyle;
          }
        }
        xSection('OPERATING ACTIVITIES');
        xRow('Operating', 'Net Profit (from Income Statement)',                         cf['operatingProfit']!);
        xRow('Operating', '(Increase)/Decrease in Accounts Receivables & Prepayments', cf['receivablesImpact']!);
        xRow('Operating', 'Increase/(Decrease) in Accounts Payables',                  cf['payablesImpact']!);
        xRow('Operating', 'Add: Depreciation & Amortization (non-cash)',                cf['depreciationAddBack']!);
        xRow('Operating', 'NET CASH FROM OPERATING ACTIVITIES',                        cf['netOperating']!, bold: true);
        xSection('INVESTING ACTIVITIES');
        xRow('Investing', 'Acquisition of Assets',                                     -cf['assetAcquisitions']!);
        xRow('Investing', 'NET CASH FROM INVESTING ACTIVITIES',                        cf['netInvesting']!, bold: true);
        xSection('FINANCING ACTIVITIES');
        xRow('Financing', 'Acquisition of Loans',                                      cf['loanProceeds']!);
        xRow('Financing', 'Loan Repayment',                                            -cf['loanRepayment']!);
        xRow('Financing', 'Dividends Paid',                                            -cf['dividendsPaid']!);
        xRow('Financing', 'NET CASH FROM FINANCING ACTIVITIES',                        cf['netFinancing']!, bold: true);
        xSection('SUMMARY');
        xRow('Summary',  'Opening Cash Balance (Cash + Bank accounts)',                cf['openingCash']!);
        xRow('Summary',  'Net Increase/(Decrease) in Cash',                           cf['netIncrease']!, bold: true);
        xRow('Summary',  'CLOSING CASH BALANCE (Closing Bank & Cash total)',           cf['closingCash']!, bold: true);
      } else if (reportName == 'GGR Tax Report' || reportName == 'Tax Summary') {
        final ggr = dashData?.totalRevenue ?? 0;
        addTitle('MAGIC BET LTD — GGR REVENUE REPORT');
        addHeader(['Item', 'Amount (UGX)']);
        sheet.appendRow([xl.TextCellValue('Total Stakes (Cash In)'), xl.DoubleCellValue(dashData?.cashIn ?? 0)]);
        sheet.appendRow([xl.TextCellValue('Less: Customer Winnings'), xl.DoubleCellValue(-(dashData?.cashOut ?? 0))]);
        sheet.appendRow([xl.TextCellValue('Gross Gaming Revenue (GGR)'), xl.DoubleCellValue(ggr)]);
        sheet.appendRow([xl.TextCellValue('Outlet Commission (40%)'), xl.DoubleCellValue(-(dashData?.totalExpenses ?? 0))]);
        sheet.appendRow([xl.TextCellValue('Net Revenue After Commission'), xl.DoubleCellValue(ggr - (dashData?.totalExpenses ?? 0))]);
      } else if (reportName == 'Income Statement' || reportName == 'GGR by Month') {
        final isAccts4   = ref.read(accountsProvider).accounts;
        final isEntries4 = ref.read(journalsProvider).entries;
        final isMonthly4 = _computeMonthlyLedgerFull(_filterEntries(isEntries4));
        final (isStart4, isEnd4) = _getPeriodDates();
        final isMonths4  = <int>[];
        for (var _d = DateTime(isStart4.year, isStart4.month);
             !_d.isAfter(DateTime(isEnd4.year, isEnd4.month));
             _d = DateTime(_d.year, _d.month + 1)) {
          isMonths4.add(_d.year * 100 + _d.month);
        }
        final _isXlCrossYear = isStart4.year != isEnd4.year;

        const cCorCodes4  = {'107', '178'};
        const cTaxCodes4  = {'108'};
        final allExp4     = isAccts4.where((a) => a.type == AccountType.expense).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final revAccts4   = isAccts4.where((a) => a.type == AccountType.revenue).toList();
        _sortRevenueAccts(revAccts4);
        final corAccts4   = allExp4.where((a) => cCorCodes4.contains(a.code)).toList();
        final taxAccts4   = allExp4.where((a) => cTaxCodes4.contains(a.code)).toList();
        final opexAccts4  = allExp4
            .where((a) => !cCorCodes4.contains(a.code) && !cTaxCodes4.contains(a.code))
            .toList();

        final revM4  = {for (final m in isMonths4) m: _monthSumFull(revAccts4,  isMonthly4, m)};
        final corM4  = {for (final m in isMonths4) m: _monthSumFull(corAccts4,  isMonthly4, m)};
        final taxM4  = {for (final m in isMonths4) m: _monthSumFull(taxAccts4,  isMonthly4, m)};
        final opexM4 = {for (final m in isMonths4) m: _monthSumFull(opexAccts4, isMonthly4, m)};

        final _isXlMFmt = _isXlCrossYear ? DateFormat("MMM ''yy") : DateFormat('MMM');
        addTitle('MAGIC BET LTD — INCOME STATEMENT ($_selectedPeriod)');
        addHeader([
          'Line Item',
          ...isMonths4.map((m) => _isXlMFmt.format(DateTime(m ~/ 100, m % 100))),
          'YTD',
        ]);

        final isColCount4 = isMonths4.length + 2;
        final isSectionStyle4 = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#E8EEF7'),
        );

        void xlSection4(String label) {
          sheet.appendRow([xl.TextCellValue(label)]);
          final r = sheet.maxRows - 1;
          for (int c = 0; c < isColCount4; c++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                .cellStyle = isSectionStyle4;
          }
        }

        void xlPivotRow4(String label, List<Account> accts, {bool bold = false}) {
          final row = <xl.CellValue>[xl.TextCellValue(label)];
          double ytd = 0;
          for (final m in isMonths4) {
            final v = _monthSumFull(accts, isMonthly4, m);
            ytd += v;
            row.add(v != 0 ? xl.DoubleCellValue(v) : xl.TextCellValue('-'));
          }
          row.add(ytd != 0 ? xl.DoubleCellValue(ytd) : xl.TextCellValue('-'));
          sheet.appendRow(row);
          if (bold) {
            final r = sheet.maxRows - 1;
            for (int c = 0; c < isColCount4; c++) {
              sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                  .cellStyle = xl.CellStyle(bold: true);
            }
          }
        }

        void xlDerivedRow4(String label, double Function(int) fn) {
          final row = <xl.CellValue>[xl.TextCellValue(label)];
          double ytd = 0;
          for (final m in isMonths4) {
            final v = fn(m);
            ytd += v;
            row.add(v != 0 ? xl.DoubleCellValue(v) : xl.TextCellValue('-'));
          }
          row.add(ytd != 0 ? xl.DoubleCellValue(ytd) : xl.TextCellValue('-'));
          sheet.appendRow(row);
          final r = sheet.maxRows - 1;
          for (int c = 0; c < isColCount4; c++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                .cellStyle = xl.CellStyle(bold: true);
          }
        }

        xlSection4('REVENUE');
        for (final a in revAccts4) xlPivotRow4(a.name, [a]);
        xlPivotRow4('Total Revenue', revAccts4, bold: true);
        sheet.appendRow([xl.TextCellValue('')]);

        xlSection4('COST OF REVENUE');
        for (final a in corAccts4) xlPivotRow4(a.name, [a]);
        xlPivotRow4('Total Cost of Revenue', corAccts4, bold: true);
        sheet.appendRow([xl.TextCellValue('')]);

        xlDerivedRow4('Gross Gaming Revenue (GGR)',
            (m) => (revM4[m] ?? 0) - (corM4[m] ?? 0));

        if (taxAccts4.isNotEmpty) {
          sheet.appendRow([xl.TextCellValue('')]);
          xlSection4('DIRECT TAXES');
          for (final a in taxAccts4) xlPivotRow4(a.name, [a]);
          xlDerivedRow4('Net Gaming Revenue (NGR)',
              (m) => (revM4[m] ?? 0) - (corM4[m] ?? 0) - (taxM4[m] ?? 0));
        }

        sheet.appendRow([xl.TextCellValue('')]);
        xlSection4('OPERATING EXPENSES');
        for (final a in opexAccts4) xlPivotRow4(a.name, [a]);
        xlPivotRow4('Total Operating Expenses', opexAccts4, bold: true);
        sheet.appendRow([xl.TextCellValue('')]);

        xlDerivedRow4('Net Profit', (m) {
          final ggr = (revM4[m] ?? 0) - (corM4[m] ?? 0);
          return ggr - (taxM4[m] ?? 0) - (opexM4[m] ?? 0);
        });
      } else if (reportName == 'Balance Sheet') {
        final bsAccts3   = ref.read(accountsProvider).accounts;
        final bsEntries3 = ref.read(journalsProvider).entries;
        final bsRaw3     = _computeLedgerBalances(_cumulativeEntries(bsEntries3));

        double bsBal3(Account a) {
          final b = bsRaw3['acct-${a.code}'] ?? bsRaw3[a.id] ?? 0.0;
          return a.isDebitNormal ? b : -b;
        }

        final bsAssets3  = bsAccts3.where((a) => a.type == AccountType.asset).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsLiabs3   = bsAccts3.where((a) => a.type == AccountType.liability).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsEq3      = bsAccts3.where((a) => a.type == AccountType.equity).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        final bsRevAccts3 = bsAccts3.where((a) => a.type == AccountType.revenue).toList();
        final bsExpAccts3 = bsAccts3.where((a) => a.type == AccountType.expense).toList();

        final totalAssets3  = bsAssets3.fold(0.0, (s, a) => s + bsBal3(a));
        final totalLiabs3   = bsLiabs3.fold(0.0, (s, a) => s + bsBal3(a));
        final permEquity3   = bsEq3.fold(0.0, (s, a) => s + bsBal3(a));
        final netEarnings3  = bsRevAccts3.fold(0.0, (s, a) => s + bsBal3(a))
            - bsExpAccts3.fold(0.0, (s, a) => s + bsBal3(a));
        final totalEquity3  = permEquity3 + netEarnings3;

        addTitle('MAGIC BET LTD — BALANCE SHEET');
        sheet.appendRow([xl.TextCellValue('As at ${DateFormat('MMMM d, yyyy').format(DateTime.now())}')]);
        sheet.appendRow([xl.TextCellValue('')]);
        addHeader(['Section', 'Code', 'Account Name', 'Amount (UGX)']);

        final sectionStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#E8EEF7'),
        );
        final subtotalStyle = xl.CellStyle(bold: true);

        void bsSection(String title, List<Account> accounts, double total, String totalLabel) {
          final hRow = sheet.maxRows;
          sheet.appendRow([xl.TextCellValue(title), xl.TextCellValue(''), xl.TextCellValue(''), xl.TextCellValue('')]);
          for (int c = 0; c < 4; c++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: hRow)).cellStyle = sectionStyle;
          }
          for (final a in accounts.where((a) => bsBal3(a) != 0)) {
            sheet.appendRow([
              xl.TextCellValue(''),
              xl.TextCellValue(a.code),
              xl.TextCellValue(a.name),
              xl.DoubleCellValue(bsBal3(a)),
            ]);
          }
          final tRow = sheet.maxRows;
          sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue(''), xl.TextCellValue(totalLabel), xl.DoubleCellValue(total)]);
          for (int c = 0; c < 4; c++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: tRow)).cellStyle = subtotalStyle;
          }
          sheet.appendRow([xl.TextCellValue('')]);
        }

        bsSection('ASSETS', bsAssets3, totalAssets3, 'TOTAL ASSETS');
        bsSection('LIABILITIES', bsLiabs3, totalLiabs3, 'TOTAL LIABILITIES');

        // Equity section
        final eHRow = sheet.maxRows;
        sheet.appendRow([xl.TextCellValue('EQUITY'), xl.TextCellValue(''), xl.TextCellValue(''), xl.TextCellValue('')]);
        for (int c = 0; c < 4; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: eHRow)).cellStyle = sectionStyle;
        }
        for (final a in bsEq3.where((a) => bsBal3(a) != 0)) {
          sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue(a.code), xl.TextCellValue(a.name), xl.DoubleCellValue(bsBal3(a))]);
        }
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue(''), xl.TextCellValue('Current Year Earnings'), xl.DoubleCellValue(netEarnings3)]);
        final eTRow = sheet.maxRows;
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue(''), xl.TextCellValue('TOTAL EQUITY'), xl.DoubleCellValue(totalEquity3)]);
        for (int c = 0; c < 4; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: eTRow)).cellStyle = subtotalStyle;
        }
        sheet.appendRow([xl.TextCellValue('')]);
        final grandRow = sheet.maxRows;
        sheet.appendRow([xl.TextCellValue(''), xl.TextCellValue(''), xl.TextCellValue('TOTAL LIABILITIES + EQUITY'), xl.DoubleCellValue(totalLiabs3 + totalEquity3)]);
        for (int c = 0; c < 4; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: grandRow)).cellStyle = subtotalStyle;
        }
      } else {
        // Outlet performance
        final sortedEntries = (summary?.entries.toList() ?? [])
          ..sort((a, b) => (b.value['totalGGR'] ?? 0).compareTo(a.value['totalGGR'] ?? 0));
        addTitle('MAGIC BET LTD — ${reportName.toUpperCase()}');
        addHeader(['Outlet Code', 'Outlet Name', 'Total In (UGX)', 'Total Out (UGX)', 'GGR (UGX)', 'Days']);
        for (final e in sortedEntries) {
          final outlet = outlets.where((o) => o.outletCode == e.key).firstOrNull;
          sheet.appendRow([
            xl.TextCellValue(e.key),
            xl.TextCellValue(outlet?.name ?? 'Outlet ${e.key}'),
            xl.DoubleCellValue((e.value['totalIn'] ?? 0).toDouble()),
            xl.DoubleCellValue((e.value['totalOut'] ?? 0).toDouble()),
            xl.DoubleCellValue((e.value['totalGGR'] ?? 0).toDouble()),
            xl.IntCellValue((e.value['days'] ?? 0).toInt()),
          ]);
        }
      }

      // Auto-size first two columns
      sheet.setColumnWidth(0, 16);
      sheet.setColumnWidth(1, 36);
      sheet.setColumnWidth(2, 28);
      sheet.setColumnWidth(3, 20);
      sheet.setColumnWidth(4, 20);

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final filename = '${reportName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export $reportName as Excel',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (path != null) {
        await File(path).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel exported: $path'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;

  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              change,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCategorySection extends StatelessWidget {
  final String category;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> reports;
  final Function(Map<String, dynamic>) onReportTap;

  const _ReportCategorySection({
    required this.category,
    required this.icon,
    required this.color,
    required this.reports,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              category,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: reports.map((report) {
            return SizedBox(
              width: 280,
              child: Card(
                child: InkWell(
                  onTap: () => onReportTap(report),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(report['icon'], color: color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report['name'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report['description'],
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final double total;
  final bool isPositive;
  /// Optional — if supplied, each line becomes tappable for ledger drill-down.
  final void Function(Map<String, dynamic> item)? onItemTap;

  const _ReportSection({
    required this.title,
    required this.items,
    required this.total,
    required this.isPositive,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final canDrill = onItemTap != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline)),
            if (canDrill) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Tap any line to view journal entries',
                child: Icon(Icons.receipt_long_outlined, size: 13, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final rowContent = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('  ${item['name']}'),
                    if (canDrill)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.open_in_new, size: 11, color: Colors.blueGrey),
                      ),
                  ],
                ),
                Text(
                  'UGX ${NumberFormat('#,###').format(item['amount'])}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          );
          if (!canDrill) return rowContent;
          return InkWell(
            onTap: () => onItemTap!(item),
            borderRadius: BorderRadius.circular(4),
            hoverColor: Colors.blueGrey.withOpacity(0.06),
            child: rowContent,
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('  Total $title', style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              'UGX ${NumberFormat('#,###').format(total)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportTotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isHighlight;
  final bool isFinal;

  const _ReportTotalRow({
    required this.label,
    required this.amount,
    this.isHighlight = false,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isFinal ? FontWeight.bold : FontWeight.w600,
              fontSize: isFinal ? 16 : 14,
            ),
          ),
          Text(
            'UGX ${NumberFormat('#,###').format(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: isFinal ? 16 : 14,
              color: isHighlight ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
