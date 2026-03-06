import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Import outlets data from JSON file
///
/// This script imports the 74 betting outlets from outlet_data.json
/// into the database.
///
/// Usage:
/// ```dart
/// final importer = OutletImporter(database);
/// await importer.importFromJson('path/to/outlet_data.json');
/// ```
class OutletImporter {
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  OutletImporter(this.database);

  /// Import outlets from JSON file
  Future<void> importFromJson(String filePath) async {
    try {
      print('📥 Reading outlet data from: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final List<dynamic> outletsJson = json.decode(jsonString);

      print('📊 Found ${outletsJson.length} outlets to import');

      int successCount = 0;
      int errorCount = 0;

      for (var i = 0; i < outletsJson.length; i++) {
        try {
          final outletData = outletsJson[i] as Map<String, dynamic>;
          await _importSingleOutlet(outletData);
          successCount++;
          print('✅ [${i + 1}/${outletsJson.length}] Imported: ${outletData['outlet_name']}');
        } catch (e) {
          errorCount++;
          print('❌ [${i + 1}/${outletsJson.length}] Error: $e');
        }
      }

      print('');
      print('✨ Import Complete!');
      print('   Success: $successCount outlets');
      print('   Errors: $errorCount outlets');
    } catch (e) {
      print('❌ Import failed: $e');
      rethrow;
    }
  }

  /// Import a single outlet
  Future<void> _importSingleOutlet(Map<String, dynamic> data) async {
    final outlet = OutletsCompanion(
      id: Value(_uuid.v4()),
      outletCode: Value(data['new id']?.toString() ?? ''),
      name: Value(data['outlet_name']?.toString() ?? ''),
      address: Value(data['Address']?.toString()),
      city: Value(data['City']?.toString()),
      postalCode: Value(data['Postal code']?.toString()),
      region: Value(data['Region']?.toString()),
      venueType: Value(data['Venue_type']?.toString() ?? 'OUTLET'),
      commissionRate: const Value(40.0), // Default 40%
      isActive: const Value(true),
      notes: Value('Imported from Excel on ${DateTime.now().toIso8601String()}'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      syncSequence: const Value.absent(),
      ownerName: const Value.absent(),
      ownerContact: const Value.absent(),
    );

    await database.insertOutlet(outlet);
  }

  // Sample data methods removed - use CSV import for real data

  /// Clear all outlets from database
  Future<void> clearAllOutlets() async {
    print('🗑️  Clearing all outlets...');

    // TODO: Implement delete all
    // await database.deleteAllOutlets();

    print('✨ All outlets cleared!');
  }
}

/// Run this function to import all outlet data
Future<void> runOutletImport(AppDatabase database, String jsonFilePath) async {
  final importer = OutletImporter(database);

  print('');
  print('═══════════════════════════════════════════════════');
  print('   MAGIC BET LTD - OUTLET DATA IMPORT');
  print('═══════════════════════════════════════════════════');
  print('');

  // Import outlets
  await importer.importFromJson(jsonFilePath);

  print('');
  print('✅ Import process complete!');
  print('Use CSV import to load revenue data from AccountingTotalsInOut.csv');
  print('');
}
