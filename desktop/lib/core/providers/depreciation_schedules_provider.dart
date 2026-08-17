// Depreciation Schedules Provider
// Stores asset depreciation schedules locally with persistence.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Standard default method/rate by asset category — matches URA capital
// allowance classes for tangible assets and typical useful-life-based
// straight-line rates for intangibles (IAS 38). Shared by both the
// automatic on-confirm schedule creation and the manual bulk-setup tool
// so they always agree.
// ---------------------------------------------------------------------------
({String method, double rate}) defaultDepreciationFor(String category) {
  switch (category) {
    case 'Electronics':
      return (method: 'declining_balance', rate: 40.0);
    case 'Vehicle':
      return (method: 'declining_balance', rate: 35.0);
    case 'Machinery':
      return (method: 'declining_balance', rate: 30.0);
    case 'Equipment':
    case 'Furniture':
      return (method: 'declining_balance', rate: 20.0);
    case 'Building':
      return (method: 'straight_line', rate: 5.0);
    case 'Software':
    case 'License':
      return (method: 'straight_line', rate: 33.33);
    case 'Patent':
    case 'Trademark':
      return (method: 'straight_line', rate: 20.0);
    case 'Goodwill':
      return (method: 'straight_line', rate: 10.0);
    default:
      return (method: 'declining_balance', rate: 20.0);
  }
}

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

  double get accumulatedDepreciation => assetValue - currentValue;

  double get percentageDepreciated =>
      assetValue > 0 ? (accumulatedDepreciation / assetValue) * 100 : 0;

  /// Live, unposted estimate of total depreciation accrued from [startDate]
  /// up to [asOf] — independent of whether "Run"/"Generate Entries" has
  /// actually been clicked yet. Simulates forward period-by-period using
  /// the same math as the real posting logic, without mutating currentValue
  /// or lastRunDate. This is what the Asset Register displays, so
  /// Accumulated Depreciation always shows a correct current figure
  /// instead of staying blank until someone manually posts entries.
  double accumulatedAsOf(DateTime asOf) {
    if (asOf.isBefore(startDate)) return 0.0;

    double simulatedValue = currentValue;
    double totalAccrued = accumulatedDepreciation; // whatever is already actually posted
    DateTime from = lastRunDate == null ? startDate : nextRunDate;

    while (simulatedValue > 0) {
      final periodEnd = periodEndDate(period, from);
      final segmentEnd = periodEnd.isAfter(asOf) ? asOf : periodEnd;
      if (from.isAfter(segmentEnd)) break;

      final days = segmentEnd.difference(from).inDays + 1;
      const daysInYear = 365.0;
      final dailyRate = rate / 100 / daysInYear;
      final baseValue = method == 'declining_balance' ? simulatedValue : assetValue;
      final dep = (baseValue * dailyRate * days).clamp(0.0, simulatedValue);

      totalAccrued += dep;
      simulatedValue -= dep;

      if (!periodEnd.isAfter(asOf)) {
        from = period == 'monthly'
            ? DateTime(periodEnd.year, periodEnd.month + 1, 1)
            : DateTime(periodEnd.year + 1, 1, 1);
      } else {
        break; // reached asOf mid-period
      }
    }

    return totalAccrued.clamp(0.0, assetValue);
  }

  // Returns the last calendar day of the period that starts on [from].
  // Monthly → last day of [from]'s month. Yearly → Dec 31 of [from]'s year.
  static DateTime periodEndDate(String period, DateTime from) {
    return period == 'monthly'
        ? DateTime(from.year, from.month + 1, 0) // day 0 of next month = last day of this month
        : DateTime(from.year, 12, 31);
  }

  // Pro-rata depreciation using daily rate over the exact days in [from..to].
  double depreciationForPeriod(DateTime from, DateTime to) {
    final days = to.difference(from).inDays + 1;
    const daysInYear = 365.0;
    final dailyRate = rate / 100 / daysInYear;
    final baseValue = method == 'declining_balance' ? currentValue : assetValue;
    return (baseValue * dailyRate * days).clamp(0.0, currentValue);
  }

  // Next period's pro-rata depreciation (used for display in UI cards).
  double get nextDepreciation {
    final from = nextRunDate;
    final to = DepreciationSchedule.periodEndDate(period, from);
    return depreciationForPeriod(from, to);
  }

  // First period: starts at purchase date.
  // Subsequent periods: always the 1st of the next calendar month/year so
  // that each period covers a full calendar month after the first partial one.
  DateTime get nextRunDate {
    if (lastRunDate == null) return startDate;
    return period == 'monthly'
        ? DateTime(lastRunDate!.year, lastRunDate!.month + 1, 1)
        : DateTime(lastRunDate!.year + 1, 1, 1);
  }

  bool get isDue => nextRunDate.isBefore(DateTime.now());

  // [forDate] should be the LAST day of the period (periodEndDate) so that the
  // next nextRunDate advances to the 1st of the following month.
  // [amount] is the pre-computed pro-rata depreciation for the period.
  DepreciationSchedule applyDepreciation([DateTime? forDate, double? amount]) {
    final dep = amount ?? nextDepreciation;
    final newValue = (currentValue - dep).clamp(0.0, assetValue);
    return copyWith(currentValue: newValue, lastRunDate: forDate ?? DateTime.now());
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
    state = state.map((s) {
      if (s.id != id) return s;
      final from = s.nextRunDate;
      final to   = DepreciationSchedule.periodEndDate(s.period, from);
      return s.applyDepreciation(to, s.depreciationForPeriod(from, to));
    }).toList();
    await _save();
  }

  /// Replace the schedule with an already-updated instance (used when back-filling
  /// multiple overdue periods at once in depreciation_screen).
  Future<void> updateSchedule(DepreciationSchedule updated) async {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
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

  /// Reload from disk after a server pull has overwritten the JSON file.
  Future<void> reload() => _load();

  /// Replace entire list (called after a server pull overwrites local storage).
  void replaceAll(List<DepreciationSchedule> schedules) {
    state = schedules;
    _save();
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
