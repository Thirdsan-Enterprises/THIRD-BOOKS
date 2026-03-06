import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/app_database.dart';
import '../utils/magic_bet_setup.dart';

/// Initialization Service
///
/// Handles first-time setup tasks:
/// - Run MagicBet setup (import outlets, configure system)
/// - Initialize chart of accounts
/// - Set commission rates
class InitializationService {
  static const _storage = FlutterSecureStorage();
  static const _setupCompleteKey = 'magicbet_setup_complete';
  static const _setupVersionKey = 'magicbet_setup_version';
  static const currentSetupVersion = '1.0.0';

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

  /// Run the complete MagicBet initialization
  ///
  /// This includes:
  /// - Importing 74 outlets from outlet_data.json
  /// - Setting up Chart of Accounts
  /// - Configuring 40% commission rates
  /// - Creating company profile
  static Future<void> runMagicBetSetup(AppDatabase db) async {
    try {
      print('🚀 Starting MagicBet initialization...');

      // Run the main setup script
      await setupMagicBet(db);

      // Mark setup as complete
      await markSetupComplete();

      print('✅ MagicBet initialization completed successfully!');
    } catch (e) {
      print('❌ MagicBet initialization failed: $e');
      rethrow;
    }
  }

  /// Check and run setup if needed
  ///
  /// Call this after user login to ensure system is initialized
  static Future<bool> checkAndRunSetup(AppDatabase db) async {
    final setupComplete = await isSetupComplete();

    if (!setupComplete) {
      print('📋 First-time setup detected. Running MagicBet initialization...');
      await runMagicBetSetup(db);
      return true; // Setup was run
    }

    print('✓ MagicBet setup already complete.');
    return false; // Setup was already complete
  }
}
