import 'package:flutter/material.dart';

import '../../../models/expense.dart';

/// Colors and icons for expense categories, indexed in the same order as
/// [ExpenseCategory.values].
class ExpenseCategoryStyle {
  ExpenseCategoryStyle._();

  static const List<Color> _colors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFF6B7280),
  ];

  static const List<IconData> _icons = [
    Icons.restaurant, // Food
    Icons.inventory_outlined, // Bills
    Icons.shopping_cart, // Shopping
    Icons.pedal_bike, // Transport
    Icons.family_restroom, // Family
    Icons.celebration_outlined, // Social
    Icons.person_outline, // Personal
    Icons.handshake_outlined, // Lend
    Icons.more_horiz, // Other
  ];

  static int indexOf(String categoryKey) =>
      ExpenseCategory.allKeys.indexOf(categoryKey);

  static int get otherIndex => indexOf('Other');

  /// Unknown categories ([index] < 0) fall back to the "Other" color.
  static Color colorAt(int index) {
    final effective = index >= 0 ? index : otherIndex;
    return _colors[(effective < 0 ? 0 : effective) % _colors.length];
  }

  static IconData iconAt(int index) =>
      index >= 0 && index < _icons.length ? _icons[index] : Icons.more_horiz;
}
