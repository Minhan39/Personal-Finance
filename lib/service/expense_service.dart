import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:personal_finance/service/supabase/supabase_expense_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/expense.dart';
import '../utils/fallback_stream_transformer.dart';

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

      final docRef = await _firestore.collection('expenses').add(expense);

      if (AppConfig.supabaseEnabled) {
        SupabaseExpenseService.addExpense(
          firebaseId: docRef.id,
          userId: currentUserId!,
          category: category,
          amount: amount,
          description: description,
          date: date ?? DateTime.now(),
        ).catchError((e) {
          debugPrint('Supabase mirror failed: $e');
          return e;
        });
      }

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
      if (AppConfig.supabaseEnabled && currentUserId != null) {
        final supabaseExpenses =
            await SupabaseExpenseService.getExpensesByMonth(
              month: month,
              year: year,
              userId: currentUserId!,
            );
        return supabaseExpenses.map((e) => e.toMap()..['id'] = e.id).toList();
      }
      return [];
    }
  }

  static Future<List<Expense>> getExpensesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    if (currentUserId == null) return [];
    if (AppConfig.supabaseEnabled) {
      try {
        final expenses = await SupabaseExpenseService.getExpensesByRange(
          startMonth: startMonth,
          endMonth: endMonth,
          userId: currentUserId!,
        );
        if (expenses.isNotEmpty) return expenses;
      } catch (e) {
        debugPrint('Supabase getExpensesByRange error, fallback Firebase: $e');
      }
    }

    try {
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
      debugPrint('Firebase getExpensesByRange error: $e');
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
      if (AppConfig.supabaseEnabled && currentUserId != null) {
        final supabaseExpenses =
            await SupabaseExpenseService.getMonthlyTotalsByYear(
              year: year,
              userId: currentUserId!,
            );
        return supabaseExpenses;
      }
      return List.filled(12, 0.0);
    }
  }

  static Future<bool> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).delete();
      if (AppConfig.supabaseEnabled) {
        SupabaseExpenseService.deleteExpense(expenseId);
      }
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
      final Map<String, dynamic> updateData = {
        if (category != null) 'category': category,
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (date != null) ...{
          'date': date,
          'month': date.month,
          'year': date.year,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updateData.length <= 1) return true;

      final futures = <Future>[
        _firestore.collection('expenses').doc(expenseId).update(updateData),
        if (AppConfig.supabaseEnabled) ...{
          SupabaseExpenseService.updateExpense(
            firebaseId: expenseId,
            category: category,
            amount: amount,
            description: description,
            date: date,
          ),
        },
      ];
      await Future.wait(futures);
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
    if (currentUserId == null) return Stream.value([]);

    final firebaseStream = _firestore
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

    if (!AppConfig.supabaseEnabled) return firebaseStream;

    return firebaseStream
        .handleError((_) {
          debugPrint('Firebase stream lỗi, chuyển sang Supabase Realtime');
        })
        .transform(
          FallbackStreamTransformer(
            fallbackStream: _buildSupabaseRealtimeStream(
              month: month,
              year: year,
            ),
          ),
        );
  }

  static Stream<List<Map<String, dynamic>>> _buildSupabaseRealtimeStream({
    required int month,
    required int year,
  }) {
    if (currentUserId == null) return Stream.value([]);

    final controller = StreamController<List<Map<String, dynamic>>>();
    final client = Supabase.instance.client;

    Future(() async {
      final res = await client
          .from('expenses')
          .select()
          .eq('user_id', currentUserId!)
          .eq('month', month)
          .eq('year', year)
          .order('date', ascending: false);

      if (!controller.isClosed) {
        controller.add(_mapSupabaseRows(res as List));
      }
    });

    final channel = client
        .channel('expenses_${currentUserId}_${year}_$month')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId!,
          ),
          callback: (payload) async {
            try {
              final res = await client
                  .from('expenses')
                  .select()
                  .eq('user_id', currentUserId!)
                  .eq('month', month)
                  .eq('year', year)
                  .order('date', ascending: false);

              if (!controller.isClosed) {
                controller.add(_mapSupabaseRows(res as List));
              }
            } catch (e) {
              debugPrint('Supabase realtime re-fetch error: $e');
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  static List<Map<String, dynamic>> _mapSupabaseRows(List rows) {
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return {
        'id': map['firebase_id'] ?? map['id'],
        'userId': map['user_id'],
        'category': map['category'],
        'amount': map['amount'],
        'description': map['description'] ?? '',
        'date': map['date'] is String
            ? Timestamp.fromDate(DateTime.parse(map['date']))
            : map['date'],
        'month': map['month'],
        'year': map['year'],
      };
    }).toList();
  }
}
