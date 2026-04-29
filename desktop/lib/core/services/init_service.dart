import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_storage_service.dart';

/// Initialization Service
///
/// Handles first-time setup tasks and cached demo-data purge.
/// The SQLite / AppDatabase layer has been removed — all data now comes
/// directly from the server API.
class InitializationService {
  static const _storage = FlutterSecureStorage();
  static const _setupCompleteKey = 'magicbet_setup_complete';
  static const _setupVersionKey = 'magicbet_setup_version';
  static const _demoPurgedKey = 'demo_data_purged_v4';
  static const currentSetupVersion = '5.0.0';

  static Future<bool> isSetupComplete() async {
    final complete = await _storage.read(key: _setupCompleteKey);
    final version = await _storage.read(key: _setupVersionKey);
    return complete == 'true' && version == currentSetupVersion;
  }

  static Future<void> markSetupComplete() async {
    await _storage.write(key: _setupCompleteKey, value: 'true');
    await _storage.write(key: _setupVersionKey, value: currentSetupVersion);
  }

  static Future<void> resetSetup() async {
    await _storage.delete(key: _setupCompleteKey);
    await _storage.delete(key: _setupVersionKey);
  }

  /// Purge any locally cached demo data left over from prior offline-first
  /// builds. Runs once per install; subsequent calls are no-ops.
  static Future<void> purgeDemoData() async {
    final purged = await _storage.read(key: _demoPurgedKey);
    if (purged == 'true') return;

    final localStorage = LocalStorageService.instance;
    await localStorage.saveCustomers([]);
    await localStorage.saveVendors([]);
    await localStorage.saveInvoices([]);
    await localStorage.saveBills([]);
    await localStorage.saveJournalEntries([]);
    await localStorage.savePayments([]);
    await localStorage.saveAccounts([]);

    await _storage.write(key: _demoPurgedKey, value: 'true');
  }

  /// Called after every login. Clears demo data once, then marks setup done.
  static Future<void> checkAndRunSetup() async {
    await purgeDemoData();

    if (!await isSetupComplete()) {
      await markSetupComplete();
    }
  }
}
