// Depreciation Schedules Provider
// Stores asset depreciation schedules locally with persistence.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class DepreciationSchedule {
  final String id;
  final String assetDraftId;
  final String assetName;
  final String assetCategory;
  final double assetValue; // original purchase value
  final double currentValue; // book value after depreciation
  final String method; // 'declining_balance' | 'straight_line'
  final double rate; // annual percentage e.g. 20.0
  final String period; // 'monthly' | 'yearly'
  final DateTime startDate;
  final DateTime? lastRunDate;
  final bool isActive;
  final DateTime createdAt;

  const DepreciationSchedule({
    required this.id,
    required this.assetDraftId,
    required this.assetName,
    required this.assetCategory,
    required this.assetValue,
    required this.currentValue,
    required this.method,
    required this.rate,
    required this.period,
    required this.startDate,
    this.lastRunDate,
    this.isActive = true,
    required this.createdAt,
  });

  // ── Computed values ────────────────────────────────────────────────────────
  double get periodRate =>
      period == 'monthly' ? rate / 100 / 12 : rate / 100;

  double get nextDepreciation =>
      method == 'declining_balance'
          ? currentValue * periodRate
          : assetValue * periodRate;

  double get accumulatedDepreciation => assetValue - currentValue;

  double get percentageDepreciated =>
      assetValue > 0 ? (accumulatedDepreciation / assetValue) * 100 : 0;

  DateTime get nextRunDate {
    final base = lastRunDate ?? startDate;
    return period == 'monthly'
        ? DateTime(base.year, base.month + 1, base.day)
        : DateTime(base.year + 1, base.month, base.day);
  }

  bool get isDue => nextRunDate.isBefore(DateTime.now());

  DepreciationSchedule applyDepreciation() {
    final dep = nextDepreciation;
    final newValue = (currentValue - dep).clamp(0.0, assetValue);
    return copyWith(currentValue: newValue, lastRunDate: DateTime.now());
  }

  DepreciationSchedule copyWith({
    double? currentValue,
    DateTime? lastRunDate,
    bool? isActive,
  }) =>
      DepreciationSchedule(
        id: id,
        assetDraftId: assetDraftId,
        assetName: assetName,
        assetCategory: assetCategory,
        assetValue: assetValue,
        currentValue: currentValue ?? this.currentValue,
        method: method,
        rate: rate,
        period: period,
        startDate: startDate,
        lastRunDate: lastRunDate ?? this.lastRunDate,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetDraftId': assetDraftId,
        'assetName': assetName,
        'assetCategory': assetCategory,
        'assetValue': assetValue,
        'currentValue': currentValue,
        'method': method,
        'rate': rate,
        'period': period,
        'startDate': startDate.toIso8601String(),
        'lastRunDate': lastRunDate?.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DepreciationSchedule.fromJson(Map<String, dynamic> j) =>
      DepreciationSchedule(
        id: j['id'] as String,
        assetDraftId: j['assetDraftId'] as String,
        assetName: j['assetName'] as String,
        assetCategory: j['assetCategory'] as String? ?? '',
        assetValue: (j['assetValue'] as num).toDouble(),
        currentValue: (j['currentValue'] as num).toDouble(),
        method: j['method'] as String,
        rate: (j['rate'] as num).toDouble(),
        period: j['period'] as String,
        startDate: DateTime.parse(j['startDate'] as String),
        lastRunDate: j['lastRunDate'] != null
            ? DateTime.parse(j['lastRunDate'] as String)
            : null,
        isActive: j['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------
class DepreciationSchedulesNotifier
    extends StateNotifier<List<DepreciationSchedule>> {
  final LocalStorageService _storage;

  DepreciationSchedulesNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _storage.loadData(
          'depreciation_schedules', DepreciationSchedule.fromJson);
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    await _storage.saveData(
        'depreciation_schedules', state, (s) => s.toJson());
  }

  Future<void> add(DepreciationSchedule schedule) async {
    state = [schedule, ...state];
    await _save();
  }

  Future<void> runDepreciation(String id) async {
    state = state
        .map((s) => s.id == id ? s.applyDepreciation() : s)
        .toList();
    await _save();
  }

  Future<void> toggleActive(String id) async {
    state = state
        .map((s) => s.id == id ? s.copyWith(isActive: !s.isActive) : s)
        .toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  /// Clear all schedules — used by the settings "clear cache" action.
  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final depreciationSchedulesProvider = StateNotifierProvider<
    DepreciationSchedulesNotifier, List<DepreciationSchedule>>(
  (ref) =>
      DepreciationSchedulesNotifier(ref.read(localStorageServiceProvider)),
);
