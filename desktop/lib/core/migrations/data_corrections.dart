// One-time, versioned data-correction migrations.
//
// Code in here is allowed to be tied to one specific historical incident and
// to specific hardcoded record ids — that is the whole point. Each migration
// ships as a small bundled JSON asset (assets/migrations/*.json) describing
// exactly what to change, is checked against the CURRENT local data before
// anything is touched, and is recorded once applied so it never runs twice.
//
// A migration that ADDS records is retired here, deliberately. The first
// version of this file added corrected journal entries and skipped any whose
// id was already present — but the app had already posted its own entries for
// the same assets and months under DIFFERENT ids, so the id check passed and
// every August entry ended up posted twice. Matching on id alone is not a
// duplicate check; it only catches re-running the same migration.
//
// So migrations here only ever REMOVE records (by exact id, which is
// idempotent — an id is either present or it is not) and SET known-correct
// values. Anything that needs records created should go through the app's
// normal posting path, which has a real duplicate guard.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/journal_entry.dart';
import '../providers/depreciation_schedules_provider.dart';
import '../services/data_service.dart' show journalsProvider;
import '../services/local_storage_service.dart';

const _migrationAssetPaths = [
  'assets/migrations/depreciation_duplicate_cleanup_2026_09.json',
];

Future<void> runDataCorrectionMigrations(T Function<T>(ProviderListenable<T> provider) read) async {
  final storage = LocalStorageService.instance;
  await storage.initialize();
  final applied = await storage.getAppliedMigrations();

  for (final assetPath in _migrationAssetPaths) {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final id = payload['id'] as String;
      if (applied.contains(id)) continue;

      final ok = await _applyCorrection(read, payload);
      // Only record it as done if it actually ran against real data. A
      // machine whose ledger failed to load must get another chance on a
      // later launch rather than having the migration quietly marked off.
      if (ok) await storage.markMigrationApplied(id);
    } catch (e) {
      debugPrint('Data-correction migration $assetPath failed, will retry next launch: $e');
    }
  }
}

Future<bool> _applyCorrection(
    T Function<T>(ProviderListenable<T> provider) read, Map<String, dynamic> payload) async {
  final journalsNotifier = read(journalsProvider.notifier);
  final schedulesNotifier = read(depreciationSchedulesProvider.notifier);

  await journalsNotifier.ready;
  await schedulesNotifier.ready;

  final journalsState = read(journalsProvider);
  // Never edit a ledger the app could not read. Acting on an empty
  // in-memory list here would mean "none of these ids are present, nothing
  // to remove" — and the migration would mark itself done having fixed
  // nothing.
  if (journalsState.loadFailed) {
    debugPrint('Skipping correction: journals failed to load, will retry next launch');
    return false;
  }

  final entriesById = {for (final e in journalsState.entries) e.id: e};

  // Remove only entries that are still present AND still look like what this
  // migration was written against. If an entry's amount or date no longer
  // matches, something else has changed it since — leave it for a person.
  final removeIds = <String>[];
  for (final r in (payload['removeJournalEntries'] as List<dynamic>? ?? [])) {
    final m = r as Map<String, dynamic>;
    final entry = entriesById[m['id'] as String];
    if (entry == null) continue; // already gone — nothing to do

    final expectedAmount = (m['expectedAmount'] as num).toDouble();
    final actualAmount =
        entry.lines.fold(0.0, (s, l) => s + (l.debit > 0 ? l.debit : 0.0));
    final expectedDate = (m['expectedDate'] as String).substring(0, 10);
    final actualDate = entry.date.toIso8601String().substring(0, 10);

    if ((actualAmount - expectedAmount).abs() <= 1.0 && actualDate == expectedDate) {
      removeIds.add(entry.id);
    } else {
      debugPrint('Correction: leaving ${entry.id} alone — it no longer matches '
          'what this migration expected (amount/date changed)');
    }
  }

  // Schedules are set to a known-correct value rather than adjusted, so
  // applying this twice lands on the same place.
  final scheduleCorrections = <String, ({double currentValue, DateTime lastRunDate})>{};
  final schedulesById = {for (final s in read(depreciationSchedulesProvider)) s.id: s};
  for (final u in (payload['scheduleUpdates'] as List<dynamic>? ?? [])) {
    final m = u as Map<String, dynamic>;
    final id = m['id'] as String;
    if (!schedulesById.containsKey(id)) continue;
    scheduleCorrections[id] = (
      currentValue: (m['correctedCurrentValue'] as num).toDouble(),
      lastRunDate: DateTime.parse(m['correctedLastRunDate'] as String),
    );
  }

  if (removeIds.isNotEmpty) journalsNotifier.removeEntries(removeIds);
  if (scheduleCorrections.isNotEmpty) {
    await schedulesNotifier.applyCorrections(scheduleCorrections);
  }
  debugPrint('Correction "${payload['id']}": removed ${removeIds.length} entries, '
      'reset ${scheduleCorrections.length} schedules');
  return true;
}

// ---------------------------------------------------------------------------
// Read-only diagnostic — never writes anything. Reports what is actually
// posted per asset and month, flags any asset+month posted more than once,
// and shows monthly totals computed the same way the Income Statement
// computes them, so a figure on screen can be traced to real records.
// ---------------------------------------------------------------------------
Future<String> buildDepreciationDiagnosticReport(
    T Function<T>(ProviderListenable<T> provider) read) async {
  final buf = StringBuffer();
  final journalsNotifier = read(journalsProvider.notifier);
  await journalsNotifier.ready;

  final journalsState = read(journalsProvider);
  if (journalsState.loadFailed) {
    return 'The journals file could not be read on this machine, so there is '
        'nothing reliable to report yet. Reopen the app — it now repairs this '
        'automatically — and run this again.';
  }

  final allEntries = journalsState.entries;
  final schedules = read(depreciationSchedulesProvider);

  final storage = LocalStorageService.instance;
  await storage.initialize();
  final applied = await storage.getAppliedMigrations();
  buf.writeln('Applied corrections: ${applied.isEmpty ? "(none)" : applied.join(", ")}');
  buf.writeln('Journal entries loaded: ${allEntries.length}');
  buf.writeln();

  buf.writeln('SCHEDULES');
  buf.writeln(''.padRight(72, '-'));
  for (final s in schedules) {
    buf.writeln('${s.assetName}: currentValue=${s.currentValue.toStringAsFixed(2)} '
        'lastRunDate=${s.lastRunDate?.toIso8601String().substring(0, 10) ?? "never"} '
        'due=${s.isDue}');
  }
  buf.writeln();

  // Every posted depreciation/amortisation entry, grouped by asset+month, so
  // a double posting is visible as a count rather than inferred from a total.
  buf.writeln('POSTED DEPRECIATION / AMORTISATION BY ASSET AND MONTH');
  buf.writeln(''.padRight(72, '-'));
  final grouped = <String, List<double>>{};
  for (final e in allEntries) {
    if (e.status != JournalEntryStatus.posted) continue;
    final amount = e.lines
        .where((l) => (l.accountCode == '143' || l.accountCode == '180') && l.debit > 0)
        .fold(0.0, (s, l) => s + l.debit);
    if (amount <= 0) continue;
    final month = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
    grouped.putIfAbsent('$month  ${e.description}', () => []).add(amount);
  }
  final keys = grouped.keys.toList()..sort();
  for (final k in keys) {
    final v = grouped[k]!;
    final flag = v.length > 1 ? '   <== POSTED ${v.length} TIMES' : '';
    buf.writeln('$k  ${v.map((a) => a.toStringAsFixed(2)).join(" + ")}$flag');
  }
  buf.writeln();

  buf.writeln('MONTHLY TOTALS (same math as the Income Statement)');
  buf.writeln(''.padRight(72, '-'));
  for (final entry in [('143', 'Depreciation'), ('180', 'Amortization Expense')]) {
    final code = entry.$1, label = entry.$2;
    final byMonth = <String, double>{};
    for (final e in allEntries) {
      if (e.status != JournalEntryStatus.posted) continue;
      final month = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      for (final l in e.lines) {
        if (l.accountCode == code) {
          byMonth[month] = (byMonth[month] ?? 0) + l.debit - l.credit;
        }
      }
    }
    buf.writeln('$label (acct $code):');
    for (final m in byMonth.keys.toList()..sort()) {
      buf.writeln('   $m: ${byMonth[m]!.toStringAsFixed(2)}');
    }
  }

  return buf.toString();
}
