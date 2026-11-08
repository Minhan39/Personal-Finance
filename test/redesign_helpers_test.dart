import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/models/saving_plan.dart';
import 'package:personal_finance/service/savings_repository.dart';
import 'package:personal_finance/shared/helpers/number_helper.dart';
import 'package:personal_finance/shared/ui/lists.dart';

void main() {
  group('SavingsRepository.parse', () {
    final header = List<Object?>.filled(14, '');
    header[11] = '124.800.000 đ';
    header[13] = '138.500.000 đ';

    test('reads totals and skips cancelled plans', () {
      final overview = SavingsRepository.parse([
        header,
        [
          'Đang gửi',
          'mb',
          '6,2%',
          '01/01/2026',
          '',
          '01/01/2027',
          '80.000.000',
          '4.960.000',
        ],
        ['Đã huỷ', 'bidv', '5%', '', '', '', '10.000.000', '0'],
        ['Đang gửi', '9999', '', '', '', '', '24.000.000', '0'],
      ]);

      expect(overview.currentTotal, 124800000);
      expect(overview.futureTotal, 138500000);
      expect(overview.plans, hasLength(2));
      expect(overview.totalCapital, 104000000);
      expect(
        overview.plans.map((p) => p.kind),
        contains(SavingProviderKind.gold),
      );
    });

    test('handles an empty sheet', () {
      final overview = SavingsRepository.parse(const []);
      expect(overview.plans, isEmpty);
      expect(overview.currentTotal, 0);
    });
  });

  test('parseSheetDate accepts common formats', () {
    expect(parseSheetDate('05/11/2026'), DateTime(2026, 11, 5));
    expect(parseSheetDate('5-1-2026'), DateTime(2026, 1, 5));
    expect(parseSheetDate('2026-03-15'), DateTime(2026, 3, 15));
    expect(parseSheetDate('12/2026'), DateTime(2026, 12));
    expect(parseSheetDate('không rõ'), isNull);
  });

  test('NumberHelper.formatCompact shortens amounts', () {
    expect(NumberHelper.formatCompact(28500000), '28,5 tr');
    expect(NumberHelper.formatCompact(1200000000), '1,2 tỷ');
    expect(NumberHelper.formatCompact(-850000), '−850 k');
    expect(NumberHelper.formatCompact(500), '500 ₫');
  });

  test('NumberHelper.tryParseMoney is lenient', () {
    expect(NumberHelper.tryParseMoney('1.200.000 đ'), 1200000);
    expect(NumberHelper.tryParseMoney('-50.000₫'), -50000);
    expect(NumberHelper.tryParseMoney(42), 42);
    expect(NumberHelper.tryParseMoney(''), 0);
  });

  test('groupByDay groups newest day first', () {
    final dates = [
      DateTime(2026, 11, 1, 9),
      DateTime(2026, 11, 3, 8),
      DateTime(2026, 11, 1, 18),
    ];
    final groups = groupByDay(dates, (date) => date);

    expect(groups.map((g) => g.$1), [
      DateTime(2026, 11, 3),
      DateTime(2026, 11, 1),
    ]);
    expect(groups.last.$2.first, DateTime(2026, 11, 1, 18));
  });
}
