import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'package:personal_finance/config/app_config.dart';
import 'package:personal_finance/service/auth_service.dart';
import 'package:personal_finance/service/data_source_sync.dart';
import 'package:personal_finance/service/supabase/supabase_expense_service.dart';

import '../models/expense.dart';

class ExpenseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _supabaseKey = 'expense_supabase';
  static const String _firebaseKey = 'expense_firebase';

  static String? get supabaseUserId => AppAuthService.supabaseUserId;

  static String? get firebaseUserId => AppAuthService.firebaseUserId;

  static bool get _canUseSupabase =>
      AppConfig.supabaseEnabled && SourceCircuitBreaker.canUse(_supabaseKey);

  static bool get _canUseFirebase => SourceCircuitBreaker.canUse(_firebaseKey);

  static Future<bool> addExpense({
    required String category,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final docRef = _firestore.collection('expenses').doc();

    try {
      final effectiveDate = date ?? DateTime.now();
      final supabaseExpense = supabaseUserId == null
          ? null
          : Expense(
              id: docRef.id,
              userId: supabaseUserId!,
              category: category,
              amount: amount,
              description: description,
              date: effectiveDate,
              month: effectiveDate.month,
              year: effectiveDate.year,
            );
      final firebaseExpense = firebaseUserId == null
          ? null
          : Expense(
              id: docRef.id,
              userId: firebaseUserId!,
              category: category,
              amount: amount,
              description: description,
              date: effectiveDate,
              month: effectiveDate.month,
              year: effectiveDate.year,
            );

      var success = false;

      if (supabaseExpense != null && _canUseSupabase) {
        final supabaseId = await SupabaseExpenseService.addExpense(
          firebaseId: docRef.id,
          userId: supabaseExpense.userId,
          category: category,
          amount: amount,
          description: description,
          date: effectiveDate,
        );
        if (supabaseId != null) {
          SourceCircuitBreaker.markSuccess(_supabaseKey);
          success = true;
        } else {
          SourceCircuitBreaker.markFailure(_supabaseKey);
        }
      }

      if (firebaseExpense != null && _canUseFirebase) {
        await docRef.set(_expenseToFirestoreMap(firebaseExpense));
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        success = true;
      }

      return success;
    } catch (e) {
      debugPrint('Error adding expense: $e');
      if (_canUseFirebase && firebaseUserId != null) {
        try {
          final effectiveDate = date ?? DateTime.now();
          await _firestore.collection('expenses').doc(docRef.id).set(
                {
                  'userId': firebaseUserId,
                  'category': category,
                  'amount': amount,
                  'description': description,
                  'date': effectiveDate,
                  'month': effectiveDate.month,
                  'year': effectiveDate.year,
                  'createdAt': FieldValue.serverTimestamp(),
                },
              );
          SourceCircuitBreaker.markSuccess(_firebaseKey);
          return true;
        } catch (firebaseError) {
          debugPrint('Firebase addExpense fallback failed: $firebaseError');
          SourceCircuitBreaker.markFailure(_firebaseKey);
        }
      }
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getExpensesByMonth({
    required int month,
    required int year,
  }) async {
    final primaryEnabled = supabaseUserId != null && _canUseSupabase;
    final fallbackEnabled = firebaseUserId != null && _canUseFirebase;
    if (!primaryEnabled && !fallbackEnabled) return [];

    final expenses = primaryEnabled && fallbackEnabled
        ? await _loadSyncedExpenses(
            logLabel: 'Expense month $month/$year',
            primaryFetch: () => _fetchSupabaseExpensesByMonth(month, year),
            fallbackFetch: () => _fetchFirebaseExpensesByMonth(month, year),
            pushToPrimary: _saveExpenseToSupabase,
            pushToFallback: _saveExpenseToFirebase,
          )
        : primaryEnabled
        ? await _fetchSupabaseExpensesByMonth(month, year)
        : await _fetchFirebaseExpensesByMonth(month, year);

    return expenses.map((expense) => _expenseToMap(expense)).toList();
  }

  static Future<List<Expense>> getExpensesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final primaryEnabled = supabaseUserId != null && _canUseSupabase;
    final fallbackEnabled = firebaseUserId != null && _canUseFirebase;
    if (!primaryEnabled && !fallbackEnabled) return [];

    final normalizedStart = DateTime(startMonth.year, startMonth.month);
    final normalizedEnd = DateTime(endMonth.year, endMonth.month);

    if (primaryEnabled && fallbackEnabled) {
      return _loadSyncedExpenses(
        logLabel: 'Expense range',
        primaryFetch: () => _fetchSupabaseExpensesByRange(
          startMonth: normalizedStart,
          endMonth: normalizedEnd,
        ),
        fallbackFetch: () => _fetchFirebaseExpensesByRange(
          startMonth: normalizedStart,
          endMonth: normalizedEnd,
        ),
        pushToPrimary: _saveExpenseToSupabase,
        pushToFallback: _saveExpenseToFirebase,
      );
    }

    if (primaryEnabled) {
      return _fetchSupabaseExpensesByRange(
        startMonth: normalizedStart,
        endMonth: normalizedEnd,
      );
    }

    return _fetchFirebaseExpensesByRange(
      startMonth: normalizedStart,
      endMonth: normalizedEnd,
    );
  }

  static Future<Map<String, double>> getCategoryTotalsByMonth({
    required int month,
    required int year,
  }) async {
    try {
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
    final primaryEnabled = supabaseUserId != null && _canUseSupabase;
    final fallbackEnabled = firebaseUserId != null && _canUseFirebase;

    if (!primaryEnabled && !fallbackEnabled) {
      return List.filled(12, 0.0);
    }

    final expenses = primaryEnabled && fallbackEnabled
        ? await _loadSyncedExpenses(
            logLabel: 'Expense year $year',
            primaryFetch: () => _fetchSupabaseExpensesByYear(year),
            fallbackFetch: () => _fetchFirebaseExpensesByYear(year),
            pushToPrimary: _saveExpenseToSupabase,
            pushToFallback: _saveExpenseToFirebase,
          )
        : primaryEnabled
        ? await _fetchSupabaseExpensesByYear(year)
        : await _fetchFirebaseExpensesByYear(year);

    final monthlyTotals = List.filled(12, 0.0);
    for (final expense in expenses) {
      monthlyTotals[expense.month - 1] += expense.amount;
    }
    return monthlyTotals;
  }

  static Future<bool> deleteExpense(String expenseId) async {
    var success = false;

    if (supabaseUserId != null && _canUseSupabase) {
      final supabaseDeleted = await SupabaseExpenseService.deleteExpense(
        expenseId,
      );
      if (supabaseDeleted) {
        SourceCircuitBreaker.markSuccess(_supabaseKey);
        success = true;
      } else {
        SourceCircuitBreaker.markFailure(_supabaseKey);
      }
    }

    if (_canUseFirebase) {
      try {
        await _firestore.collection('expenses').doc(expenseId).delete();
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        success = true;
      } catch (e) {
        debugPrint('Error deleting expense: $e');
        SourceCircuitBreaker.markFailure(_firebaseKey);
      }
    }

    return success;
  }

  static Future<bool> updateExpense({
    required String expenseId,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
  }) async {
    var success = false;

    if (supabaseUserId != null && _canUseSupabase) {
      final supabaseDate = date ?? DateTime.now();
      final supabaseUpdated = await SupabaseExpenseService.updateExpense(
        firebaseId: expenseId,
        category: category,
        amount: amount,
        description: description,
        date: supabaseDate,
      );
      if (supabaseUpdated) {
        SourceCircuitBreaker.markSuccess(_supabaseKey);
        success = true;
      } else {
        SourceCircuitBreaker.markFailure(_supabaseKey);
      }
    }

    if (_canUseFirebase) {
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

        if (updateData.length > 1) {
          await _firestore.collection('expenses').doc(expenseId).update(
                updateData,
              );
          SourceCircuitBreaker.markSuccess(_firebaseKey);
          success = true;
        }
      } catch (e) {
        debugPrint('Error updating expense: $e');
        SourceCircuitBreaker.markFailure(_firebaseKey);
      }
    }

    return success;
  }

  static Future<List<Expense>> _loadSyncedExpenses({
    required String logLabel,
    required Future<List<Expense>> Function() primaryFetch,
    required Future<List<Expense>> Function() fallbackFetch,
    required Future<bool> Function(Expense expense) pushToPrimary,
    required Future<bool> Function(Expense expense) pushToFallback,
  }) async {
    final primaryEnabled = _canUseSupabase;
    final fallbackEnabled = _canUseFirebase;

    if (primaryEnabled && fallbackEnabled) {
      return reconcileBetweenSources<Expense>(
        primarySourceKey: _supabaseKey,
        fallbackSourceKey: _firebaseKey,
        logLabel: logLabel,
        primaryFetch: primaryFetch,
        fallbackFetch: fallbackFetch,
        pushToPrimary: pushToPrimary,
        pushToFallback: pushToFallback,
        itemId: (expense) => expense.id ?? '',
        sortItems: _sortExpenses,
      );
    }

    if (primaryEnabled) {
      try {
        final data = await primaryFetch();
        SourceCircuitBreaker.markSuccess(_supabaseKey);
        return _sortExpenses(data);
      } catch (error) {
        debugPrint('$logLabel primary fetch failed: $error');
        SourceCircuitBreaker.markFailure(_supabaseKey);
      }
    }

    if (fallbackEnabled) {
      try {
        final data = await fallbackFetch();
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        return _sortExpenses(data);
      } catch (error) {
        debugPrint('$logLabel fallback fetch failed: $error');
        SourceCircuitBreaker.markFailure(_firebaseKey);
      }
    }

    return [];
  }

  static Future<List<Expense>> _fetchFirebaseExpensesByMonth(
    int month,
    int year,
  ) async {
    if (firebaseUserId == null) {
      return [];
    }

    final primary = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: firebaseUserId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();

    final legacy = await _firestore
        .collection('expenses')
        .where('user_id', isEqualTo: firebaseUserId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();

    return _sortExpenses([
      ...primary.docs.map((doc) => Expense.fromMap(doc.data(), id: doc.id)),
      ...legacy.docs.map((doc) => Expense.fromMap(doc.data(), id: doc.id)),
    ]);
  }

  static Future<List<Expense>> _fetchFirebaseExpensesByYear(int year) async {
    if (firebaseUserId == null) {
      return [];
    }

    final primary = await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: firebaseUserId)
        .where('year', isEqualTo: year)
        .get();

    final legacy = await _firestore
        .collection('expenses')
        .where('user_id', isEqualTo: firebaseUserId)
        .where('year', isEqualTo: year)
        .get();

    return _sortExpenses([
      ...primary.docs.map((doc) => Expense.fromMap(doc.data(), id: doc.id)),
      ...legacy.docs.map((doc) => Expense.fromMap(doc.data(), id: doc.id)),
    ]);
  }

  static Future<List<Expense>> _fetchFirebaseExpensesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final expenses = <Expense>[];
    var cursor = startMonth;

    while (!cursor.isAfter(endMonth)) {
      final monthly = await _fetchFirebaseExpensesByMonth(
        cursor.month,
        cursor.year,
      );
      expenses.addAll(monthly);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return _sortExpenses(expenses);
  }

  static Future<List<Expense>> _fetchSupabaseExpensesByMonth(
    int month,
    int year,
  ) async {
    final res = await SupabaseExpenseService.getExpensesByMonth(
      month: month,
      year: year,
      userId: supabaseUserId!,
    );
    return _sortExpenses(res);
  }

  static Future<List<Expense>> _fetchSupabaseExpensesByYear(int year) async {
    final expenses = <Expense>[];
    for (var month = 1; month <= 12; month++) {
      final monthExpenses = await SupabaseExpenseService.getExpensesByMonth(
        month: month,
        year: year,
        userId: supabaseUserId!,
      );
      expenses.addAll(monthExpenses);
    }

    return _sortExpenses(expenses);
  }

  static Future<List<Expense>> _fetchSupabaseExpensesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final res = await SupabaseExpenseService.getExpensesByRange(
      startMonth: startMonth,
      endMonth: endMonth,
      userId: supabaseUserId!,
    );
    return _sortExpenses(res);
  }

  static Future<bool> _saveExpenseToFirebase(Expense expense) async {
    if (firebaseUserId == null || !_canUseFirebase || expense.id == null) {
      return false;
    }

    try {
      final firebaseExpense = expense.copyWith(userId: firebaseUserId!);
      await _firestore.collection('expenses').doc(expense.id).set(
            _expenseToFirestoreMap(firebaseExpense),
            SetOptions(merge: true),
          );
      SourceCircuitBreaker.markSuccess(_firebaseKey);
      return true;
    } catch (e) {
      debugPrint('Firebase saveExpense failed: $e');
      SourceCircuitBreaker.markFailure(_firebaseKey);
      return false;
    }
  }

  static Future<bool> _saveExpenseToSupabase(Expense expense) async {
    if (supabaseUserId == null || !_canUseSupabase || expense.id == null) {
      return false;
    }

    try {
      final supabaseExpense = expense.copyWith(userId: supabaseUserId!);
      final result = await SupabaseExpenseService.addExpense(
        firebaseId: supabaseExpense.id!,
        userId: supabaseExpense.userId,
        category: supabaseExpense.category,
        amount: supabaseExpense.amount,
        description: supabaseExpense.description,
        date: supabaseExpense.date,
      );
      if (result == null) {
        SourceCircuitBreaker.markFailure(_supabaseKey);
        return false;
      }
      SourceCircuitBreaker.markSuccess(_supabaseKey);
      return true;
    } catch (e) {
      debugPrint('Supabase saveExpense failed: $e');
      SourceCircuitBreaker.markFailure(_supabaseKey);
      return false;
    }
  }

  static Map<String, dynamic> _expenseToFirestoreMap(Expense expense) {
    return {
      'userId': expense.userId,
      'category': expense.category,
      'amount': expense.amount,
      'description': expense.description,
      'date': expense.date,
      'month': expense.month,
      'year': expense.year,
      if (expense.createdAt != null)
        'createdAt': Timestamp.fromDate(expense.createdAt!),
      if (expense.updatedAt != null)
        'updatedAt': Timestamp.fromDate(expense.updatedAt!),
    };
  }

  static Map<String, dynamic> _expenseToMap(Expense expense) {
    return {
      if (expense.id != null) 'id': expense.id,
      'userId': expense.userId,
      'category': expense.category,
      'amount': expense.amount,
      'description': expense.description,
      'date': Timestamp.fromDate(expense.date),
      'month': expense.month,
      'year': expense.year,
      if (expense.createdAt != null) 'createdAt': expense.createdAt,
      if (expense.updatedAt != null) 'updatedAt': expense.updatedAt,
    };
  }

  static List<Expense> _sortExpenses(List<Expense> expenses) {
    final byId = <String, Expense>{};
    for (final expense in expenses) {
      final id = expense.id;
      if (id == null || id.isEmpty) continue;
      byId[id] = expense;
    }

    final sorted = byId.values.toList();
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }
}
