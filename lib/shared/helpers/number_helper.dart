import 'package:intl/intl.dart';

class NumberHelper {
  static const GOLD_DIFFERENCE = 1_200_00;

  static String hideMoney() => '***.000,00 đ';

  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
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