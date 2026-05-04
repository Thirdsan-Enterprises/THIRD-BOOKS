import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/app_database.dart';
import '../utils/magic_bet_setup.dart';
import 'local_storage_service.dart';

/// Initialization Service
///
/// Handles first-time setup tasks:
/// - Run MagicBet setup (import outlets, configure system)
/// - Initialize chart of accounts
/// - Set commission rates
/// - Clear demo data from ThirdBooks API on upgrade
class InitializationService {
  static const _storage = FlutterSecureStorage();
  static const _setupCompleteKey = 'magicbet_setup_complete';
  static const _setupVersionKey = 'magicbet_setup_version';
  static const _demoPurgedKey = 'demo_data_purged_v4';
  // All previous purge-key versions — if any of these are set the user has
  // already gone through the one-time wipe, so we must not wipe again.
  static const _legacyPurgeKeys = [
    'demo_data_purged_v1',
    'demo_data_purged_v2',
    'demo_data_purged_v3',
  ];
  static const currentSetupVersion = '4.0.0';

  /// Check if initial setup has been completed
  static Future<bool> isSetupComplete() async {
    final complete = await _storage.read(key: _setupCompleteKey);
    final version = await _storage.read(key: _setupVersionKey);

    // If setup is marked complete and version matches, return true
    if (complete == 'true' && version == currentSetupVersion) {
      return true;
    }

    return false;
  }

  /// Mark setup as complete
  static Future<void> markSetupComplete() async {
    await _storage.write(key: _setupCompleteKey, value: 'true');
    await _storage.write(key: _setupVersionKey, value: currentSetupVersion);
  }

  /// Reset setup status (for testing/re-initialization)
  static Future<void> resetSetup() async {
    await _storage.delete(key: _setupCompleteKey);
    await _storage.delete(key: _setupVersionKey);
  }

  /// Purge demo data from ThirdBooks API that was cached in local storage.
  /// Runs once on first install to remove any fake data fetched from
  /// api.thirdbooks.digital and seed the MagicBet Chart of Accounts.
  ///
  /// Only accounts are wiped — they are always re-seeded from the MagicBet
  /// CoA.  Bills, invoices, journals, payments, customers, and vendors are
  /// user data and must never be cleared by this migration, even when the
  /// purge key is bumped to a new version.
  static Future<void> purgeDemoData() async {
    final purged = await _storage.read(key: _demoPurgedKey);
    if (purged == 'true') return;

    // If any previous-version purge key is set, the one-time wipe already ran
    // on an older build.  Just stamp the new key so we don't repeat the wipe
    // and destroy user data (bills, invoices, etc.).
    for (final legacyKey in _legacyPurgeKeys) {
      final prev = await _storage.read(key: legacyKey);
      if (prev == 'true') {
        await _storage.write(key: _demoPurgedKey, value: 'true');
        print('Previous purge detected ($legacyKey) — skipping data wipe, stamping $currentSetupVersion.');
        return;
      }
    }

    print('First-time purge: clearing demo accounts so MagicBet CoA can be seeded...');
    final localStorage = LocalStorageService.instance;
    await localStorage.initialize();

    // Only reset accounts — everything else is user-created data that must
    // survive reinstalls and version upgrades.
    await localStorage.saveAccounts([]);

    await _storage.write(key: _demoPurgedKey, value: 'true');
    print('Demo accounts cleared. MagicBet CoA will be seeded on next load.');
  }

  /// Run the complete MagicBet initialization
  static Future<void> runMagicBetSetup(AppDatabase db) async {
    try {
      print('Starting MagicBet initialization...');

      // First purge any cached demo data from ThirdBooks API
      await purgeDemoData();

      // Seed the 72 MagicBet outlet locations into local SQLite
      await db.seedOutlets();

      // Mark setup as complete
      await markSetupComplete();

      print('MagicBet initialization completed successfully!');
    } catch (e) {
      print('MagicBet initialization failed: $e');
      rethrow;
    }
  }

  /// Check and run setup if needed.
  ///
  /// Called after every login. Always ensures the 72 outlet locations are
  /// present in the database (idempotent — seedOutlets only inserts missing
  /// codes, so this is fast after the first run).
  static Future<bool> checkAndRunSetup(AppDatabase db) async {
    // Always purge demo data on upgrade (idempotent - only runs once)
    await purgeDemoData();

    final setupComplete = await isSetupComplete();

    if (!setupComplete) {
      print('First-time setup detected. Running MagicBet initialization...');
      await runMagicBetSetup(db);
      return true; // Full setup was run
    }

    // Even when setup is flagged complete, always ensure outlets are seeded.
    // Handles: clearAllData() called, DB migrated with stale codes, fresh DB
    // on a new machine where onCreate already ran but old codes were used.
    await db.seedOutlets();
    print('MagicBet outlets verified.');
    return false; // Setup was already complete
  }
}
