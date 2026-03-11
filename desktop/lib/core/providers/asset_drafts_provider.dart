// Asset Drafts Provider
// When a bill of an asset category is created, a draft asset is auto-generated
// and shown in the Assets screen until confirmed/posted.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  AssetDraft copyWith({bool? isConfirmed}) => AssetDraft(
        id: id,
        assetName: assetName,
        category: category,
        amount: amount,
        currency: currency,
        vendorName: vendorName,
        billReference: billReference,
        date: date,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );
}

// ---------------------------------------------------------------------------
// Asset Drafts Notifier
// ---------------------------------------------------------------------------
class AssetDraftsNotifier extends StateNotifier<List<AssetDraft>> {
  AssetDraftsNotifier() : super([]);

  void addFromBill({
    required String id,
    required String assetName,
    required String category,
    required double amount,
    required String currency,
    String? vendorName,
    String? billReference,
    required DateTime date,
  }) {
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
  }

  void confirmAsset(String id) {
    state = state
        .map((a) => a.id == id ? a.copyWith(isConfirmed: true) : a)
        .toList();
  }

  void removeDraft(String id) {
    state = state.where((a) => a.id != id).toList();
  }
}

final assetDraftsProvider =
    StateNotifierProvider<AssetDraftsNotifier, List<AssetDraft>>(
  (ref) => AssetDraftsNotifier(),
);

// Categories that are considered assets (not expenses)
const kAssetCategories = [
  'Equipment',
  'Vehicle',
  'Furniture',
  'Electronics',
];

bool isAssetCategory(String? category) =>
    category != null && kAssetCategories.contains(category);
