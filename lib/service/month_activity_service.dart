import '../models/expense.dart';
import '../models/income_model.dart';
import 'expense_service.dart';
import 'income_service.dart';

/// One transaction, income or expense, in a shape the lists can share.
class ActivityItem {
  const ActivityItem({
    required this.date,
    required this.amount,
    required this.isIncome,
    this.income,
    this.expense,
  });

  final DateTime date;
  final double amount;
  final bool isIncome;
  final IncomeModel? income;
  final Expense? expense;
}

/// Incomes and expenses of one month, merged.
class MonthActivity {
  const MonthActivity({
    required this.month,
    required this.year,
    required this.incomes,
    required this.expenses,
  });

  final int month;
  final int year;
  final List<IncomeModel> incomes;
  final List<Expense> expenses;

  double get totalIncome => incomes.fold(0, (sum, item) => sum + item.amount);

  double get totalExpense => expenses.fold(0, (sum, item) => sum + item.amount);

  double get net => totalIncome - totalExpense;

  /// Newest first.
  List<ActivityItem> get items {
    final all = [
      for (final income in incomes)
        ActivityItem(
          date: income.date,
          amount: income.amount,
          isIncome: true,
          income: income,
        ),
      for (final expense in expenses)
        ActivityItem(
          date: expense.date,
          amount: expense.amount,
          isIncome: false,
          expense: expense,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return all;
  }
}

class MonthActivityService {
  MonthActivityService({IncomeService? incomeService})
    : _incomeService = incomeService ?? IncomeService();

  final IncomeService _incomeService;

  Future<MonthActivity> load(int month, int year) async {
    final monthDate = DateTime(year, month);
    final results = await Future.wait([
      _incomeService.getIncomesByRange(
        startMonth: monthDate,
        endMonth: monthDate,
      ),
      ExpenseService.getExpensesByRange(
        startMonth: monthDate,
        endMonth: monthDate,
      ),
    ]);

    return MonthActivity(
      month: month,
      year: year,
      incomes: results[0] as List<IncomeModel>,
      expenses: results[1] as List<Expense>,
    );
  }
}
