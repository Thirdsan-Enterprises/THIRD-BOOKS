// Local Bank Statements Provider
// Stores CSV-parsed bank statements on device so they are visible offline.
// Server sync is attempted in the background; status reflects outcome.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class LocalBankStatement {
  final String id;
  final String fileName;
  final String? bankAccountId;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final DateTime fromDate;
  final DateTime toDate;
  /// Parsed CSV rows — first item is the header row.
  final List<List<String>> rows;
  /// Opening balance at the start of the statement period.
  final double? openingBalance;
  /// Closing balance at the end of the statement period.
  final double? closingBalance;
  /// 'local' = not yet synced, 'synced' = accepted by server.
  final String status;
  /// Server-assigned ID once the statement is synced.
  final int? serverStatementId;
  final DateTime uploadedAt;
  /// IDs of journal entries created during reconciliation of this statement.
  /// Used to reverse them when the statement is deleted.
  final List<String> jeIds;

  const LocalBankStatement({
    required this.id,
    required this.fileName,
    this.bankAccountId,
    this.bankAccountName,
    this.bankAccountNumber,
    required this.fromDate,
    required this.toDate,
    required this.rows,
    this.openingBalance,
    this.closingBalance,
    this.status = 'local',
    this.serverStatementId,
    required this.uploadedAt,
    this.jeIds = const [],
  });

  int get lineCount => rows.isEmpty ? 0 : rows.length - 1; // exclude header

  LocalBankStatement copyWith({
    String? status,
    int? serverStatementId,
    double? openingBalance,
    double? closingBalance,
    List<String>? jeIds,
  }) =>
      LocalBankStatement(
        id: id,
        fileName: fileName,
        bankAccountId: bankAccountId,
        bankAccountName: bankAccountName,
        bankAccountNumber: bankAccountNumber,
        fromDate: fromDate,
        toDate: toDate,
        rows: rows,
        openingBalance: openingBalance ?? this.openingBalance,
        closingBalance: closingBalance ?? this.closingBalance,
        status: status ?? this.status,
        serverStatementId: serverStatementId ?? this.serverStatementId,
        uploadedAt: uploadedAt,
        jeIds: jeIds ?? this.jeIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'bankAccountId': bankAccountId,
        'bankAccountName': bankAccountName,
        'bankAccountNumber': bankAccountNumber,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'rows': rows,
        'openingBalance': openingBalance,
        'closingBalance': closingBalance,
        'status': status,
        'serverStatementId': serverStatementId,
        'uploadedAt': uploadedAt.toIso8601String(),
        'jeIds': jeIds,
      };

  factory LocalBankStatement.fromJson(Map<String, dynamic> j) {
    final rawRows = j['rows'] as List<dynamic>? ?? [];
    final rows = rawRows
        .map((r) => (r as List<dynamic>).map((c) => c.toString()).toList())
        .toList();
    final rawJeIds = j['jeIds'] as List<dynamic>? ?? [];
    return LocalBankStatement(
      id: j['id'] as String,
      fileName: j['fileName'] as String,
      bankAccountId: j['bankAccountId'] as String?,
      bankAccountName: j['bankAccountName'] as String?,
      bankAccountNumber: j['bankAccountNumber'] as String?,
      fromDate: DateTime.parse(j['fromDate'] as String),
      toDate: DateTime.parse(j['toDate'] as String),
      rows: rows,
      openingBalance: (j['openingBalance'] as num?)?.toDouble(),
      closingBalance: (j['closingBalance'] as num?)?.toDouble(),
      status: j['status'] as String? ?? 'local',
      serverStatementId: j['serverStatementId'] as int?,
      uploadedAt: DateTime.parse(j['uploadedAt'] as String),
      jeIds: rawJeIds.map((e) => e.toString()).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------
class LocalBankStatementsNotifier
    extends StateNotifier<List<LocalBankStatement>> {
  final LocalStorageService _storage;

  LocalBankStatementsNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _storage.loadData(
          'local_bank_statements', LocalBankStatement.fromJson);
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    await _storage.saveData(
        'local_bank_statements', state, (s) => s.toJson());
  }

  Future<void> add(LocalBankStatement stmt) async {
    state = [stmt, ...state];
    await _save();
  }

  Future<void> markSynced(String id, int serverStatementId) async {
    state = state
        .map((s) => s.id == id
            ? s.copyWith(status: 'synced', serverStatementId: serverStatementId)
            : s)
        .toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  Future<void> updateJeIds(String id, List<String> jeIds) async {
    state = state
        .map((s) => s.id == id ? s.copyWith(jeIds: jeIds) : s)
        .toList();
    await _save();
  }

  /// Clear all statements — used by the settings "clear cache" action.
  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final localBankStatementsProvider = StateNotifierProvider<
    LocalBankStatementsNotifier, List<LocalBankStatement>>(
  (ref) => LocalBankStatementsNotifier(ref.read(localStorageServiceProvider)),
);
