import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class CompanySettings {
  final String companyName;
  final String registrationNumber;
  final String taxId;
  final String email;
  final String phone;
  final String website;
  final String address;
  final String? logoPath;
  final String fiscalYearStart;
  final String accountingMethod;
  final String baseCurrency;
  final String invoicePrefix;
  final String invoiceNextNumber;
  final String defaultPaymentTerms;
  final String? defaultNotes;
  final String? defaultTerms;

  const CompanySettings({
    this.companyName = 'Magic Bet Ltd',
    this.registrationNumber = '',
    this.taxId = '',
    this.email = 'info@magicbet.ug',
    this.phone = '+256 700 000 000',
    this.website = 'www.magicbet.ug',
    this.address = 'Kampala, Uganda',
    this.logoPath,
    this.fiscalYearStart = 'January',
    this.accountingMethod = 'Accrual',
    this.baseCurrency = 'UGX',
    this.invoicePrefix = 'INV-',
    this.invoiceNextNumber = '2026-001',
    this.defaultPaymentTerms = 'Net 30',
    this.defaultNotes,
    this.defaultTerms,
  });

  CompanySettings copyWith({
    String? companyName,
    String? registrationNumber,
    String? taxId,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? logoPath,
    bool clearLogo = false,
    String? fiscalYearStart,
    String? accountingMethod,
    String? baseCurrency,
    String? invoicePrefix,
    String? invoiceNextNumber,
    String? defaultPaymentTerms,
    String? defaultNotes,
    String? defaultTerms,
  }) {
    return CompanySettings(
      companyName: companyName ?? this.companyName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      taxId: taxId ?? this.taxId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      address: address ?? this.address,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      fiscalYearStart: fiscalYearStart ?? this.fiscalYearStart,
      accountingMethod: accountingMethod ?? this.accountingMethod,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceNextNumber: invoiceNextNumber ?? this.invoiceNextNumber,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      defaultNotes: defaultNotes ?? this.defaultNotes,
      defaultTerms: defaultTerms ?? this.defaultTerms,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'registrationNumber': registrationNumber,
        'taxId': taxId,
        'email': email,
        'phone': phone,
        'website': website,
        'address': address,
        'logoPath': logoPath,
        'fiscalYearStart': fiscalYearStart,
        'accountingMethod': accountingMethod,
        'baseCurrency': baseCurrency,
        'invoicePrefix': invoicePrefix,
        'invoiceNextNumber': invoiceNextNumber,
        'defaultPaymentTerms': defaultPaymentTerms,
        'defaultNotes': defaultNotes,
        'defaultTerms': defaultTerms,
      };

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    return CompanySettings(
      companyName: json['companyName'] as String? ?? 'Magic Bet Ltd',
      registrationNumber: json['registrationNumber'] as String? ?? '',
      taxId: json['taxId'] as String? ?? '',
      email: json['email'] as String? ?? 'info@magicbet.ug',
      phone: json['phone'] as String? ?? '+256 700 000 000',
      website: json['website'] as String? ?? 'www.magicbet.ug',
      address: json['address'] as String? ?? 'Kampala, Uganda',
      logoPath: json['logoPath'] as String?,
      fiscalYearStart: json['fiscalYearStart'] as String? ?? 'January',
      accountingMethod: json['accountingMethod'] as String? ?? 'Accrual',
      baseCurrency: json['baseCurrency'] as String? ?? 'UGX',
      invoicePrefix: json['invoicePrefix'] as String? ?? 'INV-',
      invoiceNextNumber: json['invoiceNextNumber'] as String? ?? '2026-001',
      defaultPaymentTerms: json['defaultPaymentTerms'] as String? ?? 'Net 30',
      defaultNotes: json['defaultNotes'] as String?,
      defaultTerms: json['defaultTerms'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class CompanySettingsNotifier extends StateNotifier<CompanySettings> {
  CompanySettingsNotifier() : super(const CompanySettings()) {
    _load();
  }

  static const _prefKey = 'company_settings_json';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        state = CompanySettings.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading company settings: $e');
    }
  }

  Future<void> save(CompanySettings settings) async {
    try {
      state = settings;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('Error saving company settings: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final companySettingsProvider =
    StateNotifierProvider<CompanySettingsNotifier, CompanySettings>(
  (_) => CompanySettingsNotifier(),
);
