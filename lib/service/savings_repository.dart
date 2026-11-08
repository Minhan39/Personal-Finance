import 'package:flutter/foundation.dart';

import '../models/gold.dart';
import '../models/saving_plan.dart';
import '../shared/helpers/number_helper.dart';
import 'gold_service.dart';
import 'save_service.dart';

/// Reads the `save_money` Google Sheet into [SavingsOverview].
///
/// Sheet layout: row 0 holds the current total at column 11 and the future
/// total at column 13. Each following row is a plan:
/// status | provider | percent | start | – | end | capital | profit.
class SavingsRepository {
  SavingsRepository._();

  static const _goldProductName = 'NHẪN TRÒN TRƠN (Vàng Rồng Thăng Long)';

  static Future<SavingsOverview> load({bool withGoldPrice = true}) async {
    final rows = await SaveService.readSheet() ?? const [];
    final overview = parse(rows);
    if (!withGoldPrice || !overview.plans.any((plan) => plan.isGold)) {
      return overview;
    }

    try {
      final golds = await GoldService.getGolds();
      final gold = golds.where((g) => g.name == _goldProductName).firstOrNull;
      return gold == null ? overview : _applyGoldPrice(overview, gold);
    } catch (error) {
      debugPrint('Gold price unavailable: $error');
      return overview;
    }
  }

  static SavingsOverview parse(List<List<Object?>> rows) {
    if (rows.isEmpty) {
      return const SavingsOverview(currentTotal: 0, futureTotal: 0, plans: []);
    }

    String cell(List<Object?> row, int index) =>
        index < row.length ? (row[index]?.toString() ?? '') : '';

    final plans = <SavingPlan>[
      for (final row in rows.skip(1))
        if (row.isNotEmpty && !_isCancelled(cell(row, 0)))
          SavingPlan(
            status: cell(row, 0).trim(),
            providerCode: cell(row, 1).trim(),
            percentLabel: cell(row, 2).trim(),
            startLabel: cell(row, 3).trim(),
            endLabel: cell(row, 5).trim(),
            capital: NumberHelper.tryParseMoney(cell(row, 6)),
            profit: NumberHelper.tryParseMoney(cell(row, 7)),
          ),
    ]..sort((a, b) => a.providerCode.compareTo(b.providerCode));

    return SavingsOverview(
      currentTotal: NumberHelper.tryParseMoney(cell(rows.first, 11)),
      futureTotal: NumberHelper.tryParseMoney(cell(rows.first, 13)),
      plans: plans,
    );
  }

  /// Gold profit follows today's BTMC buying price, as the old screen did.
  static SavingsOverview _applyGoldPrice(SavingsOverview overview, Gold gold) {
    final price = double.tryParse(gold.purchasePrice);
    if (price == null) return overview;

    return SavingsOverview(
      currentTotal: overview.currentTotal,
      futureTotal: overview.futureTotal,
      plans: [
        for (final plan in overview.plans)
          if (!plan.isGold || plan.capital <= 0)
            plan
          else
            () {
              final profit = price - plan.capital - NumberHelper.goldDifference;
              return plan.copyWith(
                profit: profit,
                percentLabel:
                    '${(profit * 100 / plan.capital).toStringAsFixed(2).replaceAll('.', ',')}%',
              );
            }(),
      ],
    );
  }

  static bool _isCancelled(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('huỷ') ||
        normalized.contains('hủy') ||
        normalized.contains('cancel');
  }
}
