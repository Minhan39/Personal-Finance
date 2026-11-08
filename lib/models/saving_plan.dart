import 'package:flutter/material.dart';

/// Where a saving plan is held, derived from the provider code in the sheet.
enum SavingProviderKind { bank, wallet, gold, other }

/// One row of the `save_money` sheet.
class SavingPlan {
  const SavingPlan({
    required this.status,
    required this.providerCode,
    required this.percentLabel,
    required this.startLabel,
    required this.endLabel,
    required this.capital,
    required this.profit,
  });

  final String status;
  final String providerCode;
  final String percentLabel;
  final String startLabel;
  final String endLabel;
  final double capital;
  final double profit;

  /// Gold is stored under the code `9999` in the sheet.
  bool get isGold => providerCode.trim() == '9999';

  SavingProviderKind get kind {
    switch (providerCode.trim().toLowerCase()) {
      case '9999':
        return SavingProviderKind.gold;
      case 'momo':
      case 'tikop':
        return SavingProviderKind.wallet;
      case 'mb':
      case 'bidv':
      case 'vcb':
      case 'tcb':
      case 'acb':
        return SavingProviderKind.bank;
      default:
        return SavingProviderKind.other;
    }
  }

  String get providerName {
    switch (providerCode.trim().toLowerCase()) {
      case '9999':
        return 'Vàng nhẫn 9999';
      case 'momo':
        return 'MoMo';
      case 'tikop':
        return 'Tikop';
      case 'mb':
        return 'MB Bank';
      case 'bidv':
        return 'BIDV';
      default:
        final code = providerCode.trim();
        return code.isEmpty ? 'Khoản tiết kiệm' : code.toUpperCase();
    }
  }

  IconData get icon {
    switch (kind) {
      case SavingProviderKind.gold:
        return Icons.diamond_outlined;
      case SavingProviderKind.wallet:
        return Icons.account_balance_wallet_outlined;
      case SavingProviderKind.bank:
        return Icons.account_balance_outlined;
      case SavingProviderKind.other:
        return Icons.savings_outlined;
    }
  }

  DateTime? get startDate => parseSheetDate(startLabel);

  DateTime? get endDate => parseSheetDate(endLabel);

  /// Share of the term already elapsed, or `null` when the dates are unknown.
  double? get termProgress {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null || !end.isAfter(start)) return null;
    final elapsed = DateTime.now().difference(start).inDays;
    return (elapsed / end.difference(start).inDays).clamp(0.0, 1.0);
  }

  SavingPlan copyWith({double? profit, String? percentLabel}) {
    return SavingPlan(
      status: status,
      providerCode: providerCode,
      percentLabel: percentLabel ?? this.percentLabel,
      startLabel: startLabel,
      endLabel: endLabel,
      capital: capital,
      profit: profit ?? this.profit,
    );
  }
}

/// Totals at the top of the sheet plus the active plans.
class SavingsOverview {
  const SavingsOverview({
    required this.currentTotal,
    required this.futureTotal,
    required this.plans,
  });

  final double currentTotal;
  final double futureTotal;
  final List<SavingPlan> plans;

  double get totalCapital => plans.fold(0, (sum, plan) => sum + plan.capital);

  double get totalProfit => plans.fold(0, (sum, plan) => sum + plan.profit);
}

/// Accepts dd/MM/yyyy, d/M/yyyy, dd-MM-yyyy, yyyy-MM-dd and MM/yyyy.
DateTime? parseSheetDate(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;

  final dayFirst = RegExp(
    r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$',
  ).firstMatch(value);
  if (dayFirst != null) {
    return DateTime(
      int.parse(dayFirst.group(3)!),
      int.parse(dayFirst.group(2)!),
      int.parse(dayFirst.group(1)!),
    );
  }

  final monthYear = RegExp(r'^(\d{1,2})[/\-.](\d{4})$').firstMatch(value);
  if (monthYear != null) {
    return DateTime(
      int.parse(monthYear.group(2)!),
      int.parse(monthYear.group(1)!),
    );
  }

  return null;
}
