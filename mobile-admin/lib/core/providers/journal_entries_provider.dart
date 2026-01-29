import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Journal entry with lines for display
class JournalEntryWithLines {
  final JournalEntry entry;
  final List<JournalEntryLine> lines;
  final Map<String, Account> accountsMap;

  JournalEntryWithLines({
    required this.entry,
    required this.lines,
    required this.accountsMap,
  });

  bool get isBalanced => entry.totalDebit == entry.totalCredit;
}

/// State for journal entries
class JournalEntriesState {
  final List<JournalEntry> entries;
  final bool isLoading;
  final String? error;
  final String? statusFilter;
  final DateTimeRange? dateRange;

  const JournalEntriesState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.statusFilter,
    this.dateRange,
  });

  JournalEntriesState copyWith({
    List<JournalEntry>? entries,
    bool? isLoading,
    String? error,
    String? statusFilter,
    DateTimeRange? dateRange,
  }) {
    return JournalEntriesState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      dateRange: dateRange ?? this.dateRange,
    );
  }

  List<JournalEntry> get filteredEntries {
    var result = entries;

    if (statusFilter != null && statusFilter!.isNotEmpty) {
      result = result.where((e) => e.status == statusFilter).toList();
    }

    if (dateRange != null) {
      result = result.where((e) =>
          e.entryDate.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
          e.entryDate.isBefore(dateRange!.end.add(const Duration(days: 1)))).toList();
    }

    return result;
  }

  List<JournalEntry> get draftEntries =>
      entries.where((e) => e.status == 'draft').toList();

  List<JournalEntry> get postedEntries =>
      entries.where((e) => e.status == 'posted').toList();
}

/// Date range helper class
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({required this.start, required this.end});
}

/// Provider for managing journal entries
class JournalEntriesNotifier extends StateNotifier<JournalEntriesState> {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  JournalEntriesNotifier(this._db) : super(const JournalEntriesState()) {
    loadJournalEntries();
  }

  Future<void> loadJournalEntries() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final entries = await _db.getAllJournalEntries();
      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status);
  }

  void setDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: range);
  }

  Future<String> generateNextNumber() async {
    final entries = await _db.getAllJournalEntries();
    int maxNum = 0;
    for (final entry in entries) {
      final match = RegExp(r'JE-(\d+)').firstMatch(entry.entryNumber);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'JE-${(maxNum + 1).toString().padLeft(5, '0')}';
  }

  Future<String> createJournalEntry({
    required DateTime entryDate,
    required String description,
    required List<Map<String, dynamic>> lines,
    String? entryNumber,
    String? reference,
    String? sourceType,
    String? sourceId,
    String currencyCode = 'UGX',
    double exchangeRate = 1.0,
    required String createdBy,
    bool postImmediately = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final number = entryNumber ?? await generateNextNumber();

    // Calculate totals
    double totalDebit = 0;
    double totalCredit = 0;

    for (final line in lines) {
      totalDebit += (line['debit_amount'] as num?)?.toDouble() ?? 0.0;
      totalCredit += (line['credit_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Validate balance
    if ((totalDebit - totalCredit).abs() > 0.001) {
      throw Exception('Journal entry must be balanced. Debit: $totalDebit, Credit: $totalCredit');
    }

    final status = postImmediately ? 'posted' : 'draft';

    // Insert journal entry
    await _db.insertJournalEntry(JournalEntriesCompanion.insert(
      id: id,
      entryNumber: number,
      entryDate: entryDate,
      reference: Value(reference),
      description: description,
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      status: Value(status),
      totalDebit: Value(totalDebit),
      totalCredit: Value(totalCredit),
      currencyCode: Value(currencyCode),
      exchangeRate: Value(exchangeRate),
      postedAt: postImmediately ? Value(now) : const Value.absent(),
      postedBy: postImmediately ? Value(createdBy) : const Value.absent(),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    ));

    // Insert lines
    int lineOrder = 0;
    for (final line in lines) {
      final lineId = _uuid.v4();
      await _db.insertJournalEntryLine(JournalEntryLinesCompanion.insert(
        id: lineId,
        journalEntryId: id,
        accountId: line['account_id'] as String,
        description: Value(line['description'] as String?),
        debitAmount: Value((line['debit_amount'] as num?)?.toDouble() ?? 0.0),
        creditAmount: Value((line['credit_amount'] as num?)?.toDouble() ?? 0.0),
        currencyCode: Value(currencyCode),
        exchangeRate: Value(exchangeRate),
        lineOrder: Value(lineOrder++),
        createdAt: now,
        updatedAt: now,
      ));
    }

    // If posting immediately, update account balances
    if (postImmediately) {
      await _postToGeneralLedger(id, entryDate, lines, createdBy);
    }

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'journal_entry',
      aggregateId: id,
      eventType: 'journal_entry_created',
      eventData: jsonEncode({
        'id': id,
        'entry_number': number,
        'entry_date': entryDate.toIso8601String(),
        'description': description,
        'reference': reference,
        'source_type': sourceType,
        'source_id': sourceId,
        'status': status,
        'total_debit': totalDebit,
        'total_credit': totalCredit,
        'lines': lines,
      }),
      deviceId: '',
      userId: createdBy,
      occurredAt: now,
    ));

    await loadJournalEntries();
    return id;
  }

  Future<void> postJournalEntry(String id, String postedBy) async {
    final entry = await _db.getJournalEntryById(id);
    if (entry == null) throw Exception('Journal entry not found');
    if (entry.status == 'posted') throw Exception('Journal entry already posted');

    final now = DateTime.now();
    final lines = await _db.getJournalEntryLines(id);

    // Update entry status
    await _db.updateJournalEntry(id, JournalEntriesCompanion(
      status: const Value('posted'),
      postedAt: Value(now),
      postedBy: Value(postedBy),
      updatedAt: Value(now),
    ));

    // Post to general ledger
    final linesMaps = lines.map((l) => {
      'account_id': l.accountId,
      'description': l.description,
      'debit_amount': l.debitAmount,
      'credit_amount': l.creditAmount,
    }).toList();

    await _postToGeneralLedger(id, entry.entryDate, linesMaps, postedBy);

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'journal_entry',
      aggregateId: id,
      eventType: 'journal_entry_posted',
      eventData: jsonEncode({
        'id': id,
        'posted_at': now.toIso8601String(),
        'posted_by': postedBy,
      }),
      deviceId: '',
      userId: postedBy,
      occurredAt: now,
    ));

    await loadJournalEntries();
  }

  Future<void> _postToGeneralLedger(
    String journalEntryId,
    DateTime transactionDate,
    List<Map<String, dynamic>> lines,
    String userId,
  ) async {
    for (final line in lines) {
      final accountId = line['account_id'] as String;
      final debit = (line['debit_amount'] as num?)?.toDouble() ?? 0.0;
      final credit = (line['credit_amount'] as num?)?.toDouble() ?? 0.0;

      // Get account to determine normal balance
      final account = await _db.getAccountById(accountId);
      if (account == null) continue;

      final accountType = await _db.getAccountTypeById(account.accountTypeId);
      if (accountType == null) continue;

      // Calculate new balance based on normal balance
      double balanceChange;
      if (accountType.normalBalance == 'debit') {
        balanceChange = debit - credit;
      } else {
        balanceChange = credit - debit;
      }

      // Update account balance
      final newBalance = account.currentBalance + balanceChange;
      await _db.updateAccount(accountId, AccountsCompanion(
        currentBalance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ));

      // Insert general ledger entry
      await _db.insertGeneralLedgerEntry(GeneralLedgerCompanion.insert(
        id: _uuid.v4(),
        accountId: accountId,
        journalEntryId: journalEntryId,
        journalEntryLineId: _uuid.v4(),
        transactionDate: transactionDate,
        description: Value(line['description'] as String?),
        debitAmount: Value(debit),
        creditAmount: Value(credit),
        runningBalance: Value(newBalance),
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> voidJournalEntry(String id, String userId) async {
    final entry = await _db.getJournalEntryById(id);
    if (entry == null) throw Exception('Journal entry not found');
    if (entry.status == 'void') throw Exception('Journal entry already voided');

    final now = DateTime.now();

    // If posted, reverse the GL entries
    if (entry.status == 'posted') {
      final lines = await _db.getJournalEntryLines(id);
      for (final line in lines) {
        final account = await _db.getAccountById(line.accountId);
        if (account == null) continue;

        final accountType = await _db.getAccountTypeById(account.accountTypeId);
        if (accountType == null) continue;

        // Reverse the balance change
        double balanceChange;
        if (accountType.normalBalance == 'debit') {
          balanceChange = line.creditAmount - line.debitAmount;
        } else {
          balanceChange = line.debitAmount - line.creditAmount;
        }

        final newBalance = account.currentBalance + balanceChange;
        await _db.updateAccount(line.accountId, AccountsCompanion(
          currentBalance: Value(newBalance),
          updatedAt: Value(now),
        ));
      }
    }

    // Update entry status
    await _db.updateJournalEntry(id, JournalEntriesCompanion(
      status: const Value('void'),
      updatedAt: Value(now),
    ));

    // Create local event for sync
    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'journal_entry',
      aggregateId: id,
      eventType: 'journal_entry_voided',
      eventData: jsonEncode({
        'id': id,
        'voided_at': now.toIso8601String(),
        'voided_by': userId,
      }),
      deviceId: '',
      userId: userId,
      occurredAt: now,
    ));

    await loadJournalEntries();
  }

  Future<void> deleteJournalEntry(String id) async {
    final entry = await _db.getJournalEntryById(id);
    if (entry != null && entry.status == 'posted') {
      throw Exception('Cannot delete a posted journal entry. Void it instead.');
    }

    await _db.deleteJournalEntry(id);

    await _db.insertLocalEvent(LocalEventsCompanion.insert(
      id: _uuid.v4(),
      tenantId: '',
      aggregateType: 'journal_entry',
      aggregateId: id,
      eventType: 'journal_entry_deleted',
      eventData: jsonEncode({'id': id}),
      deviceId: '',
      userId: '',
      occurredAt: DateTime.now(),
    ));

    await loadJournalEntries();
  }

  Future<JournalEntryWithLines?> getJournalEntryWithLines(String id) async {
    final entry = await _db.getJournalEntryById(id);
    if (entry == null) return null;

    final lines = await _db.getJournalEntryLines(id);
    final accounts = await _db.getAllAccounts();
    final accountsMap = {for (var a in accounts) a.id: a};

    return JournalEntryWithLines(
      entry: entry,
      lines: lines,
      accountsMap: accountsMap,
    );
  }
}

/// Provider instance
final journalEntriesProvider =
    StateNotifierProvider<JournalEntriesNotifier, JournalEntriesState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return JournalEntriesNotifier(db);
});

/// Provider for a single journal entry with lines
final journalEntryWithLinesProvider =
    FutureProvider.family<JournalEntryWithLines?, String>((ref, id) async {
  final notifier = ref.watch(journalEntriesProvider.notifier);
  return notifier.getJournalEntryWithLines(id);
});

/// Stream provider for watching journal entries
final journalEntriesStreamProvider = StreamProvider<List<JournalEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllJournalEntries();
});

/// Provider for journal entry lines by entry ID
final journalEntryLinesProvider =
    FutureProvider.family<List<JournalEntryLine>, String>((ref, entryId) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getJournalEntryLines(entryId);
});

/// Alias for posting journal entry
extension JournalEntriesNotifierX on JournalEntriesNotifier {
  Future<void> postEntry(String id) => postJournalEntry(id, 'user');
}
