import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/income_model.dart';

class SupabaseIncomeService {
  static final _client = Supabase.instance.client;

  Future<String?> addIncome(IncomeModel income, {String? firebaseId}) async {
    try {
      final payload = {
        'firebase_id': firebaseId,
        'user_id': income.userId,
        'type': income.type.value,
        'amount': income.amount,
        'note': income.note,
        'date': income.date.toIso8601String(),
        'month': income.date.month,
        'year': income.year,
      };

      final request = firebaseId == null
          ? _client.from('incomes').insert(payload)
          : _client.from('incomes').upsert(payload, onConflict: 'firebase_id');

      await request;
      return firebaseId ?? income.id;
    } catch (e) {
      debugPrint('Supabase addIncome error: $e');
      return null;
    }
  }

  Future<void> updateIncome(IncomeModel income) async {
    try {
      await _client
          .from('incomes')
          .update({
            'type': income.type.value,
            'amount': income.amount,
            'note': income.note,
            'date': income.date.toIso8601String(),
            'month': income.date.month,
            'year': income.year,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('firebase_id', income.id);
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

  Future<List<IncomeModel>> getByMonth(int month, int year) async {
    try {
      final res = await _client
          .from('incomes')
          .select()
          .eq('month', month)
          .eq('year', year)
          .order('date', ascending: false);

      return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Supabase getByMonth error: $e');
      return [];
    }
  }

  Future<List<IncomeModel>> getByYear(int year) async {
    try {
      final res = await _client
          .from('incomes')
          .select()
          .eq('year', year)
          .order('date', ascending: false);

      return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Supabase getByYear error: $e');
      return [];
    }
  }

  Future<List<IncomeModel>> getByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    try {
      final normalizedStart = DateTime(startMonth.year, startMonth.month);
      final normalizedEnd = DateTime(endMonth.year, endMonth.month);
      final incomes = <IncomeModel>[];
      var cursor = normalizedStart;

      while (!cursor.isAfter(normalizedEnd)) {
        final monthly = await getByMonth(cursor.month, cursor.year);
        incomes.addAll(monthly);
        cursor = DateTime(cursor.year, cursor.month + 1);
      }

      incomes.sort((a, b) => a.date.compareTo(b.date));
      return incomes;
    } catch (e) {
      debugPrint('Supabase getByRange error: $e');
      return [];
    }
  }

  Stream<List<IncomeModel>> watchByMonth(int month, int year) {
    return _buildRealtimeStream(
      channelKey: 'incomes_${year}_$month',
      fetchData: () => getByMonth(month, year),
    );
  }

  Stream<List<IncomeModel>> watchByYear(int year) {
    return _buildRealtimeStream(
      channelKey: 'incomes_$year',
      fetchData: () => getByYear(year),
    );
  }

  Stream<List<IncomeModel>> _buildRealtimeStream({
    required String channelKey,
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
