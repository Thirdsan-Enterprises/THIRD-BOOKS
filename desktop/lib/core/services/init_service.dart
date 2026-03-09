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
  static const _demoPurgedKey = 'demo_data_purged_v3';
  static const currentSetupVersion = '3.0.0';

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
  /// This runs once on upgrade to v2.0.0 to remove all fake data
  /// (customers, vendors, invoices, bills, journals, payments)
  /// that was fetched from api.thirdbooks.digital.
  static Future<void> purgeDemoData() async {
    final purged = await _storage.read(key: _demoPurgedKey);
    if (purged == 'true') return;

    print('Purging cached demo data from local storage...');
    final localStorage = LocalStorageService.instance;
    await localStorage.initialize();

    // Clear all entity data that came from the ThirdBooks demo API
    await localStorage.saveCustomers([]);
    await localStorage.saveVendors([]);
    await localStorage.saveInvoices([]);
    await localStorage.saveBills([]);
    await localStorage.saveJournalEntries([]);
    await localStorage.savePayments([]);
    // Also clear accounts so MagicBet defaults get re-seeded
    await localStorage.saveAccounts([]);

    await _storage.write(key: _demoPurgedKey, value: 'true');
    print('Demo data purged. System will start fresh with MagicBet defaults.');
  }

  /// Run the complete MagicBet initialization
  static Future<void> runMagicBetSetup(AppDatabase db) async {
    try {
      print('Starting MagicBet initialization...');

      // First purge any cached demo data from ThirdBooks API
      await purgeDemoData();

      // Run the main setup script (imports outlets)
      await setupMagicBet(db);

      // Mark setup as complete
      await markSetupComplete();

      print('MagicBet initialization completed successfully!');
    } catch (e) {
      print('MagicBet initialization failed: $e');
      rethrow;
    }
  }

  /// Check and run setup if needed
  ///
  /// Call this after user login to ensure system is initialized
  static Future<bool> checkAndRunSetup(AppDatabase db) async {
    // Always purge demo data on upgrade (idempotent - only runs once)
    await purgeDemoData();

    final setupComplete = await isSetupComplete();

    if (!setupComplete) {
      print('First-time setup detected. Running MagicBet initialization...');
      await runMagicBetSetup(db);
      return true; // Setup was run
    }

    print('MagicBet setup already complete.');
    return false; // Setup was already complete
  }
}
