// Credit & Debit Notes Screen
// Credit Note: issued to a customer, reduces their invoice balance.
//   Journal: DR Revenue/Account, CR Accounts Receivable
// Debit Note: issued to a vendor, reduces a bill/payable.
//   Journal: DR Accounts Payable, CR Expense/Account
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/api_client.dart';
import '../../core/models/models.dart';
import '../../core/widgets/attachment_widget.dart';

// ---------------------------------------------------------------------------
// State / Notifiers
// ---------------------------------------------------------------------------

class CreditNotesState {
  final List<CreditNote> notes;
  CreditNotesState({required this.notes});
  CreditNotesState copyWith({List<CreditNote>? notes}) =>
      CreditNotesState(notes: notes ?? this.notes);
}

class CreditNotesNotifier extends StateNotifier<CreditNotesState> {
  final LocalStorageService _ls = LocalStorageService.instance;

  CreditNotesNotifier() : super(CreditNotesState(notes: [])) {
    _load();
  }

  Future<void> _load() async {
    final notes = await _ls.loadCreditNotes();
    state = state.copyWith(notes: notes);
  }

  Future<void> addNote(CreditNote note) async {
    final updated = [...state.notes, note];
    state = state.copyWith(notes: updated);
    await _ls.saveCreditNotes(updated);
  }

  Future<void> updateNote(CreditNote note) async {
    final updated =
        state.notes.map((n) => n.id == note.id ? note : n).toList();
    state = state.copyWith(notes: updated);
    await _ls.saveCreditNotes(updated);
  }

  Future<void> deleteNote(String id) async {
    final updated = state.notes.where((n) => n.id != id).toList();
    state = state.copyWith(notes: updated);
    await _ls.saveCreditNotes(updated);
  }
}

final creditNotesProvider =
    StateNotifierProvider<CreditNotesNotifier, CreditNotesState>(
  (_) => CreditNotesNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────

class DebitNotesState {
  final List<DebitNote> notes;
  DebitNotesState({required this.notes});
  DebitNotesState copyWith({List<DebitNote>? notes}) =>
      DebitNotesState(notes: notes ?? this.notes);
}

class DebitNotesNotifier extends StateNotifier<DebitNotesState> {
  final LocalStorageService _ls = LocalStorageService.instance;

  DebitNotesNotifier() : super(DebitNotesState(notes: [])) {
    _load();
  }

  Future<void> _load() async {
    final notes = await _ls.loadDebitNotes();
    state = state.copyWith(notes: notes);
  }

  Future<void> addNote(DebitNote note) async {
    final updated = [...state.notes, note];
    state = state.copyWith(notes: updated);
    await _ls.saveDebitNotes(updated);
  }

  Future<void> updateNote(DebitNote note) async {
    final updated =
        state.notes.map((n) => n.id == note.id ? note : n).toList();
    state = state.copyWith(notes: updated);
    await _ls.saveDebitNotes(updated);
  }

  Future<void> deleteNote(String id) async {
    final updated = state.notes.where((n) => n.id != id).toList();
    state = state.copyWith(notes: updated);
    await _ls.saveDebitNotes(updated);
  }
}

final debitNotesProvider =
    StateNotifierProvider<DebitNotesNotifier, DebitNotesState>(
  (_) => DebitNotesNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CreditDebitNotesScreen extends ConsumerStatefulWidget {
  const CreditDebitNotesScreen({super.key});

  @override
  ConsumerState<CreditDebitNotesScreen> createState() =>
      _CreditDebitNotesScreenState();
}

class _CreditDebitNotesScreenState
    extends ConsumerState<CreditDebitNotesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  final _fmt = NumberFormat('#,###');
  final _dateFmt = DateFormat('MMM d, yyyy');

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
    final creditState = ref.watch(creditNotesProvider);
    final debitState = ref.watch(debitNotesProvider);

    return Scaffold(
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit & Debit Notes',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Industry-standard adjustment notes referenced to customers and vendors',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  onPressed: () {
                    ref.invalidate(creditNotesProvider);
                    ref.invalidate(debitNotesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notes refreshed'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_tabController.index == 0
                      ? 'New Credit Note'
                      : 'New Debit Note'),
                  onPressed: () => _tabController.index == 0
                      ? _showCreditNoteDialog(context)
                      : _showDebitNoteDialog(context),
                ),
              ],
            ),
          ),

          // ── Search + Tabs ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) =>
                        setState(() => _search = v.trim().toLowerCase()),
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.remove_circle_outline, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          'Credit Notes (${creditState.notes.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          'Debit Notes (${debitState.notes.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Content ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreditNotesList(creditState.notes),
                _buildDebitNotesList(debitState.notes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Credit Notes List ─────────────────────────────────────────────────────

  Widget _buildCreditNotesList(List<CreditNote> all) {
    final filtered = _search.isEmpty
        ? all
        : all
            .where((n) =>
                n.creditNoteNumber.toLowerCase().contains(_search) ||
                (n.customerName ?? '').toLowerCase().contains(_search) ||
                n.reason.toLowerCase().contains(_search))
            .toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));

    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.remove_circle_outline,
        title: all.isEmpty ? 'No credit notes yet' : 'No notes match',
        subtitle: all.isEmpty
            ? 'Credit notes are issued to customers to reduce their invoice balance.'
            : 'Try adjusting your search.',
        onAdd: () => _showCreditNoteDialog(context),
        addLabel: 'Create Credit Note',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              columns: const [
                DataColumn(label: Text('Number')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Invoice Ref')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: filtered
                  .map((n) => DataRow(cells: [
                        DataCell(Text(n.creditNoteNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                        DataCell(Text(n.customerName ?? '—')),
                        DataCell(Text(n.invoiceNumber ?? '—')),
                        DataCell(Text(_dateFmt.format(n.date))),
                        DataCell(Text(
                          'UGX ${_fmt.format(n.amount)}',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace'),
                        )),
                        DataCell(_noteStatusChip(n.status)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Edit',
                              onPressed: () =>
                                  _showCreditNoteDialog(context, note: n),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDeleteCreditNote(context, n),
                            ),
                          ],
                        )),
                      ]))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Debit Notes List ──────────────────────────────────────────────────────

  Widget _buildDebitNotesList(List<DebitNote> all) {
    final filtered = _search.isEmpty
        ? all
        : all
            .where((n) =>
                n.debitNoteNumber.toLowerCase().contains(_search) ||
                (n.vendorName ?? '').toLowerCase().contains(_search) ||
                n.reason.toLowerCase().contains(_search))
            .toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));

    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.add_circle_outline,
        title: all.isEmpty ? 'No debit notes yet' : 'No notes match',
        subtitle: all.isEmpty
            ? 'Debit notes are issued to vendors to reduce bill/payable balances.'
            : 'Try adjusting your search.',
        onAdd: () => _showDebitNoteDialog(context),
        addLabel: 'Create Debit Note',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              columns: const [
                DataColumn(label: Text('Number')),
                DataColumn(label: Text('Vendor')),
                DataColumn(label: Text('Bill Ref')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: filtered
                  .map((n) => DataRow(cells: [
                        DataCell(Text(n.debitNoteNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                        DataCell(Text(n.vendorName ?? '—')),
                        DataCell(Text(n.billNumber ?? '—')),
                        DataCell(Text(_dateFmt.format(n.date))),
                        DataCell(Text(
                          'UGX ${_fmt.format(n.amount)}',
                          style: TextStyle(
                              color: AppColors.expense,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace'),
                        )),
                        DataCell(_noteStatusChip(n.status)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Edit',
                              onPressed: () =>
                                  _showDebitNoteDialog(context, note: n),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDeleteDebitNote(context, n),
                            ),
                          ],
                        )),
                      ]))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Credit Note Dialog ────────────────────────────────────────────────────

  void _showCreditNoteDialog(BuildContext context, {CreditNote? note}) {
    final isEdit = note != null;
    final formKey = GlobalKey<FormState>();
    final numCtrl =
        TextEditingController(text: note?.creditNoteNumber ?? _nextCreditNoteNo());
    final amtCtrl =
        TextEditingController(text: note == null ? '' : note.amount.toString());
    final reasonCtrl = TextEditingController(text: note?.reason ?? '');
    final notesCtrl = TextEditingController(text: note?.notes ?? '');

    final customersState = ref.read(customersProvider);
    final invoicesState = ref.read(invoicesProvider);
    String? selectedCustomerId = note?.customerId;
    String? selectedInvoiceId = note?.invoiceId;
    NoteStatus selectedStatus = note?.status ?? NoteStatus.draft;
    DateTime selectedDate = note?.date ?? DateTime.now();
    final dateFmt = DateFormat('MMM d, yyyy');
    // Pre-generate so attachments are stored immediately (reuse existing ID on edit).
    final noteId = note?.id ?? const Uuid().v4();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.remove_circle_outline, color: AppColors.success),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Credit Note' : 'New Credit Note'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: AppColors.success),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Journal: DR Revenue/Account  •  CR Accounts Receivable',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note number
                    TextFormField(
                      controller: numCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Credit Note Number *',
                        prefixIcon:
                            Icon(Icons.tag, size: 18),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Customer
                    DropdownButtonFormField<String>(
                      value: selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Customer *',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                      items: customersState.customers
                          .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setS(() {
                        selectedCustomerId = v;
                        selectedInvoiceId = null; // reset invoice
                      }),
                      validator: (v) =>
                          v == null ? 'Please select a customer' : null,
                    ),
                    const SizedBox(height: 12),

                    // Invoice reference (optional)
                    DropdownButtonFormField<String>(
                      value: selectedInvoiceId,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Reference (optional)',
                        prefixIcon:
                            Icon(Icons.receipt_long_outlined, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— None —')),
                        ...invoicesState.invoices
                            .where((i) =>
                                selectedCustomerId == null ||
                                i.customerId == selectedCustomerId)
                            .map((i) => DropdownMenuItem(
                                value: i.id,
                                child: Text(
                                    '${i.invoiceNumber} — UGX ${_fmt.format(i.total)}'))),
                      ],
                      onChanged: (v) => setS(() => selectedInvoiceId = v),
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextFormField(
                      controller: amtCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (UGX) *',
                        prefixIcon: Icon(Icons.attach_money, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Reason
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        prefixIcon: Icon(Icons.notes, size: 18),
                      ),
                      maxLines: 2,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Date + Status row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setS(() => selectedDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon:
                                    Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(dateFmt.format(selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<NoteStatus>(
                            value: selectedStatus,
                            decoration: const InputDecoration(
                                labelText: 'Status'),
                            items: NoteStatus.values
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name.toUpperCase())))
                                .toList(),
                            onChanged: (v) =>
                                setS(() => selectedStatus = v ?? selectedStatus),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Internal notes
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Internal Notes (optional)',
                        prefixIcon:
                            Icon(Icons.sticky_note_2_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    AttachmentPanel(
                      attachableType: 'credit-note',
                      localRecordId: noteId,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton.icon(
              icon: Icon(isEdit ? Icons.save : Icons.add, size: 18),
              label: Text(isEdit ? 'Save' : 'Create'),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now();
                final customer = ref
                    .read(customersProvider)
                    .customers
                    .cast<Customer?>()
                    .firstWhere((c) => c?.id == selectedCustomerId,
                        orElse: () => null);
                final invoice = selectedInvoiceId == null
                    ? null
                    : ref
                        .read(invoicesProvider)
                        .invoices
                        .cast<Invoice?>()
                        .firstWhere((i) => i?.id == selectedInvoiceId,
                            orElse: () => null);

                final cn = CreditNote(
                  id: noteId,
                  creditNoteNumber: numCtrl.text.trim(),
                  customerId: selectedCustomerId!,
                  customerName: customer?.name,
                  invoiceId: selectedInvoiceId,
                  invoiceNumber: invoice?.invoiceNumber,
                  date: selectedDate,
                  amount: double.parse(amtCtrl.text.trim()),
                  reason: reasonCtrl.text.trim(),
                  status: selectedStatus,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: note?.createdAt ?? now,
                  updatedAt: now,
                );

                if (isEdit) {
                  ref.read(creditNotesProvider.notifier).updateNote(cn);
                } else {
                  ref.read(creditNotesProvider.notifier).addNote(cn);
                }
                // Apply to invoice and post GL journal entry when issuing
                if (cn.status == NoteStatus.issued) {
                  if (cn.invoiceId != null) {
                    ref.read(invoicesProvider.notifier)
                        .recordPayment(cn.invoiceId!, cn.amount);
                  }
                  final wasAlreadyIssued = isEdit &&
                      (note?.status == NoteStatus.issued ||
                          note?.status == NoteStatus.applied);
                  if (!wasAlreadyIssued) {
                    _createCreditNoteJE(cn);
                  }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit
                      ? 'Credit note updated'
                      : 'Credit note issued — invoice balance updated'),
                  backgroundColor: AppColors.success,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Debit Note Dialog ─────────────────────────────────────────────────────

  void _showDebitNoteDialog(BuildContext context, {DebitNote? note}) {
    final isEdit = note != null;
    final formKey = GlobalKey<FormState>();
    final numCtrl = TextEditingController(
        text: note?.debitNoteNumber ?? _nextDebitNoteNo());
    final amtCtrl =
        TextEditingController(text: note == null ? '' : note.amount.toString());
    final reasonCtrl = TextEditingController(text: note?.reason ?? '');
    final notesCtrl = TextEditingController(text: note?.notes ?? '');

    final vendorsState = ref.read(vendorsProvider);
    final billsState = ref.read(billsProvider);
    String? selectedVendorId = note?.vendorId;
    String? selectedBillId = note?.billId;
    NoteStatus selectedStatus = note?.status ?? NoteStatus.draft;
    DateTime selectedDate = note?.date ?? DateTime.now();
    final dateFmt = DateFormat('MMM d, yyyy');
    // Pre-generate so attachments are stored immediately (reuse existing ID on edit).
    final debitNoteId = note?.id ?? const Uuid().v4();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.expense),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Debit Note' : 'New Debit Note'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.expense.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: AppColors.expense),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Journal: DR Accounts Payable  •  CR Expense/Account',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.expense),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note number
                    TextFormField(
                      controller: numCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Debit Note Number *',
                        prefixIcon: Icon(Icons.tag, size: 18),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Vendor
                    DropdownButtonFormField<String>(
                      value: selectedVendorId,
                      decoration: const InputDecoration(
                        labelText: 'Vendor *',
                        prefixIcon:
                            Icon(Icons.store_outlined, size: 18),
                      ),
                      items: vendorsState.vendors
                          .map((v) => DropdownMenuItem(
                              value: v.id, child: Text(v.name)))
                          .toList(),
                      onChanged: (v) => setS(() {
                        selectedVendorId = v;
                        selectedBillId = null;
                      }),
                      validator: (v) =>
                          v == null ? 'Please select a vendor' : null,
                    ),
                    const SizedBox(height: 12),

                    // Bill reference (optional)
                    DropdownButtonFormField<String>(
                      value: selectedBillId,
                      decoration: const InputDecoration(
                        labelText: 'Bill Reference (optional)',
                        prefixIcon:
                            Icon(Icons.description_outlined, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— None —')),
                        ...billsState.bills
                            .where((b) =>
                                selectedVendorId == null ||
                                b.vendorId == selectedVendorId)
                            .map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                    '${b.billNumber} — UGX ${_fmt.format(b.total)}'))),
                      ],
                      onChanged: (v) => setS(() => selectedBillId = v),
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextFormField(
                      controller: amtCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (UGX) *',
                        prefixIcon: Icon(Icons.attach_money, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Reason
                    TextFormField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        prefixIcon: Icon(Icons.notes, size: 18),
                      ),
                      maxLines: 2,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Date + Status row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setS(() => selectedDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon:
                                    Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(dateFmt.format(selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<NoteStatus>(
                            value: selectedStatus,
                            decoration: const InputDecoration(
                                labelText: 'Status'),
                            items: NoteStatus.values
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name.toUpperCase())))
                                .toList(),
                            onChanged: (v) =>
                                setS(() => selectedStatus = v ?? selectedStatus),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Internal notes
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Internal Notes (optional)',
                        prefixIcon:
                            Icon(Icons.sticky_note_2_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    AttachmentPanel(
                      attachableType: 'debit-note',
                      localRecordId: debitNoteId,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton.icon(
              icon: Icon(isEdit ? Icons.save : Icons.add, size: 18),
              label: Text(isEdit ? 'Save' : 'Create'),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now();
                final vendor = ref
                    .read(vendorsProvider)
                    .vendors
                    .cast<Vendor?>()
                    .firstWhere((v) => v?.id == selectedVendorId,
                        orElse: () => null);
                final bill = selectedBillId == null
                    ? null
                    : ref
                        .read(billsProvider)
                        .bills
                        .cast<Bill?>()
                        .firstWhere((b) => b?.id == selectedBillId,
                            orElse: () => null);

                final dn = DebitNote(
                  id: debitNoteId,
                  debitNoteNumber: numCtrl.text.trim(),
                  vendorId: selectedVendorId!,
                  vendorName: vendor?.name,
                  billId: selectedBillId,
                  billNumber: bill?.billNumber,
                  date: selectedDate,
                  amount: double.parse(amtCtrl.text.trim()),
                  reason: reasonCtrl.text.trim(),
                  status: selectedStatus,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: note?.createdAt ?? now,
                  updatedAt: now,
                );

                if (isEdit) {
                  ref.read(debitNotesProvider.notifier).updateNote(dn);
                } else {
                  ref.read(debitNotesProvider.notifier).addNote(dn);
                }
                // Apply to bill and post GL journal entry when issuing
                if (dn.status == NoteStatus.issued) {
                  if (dn.billId != null) {
                    ref.read(billsProvider.notifier)
                        .recordPayment(dn.billId!, dn.amount);
                  }
                  final wasAlreadyIssued = isEdit &&
                      (note?.status == NoteStatus.issued ||
                          note?.status == NoteStatus.applied);
                  if (!wasAlreadyIssued) {
                    _createDebitNoteJE(dn);
                  }
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEdit
                      ? 'Debit note updated'
                      : 'Debit note issued — bill balance updated'),
                  backgroundColor: AppColors.success,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm delete ────────────────────────────────────────────────────────

  void _confirmDeleteCreditNote(BuildContext context, CreditNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Credit Note'),
        content: Text(
            'Delete credit note ${note.creditNoteNumber}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(creditNotesProvider.notifier).deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDebitNote(BuildContext context, DebitNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Debit Note'),
        content: Text(
            'Delete debit note ${note.debitNoteNumber}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(debitNotesProvider.notifier).deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── GL Journal Entry helpers ──────────────────────────────────────────────

  /// Maps AccountType to a human-readable CoA category label shown in JE lines.
  String _coaCategory(AccountType? type) {
    switch (type) {
      case AccountType.asset:     return 'Asset';
      case AccountType.liability: return 'Liability';
      case AccountType.equity:    return 'Equity';
      case AccountType.revenue:   return 'Revenue';
      case AccountType.expense:   return 'Expense';
      default:                    return 'Account';
    }
  }

  /// Credit Note: DR Other Revenue (104), CR Accounts Receivable (150)
  /// Reduces both revenue and the customer's receivable balance.
  void _createCreditNoteJE(CreditNote cn) {
    final now = DateTime.now();
    final jeId = 'CN-JE-${cn.id}';
    final allAccounts = ref.read(accountsProvider).accounts;
    Account? lookupAcct(String id) => allAccounts
        .cast<Account?>()
        .firstWhere((a) => a?.id == id, orElse: () => null);

    final revenueAcct = lookupAcct('acct-104');
    final arAcct      = lookupAcct('acct-150');

    final je = JournalEntry(
      id: jeId,
      entryNumber: 'CN-JE-${cn.creditNoteNumber}',
      date: cn.date,
      description: 'Credit Note ${cn.creditNoteNumber}: ${cn.reason}',
      reference: cn.creditNoteNumber,
      status: JournalEntryStatus.posted,
      lines: [
        JournalLine(
          id: '$jeId-1',
          journalEntryId: jeId,
          accountId: 'acct-104',
          accountCode: '104',
          accountName: revenueAcct?.name ?? 'Other Revenue',
          debit: cn.amount,
          credit: 0,
          description: '[${_coaCategory(revenueAcct?.type ?? AccountType.revenue)}] ${cn.reason}',
        ),
        JournalLine(
          id: '$jeId-2',
          journalEntryId: jeId,
          accountId: 'acct-150',
          accountCode: '150',
          accountName: arAcct?.name ?? 'Accounts Receivable',
          debit: 0,
          credit: cn.amount,
          description: '[${_coaCategory(arAcct?.type ?? AccountType.asset)}] Credit applied to customer balance',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    ref.read(journalsProvider.notifier).addEntry(je);
  }

  /// Debit Note: DR Accounts Payable (164), CR original bill line accounts
  /// Reverses the expense accounts used in the referenced bill (proportionally).
  /// Falls back to Office Expenses (125) if no bill reference is found.
  void _createDebitNoteJE(DebitNote dn) {
    final now = DateTime.now();
    final jeId = 'DN-JE-${dn.id}';
    final allAccounts = ref.read(accountsProvider).accounts;
    Account? lookupAcct(String id) => allAccounts
        .cast<Account?>()
        .firstWhere((a) => a?.id == id, orElse: () => null);

    final apAcct = lookupAcct('acct-164');

    // Look up the referenced bill to get its expense accounts
    final bill = dn.billId == null
        ? null
        : ref.read(billsProvider).bills.cast<Bill?>().firstWhere(
              (b) => b?.id == dn.billId,
              orElse: () => null,
            );

    // Build credit lines: reverse the original bill's expense accounts
    final creditLines = <JournalLine>[];
    if (bill != null && bill.lines.isNotEmpty && bill.total > 0) {
      for (var i = 0; i < bill.lines.length; i++) {
        final l = bill.lines[i];
        final lineTotal = l.amount + l.taxAmount;
        if (lineTotal <= 0) continue;
        // Apportion debit note amount proportionally across bill lines
        final proportion = lineTotal / bill.total;
        final lineCredit = dn.amount * proportion;
        final acc = lookupAcct(l.accountId);
        final category = _coaCategory(acc?.type ?? AccountType.expense);
        final lineDesc = l.description.trim().isNotEmpty ? l.description.trim() : dn.reason;
        creditLines.add(JournalLine(
          id: '$jeId-cr-$i',
          journalEntryId: jeId,
          accountId: l.accountId,
          accountCode: l.accountId.replaceAll('acct-', ''),
          accountName: acc?.name ?? l.accountName ?? l.description,
          debit: 0,
          credit: lineCredit,
          description: '[$category] $lineDesc',
        ));
      }
    } else {
      // Fallback when no bill reference available
      final fallbackAcct = lookupAcct('acct-125');
      creditLines.add(JournalLine(
        id: '$jeId-cr-0',
        journalEntryId: jeId,
        accountId: 'acct-125',
        accountCode: '125',
        accountName: fallbackAcct?.name ?? 'Office Expenses',
        debit: 0,
        credit: dn.amount,
        description: '[${_coaCategory(fallbackAcct?.type ?? AccountType.expense)}] ${dn.reason}',
      ));
    }

    final je = JournalEntry(
      id: jeId,
      entryNumber: 'DN-JE-${dn.debitNoteNumber}',
      date: dn.date,
      description: 'Debit Note ${dn.debitNoteNumber}: ${dn.reason}',
      reference: dn.debitNoteNumber,
      status: JournalEntryStatus.posted,
      lines: [
        JournalLine(
          id: '$jeId-ap',
          journalEntryId: jeId,
          accountId: 'acct-164',
          accountCode: '164',
          accountName: apAcct?.name ?? 'Accounts Payable',
          debit: dn.amount,
          credit: 0,
          description: '[${_coaCategory(apAcct?.type ?? AccountType.liability)}] ${dn.reason}',
        ),
        ...creditLines,
      ],
      createdAt: now,
      updatedAt: now,
    );
    ref.read(journalsProvider.notifier).addEntry(je);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _nextCreditNoteNo() {
    final count = ref.read(creditNotesProvider).notes.length + 1;
    return 'CN-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
  }

  String _nextDebitNoteNo() {
    final count = ref.read(debitNotesProvider).notes.length + 1;
    return 'DN-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
  }

  Widget _noteStatusChip(NoteStatus status) {
    final (color, label) = switch (status) {
      NoteStatus.draft => (AppColors.warning, 'Draft'),
      NoteStatus.issued => (AppColors.info, 'Issued'),
      NoteStatus.applied => (AppColors.success, 'Applied'),
      NoteStatus.cancelled => (AppColors.error, 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAdd,
    required String addLabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64,
              color:
                  Theme.of(context).colorScheme.outline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  )),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withOpacity(0.7),
                  )),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(addLabel),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
