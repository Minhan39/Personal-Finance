import 'package:intl/intl.dart';

String formatVnd(double amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(amount);

double parseVnd(String value) {
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) {
    return 0;
  }
  return double.tryParse(digitsOnly) ?? 0;
}
