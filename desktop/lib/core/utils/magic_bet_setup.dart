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
      // Step 1: Setup Chart of Accounts
      print('📊 Step 1: Setting up Chart of Accounts...');
      await setupChartOfAccounts();
      print('✅ Chart of Accounts configured\n');

      // Step 2: Import Outlets
      print('🏪 Step 2: Importing 74 outlets...');
      await importOutlets();
      print('✅ Outlets imported\n');

      // Step 3: Company Configuration Notes
      print('ℹ️  Step 3: Company Configuration');
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
      print('1. Run: flutter pub run build_runner build');
      print('2. Test the application');
      print('3. Start recording revenue and expenses');
      print('');
    } catch (e) {
      print('❌ Setup failed: $e');
      rethrow;
    }
  }

  /// Setup betting-specific Chart of Accounts
  Future<void> setupChartOfAccounts() async {
    final now = DateTime.now();

    // Revenue Accounts
    final revenueAccounts = [
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '4000',
        name: 'Betting Machine Revenue',
        type: 'revenue',
        subType: const Value('operating_revenue'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '4010',
        name: 'Gaming Income',
        type: 'revenue',
        subType: const Value('operating_revenue'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Expense Accounts
    final expenseAccounts = [
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '5000',
        name: 'Location Commission Expense (40%)',
        description: const Value('Commission paid to location owners'),
        type: 'expense',
        subType: const Value('cost_of_sales'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '5100',
        name: 'Machine Maintenance & Repairs',
        description: const Value('Outlet machine maintenance costs'),
        type: 'expense',
        subType: const Value('operating_expense'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '5200',
        name: 'Outlet Operating Expenses',
        description: const Value('General outlet operational costs'),
        type: 'expense',
        subType: const Value('operating_expense'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '5300',
        name: 'Depreciation Expense',
        description: const Value('Asset depreciation charges'),
        type: 'expense',
        subType: const Value('operating_expense'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Asset Accounts
    final assetAccounts = [
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '1500',
        name: 'Fixed Assets',
        description: const Value('Vehicles, equipment, furniture, etc.'),
        type: 'asset',
        subType: const Value('fixed_asset'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '1510',
        name: 'Accumulated Depreciation',
        description: const Value('Contra asset account for depreciation'),
        type: 'asset',
        subType: const Value('fixed_asset'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Liability Accounts
    final liabilityAccounts = [
      AccountsCompanion.insert(
        id: _uuid.v4(),
        code: '2100',
        name: 'Commission Payable',
        description: const Value('Outstanding commission to location owners'),
        type: 'liability',
        subType: const Value('current_liability'),
        currencyCode: const Value('UGX'),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    // Insert all accounts
    for (var account in [...revenueAccounts, ...expenseAccounts, ...assetAccounts, ...liabilityAccounts]) {
      await database.insertAccount(account);
    }

    print('   ✓ Added ${revenueAccounts.length} revenue accounts');
    print('   ✓ Added ${expenseAccounts.length} expense accounts');
    print('   ✓ Added ${assetAccounts.length} asset accounts');
    print('   ✓ Added ${liabilityAccounts.length} liability accounts');
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
