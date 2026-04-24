// Notes Providers — Credit Notes & Debit Notes
// Kept in core/providers so both the feature screen and the sync service can
// import them without creating a circular dependency.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/credit_debit_note.dart';
import '../services/local_storage_service.dart';

export '../models/credit_debit_note.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Credit Notes
// ─────────────────────────────────────────────────────────────────────────────

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

  /// Reload from local storage after a server pull.
  Future<void> reload() => _load();

  /// Replace entire list (called after a server pull overwrites local storage).
  void replaceAll(List<CreditNote> notes) {
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

  Future<void> clearAll() async {
    state = state.copyWith(notes: []);
    await _ls.saveCreditNotes([]);
  }
}

final creditNotesProvider =
    StateNotifierProvider<CreditNotesNotifier, CreditNotesState>(
  (_) => CreditNotesNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Debit Notes
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

  /// Reload from local storage after a server pull.
  Future<void> reload() => _load();

  /// Replace entire list (called after a server pull overwrites local storage).
  void replaceAll(List<DebitNote> notes) {
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

  Future<void> clearAll() async {
    state = state.copyWith(notes: []);
    await _ls.saveDebitNotes([]);
  }
}

final debitNotesProvider =
    StateNotifierProvider<DebitNotesNotifier, DebitNotesState>(
  (_) => DebitNotesNotifier(),
);
