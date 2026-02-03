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

  const AppSettings({
    this.currency = 'UGX',
    this.dateFormat = 'dd/MM/yyyy',
    this.language = 'English',
    this.compactMode = false,
    this.showBalancesInSidebar = true,
    this.enableNotifications = true,
    this.autoSync = true,
    this.syncIntervalMinutes = 15,
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

    state = AppSettings(
      currency: currency,
      dateFormat: dateFormat,
      language: language,
      compactMode: compactMode,
      showBalancesInSidebar: showBalances,
      enableNotifications: enableNotifications,
      autoSync: autoSync,
      syncIntervalMinutes: syncInterval,
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
}
