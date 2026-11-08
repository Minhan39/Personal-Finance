import 'package:intl/intl.dart';

class NumberHelper {
  static const goldDifference = 120_000;

  static String hideMoney() => '***.000,00 đ';

  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Short form for tight spaces: "28,5 tr", "1,2 tỷ", "850 k".
  static String formatCompact(double amount) {
    final sign = amount < 0 ? '−' : '';
    final abs = amount.abs();
    String fmt(double value) => NumberFormat('#,##0.#', 'vi_VN').format(value);
    if (abs >= 1e9) return '$sign${fmt(abs / 1e9)} tỷ';
    if (abs >= 1e6) return '$sign${fmt(abs / 1e6)} tr';
    if (abs >= 1e3) return '$sign${fmt(abs / 1e3)} k';
    return '$sign${fmt(abs)} ₫';
  }

  /// Lenient parser for sheet values such as "1.200.000 đ" or "-50.000₫";
  /// returns 0 when the text holds no number.
  static double tryParseMoney(Object? value) {
    if (value is num) return value.toDouble();
    final text = (value?.toString() ?? '')
        .replaceAll(RegExp(r'[^0-9,\-]'), '')
        .replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  static double parseMoney(String value) {
    final cleaned = value
        .replaceAll('đ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();

    return double.parse(cleaned);
  }
}
