import 'dart:convert';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:flutter/services.dart';
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
    print('MAGIC BET LTD - SYSTEM SETUP');

    try {
      // Step 1: Import Outlets from bundled asset
      print('Step 1: Importing outlets...');
      await importOutlets();

      // Step 2: Company Configuration
      print('Step 2: Company configured');
      print('  Company: MAGIC BET LTD');
      print('  Admin: marion@magicbet.ug');

      print('SETUP COMPLETE!');
      print('Next: Upload CSV data to populate revenue');
    } catch (e) {
      print('Setup failed: $e');
      rethrow;
    }
  }

  /// Import 74 outlets from bundled JSON asset
  Future<void> importOutlets() async {
    try {
      // Check if outlets already exist
      final existing = await database.getAllOutlets();
      if (existing.isNotEmpty) {
        print('  ${existing.length} outlets already in database. Skipping import.');
        return;
      }

      // Load from Flutter asset bundle
      final jsonString = await rootBundle.loadString('assets/outlet_data.json');
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

      print('  Imported $count outlets');
    } catch (e) {
      print('  Outlet import error: $e');
    }
  }
}

/// Quick setup function
Future<void> setupMagicBet(AppDatabase database) async {
  final setup = MagicBetSetup(database);
  await setup.runCompleteSetup();
}
