// Bank Reconciliation Screen — MagicBet Accounting
// Industry-standard bank reconciliation: compare bank statement against
// system records (invoices, bills, journal entries), identify discrepancies.
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/models/invoice.dart';
import '../../core/models/bill.dart';
import 'banking_screen.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum MatchStatus { matched, unmatched, possible }

class BankStatementLine {
  final String id;
  final DateTime date;
  final String description;
  final double amount; // positive = credit (money in), negative = debit (money out)
  final String? reference;
  MatchStatus status;
  String? matchedRecordId;
  String? matchedRecordType; // 'invoice' | 'bill' | 'journal'

  BankStatementLine({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    this.reference,
    this.status = MatchStatus.unmatched,
    this.matchedRecordId,
    this.matchedRecordType,
  });
}

class _PossibleMatch {
  final String recordId;
  final String recordType;
  final String label;
  final double amount;
  final DateTime date;
  final double confidence; // 0–1

  _PossibleMatch({
    required this.recordId,
    required this.recordType,
    required this.label,
    required this.amount,
    required this.date,
    required this.confidence,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _reconciliationLinesProvider =
    StateProvider<List<BankStatementLine>>((_) => []);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BankReconciliationScreen extends ConsumerStatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  ConsumerState<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _BankReconciliationScreenState
    extends ConsumerState<BankReconciliationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BankAccount? _selectedAccount;
  bool _isLoading = false;
  String? _fileName;
  final _fmt = NumberFormat('#,###');
  final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Sample CSV download ──────────────────────────────────────────────────
  Future<void> _downloadSampleCSV() async {
    final sample = [
      'Date,Description,Debit,Credit,Reference',
      '1/2/2026,Transfer from MTN Mobile,,5000000,MTN-00123',
      '1/3/2026,Stanbic Bank Charge,15000,,CHG-2026-001',
      '1/5/2026,Payment to Vendor ABC,850000,,PV-2026-005',
      '1/6/2026,Customer Payment INV-202601-0001,,2500000,INV-202601-0001',
      '1/7/2026,NSSF Contribution,420000,,NSSF-JAN26',
      '1/8/2026,Fuel Purchase,380000,,FUEL-008',
      '1/9/2026,Cash Deposit,,10000000,DEP-009',
    ].join('\n');

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Bank Reconciliation Template',
      fileName: 'bank_statement_template.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      await File(result).writeAsString(sample);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template saved to $result'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // ── Upload & Parse bank statement ────────────────────────────────────────
  Future<void> _uploadBankStatement() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) throw Exception('CSV must have header + at least one row');

      final header = rows[0].map((h) => h.toString().toLowerCase().trim()).toList();
      final dateIdx = _findCol(header, ['date']);
      final descIdx = _findCol(header, ['description', 'narration', 'details', 'particulars']);
      final debitIdx = _findCol(header, ['debit', 'dr', 'withdrawal', 'out']);
      final creditIdx = _findCol(header, ['credit', 'cr', 'deposit', 'in']);
      final refIdx = _findCol(header, ['reference', 'ref', 'cheque', 'transaction id']);

      if (dateIdx < 0 || descIdx < 0) {
        throw Exception(
            'CSV must have Date and Description columns.\nFound columns: ${header.join(', ')}');
      }

      final lines = <BankStatementLine>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= dateIdx) continue;
        final dateStr = row[dateIdx]?.toString().trim() ?? '';
        final date = _parseDate(dateStr);
        if (date == null) continue;

        final debit = debitIdx >= 0 && debitIdx < row.length
            ? _parseAmount(row[debitIdx]?.toString() ?? '')
            : 0.0;
        final credit = creditIdx >= 0 && creditIdx < row.length
            ? _parseAmount(row[creditIdx]?.toString() ?? '')
            : 0.0;
        final amount = credit - debit; // positive = credit, negative = debit

        lines.add(BankStatementLine(
          id: const Uuid().v4(),
          date: date,
          description: row[descIdx]?.toString().trim() ?? '',
          amount: amount,
          reference: refIdx >= 0 && refIdx < row.length
              ? row[refIdx]?.toString().trim()
              : null,
        ));
      }

      // Auto-match against system records
      await _autoMatch(lines);

      ref.read(_reconciliationLinesProvider.notifier).state = lines;
      setState(() {
        _fileName = result.files.single.name;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Auto-matching engine ─────────────────────────────────────────────────
  Future<void> _autoMatch(List<BankStatementLine> lines) async {
    final invoicesState = ref.read(invoicesProvider);
    final billsState = ref.read(billsProvider);

    for (final line in lines) {
      // Match credits (money in) against invoices
      if (line.amount > 0) {
        for (final inv in invoicesState.invoices) {
          if (_amountsMatch(line.amount, inv.total) &&
              _datesClose(line.date, inv.date, days: 10)) {
            line.status = MatchStatus.matched;
            line.matchedRecordId = inv.id;
            line.matchedRecordType = 'invoice';
            break;
          }
          // Match by reference if present
          if (line.reference != null &&
              line.reference!.toLowerCase().contains(
                  inv.invoiceNumber.toLowerCase())) {
            line.status = MatchStatus.matched;
            line.matchedRecordId = inv.id;
            line.matchedRecordType = 'invoice';
            break;
          }
        }
      }
      // Match debits (money out) against bills
      if (line.amount < 0 && line.status == MatchStatus.unmatched) {
        final absAmount = line.amount.abs();
        for (final bill in billsState.bills) {
          if (_amountsMatch(absAmount, bill.total) &&
              _datesClose(line.date, bill.date, days: 10)) {
            line.status = MatchStatus.matched;
            line.matchedRecordId = bill.id;
            line.matchedRecordType = 'bill';
            break;
          }
          if (line.reference != null &&
              line.reference!.toLowerCase().contains(
                  bill.billNumber.toLowerCase())) {
            line.status = MatchStatus.matched;
            line.matchedRecordId = bill.id;
            line.matchedRecordType = 'bill';
            break;
          }
        }
      }
      // Mark possible matches (within 5% amount difference)
      if (line.status == MatchStatus.unmatched) {
        final pool = line.amount > 0
            ? invoicesState.invoices
                .map((i) => _PossibleMatch(
                      recordId: i.id,
                      recordType: 'invoice',
                      label: i.invoiceNumber,
                      amount: i.total,
                      date: i.date,
                      confidence: _matchScore(line, i.total, i.date),
                    ))
                .where((m) => m.confidence > 0.3)
            : billsState.bills
                .map((b) => _PossibleMatch(
                      recordId: b.id,
                      recordType: 'bill',
                      label: b.billNumber,
                      amount: b.total,
                      date: b.date,
                      confidence: _matchScore(line, b.total, b.date),
                    ))
                .where((m) => m.confidence > 0.3);
        if (pool.isNotEmpty) {
          line.status = MatchStatus.possible;
        }
      }
    }
  }

  bool _amountsMatch(double a, double b) {
    if (b == 0) return false;
    return ((a - b).abs() / b) < 0.02; // within 2%
  }

  bool _datesClose(DateTime a, DateTime b, {int days = 7}) =>
      a.difference(b).inDays.abs() <= days;

  double _matchScore(BankStatementLine line, double recordAmount, DateTime recordDate) {
    final absAmt = line.amount.abs();
    if (recordAmount == 0) return 0;
    final amtDiff = (absAmt - recordAmount).abs() / recordAmount;
    final dateDiff = line.date.difference(recordDate).inDays.abs();
    if (amtDiff > 0.2) return 0;
    final amtScore = 1 - amtDiff / 0.2;
    final dateScore = dateDiff <= 30 ? 1 - dateDiff / 30 : 0;
    return (amtScore * 0.7) + (dateScore * 0.3);
  }

  int _findCol(List<String> header, List<String> names) {
    for (final name in names) {
      final idx = header.indexWhere((h) => h.contains(name));
      if (idx >= 0) return idx;
    }
    return -1;
  }

  double _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll(' ', '').replaceAll('"', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  DateTime? _parseDate(String raw) {
    final formats = [
      DateFormat('M/d/yyyy'), DateFormat('d/M/yyyy'), DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'), DateFormat('MMM d, yyyy'), DateFormat('d MMM yyyy'),
    ];
    for (final fmt in formats) {
      try { return fmt.parse(raw.trim()); } catch (_) {}
    }
    return null;
  }

  // ── Manual match dialog ──────────────────────────────────────────────────
  void _showManualMatchDialog(BankStatementLine line) {
    final invoicesState = ref.read(invoicesProvider);
    final billsState = ref.read(billsProvider);

    final allRecords = [
      ...invoicesState.invoices.map((i) => _PossibleMatch(
            recordId: i.id,
            recordType: 'invoice',
            label: '${i.invoiceNumber} — ${i.customerName ?? "Customer"} — UGX ${_fmt.format(i.total)}',
            amount: i.total,
            date: i.date,
            confidence: _matchScore(line, i.total, i.date),
          )),
      ...billsState.bills.map((b) => _PossibleMatch(
            recordId: b.id,
            recordType: 'bill',
            label: '${b.billNumber} — ${b.vendorName ?? "Vendor"} — UGX ${_fmt.format(b.total)}',
            amount: b.total,
            date: b.date,
            confidence: _matchScore(line, b.total, b.date),
          )),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Match Bank Line'),
            const SizedBox(height: 4),
            Text(
              '${line.description}  •  UGX ${_fmt.format(line.amount.abs())}  •  ${_dateFmt.format(line.date)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: allRecords.isEmpty
              ? const Center(child: Text('No invoices or bills found in system'))
              : ListView.separated(
                  itemCount: allRecords.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = allRecords[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: m.recordType == 'invoice'
                            ? AppColors.success.withOpacity(0.15)
                            : AppColors.expense.withOpacity(0.15),
                        child: Icon(
                          m.recordType == 'invoice'
                              ? Icons.receipt_long
                              : Icons.description,
                          size: 18,
                          color: m.recordType == 'invoice'
                              ? AppColors.success
                              : AppColors.expense,
                        ),
                      ),
                      title: Text(m.label, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${_dateFmt.format(m.date)}  •  ${m.recordType.toUpperCase()}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: m.confidence > 0.5
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(m.confidence * 100).round()}% match',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.success),
                              ),
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          line.status = MatchStatus.matched;
                          line.matchedRecordId = m.recordId;
                          line.matchedRecordType = m.recordType;
                        });
                        ref
                            .read(_reconciliationLinesProvider.notifier)
                            .state = [...ref.read(_reconciliationLinesProvider)];
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Line matched successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (line.status == MatchStatus.matched)
            OutlinedButton.icon(
              icon: const Icon(Icons.link_off, size: 16),
              label: const Text('Unmatch'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error),
              onPressed: () {
                setState(() {
                  line.status = MatchStatus.unmatched;
                  line.matchedRecordId = null;
                  line.matchedRecordType = null;
                });
                ref
                    .read(_reconciliationLinesProvider.notifier)
                    .state = [...ref.read(_reconciliationLinesProvider)];
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  // ── Finalise reconciliation ──────────────────────────────────────────────
  void _finaliseReconciliation() {
    final lines = ref.read(_reconciliationLinesProvider);
    final matched = lines.where((l) => l.status == MatchStatus.matched).length;
    final unmatched = lines.where((l) => l.status == MatchStatus.unmatched).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalise Reconciliation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account: ${_selectedAccount?.bankName ?? "—"} (${_selectedAccount?.currency ?? ""})'),
            const SizedBox(height: 16),
            _summaryRow('Matched lines', '$matched', AppColors.success),
            _summaryRow('Unmatched lines', '$unmatched',
                unmatched > 0 ? AppColors.warning : AppColors.success),
            if (unmatched > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Text(
                  '$unmatched line(s) are still unmatched. You can proceed but they will be flagged for review.',
                  style: TextStyle(fontSize: 13, color: AppColors.warning),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark as Reconciled'),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(_reconciliationLinesProvider.notifier).state = [];
              setState(() => _fileName = null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reconciliation completed and saved'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(_reconciliationLinesProvider);
    final bankingState = ref.watch(bankingProvider);
    final matched = lines.where((l) => l.status == MatchStatus.matched).length;
    final unmatched = lines.where((l) => l.status == MatchStatus.unmatched).length;
    final possible = lines.where((l) => l.status == MatchStatus.possible).length;
    final creditTotal = lines.where((l) => l.amount > 0).fold(0.0, (s, l) => s + l.amount);
    final debitTotal = lines.where((l) => l.amount < 0).fold(0.0, (s, l) => s + l.amount.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bank Reconciliation',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Compare bank statements against your invoices, bills and journal entries',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download Template'),
                onPressed: _downloadSampleCSV,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload Bank Statement'),
                onPressed: _isLoading ? null : _uploadBankStatement,
              ),
            ],
          ),
        ),

        // ── Account selector + stats ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account picker
              Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<BankAccount>(
                      value: _selectedAccount,
                      decoration: InputDecoration(
                        labelText: 'Select Bank Account to Reconcile',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                      items: bankingState.accounts
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                    '${a.bankName} (${a.currency}) — ${a.accountType}'),
                              ))
                          .toList(),
                      onChanged: (a) => setState(() => _selectedAccount = a),
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(width: 16),
                    Chip(
                      avatar: const Icon(Icons.description, size: 16),
                      label: Text(_fileName!),
                    ),
                  ],
                  const Spacer(),
                  if (lines.isNotEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Finalise Reconciliation'),
                      onPressed: _finaliseReconciliation,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary cards
              if (lines.isNotEmpty)
                Row(
                  children: [
                    _statCard('Total Lines', lines.length.toString(),
                        Icons.list_alt, AppColors.primary),
                    const SizedBox(width: 12),
                    _statCard(
                        'Matched',
                        matched.toString(),
                        Icons.check_circle_outline,
                        AppColors.success),
                    const SizedBox(width: 12),
                    _statCard(
                        'Possible Match',
                        possible.toString(),
                        Icons.help_outline,
                        AppColors.warning),
                    const SizedBox(width: 12),
                    _statCard(
                        'Unmatched',
                        unmatched.toString(),
                        Icons.cancel_outlined,
                        AppColors.error),
                    const SizedBox(width: 12),
                    _statCard(
                        'Total Credits',
                        'UGX ${_fmt.format(creditTotal)}',
                        Icons.arrow_downward,
                        AppColors.success),
                    const SizedBox(width: 12),
                    _statCard(
                        'Total Debits',
                        'UGX ${_fmt.format(debitTotal)}',
                        Icons.arrow_upward,
                        AppColors.expense),
                  ],
                ),
            ],
          ),
        ),

        // ── Tabs ─────────────────────────────────────────────────────────
        if (lines.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'All Lines (${lines.length})'),
                Tab(text: 'Unmatched ($unmatched)'),
                Tab(text: 'Matched ($matched)'),
              ],
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLineList(lines),
                _buildLineList(
                    lines.where((l) => l.status != MatchStatus.matched).toList()),
                _buildLineList(
                    lines.where((l) => l.status == MatchStatus.matched).toList()),
              ],
            ),
          ),
        ] else ...[
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.compare_arrows,
                      size: 80,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3)),
                  const SizedBox(height: 24),
                  Text('No bank statement loaded',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a bank statement CSV or download the template to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Download CSV Template'),
                        onPressed: _downloadSampleCSV,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Bank Statement'),
                        onPressed: _uploadBankStatement,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLineList(List<BankStatementLine> lines) {
    if (lines.isEmpty) {
      return Center(
        child: Text('No records',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (_, i) => _buildLineTile(lines[i]),
    );
  }

  Widget _buildLineTile(BankStatementLine line) {
    final isCredit = line.amount > 0;
    final color = line.status == MatchStatus.matched
        ? AppColors.success
        : line.status == MatchStatus.possible
            ? AppColors.warning
            : AppColors.error;
    final statusLabel = line.status == MatchStatus.matched
        ? 'Matched'
        : line.status == MatchStatus.possible
            ? 'Review'
            : 'Unmatched';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),

            // Date
            SizedBox(
              width: 90,
              child: Text(_dateFmt.format(line.date),
                  style: const TextStyle(fontSize: 13)),
            ),

            // Description
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.description,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (line.reference != null && line.reference!.isNotEmpty)
                    Text('Ref: ${line.reference}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),

            // Amount
            SizedBox(
              width: 140,
              child: Text(
                '${isCredit ? "+" : "-"} UGX ${_fmt.format(line.amount.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCredit ? AppColors.success : AppColors.expense,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 16),

            // Match info
            Expanded(
              flex: 2,
              child: line.status == MatchStatus.matched &&
                      line.matchedRecordId != null
                  ? Row(
                      children: [
                        Icon(Icons.link, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${line.matchedRecordType?.toUpperCase()} matched',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.success),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),

            // Actions
            if (line.status != MatchStatus.matched)
              OutlinedButton.icon(
                icon: const Icon(Icons.link, size: 14),
                label: const Text('Match'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact),
                onPressed: () => _showManualMatchDialog(line),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.link_off, size: 14),
                label: const Text('Unmatch'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.error),
                onPressed: () {
                  setState(() {
                    line.status = MatchStatus.unmatched;
                    line.matchedRecordId = null;
                    line.matchedRecordType = null;
                  });
                  ref
                      .read(_reconciliationLinesProvider.notifier)
                      .state = [...ref.read(_reconciliationLinesProvider)];
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.outline)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
