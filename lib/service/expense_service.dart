import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../models/expense.dart';

class ExpenseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  static Future<bool> addExpense({
    required String category,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    try {
      if (currentUserId == null) return false;

      final expense = {
        'userId': currentUserId,
        'category': category,
        'amount': amount,
        'description': description,
        'date': date ?? DateTime.now(),
        'month': (date ?? DateTime.now()).month,
        'year': (date ?? DateTime.now()).year,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('expenses').add(expense);
      return true;
    } catch (e) {
      debugPrint('Error adding expense: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getExpensesByMonth({
    required int month,
    required int year,
  }) async {
    try {
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('expenses')
          .where('userId', isEqualTo: currentUserId)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting expenses by month: $e');
      return [];
    }
  }

  static Future<List<Expense>> getExpensesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    try {
      if (currentUserId == null) return [];

      final normalizedStart = DateTime(startMonth.year, startMonth.month);
      final normalizedEnd = DateTime(endMonth.year, endMonth.month);
      final List<Expense> expenses = [];

      DateTime cursor = normalizedStart;
      while (!cursor.isAfter(normalizedEnd)) {
        final querySnapshot = await _firestore
            .collection('expenses')
            .where('userId', isEqualTo: currentUserId)
            .where('month', isEqualTo: cursor.month)
            .where('year', isEqualTo: cursor.year)
            .orderBy('date')
            .get();

        expenses.addAll(
          querySnapshot.docs.map(
            (doc) => Expense.fromMap(doc.data(), id: doc.id),
          ),
        );

        cursor = DateTime(cursor.year, cursor.month + 1);
      }

      expenses.sort((a, b) => a.date.compareTo(b.date));
      return expenses;
    } catch (e) {
      debugPrint('Error getting expenses by range: $e');
      return [];
    }
  }

  static Future<Map<String, double>> getCategoryTotalsByMonth({
    required int month,
    required int year,
  }) async {
    try {
      if (currentUserId == null) return {};

      final expenses = await getExpensesByMonth(month: month, year: year);
      final Map<String, double> categoryTotals = {};

      for (final expense in expenses) {
        final category = expense['category'] as String;
        final amount = (expense['amount'] as num).toDouble();

        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }

      return categoryTotals;
    } catch (e) {
      debugPrint('Error getting category totals: $e');
      return {};
    }
  }

  static Future<List<double>> getMonthlyTotalsByYear(int year) async {
    try {
      if (currentUserId == null) return List.filled(12, 0.0);

      final List<double> monthlyTotals = List.filled(12, 0.0);

      for (int month = 1; month <= 12; month++) {
        final querySnapshot = await _firestore
            .collection('expenses')
            .where('userId', isEqualTo: currentUserId)
            .where('month', isEqualTo: month)
            .where('year', isEqualTo: year)
            .get();

        double monthTotal = 0;
        for (final doc in querySnapshot.docs) {
          monthTotal += (doc.data()['amount'] as num).toDouble();
        }
        monthlyTotals[month - 1] = monthTotal;
      }

      return monthlyTotals;
    } catch (e) {
      debugPrint('Error getting monthly totals by year: $e');
      return List.filled(12, 0.0);
    }
  }

  static Future<bool> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  static Future<bool> updateExpense({
    required String expenseId,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (category != null) updateData['category'] = category;
      if (amount != null) updateData['amount'] = amount;
      if (description != null) updateData['description'] = description;
      if (date != null) {
        updateData['date'] = date;
        updateData['month'] = date.month;
        updateData['year'] = date.year;
      }

      if (updateData.isNotEmpty) {
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('expenses')
            .doc(expenseId)
            .update(updateData);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      return false;
    }
  }

  static Future<double> getTotalExpenseByMonth({
    required int month,
    required int year,
  }) async {
    try {
      final categoryTotals = await getCategoryTotalsByMonth(
        month: month,
        year: year,
      );
      return categoryTotals.values.fold<double>(
        0.0,
        (double sum, double amount) => sum + amount,
      );
    } catch (e) {
      debugPrint('Error getting total expense by month: $e');
      return 0.0;
    }
  }

  static Stream<List<Map<String, dynamic>>> watchExpensesByMonth({
    required int month,
    required int year,
  }) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('expenses')
        .where('userId', isEqualTo: currentUserId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }
}
