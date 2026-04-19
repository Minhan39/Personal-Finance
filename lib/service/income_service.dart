import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:personal_finance/config/app_config.dart';
import 'package:personal_finance/service/supabase/supabase_income_service.dart';

import '../models/income_model.dart';
import '../utils/fallback_stream_transformer.dart';

class IncomeService {
  IncomeService({
    FirebaseFirestore? firestore,
    SupabaseIncomeService? supabaseService,
    bool supabaseEnabled = true,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _supabase = supabaseService ?? SupabaseIncomeService(),
       _supabaseEnabled = AppConfig.supabaseEnabled;

  final FirebaseFirestore _firestore;
  final SupabaseIncomeService _supabase;
  final bool _supabaseEnabled;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _incomeCollection =>
      _firestore.collection('incomes');

  Future<void> addIncome(IncomeModel income) async {
    final document = _incomeCollection.doc();
    await document.set({
      'user_id': _userId,
      'id': document.id,
      'type': income.type.value,
      'amount': income.amount,
      'note': income.note,
      'date': Timestamp.fromDate(income.date),
      'month': income.date.month,
      'year': income.date.year,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (_supabaseEnabled) {
      _supabase
          .addIncome(income.copyWith(id: document.id), firebaseId: document.id)
          .catchError((e) {
            debugPrint('Supabase mirror addIncome failed: $e');
            return null;
          });
    }
  }

  Future<void> updateIncome(IncomeModel income) async {
    final futures = <Future>[
      _incomeCollection.doc(income.id).update({
        'id': income.id,
        'user_id': _userId,
        'type': income.type.value,
        'amount': income.amount,
        'note': income.note,
        'date': Timestamp.fromDate(income.date),
        'month': income.date.month,
        'year': income.date.year,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      if (_supabaseEnabled) _supabase.updateIncome(income),
    ];
    await Future.wait(futures);
  }

  Future<void> deleteIncome(String id) async {
    final futures = <Future>[
      _incomeCollection.doc(id).delete(),
      if (_supabaseEnabled) _supabase.deleteIncome(id),
    ];
    await Future.wait(futures);
  }

  Stream<List<IncomeModel>> watchByMonth(int month, int year) {
    final firebaseStream = _incomeCollection
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}))
              .toList(),
        );

    if (!_supabaseEnabled || _userId == null) return firebaseStream;

    return firebaseStream
        .handleError((_) {})
        .transform(
          FallbackStreamTransformer(
            fallbackStream: _supabase.watchByMonth(month, year, _userId!),
          ),
        );
  }

  Stream<List<IncomeModel>> watchByYear(int year) {
    final firebaseStream = _incomeCollection
        .where('year', isEqualTo: year)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}))
              .toList(),
        );

    if (!_supabaseEnabled || _userId == null) return firebaseStream;

    return firebaseStream
        .handleError((_) {})
        .transform(
          FallbackStreamTransformer(
            fallbackStream: _supabase.watchByYear(year, _userId!),
          ),
        );
  }
}
