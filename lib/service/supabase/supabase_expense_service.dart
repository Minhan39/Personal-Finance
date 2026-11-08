import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/cupertino.dart';
import '../../models/expense.dart';

class SupabaseExpenseService {
  static final _client = Supabase.instance.client;

  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<String?> addExpense({
    required String category,
    required double amount,
    required String description,
    required String userId,
    DateTime? date,
    String? firebaseId,
  }) async {
    try {
      final effectiveDate = date ?? DateTime.now();
      final payload = {
        'firebase_id': firebaseId,
        'user_id': userId,
        'category': category,
        'amount': amount,
        'description': description,
        'date': effectiveDate.toIso8601String(),
        'month': effectiveDate.month,
        'year': effectiveDate.year,
      };

      final request = firebaseId == null
          ? _client.from('expenses').insert(payload)
          : _client.from('expenses').upsert(payload, onConflict: 'firebase_id');

      await request;
      return firebaseId ?? '';
    } catch (e) {
      debugPrint('Supabase addExpense error: $e');
      return null;
    }
  }

  static Future<bool> updateFirebaseId({
    required String supabaseId,
    required String firebaseId,
  }) async {
    try {
      await _client
          .from('expenses')
          .update({'firebase_id': firebaseId})
          .eq('id', supabaseId);
      return true;
    } catch (e) {
      debugPrint('Supabase updateFirebaseId error: $e');
      return false;
    }
  }

  static Future<bool> deleteExpense(String firebaseId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;
      await _client
          .from('expenses')
          .delete()
          .eq('firebase_id', firebaseId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Supabase deleteExpense error: $e');
      return false;
    }
  }

  static Future<bool> updateExpense({
    required String firebaseId,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (category != null) data['category'] = category;
      if (amount != null) data['amount'] = amount;
      if (description != null) data['description'] = description;
      if (date != null) {
        data['date'] = date.toIso8601String();
        data['month'] = date.month;
        data['year'] = date.year;
      }

      final userId = currentUserId;
      if (userId == null) return false;
      await _client
          .from('expenses')
          .update(data)
          .eq('firebase_id', firebaseId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Supabase updateExpense error: $e');
      return false;
    }
  }

  // Read methods let errors propagate: the sync layer relies on exceptions
  // to tell "source unavailable" apart from "source has no rows".
  static Future<List<Expense>> getExpensesByMonth({
    required int month,
    required int year,
    required String userId,
  }) async {
    final res = await _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .eq('month', month)
        .eq('year', year)
        .order('date', ascending: false);

    return (res as List).map((row) => Expense.fromSupabase(row)).toList();
  }

  static Future<List<double>> getMonthlyTotalsByYear({
    required int year,
    required String userId,
  }) async {
    final res = await _client
        .from('expenses')
        .select('month, amount')
        .eq('user_id', userId)
        .eq('year', year);

    final totals = List.filled(12, 0.0);
    for (final row in res as List) {
      final month = (row['month'] as int) - 1;
      totals[month] += (row['amount'] as num).toDouble();
    }
    return totals;
  }

  static Future<List<Expense>> getExpensesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
    required String userId,
  }) async {
    final normalizedStart = DateTime(startMonth.year, startMonth.month);
    final normalizedEnd = DateTime(endMonth.year, endMonth.month);
    final rangeStart = normalizedStart.toIso8601String();
    final rangeEnd = DateTime(
      normalizedEnd.year,
      normalizedEnd.month + 1,
    ).toIso8601String();

    final res = await _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .gte('date', rangeStart)
        .lt('date', rangeEnd)
        .order('date', ascending: true);

    return (res as List).map((row) => Expense.fromSupabase(row)).toList();
  }
}
