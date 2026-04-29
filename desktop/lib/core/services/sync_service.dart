// No-op sync service stub for Flutter Web (always-online).
// The app talks directly to the API; there is no local queue or offline sync.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart' show SyncEntityType, SyncAction;

// ---------------------------------------------------------------------------
// SyncState — all fields are neutral defaults (no syncing, nothing pending)
// ---------------------------------------------------------------------------

class SyncState {
  final bool isSyncing;
  final int pendingChanges;
  final DateTime? lastSyncTime;
  final double progress;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.pendingChanges = 0,
    this.lastSyncTime,
    this.progress = 0.0,
    this.error,
  });
}

// ---------------------------------------------------------------------------
// SyncService — no-op notifier
// ---------------------------------------------------------------------------

class SyncService extends StateNotifier<SyncState> {
  SyncService() : super(const SyncState());

  /// No-op: data is always online; nothing to sync.
  Future<void> syncAll() async {}

  /// No-op: there is no local queue in the web app.
  void queueChange({
    required SyncAction action,
    required SyncEntityType entityType,
    required String entityId,
    Map<String, dynamic>? data,
  }) {}

  /// No-op: no local cache exists on the web.
  Future<void> clearLocalCache() async {}

  /// No-op: deletion is handled directly via API calls.
  Future<void> deleteAllCloudData() async {}
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncState>((ref) => SyncService());
