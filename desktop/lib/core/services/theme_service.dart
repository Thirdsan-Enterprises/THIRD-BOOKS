// Theme Service for ThirdBooks
// Handles theme switching (light/dark mode) with persistence
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _themeModeKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final savedMode = await _storage.read(key: _themeModeKey);
    if (savedMode != null) {
      switch (savedMode) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _themeModeKey, value: mode.name);
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}

// App Settings Provider
class AppSettings {
  final String currency;
  final String dateFormat;
  final String language;
  final bool compactMode;
  final bool showBalancesInSidebar;
  final bool enableNotifications;
  final bool autoSync;
  final int syncIntervalMinutes;

  // Tax preferences
  final bool enableVAT;
  final bool pricesIncludeTax;
  final bool showTaxOnInvoices;

  // Appearance preferences
  final bool showAccountCodes;
  final bool enableAnimations;

  // Auto-journalization controls
  final bool autoGamingTaxJE;
  final bool autoPayrollNSSFJE;
  final bool autoWHTJE;

  const AppSettings({
    this.currency = 'UGX',
    this.dateFormat = 'dd/MM/yyyy',
    this.language = 'English',
    this.compactMode = false,
    this.showBalancesInSidebar = true,
    this.enableNotifications = true,
    this.autoSync = true,
    this.syncIntervalMinutes = 15,
    this.enableVAT = true,
    this.pricesIncludeTax = false,
    this.showTaxOnInvoices = true,
    this.showAccountCodes = true,
    this.enableAnimations = true,
    this.autoGamingTaxJE = true,
    this.autoPayrollNSSFJE = true,
    this.autoWHTJE = true,
  });

  AppSettings copyWith({
    String? currency,
    String? dateFormat,
    String? language,
    bool? compactMode,
    bool? showBalancesInSidebar,
    bool? enableNotifications,
    bool? autoSync,
    int? syncIntervalMinutes,
    bool? enableVAT,
    bool? pricesIncludeTax,
    bool? showTaxOnInvoices,
    bool? showAccountCodes,
    bool? enableAnimations,
    bool? autoGamingTaxJE,
    bool? autoPayrollNSSFJE,
    bool? autoWHTJE,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      language: language ?? this.language,
      compactMode: compactMode ?? this.compactMode,
      showBalancesInSidebar: showBalancesInSidebar ?? this.showBalancesInSidebar,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      autoSync: autoSync ?? this.autoSync,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      enableVAT: enableVAT ?? this.enableVAT,
      pricesIncludeTax: pricesIncludeTax ?? this.pricesIncludeTax,
      showTaxOnInvoices: showTaxOnInvoices ?? this.showTaxOnInvoices,
      showAccountCodes: showAccountCodes ?? this.showAccountCodes,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      autoGamingTaxJE: autoGamingTaxJE ?? this.autoGamingTaxJE,
      autoPayrollNSSFJE: autoPayrollNSSFJE ?? this.autoPayrollNSSFJE,
      autoWHTJE: autoWHTJE ?? this.autoWHTJE,
    );
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppSettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final currency = await _storage.read(key: 'currency') ?? 'UGX';
    final dateFormat = await _storage.read(key: 'date_format') ?? 'dd/MM/yyyy';
    final language = await _storage.read(key: 'language') ?? 'English';
    final compactMode = await _storage.read(key: 'compact_mode') == 'true';
    final showBalances = await _storage.read(key: 'show_balances') != 'false';
    final enableNotifications = await _storage.read(key: 'notifications') != 'false';
    final autoSync = await _storage.read(key: 'auto_sync') != 'false';
    final syncInterval = int.tryParse(await _storage.read(key: 'sync_interval') ?? '15') ?? 15;
    final enableVAT = await _storage.read(key: 'enable_vat') != 'false';
    final pricesIncludeTax = await _storage.read(key: 'prices_include_tax') == 'true';
    final showTaxOnInvoices = await _storage.read(key: 'show_tax_on_invoices') != 'false';
    final showAccountCodes = await _storage.read(key: 'show_account_codes') != 'false';
    final enableAnimations = await _storage.read(key: 'enable_animations') != 'false';
    final autoGamingTaxJE = await _storage.read(key: 'auto_gaming_tax_je') != 'false';
    final autoPayrollNSSFJE = await _storage.read(key: 'auto_payroll_nssf_je') != 'false';
    final autoWHTJE = await _storage.read(key: 'auto_wht_je') != 'false';

    state = AppSettings(
      currency: currency,
      dateFormat: dateFormat,
      language: language,
      compactMode: compactMode,
      showBalancesInSidebar: showBalances,
      enableNotifications: enableNotifications,
      autoSync: autoSync,
      syncIntervalMinutes: syncInterval,
      enableVAT: enableVAT,
      pricesIncludeTax: pricesIncludeTax,
      showTaxOnInvoices: showTaxOnInvoices,
      showAccountCodes: showAccountCodes,
      enableAnimations: enableAnimations,
      autoGamingTaxJE: autoGamingTaxJE,
      autoPayrollNSSFJE: autoPayrollNSSFJE,
      autoWHTJE: autoWHTJE,
    );
  }

  Future<void> setCurrency(String currency) async {
    state = state.copyWith(currency: currency);
    await _storage.write(key: 'currency', value: currency);
  }

  Future<void> setDateFormat(String format) async {
    state = state.copyWith(dateFormat: format);
    await _storage.write(key: 'date_format', value: format);
  }

  Future<void> setLanguage(String language) async {
    state = state.copyWith(language: language);
    await _storage.write(key: 'language', value: language);
  }

  Future<void> setCompactMode(bool enabled) async {
    state = state.copyWith(compactMode: enabled);
    await _storage.write(key: 'compact_mode', value: enabled.toString());
  }

  Future<void> setShowBalances(bool show) async {
    state = state.copyWith(showBalancesInSidebar: show);
    await _storage.write(key: 'show_balances', value: show.toString());
  }

  Future<void> setNotifications(bool enabled) async {
    state = state.copyWith(enableNotifications: enabled);
    await _storage.write(key: 'notifications', value: enabled.toString());
  }

  Future<void> setAutoSync(bool enabled) async {
    state = state.copyWith(autoSync: enabled);
    await _storage.write(key: 'auto_sync', value: enabled.toString());
  }

  Future<void> setSyncInterval(int minutes) async {
    state = state.copyWith(syncIntervalMinutes: minutes);
    await _storage.write(key: 'sync_interval', value: minutes.toString());
  }

  Future<void> setEnableVAT(bool enabled) async {
    state = state.copyWith(enableVAT: enabled);
    await _storage.write(key: 'enable_vat', value: enabled.toString());
  }

  Future<void> setPricesIncludeTax(bool enabled) async {
    state = state.copyWith(pricesIncludeTax: enabled);
    await _storage.write(key: 'prices_include_tax', value: enabled.toString());
  }

  Future<void> setShowTaxOnInvoices(bool enabled) async {
    state = state.copyWith(showTaxOnInvoices: enabled);
    await _storage.write(key: 'show_tax_on_invoices', value: enabled.toString());
  }

  Future<void> setShowAccountCodes(bool enabled) async {
    state = state.copyWith(showAccountCodes: enabled);
    await _storage.write(key: 'show_account_codes', value: enabled.toString());
  }

  Future<void> setEnableAnimations(bool enabled) async {
    state = state.copyWith(enableAnimations: enabled);
    await _storage.write(key: 'enable_animations', value: enabled.toString());
  }

  Future<void> setAutoGamingTaxJE(bool enabled) async {
    state = state.copyWith(autoGamingTaxJE: enabled);
    await _storage.write(key: 'auto_gaming_tax_je', value: enabled.toString());
  }

  Future<void> setAutoPayrollNSSFJE(bool enabled) async {
    state = state.copyWith(autoPayrollNSSFJE: enabled);
    await _storage.write(key: 'auto_payroll_nssf_je', value: enabled.toString());
  }

  Future<void> setAutoWHTJE(bool enabled) async {
    state = state.copyWith(autoWHTJE: enabled);
    await _storage.write(key: 'auto_wht_je', value: enabled.toString());
  }
}
