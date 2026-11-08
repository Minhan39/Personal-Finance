import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class IncomeModel {
  final String id;
  final String userId;
  final IncomeType type;
  final double amount;
  final String note;
  final DateTime date;
  final int month;
  final int year;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IncomeModel({
    required this.id,
    required this.type,
    required this.amount,
    this.note = '',
    required this.date,
    required this.month,
    required this.year,
    this.createdAt,
    this.updatedAt,
    required this.userId,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    return IncomeModel(
      id: json['id'] ?? '',
      type: IncomeType.fromValue(json['type'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note'] ?? '',
      date: _dateTimeFromJson(json['date']) ?? DateTime.now(),
      month: (json['month'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
      userId: json['user_id'] ?? json['userId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.value,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
      'month': month,
      'year': year,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  IncomeModel copyWith({
    String? id,
    String? userId,
    IncomeType? type,
    double? amount,
    String? note,
    DateTime? date,
    int? month,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncomeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory IncomeModel.fromSupabase(Map<String, dynamic> row) {
    final parsedDate = _dateTimeFromJson(row['date']) ?? DateTime.now();
    return IncomeModel(
      id: row['firebase_id'] ?? row['id'],
      userId: row['user_id'] ?? row['userId'] ?? '',
      type: IncomeType.fromValue(row['type'] as String?),
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      note: row['note'] ?? '',
      date: parsedDate,
      month: parsedDate.month,
      year: parsedDate.year,
    );
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
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

enum IncomeType {
  salary,
  trading,
  teaching;

  String get label {
    switch (this) {
      case IncomeType.salary:
        return 'Lương';
      case IncomeType.trading:
        return 'Mua bán';
      case IncomeType.teaching:
        return 'Dạy học';
    }
  }

  IconData get icon {
    switch (this) {
      case IncomeType.salary:
        return Icons.work;
      case IncomeType.trading:
        return Icons.storefront;
      case IncomeType.teaching:
        return Icons.school;
    }
  }

  Color get color {
    switch (this) {
      case IncomeType.salary:
        return Colors.blue;
      case IncomeType.trading:
        return Colors.green;
      case IncomeType.teaching:
        return Colors.orange;
    }
  }

  String get value => name;

  static IncomeType fromValue(String? value) {
    return IncomeType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => IncomeType.salary,
    );
  }
}

extension IncomeTypeX on List<IncomeModel> {
  Map<IncomeType, double> totalByType() {
    final totals = {for (final type in IncomeType.values) type: 0.0};

    for (final income in this) {
      totals[income.type] = (totals[income.type] ?? 0) + income.amount;
    }

    return totals;
  }

  double grandTotal() {
    return fold<double>(
      0,
      (currentTotal, income) => currentTotal + income.amount,
    );
  }
}
