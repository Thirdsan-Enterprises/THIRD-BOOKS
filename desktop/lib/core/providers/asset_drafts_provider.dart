// Asset Drafts Provider
// When a bill of an asset category is created, a draft asset is auto-generated
// and shown in the Assets screen until confirmed/posted.
// © 2026 ThirdBooks. All rights reserved.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

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

  // Completer that resolves once the initial load from disk is done.
  // All mutation methods await this so they never race with _load().
  final Completer<void> _loadCompleter = Completer<void>();

  AssetDraftsNotifier(this._storage) : super([]) {
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
  }

  Future<void> removeDraft(String id) async {
    await _loadCompleter.future;
    state = state.where((a) => a.id != id).toList();
    await _save();
  }

  /// Remove every draft linked to [billRef] and replace them with [newDrafts].
  /// This is the canonical update path when a bill is edited — it guarantees
  /// exactly one draft per asset line with no stale duplicates.
  Future<void> resetDraftsForBillRef(
    String billRef, {
    required List<AssetDraft> newDrafts,
  }) async {
    await _loadCompleter.future;
    // Keep confirmed assets (already in the register) and unrelated drafts.
    final keep = state
        .where((a) => a.billReference != billRef || a.isConfirmed)
        .toList();
    state = [...keep, ...newDrafts];
    await _save();
  }
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
    final idx = state.indexWhere((a) => a.billReference == billRef);
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

  /// Clear all drafts — used by the settings "clear cache" action.
  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}

final assetDraftsProvider =
    StateNotifierProvider<AssetDraftsNotifier, List<AssetDraft>>(
  (ref) => AssetDraftsNotifier(ref.read(localStorageServiceProvider)),
);

// ---------------------------------------------------------------------------
// Categories that are considered assets (not expenses)
// ---------------------------------------------------------------------------
const kAssetCategories = [
  'Equipment',
  'Vehicle',
  'Furniture',
  'Electronics',
  'Building',
  'Land',
  'Machinery',
];

bool isAssetCategory(String? category) =>
    category != null && kAssetCategories.contains(category);
