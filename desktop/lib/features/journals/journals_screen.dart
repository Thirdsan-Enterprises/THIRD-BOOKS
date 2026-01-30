import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class JournalsScreen extends ConsumerStatefulWidget {
  const JournalsScreen({super.key});

  @override
  ConsumerState<JournalsScreen> createState() => _JournalsScreenState();
}

class _JournalsScreenState extends ConsumerState<JournalsScreen> {
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  String? _selectedStatus;

  final List<Map<String, dynamic>> _journalEntries = [
    {
      'id': 'JE-2024-001',
      'date': DateTime(2024, 1, 15),
      'description': 'Sales revenue - Invoice INV-001',
      'reference': 'INV-001',
      'debitTotal': 5850000.0,
      'creditTotal': 5850000.0,
      'status': 'Posted',
      'createdBy': 'John Doe',
      'lines': [
        {'account': 'Accounts Receivable', 'debit': 5850000.0, 'credit': 0.0},
        {'account': 'Sales Revenue', 'debit': 0.0, 'credit': 5000000.0},
        {'account': 'VAT Payable', 'debit': 0.0, 'credit': 850000.0},
      ],
    },
    {
      'id': 'JE-2024-002',
      'date': DateTime(2024, 1, 16),
      'description': 'Office rent payment - January',
      'reference': 'CHQ-456',
      'debitTotal': 2500000.0,
      'creditTotal': 2500000.0,
      'status': 'Posted',
      'createdBy': 'Jane Smith',
      'lines': [
        {'account': 'Rent Expense', 'debit': 2500000.0, 'credit': 0.0},
        {'account': 'Bank Account - UGX', 'debit': 0.0, 'credit': 2500000.0},
      ],
    },
    {
      'id': 'JE-2024-003',
      'date': DateTime(2024, 1, 17),
      'description': 'Purchase of office supplies',
      'reference': 'BILL-089',
      'debitTotal': 450000.0,
      'creditTotal': 450000.0,
      'status': 'Posted',
      'createdBy': 'John Doe',
      'lines': [
        {'account': 'Office Supplies', 'debit': 450000.0, 'credit': 0.0},
        {'account': 'Accounts Payable', 'debit': 0.0, 'credit': 450000.0},
      ],
    },
    {
      'id': 'JE-2024-004',
      'date': DateTime(2024, 1, 18),
      'description': 'Customer payment received',
      'reference': 'REC-012',
      'debitTotal': 3500000.0,
      'creditTotal': 3500000.0,
      'status': 'Posted',
      'createdBy': 'Jane Smith',
      'lines': [
        {'account': 'Bank Account - UGX', 'debit': 3500000.0, 'credit': 0.0},
        {'account': 'Accounts Receivable', 'debit': 0.0, 'credit': 3500000.0},
      ],
    },
    {
      'id': 'JE-2024-005',
      'date': DateTime(2024, 1, 19),
      'description': 'Salary advance - Staff',
      'reference': 'ADV-001',
      'debitTotal': 500000.0,
      'creditTotal': 500000.0,
      'status': 'Draft',
      'createdBy': 'John Doe',
      'lines': [
        {'account': 'Salary Advance', 'debit': 500000.0, 'credit': 0.0},
        {'account': 'Cash on Hand', 'debit': 0.0, 'credit': 500000.0},
      ],
    },
    {
      'id': 'JE-2024-006',
      'date': DateTime(2024, 1, 20),
      'description': 'Depreciation - January',
      'reference': 'DEP-JAN',
      'debitTotal': 850000.0,
      'creditTotal': 850000.0,
      'status': 'Pending',
      'createdBy': 'System',
      'lines': [
        {'account': 'Depreciation Expense', 'debit': 850000.0, 'credit': 0.0},
        {'account': 'Accumulated Depreciation', 'debit': 0.0, 'credit': 850000.0},
      ],
    },
  ];

  List<Map<String, dynamic>> get _filteredEntries {
    return _journalEntries.where((entry) {
      final matchesSearch = _searchQuery.isEmpty ||
          entry['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry['reference'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == null || entry['status'] == _selectedStatus;
      final matchesDate = _dateRange == null ||
          ((entry['date'] as DateTime).isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              (entry['date'] as DateTime).isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
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
            _buildFilters(context),
            const SizedBox(height: 16),
            _buildSummaryCards(context),
            const SizedBox(height: 16),
            Expanded(child: _buildJournalTable(context)),
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
              'Journal Entries',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Record and manage financial transactions',
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
              onPressed: () => _showNewJournalEntryDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Entry'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search entries...',
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
        const SizedBox(width: 16),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              hintText: 'All Statuses',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...['Posted', 'Draft', 'Pending', 'Voided']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (value) => setState(() => _selectedStatus = value),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRange,
            );
            if (range != null) {
              setState(() => _dateRange = range);
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(_dateRange != null
              ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
              : 'Date Range'),
        ),
        if (_dateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => setState(() => _dateRange = null),
            tooltip: 'Clear date filter',
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final posted = _journalEntries.where((e) => e['status'] == 'Posted').length;
    final draft = _journalEntries.where((e) => e['status'] == 'Draft').length;
    final pending = _journalEntries.where((e) => e['status'] == 'Pending').length;
    final totalDebit = _journalEntries.fold<double>(0, (sum, e) => sum + (e['debitTotal'] as double));

    return Row(
      children: [
        _SummaryCard(
          icon: Icons.check_circle,
          iconColor: AppColors.income,
          label: 'Posted',
          value: posted.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.edit_note,
          iconColor: AppColors.warning,
          label: 'Drafts',
          value: draft.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.pending_actions,
          iconColor: AppColors.info,
          label: 'Pending',
          value: pending.toString(),
        ),
        const SizedBox(width: 16),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.primary,
          label: 'Total Volume',
          value: 'UGX ${_formatNumber(totalDebit)}',
        ),
      ],
    );
  }

  Widget _buildJournalTable(BuildContext context) {
    return Card(
      child: DataTable2(
        columnSpacing: 24,
        horizontalMargin: 24,
        minWidth: 1000,
        headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
        columns: const [
          DataColumn2(label: Text('Entry ID'), size: ColumnSize.S),
          DataColumn2(label: Text('Date'), size: ColumnSize.S),
          DataColumn2(label: Text('Description'), size: ColumnSize.L),
          DataColumn2(label: Text('Reference'), size: ColumnSize.S),
          DataColumn2(label: Text('Debit'), size: ColumnSize.M, numeric: true),
          DataColumn2(label: Text('Credit'), size: ColumnSize.M, numeric: true),
          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],
        rows: _filteredEntries.map((entry) {
          return DataRow2(
            onTap: () => _showEntryDetails(context, entry),
            cells: [
              DataCell(
                Text(
                  entry['id'],
                  style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                ),
              ),
              DataCell(Text(DateFormat('MMM d, yyyy').format(entry['date']))),
              DataCell(
                Text(
                  entry['description'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DataCell(Text(entry['reference'])),
              DataCell(
                Text(
                  'UGX ${_formatNumber(entry['debitTotal'])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.debit,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              DataCell(
                Text(
                  'UGX ${_formatNumber(entry['creditTotal'])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.credit,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              DataCell(_buildStatusBadge(entry['status'])),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      onPressed: () => _showEntryDetails(context, entry),
                      tooltip: 'View',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: entry['status'] == 'Draft' ? () {} : null,
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Posted':
        color = AppColors.income;
        break;
      case 'Draft':
        color = AppColors.warning;
        break;
      case 'Pending':
        color = AppColors.info;
        break;
      case 'Voided':
        color = AppColors.expense;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showNewJournalEntryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Journal Entry'),
        content: SizedBox(
          width: 700,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Date'),
                      readOnly: true,
                      initialValue: DateFormat('MMM d, yyyy').format(DateTime.now()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Reference'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 24),
              Text('Journal Lines', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 3, child: Text('Account', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Debit', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Credit', style: TextStyle(fontWeight: FontWeight.w600))),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const Divider(),
                    _JournalLineRow(),
                    _JournalLineRow(),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Line'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Save as Draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Post Entry'),
          ),
        ],
      ),
    );
  }

  void _showEntryDetails(BuildContext context, Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Journal Entry: ${entry['id']}'),
            _buildStatusBadge(entry['status']),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Date', DateFormat('MMMM d, yyyy').format(entry['date'])),
              _DetailRow('Description', entry['description']),
              _DetailRow('Reference', entry['reference']),
              _DetailRow('Created By', entry['createdBy']),
              const SizedBox(height: 16),
              Text('Lines', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Account')),
                    DataColumn(label: Text('Debit'), numeric: true),
                    DataColumn(label: Text('Credit'), numeric: true),
                  ],
                  rows: (entry['lines'] as List).map((line) {
                    return DataRow(cells: [
                      DataCell(Text(line['account'])),
                      DataCell(Text(
                        line['debit'] > 0 ? 'UGX ${NumberFormat('#,###').format(line['debit'])}' : '-',
                        style: const TextStyle(color: AppColors.debit, fontFamily: 'monospace'),
                      )),
                      DataCell(Text(
                        line['credit'] > 0 ? 'UGX ${NumberFormat('#,###').format(line['credit'])}' : '-',
                        style: const TextStyle(color: AppColors.credit, fontFamily: 'monospace'),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: UGX ${NumberFormat('#,###').format(entry['debitTotal'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (entry['status'] == 'Draft')
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Post Entry'),
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

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              Column(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _JournalLineRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: 'Select account',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: ['Cash on Hand', 'Bank Account - UGX', 'Accounts Receivable', 'Sales Revenue', 'VAT Payable']
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) {},
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: '0.00',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: '0.00',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
