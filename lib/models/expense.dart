import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String userId;
  final String category;
  final double amount;
  final String description;
  final DateTime date;
  final int month;
  final int year;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Expense({
    this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    required this.month,
    required this.year,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map, {String? id}) {
    return Expense(
      id: id,
      userId: (map['userId'] ?? map['user_id'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: (map['description'] ?? '') as String,
      date: _dateFromDynamic(map['date']) ?? DateTime.now(),
      month: (map['month'] as num?)?.toInt() ?? 1,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      createdAt: _dateFromDynamic(map['createdAt']),
      updatedAt: _dateFromDynamic(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'month': month,
      'year': year,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Expense copyWith({
    String? id,
    String? userId,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
    int? month,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Expense.fromSupabase(Map<String, dynamic> row) {
    final parsedDate = _dateFromDynamic(row['date']) ?? DateTime.now();

    return Expense(
      id: row['firebase_id'] ?? row['id'],
      userId: row['user_id'] ?? row['userId'] ?? '',
      category: row['category'] ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
      description: row['description'] ?? '',
      date: parsedDate,
      month: parsedDate.month,
      year: parsedDate.year,
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, category: $category, amount: $amount, description: $description, date: $date}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          category == other.category &&
          amount == other.amount &&
          description == other.description &&
          date == other.date;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      category.hashCode ^
      amount.hashCode ^
      description.hashCode ^
      date.hashCode;

  static DateTime? _dateFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is Map && value['seconds'] != null) {
      final seconds = value['seconds'];
      final nanoseconds = value['nanoseconds'] ?? 0;
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds is int ? nanoseconds ~/ 1000000 : 0),
        );
      }
    }
    return null;
  }
}

enum ExpenseCategory {
  food('Food', '\u0102n u\u1ed1ng', [
    'c\u01a1m tr\u01b0a',
    'tr\u00e0 s\u1eefa',
    'c\u00e0 ph\u00ea',
    'b\u00e1nh tr\u00e1ng n\u01b0\u1edbng',
    'k\u00e8o \u0103n',
  ]),
  bills('Bills', 'H\u00f3a \u0111\u01a1n', [
    'ti\u1ec1n \u0111i\u1ec7n',
    'ti\u1ec1n n\u01b0\u1edbc',
    '4g 1 ng\u00e0y',
    'n\u1ea1p \u0111i\u1ec7n tho\u1ea1i',
    'ChatGPT Plus',
  ]),
  shopping('Shopping', 'Mua s\u1eafm', [
    '\u0111\u1ed3 b\u00e1ch ho\u00e1',
    'mua \u00e1o',
    'mua gi\u00e0y',
    'thu\u1ed1c',
    '\u0111\u1ed3 gia d\u1ee5ng',
  ]),
  transport('Transport', 'Di chuy\u1ec3n', [
    '\u0111\u1ed5 x\u0103ng',
    'g\u1eedi xe',
    'b\u1eaft grab',
    'b\u01a1m b\u00e1nh xe',
    's\u1eeda xe',
  ]),
  family('Family', 'H\u1ed7 tr\u1ee3 gia \u0111\u00ecnh', ['g\u1eedi m\u1eb9']),
  social(
    'Social',
    'Qu\u00e0 c\u00e1p, hi\u1ebfu h\u1ef7, giao l\u01b0u, l\u00ec x\u00ec',
    [
      'sinh nh\u1eadt',
      'l\u00ec x\u00ec',
      'qu\u00e0 t\u1eb7ng',
      'm\u1eebng',
      '\u1ee7ng h\u1ed9',
    ],
  ),
  personal('Personal', 'Gi\u1ea3i tr\u00ed, c\u00e1 nh\u00e2n', [
    'c\u1eaft t\u00f3c',
    '\u0111i net',
    '\u0111i b\u01a1i',
    'kh\u00e1m s\u1ee9c kho\u1ebb',
    'gi\u1ea5y t\u1edd c\u00e1 nh\u00e2n',
  ]),
  lend('Lend', 'Cho m\u01b0\u1ee3n / chi h\u1ed9', []),
  other('Other', 'Kh\u00e1c', []);

  const ExpenseCategory(this.key, this.displayName, this.quickSuggestions);

  final String key;
  final String displayName;
  final List<String> quickSuggestions;

  static ExpenseCategory fromKey(String key) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.key == key,
      orElse: () => ExpenseCategory.other,
    );
  }

  static List<String> get allKeys =>
      ExpenseCategory.values.map((e) => e.key).toList();

  static List<String> get allDisplayNames =>
      ExpenseCategory.values.map((e) => e.displayName).toList();
}
