import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/income_model.dart';

class SupabaseIncomeService {
  static final _client = Supabase.instance.client;

  Future<String?> addIncome(IncomeModel income, {String? firebaseId}) async {
    try {
      final res = await _client.from('incomes').insert({
        'firebase_id': firebaseId,
        'user_id': income.userId,
        'type': income.type.value,
        'amount': income.amount,
        'note': income.note,
        'date': income.date.toIso8601String(),
        'month': income.date.month,
        'year': income.date.year,
      }).select('id').single();

      return res['id'] as String?;
    } catch (e) {
      debugPrint('Supabase addIncome error: $e');
      return null;
    }
  }

  Future<void> updateIncome(IncomeModel income) async {
    try {
      await _client.from('incomes').update({
        'type': income.type.value,
        'amount': income.amount,
        'note': income.note,
        'date': income.date.toIso8601String(),
        'month': income.date.month,
        'year': income.date.year,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('firebase_id', income.id);
    } catch (e) {
      debugPrint('Supabase updateIncome error: $e');
    }
  }

  Future<void> deleteIncome(String firebaseId) async {
    try {
      await _client.from('incomes').delete().eq('firebase_id', firebaseId);
    } catch (e) {
      debugPrint('Supabase deleteIncome error: $e');
    }
  }

  Future<List<IncomeModel>> getByMonth(int month, int year, String userId) async {
    try {
      final res = await _client
          .from('incomes')
          .select()
          .eq('user_id', userId)
          .eq('month', month)
          .eq('year', year)
          .order('date', ascending: false);

      return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Supabase getByMonth error: $e');
      return [];
    }
  }

  Future<List<IncomeModel>> getByYear(int year, String userId) async {
    try {
      final res = await _client
          .from('incomes')
          .select()
          .eq('user_id', userId)
          .eq('year', year)
          .order('date', ascending: false);

      return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Supabase getByYear error: $e');
      return [];
    }
  }

  Stream<List<IncomeModel>> watchByMonth(
      int month,
      int year,
      String userId,
      ) {
    return _buildRealtimeStream(
      channelKey: 'incomes_${userId}_${year}_$month',
      userId: userId,
      fetchData: () => getByMonth(month, year, userId),
    );
  }

  Stream<List<IncomeModel>> watchByYear(int year, String userId) {
    return _buildRealtimeStream(
      channelKey: 'incomes_${userId}_$year',
      userId: userId,
      fetchData: () => getByYear(year, userId),
    );
  }

  Stream<List<IncomeModel>> _buildRealtimeStream({
    required String channelKey,
    required String userId,
    required Future<List<IncomeModel>> Function() fetchData,
  }) {
    final controller = StreamController<List<IncomeModel>>.broadcast();

    fetchData().then((data) {
      if (!controller.isClosed) controller.add(data);
    });

    final channel = _client
        .channel(channelKey)
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'incomes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) async {
        final data = await fetchData();
        if (!controller.isClosed) controller.add(data);
      },
    )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}