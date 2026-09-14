// One-time, versioned data-correction migrations.
//
// Unlike the rest of the app, code in here is allowed to be tied to one
// specific historical incident and even to specific hardcoded record ids —
// that is the whole point. Each migration ships as a small bundled JSON
// asset (assets/migrations/*.json) describing an exact known-bad state and
// its correction. At startup, every value is checked against the CURRENT
// local data before anything is touched, so a migration is a safe no-op on
// any machine whose data doesn't match — a different install, or one
// already corrected some other way (e.g. a manual file swap done before
// this shipped). Applied migrations are recorded on disk so none of this
// ever runs twice.
//
// Each entry below should be deleted (and its asset file removed) once
// confirmed applied everywhere it needs to be — this is meant to be
// temporary, same as the emergency diagnostic endpoints elsewhere in this
// codebase (see sync-server/debug_log.php).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/journal_entry.dart';
import '../providers/depreciation_schedules_provider.dart';
import '../services/data_service.dart' show journalsProvider;
import '../services/local_storage_service.dart';

const _migrationAssetPaths = [
  'assets/migrations/depreciation_correction_2026_09.json',
];

Future<void> runDataCorrectionMigrations(Ref ref) async {
  final storage = LocalStorageService.instance;
  await storage.initialize();
  final applied = await storage.getAppliedMigrations();

  for (final assetPath in _migrationAssetPaths) {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final id = payload['id'] as String;
      if (applied.contains(id)) continue;

      await _applyDepreciationCorrection(ref, payload);
      await storage.markMigrationApplied(id);
    } catch (e) {
      // Never block app startup on this. Not marking as applied means it
      // simply gets re-evaluated (and re-attempted) on the next launch.
      debugPrint('Data-correction migration $assetPath failed, will retry next launch: $e');
    }
  }
}

Future<void> _applyDepreciationCorrection(Ref ref, Map<String, dynamic> payload) async {
  final journalsNotifier = ref.read(journalsProvider.notifier);
  final schedulesNotifier = ref.read(depreciationSchedulesProvider.notifier);

  await journalsNotifier.ready;
  await schedulesNotifier.ready;

  final currentEntryIds = ref.read(journalsProvider).entries.map((e) => e.id).toSet();
  final currentSchedulesById = {
    for (final s in ref.read(depreciationSchedulesProvider)) s.id: s,
  };

  // Only remove ids that are actually still present (already removed some
  // other way is a no-op, not an error) and only add entries whose id isn't
  // already there (so this is safe to evaluate even after a manual fix).
  final removeIds = ((payload['removeJournalEntryIds'] as List<dynamic>?) ?? [])
      .map((e) => e.toString())
      .where(currentEntryIds.contains)
      .toSet();

  final addEntries = ((payload['addJournalEntries'] as List<dynamic>?) ?? [])
      .map((j) => JournalEntry.fromJson(j as Map<String, dynamic>))
      .where((e) => !currentEntryIds.contains(e.id))
      .toList();

  // Only correct a schedule whose current book value still exactly matches
  // the known-bad figure this migration was written against. Matches the
  // already-corrected figure → leave it (already fixed some other way).
  // Matches neither → something else changed this schedule since the
  // incident was diagnosed; never guess, leave it alone for manual review
  // rather than silently overwriting a book value we can no longer verify.
  const epsilon = 1.0; // UGX — comfortably tighter than any real rounding drift
  final scheduleCorrections = <String, ({double currentValue, DateTime lastRunDate})>{};
  for (final u in (payload['scheduleUpdates'] as List<dynamic>? ?? [])) {
    final m = u as Map<String, dynamic>;
    final id = m['id'] as String;
    final schedule = currentSchedulesById[id];
    if (schedule == null) continue; // asset no longer exists here

    final expectedBad = (m['expectedBadCurrentValue'] as num).toDouble();
    if ((schedule.currentValue - expectedBad).abs() <= epsilon) {
      scheduleCorrections[id] = (
        currentValue: (m['correctedCurrentValue'] as num).toDouble(),
        lastRunDate: DateTime.parse(m['correctedLastRunDate'] as String),
      );
    }
  }

  if (removeIds.isNotEmpty) journalsNotifier.removeEntries(removeIds.toList());
  if (addEntries.isNotEmpty) await journalsNotifier.addEntries(addEntries);
  if (scheduleCorrections.isNotEmpty) {
    await schedulesNotifier.applyCorrections(scheduleCorrections);
  }
}

// ---------------------------------------------------------------------------
// Read-only diagnostic — never writes anything. Traces exactly what the
// 2026-09 depreciation correction expected to find against what a machine's
// data ACTUALLY holds right now: which of the 13 known schedules are
// corrected / still on the known-bad figure / diverged into a third,
// unrecognized state, and whether any DEPR-/AMRT- journal entry exists more
// than once for the same asset+month (duplicate posting). Exists so this
// can be answered directly from the app (Settings → "Diagnose Depreciation
// Correction") instead of reverse-engineering it from report screenshots.
// ---------------------------------------------------------------------------
Future<String> buildDepreciationDiagnosticReport(Ref ref) async {
  const assetPath = 'assets/migrations/depreciation_correction_2026_09.json';
  final buf = StringBuffer();

  Map<String, dynamic> payload;
  try {
    final raw = await rootBundle.loadString(assetPath);
    payload = jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    return 'Could not load $assetPath: $e';
  }

  final journalsNotifier = ref.read(journalsProvider.notifier);
  await journalsNotifier.ready;
  final allEntries = ref.read(journalsProvider).entries;
  final schedules = ref.read(depreciationSchedulesProvider);
  final schedulesById = {for (final s in schedules) s.id: s};

  final storage = LocalStorageService.instance;
  await storage.initialize();
  final applied = await storage.getAppliedMigrations();
  buf.writeln('Migration "${payload['id']}" applied on this machine: '
      '${applied.contains(payload['id']) ? "YES" : "NO"}');
  buf.writeln();

  // ── Per-asset schedule state ────────────────────────────────────────────
  buf.writeln('SCHEDULES (13 known assets from the correction payload)');
  buf.writeln(''.padRight(72, '-'));
  const epsilon = 1.0;
  final knownReferences = <String>{
    for (final e in (payload['addJournalEntries'] as List<dynamic>? ?? []))
      if ((e as Map<String, dynamic>)['reference'] != null) e['reference'] as String,
  };
  for (final u in (payload['scheduleUpdates'] as List<dynamic>? ?? [])) {
    final m = u as Map<String, dynamic>;
    final id = m['id'] as String;
    final name = m['assetName'] as String;
    final expectedBad = (m['expectedBadCurrentValue'] as num).toDouble();
    final corrected = (m['correctedCurrentValue'] as num).toDouble();
    final schedule = schedulesById[id];

    if (schedule == null) {
      buf.writeln('$name: NOT FOUND on this machine');
      continue;
    }

    final String status;
    if ((schedule.currentValue - expectedBad).abs() <= epsilon) {
      status = 'MATCHES KNOWN-BAD (not yet corrected)';
    } else if ((schedule.currentValue - corrected).abs() <= epsilon) {
      status = 'MATCHES CORRECTED';
    } else {
      status = 'DIVERGED — matches neither known-bad nor corrected figure';
    }
    buf.writeln('$name: currentValue=${schedule.currentValue.toStringAsFixed(2)} '
        'lastRunDate=${schedule.lastRunDate?.toIso8601String().substring(0, 10)} — $status');
  }
  buf.writeln();

  // ── Actual posted entries for each known reference, by month ───────────
  buf.writeln('POSTED ENTRIES for the 13 known DEPR-/AMRT- reference codes');
  buf.writeln(''.padRight(72, '-'));
  final byRefMonth = <String, Map<int, List<JournalEntry>>>{};
  for (final e in allEntries) {
    final refCode = e.reference;
    if (refCode == null || !knownReferences.contains(refCode)) continue;
    if (e.status != JournalEntryStatus.posted) continue;
    final ym = e.date.year * 100 + e.date.month;
    (byRefMonth[refCode] ??= {}).putIfAbsent(ym, () => []).add(e);
  }
  if (byRefMonth.isEmpty) {
    buf.writeln('(none found)');
  } else {
    for (final refCode in byRefMonth.keys.toList()..sort()) {
      final byMonth = byRefMonth[refCode]!;
      for (final ym in byMonth.keys.toList()..sort()) {
        final entries = byMonth[ym]!;
        final y = ym ~/ 100, m = ym % 100;
        final flag = entries.length > 1 ? '  <== DUPLICATE (${entries.length} entries)' : '';
        buf.writeln('$refCode  $y-${m.toString().padLeft(2, '0')}$flag');
        for (final e in entries) {
          final amt = e.lines.fold(0.0, (s, l) => s + l.debit);
          buf.writeln('    id=${e.id}  date=${e.date.toIso8601String().substring(0, 10)}  amount=${amt.toStringAsFixed(2)}');
        }
      }
    }
  }
  buf.writeln();

  // ── Monthly totals for accounts 143/180 — mirrors the Income Statement's
  // own grouping exactly (sum of debit, posted entries only, by month) so
  // this can be compared line-for-line against what a report shows. ──────
  buf.writeln('MONTHLY TOTALS (matches Income Statement math exactly)');
  buf.writeln(''.padRight(72, '-'));
  for (final entry in [('143', 'Depreciation'), ('180', 'Amortization Expense')]) {
    final code = entry.$1, label = entry.$2;
    final byMonth = <int, double>{};
    for (final e in allEntries) {
      if (e.status != JournalEntryStatus.posted) continue;
      final ym = e.date.year * 100 + e.date.month;
      for (final line in e.lines) {
        if (line.accountCode == code) {
          byMonth[ym] = (byMonth[ym] ?? 0) + line.debit - line.credit;
        }
      }
    }
    buf.writeln('$label (acct $code):');
    for (final ym in byMonth.keys.toList()..sort()) {
      final y = ym ~/ 100, m = ym % 100;
      buf.writeln('   $y-${m.toString().padLeft(2, '0')}: ${byMonth[ym]!.toStringAsFixed(2)}');
    }
  }

  return buf.toString();
}
