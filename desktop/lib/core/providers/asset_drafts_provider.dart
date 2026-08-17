// Asset Drafts Provider
// When a bill of an asset category is created, a draft asset is auto-generated
// and shown in the Assets screen until confirmed/posted.
// © 2026 ThirdBooks. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/local_storage_service.dart';
import 'depreciation_schedules_provider.dart';

// ---------------------------------------------------------------------------
// Asset Draft Model (sourced from bills)
// ---------------------------------------------------------------------------
class AssetDraft {
  final String id;
  final String assetName;
  final String category; // Equipment, Vehicle, Furniture, Electronics, etc.
  final double amount;
  final String currency;
  final String? vendorName;
  final String? billReference;
  final DateTime date;
  final bool isConfirmed; // false = Draft, true = Active

  const AssetDraft({
    required this.id,
    required this.assetName,
    required this.category,
    required this.amount,
    required this.currency,
    this.vendorName,
    this.billReference,
    required this.date,
    this.isConfirmed = false,
  });

  AssetDraft copyWith({
    String? assetName,
    double? amount,
    String? vendorName,
    DateTime? date,
    bool? isConfirmed,
  }) => AssetDraft(
        id: id,
        assetName: assetName ?? this.assetName,
        category: category,
        amount: amount ?? this.amount,
        currency: currency,
        vendorName: vendorName ?? this.vendorName,
        billReference: billReference,
        date: date ?? this.date,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetName': assetName,
        'category': category,
        'amount': amount,
        'currency': currency,
        'vendorName': vendorName,
        'billReference': billReference,
        'date': date.toIso8601String(),
        'isConfirmed': isConfirmed,
      };

  factory AssetDraft.fromJson(Map<String, dynamic> j) => AssetDraft(
        id: j['id'] as String,
        assetName: j['assetName'] as String,
        category: j['category'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String,
        vendorName: j['vendorName'] as String?,
        billReference: j['billReference'] as String?,
        date: DateTime.parse(j['date'] as String),
        isConfirmed: j['isConfirmed'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// Asset Drafts Notifier — persists to local storage
// ---------------------------------------------------------------------------
class AssetDraftsNotifier extends StateNotifier<List<AssetDraft>> {
  final LocalStorageService _storage;
  final Ref _ref;

  // Completer that resolves once the initial load from disk is done.
  // All mutation methods await this so they never race with _load().
  final Completer<void> _loadCompleter = Completer<void>();

  AssetDraftsNotifier(this._storage, this._ref) : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await _storage.loadData('asset_drafts', AssetDraft.fromJson);
      state = list;
    } catch (_) {
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
    // Backfill a depreciation schedule for any already-confirmed asset that
    // doesn't have one — covers assets that were confirmed before automatic
    // schedule creation existed, so simply installing a newer build fixes
    // them on the next launch without anyone needing to click anything.
    unawaited(_backfillMissingSchedules());
  }

  Future<void> _backfillMissingSchedules() async {
    try {
      await _ref.read(depreciationSchedulesProvider.notifier).ready;
      for (final asset in state) {
        if (!asset.isConfirmed || asset.category == 'Land') continue;
        await _ensureScheduleFor(asset);
      }
    } catch (_) {
      // Best-effort — never let this block or crash startup.
    }
  }

  /// Creates a depreciation schedule for [asset] using category defaults,
  /// unless one already exists for it. Shared by confirmAsset() and the
  /// startup backfill so both paths always agree.
  Future<void> _ensureScheduleFor(AssetDraft asset) async {
    final schedules = _ref.read(depreciationSchedulesProvider);
    if (schedules.any((s) => s.assetDraftId == asset.id)) return;

    final d = defaultDepreciationFor(asset.category);
    await _ref.read(depreciationSchedulesProvider.notifier).add(DepreciationSchedule(
          id: const Uuid().v4(),
          assetDraftId: asset.id,
          assetName: asset.assetName,
          assetCategory: asset.category,
          assetValue: asset.amount,
          currentValue: asset.amount,
          method: d.method,
          rate: d.rate,
          period: 'monthly',
          startDate: asset.date,
          createdAt: DateTime.now(),
        ));
  }

  Future<void> _save() async {
    await _storage.saveData('asset_drafts', state, (a) => a.toJson());
  }

  Future<void> addFromBill({
    required String id,
    required String assetName,
    required String category,
    required double amount,
    required String currency,
    String? vendorName,
    String? billReference,
    required DateTime date,
  }) async {
    // Wait for initial load so we never overwrite existing drafts.
    await _loadCompleter.future;
    state = [
      ...state,
      AssetDraft(
        id: id,
        assetName: assetName,
        category: category,
        amount: amount,
        currency: currency,
        vendorName: vendorName,
        billReference: billReference,
        date: date,
      ),
    ];
    await _save();
  }

  Future<void> confirmAsset(String id) async {
    await _loadCompleter.future;
    state = state
        .map((a) => a.id == id ? a.copyWith(isConfirmed: true) : a)
        .toList();
    await _save();

    // Automatically create a depreciation schedule for this asset the
    // moment it's confirmed — depreciation should never depend on someone
    // remembering to click a separate "Setup Depreciation" button. Land is
    // excluded since it isn't depreciable.
    AssetDraft? asset;
    for (final a in state) {
      if (a.id == id) { asset = a; break; }
    }
    if (asset == null || asset.category == 'Land') return;
    await _ensureScheduleFor(asset);
  }

  Future<void> removeDraft(String id) async {
    await _loadCompleter.future;
    state = state.where((a) => a.id != id).toList();
    await _save();
  }

  /// Update the amount (and optional metadata) of the draft linked to a bill.
  /// If no draft exists for [billRef] yet, creates a new one from the supplied
  /// parameters (handles the "deleted then re-edit" scenario).
  Future<void> updateDraftByBillRef(
    String billRef, {
    required double amount,
    String? assetName,
    String? vendorName,
    DateTime? date,
    // Required for recreation when no existing draft is found
    String? id,
    String? category,
    String currency = 'UGX',
  }) async {
    await _loadCompleter.future;
    // Primary lookup by id — each line on a bill has a unique id, so this
    // correctly targets the specific draft for multi-line bills.
    // Fallback to billReference for single-asset bills or older drafts.
    int idx = id != null ? state.indexWhere((a) => a.id == id) : -1;
    if (idx < 0) {
      idx = state.indexWhere((a) => a.billReference == billRef);
    }
    if (idx >= 0) {
      final updated = state[idx].copyWith(
        amount: amount,
        assetName: assetName,
        vendorName: vendorName,
        date: date,
      );
      state = [...state.sublist(0, idx), updated, ...state.sublist(idx + 1)];
    } else if (id != null && category != null) {
      state = [
        ...state,
        AssetDraft(
          id: id,
          assetName: assetName ?? billRef,
          category: category,
          amount: amount,
          currency: currency,
          vendorName: vendorName,
          billReference: billRef,
          date: date ?? DateTime.now(),
        ),
      ];
    }
    await _save();
  }

  /// Reload from disk after a server pull has overwritten the JSON file.
  Future<void> reload() async {
    await _loadCompleter.future;
    await _load();
  }

  /// Replace entire list (called after a server pull).
  Future<void> replaceAll(List<AssetDraft> drafts) async {
    await _loadCompleter.future;
    state = drafts;
    await _save();
  }

  /// Clear all drafts — used by the settings "clear cache" action.
  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}

final assetDraftsProvider =
    StateNotifierProvider<AssetDraftsNotifier, List<AssetDraft>>(
  (ref) => AssetDraftsNotifier(ref.read(localStorageServiceProvider), ref),
);

// ---------------------------------------------------------------------------
// Categories that are considered assets (not expenses)
// ---------------------------------------------------------------------------
const kAssetCategories = [
  // Tangible (PP&E — IAS 16)
  'Equipment',
  'Vehicle',
  'Furniture',
  'Electronics',
  'Building',
  'Land',
  'Machinery',
  // Intangible (IAS 38)
  'Software',
  'License',
  'Patent',
  'Trademark',
  'Goodwill',
  'Intangible',
];

const kIntangibleCategories = {
  'Software', 'License', 'Patent', 'Trademark', 'Goodwill', 'Intangible',
};

bool isAssetCategory(String? category) =>
    category != null && kAssetCategories.contains(category);

bool isIntangibleCategory(String? category) =>
    category != null && kIntangibleCategories.contains(category);
