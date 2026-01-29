import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Trial Balance'),
            Tab(text: 'Income Statement'),
            Tab(text: 'Balance Sheet'),
            Tab(text: 'Aging Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TrialBalanceTab(),
          _IncomeStatementTab(),
          _BalanceSheetTab(),
          _AgingReportsTab(),
        ],
      ),
    );
  }
}

class _TrialBalanceTab extends ConsumerStatefulWidget {
  const _TrialBalanceTab();

  @override
  ConsumerState<_TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends ConsumerState<_TrialBalanceTab> {
  DateTime _asOfDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    ref.read(reportsProvider.notifier).generateTrialBalance(asOfDate: _asOfDate);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final theme = Theme.of(context);
    final report = state.trialBalance;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _asOfDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _asOfDate = date);
                      _loadReport();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('As of: ${DateFormat('MMM dd, yyyy').format(_asOfDate)}'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _loadReport, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : report == null
                  ? const Center(child: Text('No data'))
                  : _buildTrialBalanceContent(context, report),
        ),
      ],
    );
  }

  Widget _buildTrialBalanceContent(BuildContext context, TrialBalanceReport report) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: report.isBalanced ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  report.isBalanced ? Icons.check_circle : Icons.warning,
                  color: report.isBalanced ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  report.isBalanced ? 'Trial Balance is Balanced' : 'Trial Balance is NOT Balanced',
                  style: TextStyle(color: report.isBalanced ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: report.rows.isEmpty
              ? const Center(child: Text('No accounts found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
                        children: [
                          _TableHeader('Code'),
                          _TableHeader('Account'),
                          _TableHeader('Debit', align: TextAlign.right),
                          _TableHeader('Credit', align: TextAlign.right),
                        ],
                      ),
                      ...report.rows.map((row) => TableRow(
                        children: [
                          _TableCell(row.accountCode),
                          _TableCell(row.accountName),
                          _TableCell(_formatCurrency(row.debitBalance), align: TextAlign.right),
                          _TableCell(_formatCurrency(row.creditBalance), align: TextAlign.right),
                        ],
                      )),
                      TableRow(
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant),
                        children: [
                          _TableCell(''),
                          _TableCell('TOTALS', isBold: true),
                          _TableCell(_formatCurrency(report.totalDebits), align: TextAlign.right, isBold: true),
                          _TableCell(_formatCurrency(report.totalCredits), align: TextAlign.right, isBold: true),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '-';
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

class _IncomeStatementTab extends ConsumerStatefulWidget {
  const _IncomeStatementTab();

  @override
  ConsumerState<_IncomeStatementTab> createState() => _IncomeStatementTabState();
}

class _IncomeStatementTabState extends ConsumerState<_IncomeStatementTab> {
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    ref.read(reportsProvider.notifier).generateIncomeStatement(startDate: _startDate, endDate: _endDate);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final report = state.incomeStatement;
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                    );
                    if (range != null) {
                      setState(() {
                        _startDate = range.start;
                        _endDate = range.end;
                      });
                      _loadReport();
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text('${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _loadReport, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : report == null
                  ? const Center(child: Text('No data'))
                  : _buildIncomeStatementContent(context, report),
        ),
      ],
    );
  }

  Widget _buildIncomeStatementContent(BuildContext context, IncomeStatementReport report) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Net Income', style: theme.textTheme.titleMedium),
                  Text(
                    _formatCurrency(report.netIncome),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: report.netIncome >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  Text(
                    'Profit Margin: ${report.grossProfitMargin.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Revenue', style: theme.textTheme.titleMedium?.copyWith(color: Colors.green)),
          const SizedBox(height: 8),
          ...report.revenueSections.map((s) => _AccountRow(s.accountCode, s.accountName, s.amount)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Revenue', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(_formatCurrency(report.totalRevenue), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
          const Divider(),
          Text('Expenses', style: theme.textTheme.titleMedium?.copyWith(color: Colors.red)),
          const SizedBox(height: 8),
          ...report.expenseSections.map((s) => _AccountRow(s.accountCode, s.accountName, s.amount)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Expenses', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(_formatCurrency(report.totalExpenses), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

class _BalanceSheetTab extends ConsumerStatefulWidget {
  const _BalanceSheetTab();

  @override
  ConsumerState<_BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends ConsumerState<_BalanceSheetTab> {
  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    ref.read(reportsProvider.notifier).generateBalanceSheet();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final report = state.balanceSheet;
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(onPressed: _loadReport, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : report == null
                  ? const Center(child: Text('No data'))
                  : _buildBalanceSheetContent(context, report),
        ),
      ],
    );
  }

  Widget _buildBalanceSheetContent(BuildContext context, BalanceSheetReport report) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: report.isBalanced ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(report.isBalanced ? Icons.check_circle : Icons.warning, color: report.isBalanced ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    report.isBalanced ? 'Balance Sheet is Balanced' : 'Balance Sheet is NOT Balanced',
                    style: TextStyle(color: report.isBalanced ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Assets', style: theme.textTheme.titleMedium?.copyWith(color: Colors.blue)),
          const SizedBox(height: 8),
          ...report.assets.map((s) => _AccountRow(s.accountCode, s.accountName, s.balance)),
          _TotalRow('Total Assets', report.totalAssets, Colors.blue),
          const Divider(height: 32),
          Text('Liabilities', style: theme.textTheme.titleMedium?.copyWith(color: Colors.orange)),
          const SizedBox(height: 8),
          ...report.liabilities.map((s) => _AccountRow(s.accountCode, s.accountName, s.balance)),
          _TotalRow('Total Liabilities', report.totalLiabilities, Colors.orange),
          const Divider(height: 32),
          Text('Equity', style: theme.textTheme.titleMedium?.copyWith(color: Colors.purple)),
          const SizedBox(height: 8),
          ...report.equity.map((s) => _AccountRow(s.accountCode, s.accountName, s.balance)),
          _TotalRow('Total Equity', report.totalEquity, Colors.purple),
          const Divider(height: 32),
          _TotalRow('Total Liabilities & Equity', report.totalLiabilities + report.totalEquity, Colors.black),
        ],
      ),
    );
  }
}

class _AgingReportsTab extends ConsumerStatefulWidget {
  const _AgingReportsTab();

  @override
  ConsumerState<_AgingReportsTab> createState() => _AgingReportsTabState();
}

class _AgingReportsTabState extends ConsumerState<_AgingReportsTab> {
  bool _showAR = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    ref.read(reportsProvider.notifier).generateARAgingReport();
    ref.read(reportsProvider.notifier).generateAPAgingReport();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('AR (Receivable)')),
                    ButtonSegment(value: false, label: Text('AP (Payable)')),
                  ],
                  selected: {_showAR},
                  onSelectionChanged: (s) => setState(() => _showAR = s.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _loadReports, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showAR
                  ? _buildARAgingContent(context, state.arAging)
                  : _buildAPAgingContent(context, state.apAging),
        ),
      ],
    );
  }

  Widget _buildARAgingContent(BuildContext context, ARAgingReport? report) {
    if (report == null) return const Center(child: Text('No data'));
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Total Receivable', style: theme.textTheme.titleMedium),
                  Text(_formatCurrency(report.grandTotal), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AgingSummaryRow('Current', report.totalCurrent, Colors.green),
          _AgingSummaryRow('1-30 Days', report.total1to30, Colors.yellow.shade700),
          _AgingSummaryRow('31-60 Days', report.total31to60, Colors.orange),
          _AgingSummaryRow('61-90 Days', report.total61to90, Colors.deepOrange),
          _AgingSummaryRow('Over 90 Days', report.totalOver90, Colors.red),
          if (report.rows.isNotEmpty) ...[
            const Divider(height: 32),
            Text('By Customer', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...report.rows.map((r) => ListTile(
              title: Text(r.customerName),
              trailing: Text(_formatCurrency(r.total), style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildAPAgingContent(BuildContext context, APAgingReport? report) {
    if (report == null) return const Center(child: Text('No data'));
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Total Payable', style: theme.textTheme.titleMedium),
                  Text(_formatCurrency(report.grandTotal), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AgingSummaryRow('Current', report.totalCurrent, Colors.green),
          _AgingSummaryRow('1-30 Days', report.total1to30, Colors.yellow.shade700),
          _AgingSummaryRow('31-60 Days', report.total31to60, Colors.orange),
          _AgingSummaryRow('61-90 Days', report.total61to90, Colors.deepOrange),
          _AgingSummaryRow('Over 90 Days', report.totalOver90, Colors.red),
          if (report.rows.isNotEmpty) ...[
            const Divider(height: 32),
            Text('By Vendor', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...report.rows.map((r) => ListTile(
              title: Text(r.vendorName),
              trailing: Text(_formatCurrency(r.total), style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _TableHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: align),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool isBold;

  const _TableCell(this.text, {this.align = TextAlign.left, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: isBold ? FontWeight.bold : null), textAlign: align),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String code;
  final String name;
  final double amount;

  const _AccountRow(this.code, this.name, this.amount);

  String _formatCurrency(double amount) {
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(code, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyMedium)),
          Text(_formatCurrency(amount), style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _TotalRow(this.label, this.amount, this.color);

  String _formatCurrency(double amount) {
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(_formatCurrency(amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _AgingSummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AgingSummaryRow(this.label, this.amount, this.color);

  String _formatCurrency(double amount) {
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          Text(_formatCurrency(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
