import '../models/expense.dart';
import '../models/financial_snapshot.dart';
import '../models/income_model.dart';
import 'expense_service.dart';
import 'income_service.dart';
import 'save_service.dart';

class FinancialAiSnapshotService {
  FinancialAiSnapshotService({IncomeService? incomeService})
    : _incomeService = incomeService ?? IncomeService();

  final IncomeService _incomeService;

  static FinancialRange defaultRange([DateTime? now]) {
    final current = now ?? DateTime.now();
    final endMonth = DateTime(current.year, current.month);
    final startMonth = DateTime(current.year, current.month - 5);
    return FinancialRange(startMonth: startMonth, endMonth: endMonth);
  }

  Future<FinancialAiSnapshot> build({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final normalizedStart = DateTime(startMonth.year, startMonth.month);
    final normalizedEnd = DateTime(endMonth.year, endMonth.month);

    final results = await Future.wait([
      ExpenseService.getExpensesByRange(
        startMonth: normalizedStart,
        endMonth: normalizedEnd,
      ),
      _incomeService.getIncomesByRange(
        startMonth: normalizedStart,
        endMonth: normalizedEnd,
      ),
      SaveService.readSheet(),
    ]);

    final expenses = results[0] as List<Expense>;
    final incomes = results[1] as List<IncomeModel>;
    final rows = results[2] as List<List<Object?>>?;

    return FinancialAiSnapshot(
      startMonth: normalizedStart,
      endMonth: normalizedEnd,
      expenses: _buildExpenseSummary(expenses, normalizedStart, normalizedEnd),
      incomes: _buildIncomeSummary(incomes, normalizedStart, normalizedEnd),
      savings: _buildSavingSummary(rows),
      generatedAt: DateTime.now(),
    );
  }

  ExpenseSummary _buildExpenseSummary(
    List<Expense> expenses,
    DateTime startMonth,
    DateTime endMonth,
  ) {
    final monthlyTotals = _buildMonthlyTotals(
      startMonth: startMonth,
      endMonth: endMonth,
      items: expenses,
      dateOf: (expense) => expense.date,
      amountOf: (expense) => expense.amount,
    );

    final categoryTotalsMap = <String, double>{};
    for (final expense in expenses) {
      categoryTotalsMap[expense.category] =
          (categoryTotalsMap[expense.category] ?? 0) + expense.amount;
    }

    final categoryTotals = categoryTotalsMap.entries
        .map(
          (entry) => NamedAmount(
            key: entry.key,
            label: ExpenseCategory.fromKey(entry.key).displayName,
            amount: entry.value,
          ),
        )
        .toList();

    return ExpenseSummary(
      transactionCount: expenses.length,
      totalAmount: expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      ),
      monthlyTotals: monthlyTotals,
      categoryTotals: categoryTotals,
    );
  }

  IncomeSummary _buildIncomeSummary(
    List<IncomeModel> incomes,
    DateTime startMonth,
    DateTime endMonth,
  ) {
    final monthlyTotals = _buildMonthlyTotals(
      startMonth: startMonth,
      endMonth: endMonth,
      items: incomes,
      dateOf: (income) => income.date,
      amountOf: (income) => income.amount,
    );

    final typeTotalsMap = <String, double>{};
    for (final income in incomes) {
      final key = income.type.value;
      typeTotalsMap[key] = (typeTotalsMap[key] ?? 0) + income.amount;
    }

    final typeTotals = typeTotalsMap.entries
        .map(
          (entry) => NamedAmount(
            key: entry.key,
            label: IncomeType.fromValue(entry.key).label,
            amount: entry.value,
          ),
        )
        .toList();

    return IncomeSummary(
      transactionCount: incomes.length,
      totalAmount: incomes.fold<double>(
        0,
        (sum, income) => sum + income.amount,
      ),
      monthlyTotals: monthlyTotals,
      typeTotals: typeTotals,
    );
  }

  SavingSummary _buildSavingSummary(List<List<Object?>>? rows) {
    final sheetRows = rows ?? const [];

    final currentTotal = _readLabeledMoney(
      sheetRows,
      preferredRow: 0,
      preferredColumn: 11,
      labelHints: const [
        'quy hien co',
        'hien co',
        'current',
        'current total',
        'so du hien co',
        'quy hien tai',
      ],
    );
    final futureTotal = _readLabeledMoney(
      sheetRows,
      preferredRow: 0,
      preferredColumn: 13,
      labelHints: const [
        'quy tuong lai',
        'tuong lai',
        'future',
        'future total',
        'du kien',
        'ke hoach',
      ],
    );

    final plans = <SavingPlanSnapshot>[];
    for (var index = 1; index < sheetRows.length; index++) {
      final row = sheetRows[index];
      if (row.isEmpty) continue;

      final status = _cellValue(row, 0).trim();
      if (_isCancelled(status)) {
        continue;
      }

      final name = _cellValue(row, 1).trim().isEmpty
          ? 'Ke hoach $index'
          : _cellValue(row, 1).trim();
      final percent = _parsePercent(_cellValue(row, 2));
      final startLabel = _cellValue(row, 3).trim();
      final endLabel = _cellValue(row, 5).trim();
      final capital = _parseMoney(_cellValue(row, 6));
      final profit = _parseMoney(_cellValue(row, 7));

      plans.add(
        SavingPlanSnapshot(
          name: name,
          status: status.isEmpty ? 'Dang hoat dong' : status,
          capital: capital,
          profit: profit,
          percent: percent,
          startLabel: startLabel,
          endLabel: endLabel,
        ),
      );
    }

    final totalCapital = plans.fold<double>(
      0,
      (sum, plan) => sum + plan.capital,
    );
    final totalProfit = plans.fold<double>(0, (sum, plan) => sum + plan.profit);

    return SavingSummary(
      currentTotal: currentTotal,
      futureTotal: futureTotal,
      totalCapital: totalCapital,
      totalProfit: totalProfit,
      plans: plans,
      activePlanCount: plans.length,
    );
  }

  List<MonthlyAmount> _buildMonthlyTotals<T>({
    required DateTime startMonth,
    required DateTime endMonth,
    required List<T> items,
    required DateTime Function(T item) dateOf,
    required double Function(T item) amountOf,
  }) {
    final totals = <String, double>{};
    var cursor = DateTime(startMonth.year, startMonth.month);

    while (!cursor.isAfter(endMonth)) {
      totals[_monthKey(cursor)] = 0;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    for (final item in items) {
      final key = _monthKey(dateOf(item));
      if (!totals.containsKey(key)) {
        continue;
      }
      totals[key] = (totals[key] ?? 0) + amountOf(item);
    }

    final result = <MonthlyAmount>[];
    var current = DateTime(startMonth.year, startMonth.month);
    while (!current.isAfter(endMonth)) {
      final key = _monthKey(current);
      result.add(
        MonthlyAmount(
          month: current.month,
          year: current.year,
          amount: totals[key] ?? 0,
        ),
      );
      current = DateTime(current.year, current.month + 1);
    }

    return result;
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _cellValue(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.toString() ?? '';
  }

  Object? _cell(List<List<Object?>> rows, int rowIndex, int columnIndex) {
    if (rowIndex < 0 || rowIndex >= rows.length) return null;
    final row = rows[rowIndex];
    if (columnIndex < 0 || columnIndex >= row.length) return null;
    return row[columnIndex];
  }

  double _parseMoney(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    final raw = value.toString().trim();
    if (raw.isEmpty) return 0;

    var normalized = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.isEmpty) return 0;

    final lastComma = normalized.lastIndexOf(',');
    final lastDot = normalized.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '');
        normalized = normalized.replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (lastComma != -1) {
      final decimals = normalized.length - lastComma - 1;
      if (decimals == 1 || decimals == 2) {
        normalized = normalized.replaceAll('.', '');
        normalized = normalized.replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (lastDot != -1) {
      final decimals = normalized.length - lastDot - 1;
      if (normalized.indexOf('.') != lastDot || decimals > 2) {
        normalized = normalized.replaceAll('.', '');
      }
    }

    if (normalized == '-' || normalized == '.' || normalized == '-.') {
      return 0;
    }

    return double.tryParse(normalized) ?? 0;
  }

  double _readLabeledMoney(
    List<List<Object?>> rows, {
    required int preferredRow,
    required int preferredColumn,
    required List<String> labelHints,
  }) {
    final preferredCell = _cell(rows, preferredRow, preferredColumn);
    final preferredValue = _parseMoney(preferredCell);
    if (_hasMoneyContent(preferredCell)) {
      return preferredValue;
    }

    final normalizedHints = labelHints
        .map((hint) => _normalizeText(hint))
        .where((hint) => hint.isNotEmpty)
        .toList();

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var index = 0; index < row.length; index++) {
        final cellText = _normalizeText(_cellValue(row, index));
        if (cellText.isEmpty) continue;

        if (!normalizedHints.any((hint) => cellText.contains(hint))) {
          continue;
        }

        for (final candidate in _candidateCells(rows, rowIndex, index)) {
          if (_hasMoneyContent(candidate)) {
            return _parseMoney(candidate);
          }
        }
      }
    }

    return preferredValue;
  }

  Iterable<Object?> _candidateCells(
    List<List<Object?>> rows,
    int rowIndex,
    int columnIndex,
  ) sync* {
    const sameRowOffsets = [1, 2, -1, 3, -2, 4, -3, 5, -4];
    for (final offset in sameRowOffsets) {
      yield _cell(rows, rowIndex, columnIndex + offset);
    }

    const rowOffsets = [1, -1, 2, -2];
    const columnOffsets = [0, 1, -1, 2, -2];
    for (final rowOffset in rowOffsets) {
      for (final columnOffset in columnOffsets) {
        yield _cell(rows, rowIndex + rowOffset, columnIndex + columnOffset);
      }
    }
  }

  bool _hasMoneyContent(Object? value) {
    if (value == null) return false;
    if (value is num) return true;

    final text = value.toString().trim();
    if (text.isEmpty) return false;
    return RegExp(r'\d').hasMatch(text);
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^0-9a-zà-ỹ]+'), ' ')
        .trim();
  }

  double? _parsePercent(String value) {
    final normalized = value.replaceAll('%', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  bool _isCancelled(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('huỷ') ||
        normalized.contains('hủy') ||
        normalized.contains('cancel');
  }
}
