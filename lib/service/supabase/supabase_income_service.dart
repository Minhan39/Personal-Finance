import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/income_model.dart';

class SupabaseIncomeService {
  static final _client = Supabase.instance.client;

  /// Reads are scoped to the signed-in user so data never leaks across
  /// accounts even if RLS is misconfigured. Throws when nobody is signed in.
  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Supabase user is not signed in');
    }
    return id;
  }

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
          .eq('firebase_id', income.id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('Supabase updateIncome error: $e');
    }
  }

  Future<void> deleteIncome(String firebaseId) async {
    try {
      await _client
          .from('incomes')
          .delete()
          .eq('firebase_id', firebaseId)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('Supabase deleteIncome error: $e');
    }
  }

  // Read methods let errors propagate: the sync layer relies on exceptions
  // to tell "source unavailable" apart from "source has no rows".
  Future<List<IncomeModel>> getByMonth(int month, int year) async {
    final res = await _client
        .from('incomes')
        .select()
        .eq('user_id', _userId)
        .eq('month', month)
        .eq('year', year)
        .order('date', ascending: false);

    return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
  }

  Future<List<IncomeModel>> getByYear(int year) async {
    final res = await _client
        .from('incomes')
        .select()
        .eq('user_id', _userId)
        .eq('year', year)
        .order('date', ascending: false);

    return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
  }

  Future<List<IncomeModel>> getByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final rangeStart = DateTime(startMonth.year, startMonth.month);
    final rangeEnd = DateTime(endMonth.year, endMonth.month + 1);

    final res = await _client
        .from('incomes')
        .select()
        .eq('user_id', _userId)
        .gte('date', rangeStart.toIso8601String())
        .lt('date', rangeEnd.toIso8601String())
        .order('date', ascending: true);

    return (res as List).map((row) => IncomeModel.fromSupabase(row)).toList();
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

    Future<void> refresh() async {
      try {
        final data = await fetchData();
        if (!controller.isClosed) controller.add(data);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    refresh();

    final channel = _client
        .channel(channelKey)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incomes',
          callback: (_) => refresh(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
