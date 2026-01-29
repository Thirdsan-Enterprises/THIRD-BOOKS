import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/journal_entries_provider.dart';
import '../../core/providers/accounts_provider.dart';

class JournalEntriesScreen extends ConsumerStatefulWidget {
  const JournalEntriesScreen({super.key});

  @override
  ConsumerState<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends ConsumerState<JournalEntriesScreen> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final journalState = ref.watch(journalEntriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Entries'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedStatus = value == 'all' ? null : value);
              ref.read(journalEntriesProvider.notifier).setStatusFilter(_selectedStatus);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'draft', child: Text('Draft')),
              const PopupMenuItem(value: 'posted', child: Text('Posted')),
              const PopupMenuItem(value: 'void', child: Text('Void')),
            ],
          ),
        ],
      ),
      body: journalState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : journalState.error != null
              ? Center(child: Text('Error: ${journalState.error}'))
              : journalState.filteredEntries.isEmpty
                  ? _buildEmptyState(context)
                  : _buildEntriesList(context, journalState.filteredEntries),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEntryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No journal entries yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Create journal entries to record transactions', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEntriesList(BuildContext context, List<JournalEntry> entries) {
    return RefreshIndicator(
      onRefresh: () => ref.read(journalEntriesProvider.notifier).loadJournalEntries(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: entries.length,
        itemBuilder: (context, index) => _buildEntryTile(context, entries[index]),
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, JournalEntry entry) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final statusColor = _getStatusColor(entry.status, theme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showEntryDetails(context, entry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.entryNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    _formatCurrency(entry.totalDebit, entry.currencyCode),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(entry.description, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(dateFormat.format(entry.entryDate), style: theme.textTheme.bodySmall),
                  if (entry.reference != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.tag, size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(entry.reference!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'posted': return Colors.green;
      case 'void': return Colors.red;
      default: return theme.colorScheme.primary;
    }
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }

  void _showEntryDetails(BuildContext context, JournalEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _JournalEntryDetailsSheet(
          entry: entry,
          scrollController: scrollController,
          onPost: entry.status == 'draft'
              ? () async {
                  await ref.read(journalEntriesProvider.notifier).postEntry(entry.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry posted')));
                  }
                }
              : null,
          onDelete: () async {
            Navigator.pop(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Entry'),
                content: Text('Are you sure you want to delete ${entry.entryNumber}?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(journalEntriesProvider.notifier).deleteJournalEntry(entry.id);
            }
          },
        ),
      ),
    );
  }

  void _showCreateEntryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _JournalEntryFormSheet(
          onSave: (data) async {
            await ref.read(journalEntriesProvider.notifier).createJournalEntry(
              entryDate: data['entry_date'] as DateTime,
              description: data['description'] as String,
              reference: data['reference'] as String?,
              lines: data['lines'] as List<Map<String, dynamic>>,
              createdBy: 'user',
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journal entry created')));
            }
          },
        ),
      ),
    );
  }
}

class _JournalEntryDetailsSheet extends ConsumerWidget {
  final JournalEntry entry;
  final ScrollController scrollController;
  final VoidCallback? onPost;
  final VoidCallback onDelete;

  const _JournalEntryDetailsSheet({
    required this.entry,
    required this.scrollController,
    this.onPost,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final linesAsync = ref.watch(journalEntryLinesProvider(entry.id));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(entry.entryNumber, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(entry.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          _DetailRow('Entry Date', dateFormat.format(entry.entryDate)),
          _DetailRow('Status', entry.status.toUpperCase()),
          if (entry.reference != null) _DetailRow('Reference', entry.reference!),
          if (entry.postedAt != null) _DetailRow('Posted At', dateFormat.format(entry.postedAt!)),
          const Divider(height: 32),
          Text('Lines', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          linesAsync.when(
            data: (lines) => _buildLinesTable(context, lines),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading lines: $e'),
          ),
          const Divider(height: 32),
          _DetailRow('Total Debits', _formatCurrency(entry.totalDebit, entry.currencyCode), isHighlighted: true),
          _DetailRow('Total Credits', _formatCurrency(entry.totalCredit, entry.currencyCode), isHighlighted: true),
          if ((entry.totalDebit - entry.totalCredit).abs() > 0.01)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Text('Entry is not balanced!', style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (onPost != null)
            FilledButton.icon(onPressed: onPost, icon: const Icon(Icons.check_circle), label: const Text('Post Entry')),
          const SizedBox(height: 12),
          if (entry.status == 'draft')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
              label: const Text('Delete Entry'),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesTable(BuildContext context, List<JournalEntryLine> lines) {
    final theme = Theme.of(context);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant),
          children: [
            Padding(padding: const EdgeInsets.all(8), child: Text('Account', style: theme.textTheme.labelMedium)),
            Padding(padding: const EdgeInsets.all(8), child: Text('Debit', style: theme.textTheme.labelMedium, textAlign: TextAlign.right)),
            Padding(padding: const EdgeInsets.all(8), child: Text('Credit', style: theme.textTheme.labelMedium, textAlign: TextAlign.right)),
          ],
        ),
        ...lines.map((line) => TableRow(
          children: [
            Padding(padding: const EdgeInsets.all(8), child: Text(line.accountId, style: theme.textTheme.bodySmall)),
            Padding(padding: const EdgeInsets.all(8), child: Text(line.debitAmount > 0 ? _formatCurrency(line.debitAmount, 'UGX') : '', style: theme.textTheme.bodySmall, textAlign: TextAlign.right)),
            Padding(padding: const EdgeInsets.all(8), child: Text(line.creditAmount > 0 ? _formatCurrency(line.creditAmount, 'UGX') : '', style: theme.textTheme.bodySmall, textAlign: TextAlign.right)),
          ],
        )),
      ],
    );
  }

  String _formatCurrency(double amount, String currencyCode) {
    if (currencyCode == 'UGX') {
      return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '$currencyCode ${amount.toStringAsFixed(2)}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _DetailRow(this.label, this.value, {this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          Text(value, style: isHighlighted ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) : theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _JournalEntryFormSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _JournalEntryFormSheet({required this.onSave});

  @override
  ConsumerState<_JournalEntryFormSheet> createState() => _JournalEntryFormSheetState();
}

class _JournalEntryFormSheetState extends ConsumerState<_JournalEntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _entryDate = DateTime.now();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final List<Map<String, dynamic>> _lines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lines.add({'account_id': null, 'debit': 0.0, 'credit': 0.0, 'description': ''});
    _lines.add({'account_id': null, 'debit': 0.0, 'credit': 0.0, 'description': ''});
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double get _totalDebits => _lines.fold(0, (sum, line) => sum + (line['debit'] as double));
  double get _totalCredits => _lines.fold(0, (sum, line) => sum + (line['credit'] as double));
  bool get _isBalanced => (_totalDebits - _totalCredits).abs() < 0.01;

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Journal Entry', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Entry Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_entryDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _entryDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (date != null) setState(() => _entryDate = date);
              },
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description *', prefixIcon: Icon(Icons.description)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(labelText: 'Reference', prefixIcon: Icon(Icons.tag)),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lines', style: theme.textTheme.titleMedium),
                Text(
                  _isBalanced ? 'Balanced' : 'Not Balanced',
                  style: TextStyle(
                    color: _isBalanced ? Colors.green : theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._lines.asMap().entries.map((entry) => _buildLineRow(entry.key, accountsState.accounts.where((a) => a.isActive).toList())),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add({'account_id': null, 'debit': 0.0, 'credit': 0.0, 'description': ''})),
              icon: const Icon(Icons.add),
              label: const Text('Add Line'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Debits'), Text(_formatCurrency(_totalDebits))]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Credits'), Text(_formatCurrency(_totalCredits))]),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Difference', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _formatCurrency((_totalDebits - _totalCredits).abs()),
                          style: TextStyle(fontWeight: FontWeight.bold, color: _isBalanced ? Colors.green : theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading || !_isBalanced ? null : _handleSave,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineRow(int index, List<Account> accounts) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _lines[index]['account_id'] as String?,
                    decoration: const InputDecoration(labelText: 'Account', isDense: true),
                    items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.code} - ${a.name}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _lines[index]['account_id'] = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: _lines.length > 2 ? () => setState(() => _lines.removeAt(index)) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Debit', isDense: true),
                    initialValue: _lines[index]['debit'] == 0.0 ? '' : _lines[index]['debit'].toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _lines[index]['debit'] = double.tryParse(v) ?? 0.0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Credit', isDense: true),
                    initialValue: _lines[index]['credit'] == 0.0 ? '' : _lines[index]['credit'].toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _lines[index]['credit'] = double.tryParse(v) ?? 0.0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'UGX ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isBalanced) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave({
        'entry_date': _entryDate,
        'description': _descriptionController.text,
        'reference': _referenceController.text.isEmpty ? null : _referenceController.text,
        'lines': _lines.where((l) => l['account_id'] != null && ((l['debit'] as double) > 0 || (l['credit'] as double) > 0)).toList(),
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
