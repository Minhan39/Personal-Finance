import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/income_model.dart';

class IncomeRepository {
  IncomeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _incomeCollection =>
      _firestore.collection('incomes');

  Future<void> addIncome(IncomeModel income) async {
    final document = _incomeCollection.doc();
    await document.set({
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
  }

  Future<void> updateIncome(IncomeModel income) async {
    await _incomeCollection.doc(income.id).update({
      'id': income.id,
      'type': income.type.value,
      'amount': income.amount,
      'note': income.note,
      'date': Timestamp.fromDate(income.date),
      'month': income.date.month,
      'year': income.date.year,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteIncome(String id) async {
    await _incomeCollection.doc(id).delete();
  }

  Stream<List<IncomeModel>> watchByMonth(int month, int year) {
    return _incomeCollection
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}))
              .toList(),
        );
  }

  Stream<List<IncomeModel>> watchByYear(int year) {
    return _incomeCollection
        .where('year', isEqualTo: year)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}))
              .toList(),
        );
  }
}
