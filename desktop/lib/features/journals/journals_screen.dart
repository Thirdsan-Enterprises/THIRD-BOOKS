import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/data_service.dart';
import '../../core/services/api_client.dart';
import '../../core/models/journal_entry.dart';
import '../../core/widgets/attachment_widget.dart';

class JournalsScreen extends ConsumerStatefulWidget {
  const JournalsScreen({super.key});

  @override
  ConsumerState<JournalsScreen> createState() => _JournalsScreenState();
}

class _JournalsScreenState extends ConsumerState<JournalsScreen> {
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  JournalEntryStatus? _selectedStatus;

  // Pagination — industry standard for high-volume accounting journals
  int _pageIndex = 0;
  static const int _pageSize = 50;

  // Reset to page 0 whenever a filter changes so results are visible immediately.
  void _applyFilter(VoidCallback fn) {
    setState(() {
      fn();
      _pageIndex = 0;
    });
  }

  List<JournalEntry> get _filteredEntries {
    final journalsState = ref.watch(journalsProvider);
    return journalsState.entries.where((entry) {
      final matchesSearch = _searchQuery.isEmpty ||
          entry.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.entryNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (entry.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesStatus = _selectedStatus == null || entry.status == _selectedStatus;
      final matchesDate = _dateRange == null ||
          (entry.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              entry.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);

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
            Expanded(
              child: journalsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : journalsState.entries.isEmpty
                      ? _buildEmptyState(context)
                      : _buildJournalTable(context),
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
            Icons.book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No journal entries yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first journal entry to start tracking transactions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showNewJournalEntryDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Journal Entry'),
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
              onPressed: () {
                ref.invalidate(journalsProvider);
                setState(() => _pageIndex = 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Journals refreshed'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _exportToCSV(context),
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
                      onPressed: () => _applyFilter(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => _applyFilter(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<JournalEntryStatus?>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              hintText: 'All Statuses',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem<JournalEntryStatus?>(
                value: null,
                child: Text('All Statuses'),
              ),
              ...JournalEntryStatus.values.map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(_getStatusLabel(status)),
                  )),
            ],
            onChanged: (value) => _applyFilter(() => _selectedStatus = value),
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
              _applyFilter(() => _dateRange = range);
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
            onPressed: () => _applyFilter(() => _dateRange = null),
            tooltip: 'Clear date filter',
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final journalsState = ref.watch(journalsProvider);
    final entries = journalsState.entries;

    final posted = entries.where((e) => e.status == JournalEntryStatus.posted).length;
    final draft = entries.where((e) => e.status == JournalEntryStatus.draft).length;
    final pending = entries.where((e) => e.status == JournalEntryStatus.pending).length;
    final totalDebit = entries.fold<double>(0, (sum, e) => sum + e.totalDebit);

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
    final allEntries = _filteredEntries;

    if (allEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No entries match your filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    // Paginate — render only the current page so scrolling stays fast even
    // with thousands of journal entries (industry standard for ERP/accounting).
    final totalPages = ((allEntries.length - 1) ~/ _pageSize) + 1;
    final safePageIndex = _pageIndex.clamp(0, totalPages - 1);
    final entries = allEntries.skip(safePageIndex * _pageSize).take(_pageSize).toList();

    final firstItem = safePageIndex * _pageSize + 1;
    final lastItem = (safePageIndex * _pageSize + entries.length);

    return Column(
      children: [
        Expanded(
          child: Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 24,
            headingRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.surfaceVariant,
            ),
            columns: const [
              DataColumn(label: Text('Entry ID')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Reference')),
              DataColumn(label: Text('Debit'), numeric: true),
              DataColumn(label: Text('Credit'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: entries.map((entry) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      entry.entryNumber,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                    ),
                    onTap: () => _showEntryDetails(context, entry),
                  ),
                  DataCell(Text(DateFormat('MMM d, yyyy').format(entry.date))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Text(
                        entry.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () => _showEntryDetails(context, entry),
                  ),
                  DataCell(Text(entry.reference ?? '-')),
                  DataCell(
                    Text(
                      'UGX ${_formatNumber(entry.totalDebit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.debit,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      'UGX ${_formatNumber(entry.totalCredit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.credit,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge(entry.status)),
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
                          onPressed: entry.status == JournalEntryStatus.draft
                              ? () => _showEditEntryDialog(context, entry)
                              : null,
                          tooltip: 'Edit',
                        ),
                        if (entry.status == JournalEntryStatus.draft ||
                            entry.status == JournalEntryStatus.pending)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            onPressed: () => _postEntry(context, entry),
                            tooltip: 'Post',
                            color: AppColors.income,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
              ),
            ),
          ),
        ),
        ),
        // ── Pagination footer ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Text(
                'Showing $firstItem–$lastItem of ${allEntries.length} entries',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'First page',
                onPressed: safePageIndex > 0
                    ? () => setState(() => _pageIndex = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous page',
                onPressed: safePageIndex > 0
                    ? () => setState(() => _pageIndex = safePageIndex - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Page ${safePageIndex + 1} of $totalPages',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next page',
                onPressed: safePageIndex < totalPages - 1
                    ? () => setState(() => _pageIndex = safePageIndex + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Last page',
                onPressed: safePageIndex < totalPages - 1
                    ? () => setState(() => _pageIndex = totalPages - 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(JournalEntryStatus status) {
    Color color;
    switch (status) {
      case JournalEntryStatus.posted:
        color = AppColors.income;
        break;
      case JournalEntryStatus.draft:
        color = AppColors.warning;
        break;
      case JournalEntryStatus.pending:
        color = AppColors.info;
        break;
      case JournalEntryStatus.voided:
        color = AppColors.expense;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getStatusLabel(JournalEntryStatus status) {
    switch (status) {
      case JournalEntryStatus.posted:
        return 'Posted';
      case JournalEntryStatus.draft:
        return 'Draft';
      case JournalEntryStatus.pending:
        return 'Pending';
      case JournalEntryStatus.voided:
        return 'Voided';
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _exportToCSV(BuildContext context) async {
    final journalsState = ref.read(journalsProvider);
    if (journalsState.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No journal entries to export')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Journal Entries',
        fileName: 'journal_entries_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final buffer = StringBuffer();
        buffer.writeln('Entry Number,Date,Description,Reference,Total Debit,Total Credit,Status,Created By');

        for (final entry in journalsState.entries) {
          buffer.writeln(
            '${entry.entryNumber},'
            '${DateFormat('yyyy-MM-dd').format(entry.date)},'
            '"${entry.description.replaceAll('"', '""')}",'
            '"${entry.reference ?? ''}",'
            '${entry.totalDebit},'
            '${entry.totalCredit},'
            '${_getStatusLabel(entry.status)},'
            '"${entry.createdBy ?? ''}"',
          );
        }

        final file = File(result);
        await file.writeAsString(buffer.toString());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${journalsState.entries.length} entries to CSV')),
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

  void _postEntry(BuildContext context, JournalEntry entry) {
    if (!entry.isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot post: Debits and credits must be equal'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Journal Entry'),
        content: Text('Are you sure you want to post entry ${entry.entryNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(journalsProvider.notifier).postEntry(entry.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Journal entry posted (will sync when online)'),
                  backgroundColor: AppColors.income,
                ),
              );
            },
            child: const Text('Post Entry'),
          ),
        ],
      ),
    );
  }

  void _showNewJournalEntryDialog(BuildContext context) {
    final accountsState = ref.read(accountsProvider);
    final dateController = TextEditingController(
      text: DateFormat('MMM d, yyyy').format(DateTime.now()),
    );
    final referenceController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    // Start with two empty lines
    final List<_JournalLineData> lines = [
      _JournalLineData(),
      _JournalLineData(),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalDebit = lines.fold(0, (sum, line) => sum + line.debit);
          double totalCredit = lines.fold(0, (sum, line) => sum + line.credit);
          bool isBalanced = (totalDebit - totalCredit).abs() < 0.01;

          final attachKey = GlobalKey<AttachmentPanelState>();

          return AlertDialog(
            title: const Text('New Journal Entry'),
            content: SizedBox(
              width: 750,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dateController,
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                selectedDate = date;
                                dateController.text = DateFormat('MMM d, yyyy').format(date);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: referenceController,
                            decoration: const InputDecoration(labelText: 'Reference (Optional)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description *'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Journal Lines', style: Theme.of(context).textTheme.titleMedium),
                        Row(
                          children: [
                            if (!isBalanced && totalDebit > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.expense.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Unbalanced: ${NumberFormat('#,###').format((totalDebit - totalCredit).abs())}',
                                  style: const TextStyle(
                                    color: AppColors.expense,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isBalanced && totalDebit > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.income.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check, size: 14, color: AppColors.income),
                                    SizedBox(width: 4),
                                    Text(
                                      'Balanced',
                                      style: TextStyle(
                                        color: AppColors.income,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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
                          ...lines.asMap().entries.map((entry) {
                            final index = entry.key;
                            final line = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: line.accountId.isEmpty ? null : line.accountId,
                                      decoration: const InputDecoration(
                                        hintText: 'Select account',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: accountsState.accounts
                                          .map((a) => DropdownMenuItem(
                                                value: a.id,
                                                child: Text('${a.code} - ${a.name}'),
                                              ))
                                          .toList(),
                                      onChanged: (v) {
                                        setDialogState(() {
                                          line.accountId = v ?? '';
                                          final account = accountsState.accounts.firstWhere(
                                            (a) => a.id == v,
                                            orElse: () => accountsState.accounts.first,
                                          );
                                          line.accountName = account.name;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: line.debit > 0 ? line.debit.toString() : '',
                                      decoration: const InputDecoration(
                                        hintText: '0.00',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        setDialogState(() {
                                          line.debit = double.tryParse(v) ?? 0;
                                          if (line.debit > 0) line.credit = 0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: line.credit > 0 ? line.credit.toString() : '',
                                      decoration: const InputDecoration(
                                        hintText: '0.00',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        setDialogState(() {
                                          line.credit = double.tryParse(v) ?? 0;
                                          if (line.credit > 0) line.debit = 0;
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: lines.length > 2
                                        ? () {
                                            setDialogState(() {
                                              lines.removeAt(index);
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                lines.add(_JournalLineData());
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Line'),
                          ),
                          const Divider(),
                          Row(
                            children: [
                              const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  NumberFormat('#,###').format(totalDebit),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.debit),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  NumberFormat('#,###').format(totalCredit),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.credit),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    AttachmentPanel(
                      key: attachKey,
                      attachableType: 'journal-entry',
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
              OutlinedButton(
                onPressed: () {
                  if (descriptionController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a description')),
                    );
                    return;
                  }
                  if (lines.where((l) => l.accountId.isNotEmpty).length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please add at least 2 lines with accounts')),
                    );
                    return;
                  }
                  _saveEntry(
                    context: context,
                    date: selectedDate,
                    description: descriptionController.text,
                    reference: referenceController.text.isEmpty ? null : referenceController.text,
                    lines: lines,
                    status: JournalEntryStatus.draft,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Save as Draft'),
              ),
              FilledButton(
                onPressed: isBalanced && totalDebit > 0
                    ? () {
                        if (descriptionController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a description')),
                          );
                          return;
                        }
                        if (lines.where((l) => l.accountId.isNotEmpty).length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add at least 2 lines with accounts')),
                          );
                          return;
                        }
                        _saveEntry(
                          context: context,
                          date: selectedDate,
                          description: descriptionController.text,
                          reference: referenceController.text.isEmpty ? null : referenceController.text,
                          lines: lines,
                          status: JournalEntryStatus.posted,
                        );
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('Post Entry'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveEntry({
    required BuildContext context,
    required DateTime date,
    required String description,
    String? reference,
    required List<_JournalLineData> lines,
    required JournalEntryStatus status,
  }) {
    final validLines = lines.where((l) => l.accountId.isNotEmpty && (l.debit > 0 || l.credit > 0)).toList();

    final journalLines = validLines.map((l) {
      return JournalLine(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        journalEntryId: '',
        accountId: l.accountId,
        accountName: l.accountName,
        debit: l.debit,
        credit: l.credit,
      );
    }).toList();

    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      entryNumber: 'JE-${DateFormat('yyyyMMdd').format(date)}-${DateTime.now().millisecondsSinceEpoch % 1000}',
      date: date,
      description: description,
      reference: reference,
      status: status,
      lines: journalLines,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(journalsProvider.notifier).addEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status == JournalEntryStatus.posted
            ? 'Journal entry posted (will sync when online)'
            : 'Journal entry saved as draft (will sync when online)'),
        backgroundColor: AppColors.income,
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, JournalEntry entry) {
    // Similar to create dialog but pre-populated with entry data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _showEntryDetails(BuildContext context, JournalEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Journal Entry: ${entry.entryNumber}'),
            _buildStatusBadge(entry.status),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('Date', DateFormat('MMMM d, yyyy').format(entry.date)),
                _DetailRow('Description', entry.description),
                _DetailRow('Reference', entry.reference ?? '-'),
                _DetailRow('Created By', entry.createdBy ?? 'System'),
                _DetailRow('Created At', DateFormat('MMM d, yyyy HH:mm').format(entry.createdAt)),
                if (entry.notes != null && entry.notes!.isNotEmpty)
                  _DetailRow('Notes', entry.notes!),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Lines', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (entry.isBalanced)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.income.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 14, color: AppColors.income),
                            SizedBox(width: 4),
                            Text(
                              'Balanced',
                              style: TextStyle(
                                color: AppColors.income,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('Account')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Debit'), numeric: true),
                      DataColumn(label: Text('Credit'), numeric: true),
                    ],
                    rows: [
                      ...entry.lines.map((line) {
                        return DataRow(cells: [
                          DataCell(Text(
                            line.accountCode != null
                                ? '${line.accountCode}  ${line.accountName ?? line.accountId}'
                                : (line.accountName ?? line.accountId),
                          )),
                          DataCell(Text(
                            line.description ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )),
                          DataCell(Text(
                            line.debit > 0 ? 'UGX ${NumberFormat('#,###').format(line.debit)}' : '-',
                            style: const TextStyle(color: AppColors.debit, fontFamily: 'monospace'),
                          )),
                          DataCell(Text(
                            line.credit > 0 ? 'UGX ${NumberFormat('#,###').format(line.credit)}' : '-',
                            style: const TextStyle(color: AppColors.credit, fontFamily: 'monospace'),
                          )),
                        ]);
                      }),
                      DataRow(
                        color: MaterialStateProperty.all(
                          Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        cells: [
                          const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(SizedBox.shrink()),
                          DataCell(Text(
                            'UGX ${NumberFormat('#,###').format(entry.totalDebit)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.debit,
                              fontFamily: 'monospace',
                            ),
                          )),
                          DataCell(Text(
                            'UGX ${NumberFormat('#,###').format(entry.totalCredit)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.credit,
                              fontFamily: 'monospace',
                            ),
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                AttachmentPanel(
                  attachableType: 'journal-entry',
                  attachableId: entry.syncSequence,
                  apiClient: ref.read(apiClientProvider),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (entry.status == JournalEntryStatus.draft)
            FilledButton(
              onPressed: entry.isBalanced
                  ? () {
                      ref.read(journalsProvider.notifier).postEntry(entry.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Journal entry posted (will sync when online)'),
                          backgroundColor: AppColors.income,
                        ),
                      );
                    }
                  : null,
              child: const Text('Post Entry'),
            ),
        ],
      ),
    );
  }
}

class _JournalLineData {
  String accountId = '';
  String accountName = '';
  double debit = 0;
  double credit = 0;
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
