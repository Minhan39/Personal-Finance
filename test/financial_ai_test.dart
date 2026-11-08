import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/models/financial_snapshot.dart';

void main() {
  group('FinancialAiSnapshot', () {
    test('builds derived metrics and report payload', () {
      final snapshot = FinancialAiSnapshot(
        startMonth: DateTime(2026, 1),
        endMonth: DateTime(2026, 3),
        expenses: ExpenseSummary(
          transactionCount: 3,
          totalAmount: 6000000,
          monthlyTotals: const [
            MonthlyAmount(month: 1, year: 2026, amount: 1000000),
            MonthlyAmount(month: 2, year: 2026, amount: 2000000),
            MonthlyAmount(month: 3, year: 2026, amount: 3000000),
          ],
          categoryTotals: const [
            NamedAmount(key: 'Food', label: 'Ăn uống', amount: 2000000),
            NamedAmount(key: 'Transport', label: 'Di chuyển', amount: 1000000),
          ],
        ),
        incomes: IncomeSummary(
          transactionCount: 2,
          totalAmount: 9000000,
          monthlyTotals: const [
            MonthlyAmount(month: 1, year: 2026, amount: 2000000),
            MonthlyAmount(month: 2, year: 2026, amount: 3000000),
            MonthlyAmount(month: 3, year: 2026, amount: 4000000),
          ],
          typeTotals: const [
            NamedAmount(key: 'salary', label: 'Lương', amount: 9000000),
          ],
        ),
        savings: SavingSummary(
          currentTotal: 1500000,
          futureTotal: 3000000,
          totalCapital: 1200000,
          totalProfit: 300000,
          activePlanCount: 1,
          plans: const [
            SavingPlanSnapshot(
              name: 'Quỹ dự phòng',
              status: 'Đang hoạt động',
              capital: 1200000,
              profit: 300000,
              percent: 25,
              startLabel: '01/2026',
              endLabel: '12/2026',
            ),
          ],
        ),
        generatedAt: DateTime(2026, 3, 15),
      );

      expect(snapshot.monthCount, 3);
      expect(snapshot.netCashFlow, 3000000);
      expect(snapshot.expenseToIncomeRatio, closeTo(2 / 3, 0.0001));

      final prompt = snapshot.toPromptJson();
      expect(prompt['period'], isA<Map<String, dynamic>>());
      expect(prompt['income'], isA<Map<String, dynamic>>());
      expect(prompt['saving'], isA<Map<String, dynamic>>());
      expect(prompt['derived'], isA<Map<String, dynamic>>());
    });
  });
}
