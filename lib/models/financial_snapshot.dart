class FinancialAiSnapshot {
  FinancialAiSnapshot({
    required this.startMonth,
    required this.endMonth,
    required this.expenses,
    required this.incomes,
    required this.savings,
    required this.generatedAt,
  }) : monthCount = _monthCount(startMonth, endMonth),
       totalIncome = incomes.totalAmount,
       totalExpense = expenses.totalAmount,
       netCashFlow = incomes.totalAmount - expenses.totalAmount,
       expenseToIncomeRatio = incomes.totalAmount <= 0
           ? 0
           : expenses.totalAmount / incomes.totalAmount,
       savingsCoverageMonths = expenses.monthlyAverage <= 0
           ? 0
           : savings.currentTotal / expenses.monthlyAverage;

  final DateTime startMonth;
  final DateTime endMonth;
  final int monthCount;
  final ExpenseSummary expenses;
  final IncomeSummary incomes;
  final SavingSummary savings;
  final DateTime generatedAt;
  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  final double expenseToIncomeRatio;
  final double savingsCoverageMonths;

  Map<String, dynamic> toPromptJson() {
    return {
      'period': {
        'start_month': _monthLabel(startMonth),
        'end_month': _monthLabel(endMonth),
        'month_count': monthCount,
        'generated_at': generatedAt.toIso8601String(),
      },
      'income': incomes.toJson(),
      'expense': expenses.toJson(),
      'saving': savings.toJson(),
      'derived': {
        'net_cash_flow': netCashFlow,
        'expense_to_income_ratio': expenseToIncomeRatio,
        'savings_coverage_months': savingsCoverageMonths,
      },
    };
  }

  static int _monthCount(DateTime startMonth, DateTime endMonth) {
    return (endMonth.year - startMonth.year) * 12 +
        endMonth.month -
        startMonth.month +
        1;
  }

  static String _monthLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }
}

class ExpenseSummary {
  ExpenseSummary({
    required this.transactionCount,
    required this.totalAmount,
    required this.monthlyTotals,
    required this.categoryTotals,
  }) : monthlyAverage = monthlyTotals.isEmpty
           ? 0
           : totalAmount / monthlyTotals.length,
       topCategories = _buildTopItems(categoryTotals, limit: 5);

  final int transactionCount;
  final double totalAmount;
  final List<MonthlyAmount> monthlyTotals;
  final List<NamedAmount> categoryTotals;
  final double monthlyAverage;
  final List<NamedAmount> topCategories;

  Map<String, dynamic> toJson() {
    return {
      'transaction_count': transactionCount,
      'total_amount': totalAmount,
      'monthly_average': monthlyAverage,
      'monthly_totals': monthlyTotals.map((item) => item.toJson()).toList(),
      'category_totals': categoryTotals.map((item) => item.toJson()).toList(),
      'top_categories': topCategories.map((item) => item.toJson()).toList(),
    };
  }
}

class IncomeSummary {
  IncomeSummary({
    required this.transactionCount,
    required this.totalAmount,
    required this.monthlyTotals,
    required this.typeTotals,
  }) : monthlyAverage = monthlyTotals.isEmpty
           ? 0
           : totalAmount / monthlyTotals.length,
       topTypes = _buildTopItems(typeTotals, limit: 5);

  final int transactionCount;
  final double totalAmount;
  final List<MonthlyAmount> monthlyTotals;
  final List<NamedAmount> typeTotals;
  final double monthlyAverage;
  final List<NamedAmount> topTypes;

  Map<String, dynamic> toJson() {
    return {
      'transaction_count': transactionCount,
      'total_amount': totalAmount,
      'monthly_average': monthlyAverage,
      'monthly_totals': monthlyTotals.map((item) => item.toJson()).toList(),
      'type_totals': typeTotals.map((item) => item.toJson()).toList(),
      'top_types': topTypes.map((item) => item.toJson()).toList(),
    };
  }
}

class SavingSummary {
  SavingSummary({
    required this.currentTotal,
    required this.futureTotal,
    required this.totalCapital,
    required this.totalProfit,
    required this.plans,
    required this.activePlanCount,
  }) : topPlans = _buildTopSavingPlans(plans, limit: 3);

  final double currentTotal;
  final double futureTotal;
  final double totalCapital;
  final double totalProfit;
  final List<SavingPlanSnapshot> plans;
  final int activePlanCount;
  final List<SavingPlanSnapshot> topPlans;

  int get planCount => plans.length;

  Map<String, dynamic> toJson() {
    return {
      'current_total': currentTotal,
      'future_total': futureTotal,
      'total_capital': totalCapital,
      'total_profit': totalProfit,
      'plan_count': planCount,
      'active_plan_count': activePlanCount,
      'top_plans': topPlans.map((item) => item.toJson()).toList(),
      'plans': plans.map((item) => item.toJson()).toList(),
    };
  }
}

class SavingPlanSnapshot implements Comparable<SavingPlanSnapshot> {
  const SavingPlanSnapshot({
    required this.name,
    required this.status,
    required this.capital,
    required this.profit,
    required this.percent,
    required this.startLabel,
    required this.endLabel,
  });

  final String name;
  final String status;
  final double capital;
  final double profit;
  final double? percent;
  final String startLabel;
  final String endLabel;

  @override
  int compareTo(SavingPlanSnapshot other) => capital.compareTo(other.capital);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'status': status,
      'capital': capital,
      'profit': profit,
      'percent': percent,
      'start_label': startLabel,
      'end_label': endLabel,
    };
  }
}

class MonthlyAmount {
  const MonthlyAmount({
    required this.month,
    required this.year,
    required this.amount,
  });

  final int month;
  final int year;
  final double amount;

  String get label => '${month.toString().padLeft(2, '0')}/$year';

  Map<String, dynamic> toJson() {
    return {'month': month, 'year': year, 'label': label, 'amount': amount};
  }
}

class NamedAmount {
  const NamedAmount({
    required this.key,
    required this.label,
    required this.amount,
  });

  final String key;
  final String label;
  final double amount;

  Map<String, dynamic> toJson() {
    return {'key': key, 'label': label, 'amount': amount};
  }
}

List<NamedAmount> _buildTopItems(
  List<NamedAmount> items, {
  required int limit,
}) {
  final sorted = [...items]..sort((a, b) => b.amount.compareTo(a.amount));
  return sorted.take(limit).toList();
}

List<SavingPlanSnapshot> _buildTopSavingPlans(
  List<SavingPlanSnapshot> items, {
  required int limit,
}) {
  final sorted = [...items]..sort((a, b) => b.capital.compareTo(a.capital));
  return sorted.take(limit).toList();
}

class FinancialRange {
  const FinancialRange({required this.startMonth, required this.endMonth});

  final DateTime startMonth;
  final DateTime endMonth;

  int get monthCount =>
      (endMonth.year - startMonth.year) * 12 +
      endMonth.month -
      startMonth.month +
      1;

  Map<String, dynamic> toJson() {
    return {
      'start_month': FinancialAiSnapshot._monthLabel(startMonth),
      'end_month': FinancialAiSnapshot._monthLabel(endMonth),
      'month_count': monthCount,
    };
  }
}
