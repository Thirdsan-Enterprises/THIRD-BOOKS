import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Magic Bet LTD System Setup Utility
///
/// Run this once to configure the system for Magic Bet Ltd
class MagicBetSetup {
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  MagicBetSetup(this.database);

  /// Complete system setup for MAGIC BET LTD
  Future<void> runCompleteSetup() async {
    print('');
    print('═══════════════════════════════════════════════════');
    print('   MAGIC BET LTD - SYSTEM SETUP');
    print('═══════════════════════════════════════════════════');
    print('');

    try {
      // Step 1: Import Outlets
      print('🏪 Step 1: Importing 74 outlets...');
      await importOutlets();
      print('✅ Outlets imported\n');

      // Step 2: Company Configuration Notes
      print('ℹ️  Step 2: Company Configuration');
      print('   Company: MAGIC BET LTD');
      print('   Admin: marion@magicbet.ug');
      print('   Phone: +256 788 160516');
      print('   Address: Plot 45, Kampala Road, Kampala, Uganda');
      print('   TIN: 1053396130');
      print('   Registration: UG-2024-123456\n');

      print('═══════════════════════════════════════════════════');
      print('   ✨ SETUP COMPLETE!');
      print('═══════════════════════════════════════════════════');
      print('');
      print('Next steps:');
      print('1. Upload outlet CSV data to populate revenue/expenses');
      print('2. System will create Chart of Accounts automatically');
      print('3. Start recording transactions via CSV uploads');
      print('');
    } catch (e) {
      print('❌ Setup failed: $e');
      rethrow;
    }
  }

  /// Import 74 outlets from JSON
  Future<void> importOutlets() async {
    final file = File('outlet_data.json');

    if (!await file.exists()) {
      print('   ⚠️  outlet_data.json not found. Skipping outlet import.');
      return;
    }

    final jsonString = await file.readAsString();
    final List<dynamic> outletsJson = json.decode(jsonString);

    int count = 0;
    for (var outletData in outletsJson) {
      final outlet = OutletsCompanion.insert(
        id: _uuid.v4(),
        outletCode: outletData['new id']?.toString() ?? '',
        name: outletData['outlet_name']?.toString() ?? '',
        address: Value(outletData['Address']?.toString()),
        city: Value(outletData['City']?.toString()),
        region: Value(outletData['Region']?.toString()),
        venueType: Value(outletData['Venue_type']?.toString() ?? 'OUTLET'),
        commissionRate: const Value(40.0),
        isActive: const Value(true),
        notes: Value('Imported on ${DateTime.now().toIso8601String()}'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await database.insertOutlet(outlet);
      count++;
    }

    print('   ✓ Imported $count outlets');
  }
}

/// Quick setup function
Future<void> setupMagicBet(AppDatabase database) async {
  final setup = MagicBetSetup(database);
  await setup.runCompleteSetup();
}
