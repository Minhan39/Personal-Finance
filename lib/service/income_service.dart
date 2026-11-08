import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:personal_finance/config/app_config.dart';
import 'package:personal_finance/service/auth_service.dart';
import 'package:personal_finance/service/data_source_sync.dart';
import 'package:personal_finance/service/supabase/supabase_income_service.dart';

import '../models/income_model.dart';

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

  static const String _supabaseKey = 'income_supabase';
  static const String _firebaseKey = 'income_firebase';

  String? get _supabaseUserId => AppAuthService.supabaseUserId;

  String? get _firebaseUserId => AppAuthService.firebaseUserId;

  CollectionReference<Map<String, dynamic>> get _incomeCollection =>
      _firestore.collection('incomes');

  bool get _canUseSupabase =>
      _supabaseEnabled && SourceCircuitBreaker.canUse(_supabaseKey);

  bool get _canUseFirebase => SourceCircuitBreaker.canUse(_firebaseKey);

  Future<void> addIncome(IncomeModel income) async {
    final document = _incomeCollection.doc();
    final errors = <Object>[];
    var success = false;

    if (_supabaseUserId != null && _canUseSupabase) {
      try {
        final supabaseIncome = income.copyWith(
          id: document.id,
          userId: _supabaseUserId,
        );
        final supabaseId = await _supabase.addIncome(
          supabaseIncome,
          firebaseId: document.id,
        );
        if (supabaseId != null) {
          SourceCircuitBreaker.markSuccess(_supabaseKey);
          success = true;
        } else {
          SourceCircuitBreaker.markFailure(_supabaseKey);
        }
      } catch (error) {
        debugPrint('Supabase addIncome failed: $error');
        SourceCircuitBreaker.markFailure(_supabaseKey);
        errors.add(error);
      }
    }

    if (_firebaseUserId != null && _canUseFirebase) {
      try {
        final firebaseIncome = income.copyWith(
          id: document.id,
          userId: _firebaseUserId,
        );
        final firestoreData = _toFirestoreData(firebaseIncome);
        await document.set(firestoreData);
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        success = true;
      } catch (error) {
        debugPrint('Firebase addIncome failed: $error');
        SourceCircuitBreaker.markFailure(_firebaseKey);
        errors.add(error);
      }
    }

    if (!success) {
      if (errors.isNotEmpty) {
        throw errors.first;
      }
      throw StateError('Unable to save income');
    }
  }

  Future<void> updateIncome(IncomeModel income) async {
    final errors = <Object>[];
    var success = false;

    if (_supabaseUserId != null && _canUseSupabase) {
      try {
        final supabaseIncome = income.copyWith(userId: _supabaseUserId);
        await _supabase.updateIncome(supabaseIncome);
        SourceCircuitBreaker.markSuccess(_supabaseKey);
        success = true;
      } catch (error) {
        debugPrint('Supabase updateIncome failed: $error');
        SourceCircuitBreaker.markFailure(_supabaseKey);
        errors.add(error);
      }
    }

    if (_firebaseUserId != null && _canUseFirebase) {
      try {
        final firebaseIncome = income.copyWith(userId: _firebaseUserId);
        final firestoreData = _toFirestoreData(firebaseIncome);
        await _incomeCollection
            .doc(income.id)
            .set(firestoreData, SetOptions(merge: true));
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        success = true;
      } catch (error) {
        debugPrint('Firebase updateIncome failed: $error');
        SourceCircuitBreaker.markFailure(_firebaseKey);
        errors.add(error);
      }
    }

    if (!success && errors.isNotEmpty) {
      throw errors.first;
    }
  }

  Future<void> deleteIncome(String id) async {
    final errors = <Object>[];
    var success = false;

    if (_supabaseUserId != null && _canUseSupabase) {
      try {
        await _supabase.deleteIncome(id);
        SourceCircuitBreaker.markSuccess(_supabaseKey);
        success = true;
      } catch (error) {
        debugPrint('Supabase deleteIncome failed: $error');
        SourceCircuitBreaker.markFailure(_supabaseKey);
        errors.add(error);
      }
    }

    if (_firebaseUserId != null && _canUseFirebase) {
      try {
        await _incomeCollection.doc(id).delete();
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        success = true;
      } catch (error) {
        debugPrint('Firebase deleteIncome failed: $error');
        SourceCircuitBreaker.markFailure(_firebaseKey);
        errors.add(error);
      }
    }

    if (!success && errors.isNotEmpty) {
      throw errors.first;
    }
  }

  Future<List<IncomeModel>> getIncomesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final normalizedStart = DateTime(startMonth.year, startMonth.month);
    final normalizedEnd = DateTime(endMonth.year, endMonth.month);

    final primaryEnabled = _supabaseUserId != null && _canUseSupabase;
    final fallbackEnabled = _canUseFirebase;

    if (!primaryEnabled && !fallbackEnabled) {
      return [];
    }

    if (!primaryEnabled) {
      return _sortIncomes(
        await _fetchFirebaseIncomesByRange(normalizedStart, normalizedEnd),
      );
    }

    return _loadSyncedIncomes(
      logLabel: 'Income range',
      primaryFetch: () => _fetchSupabaseIncomesByRange(
        startMonth: normalizedStart,
        endMonth: normalizedEnd,
      ),
      fallbackFetch: () =>
          _fetchFirebaseIncomesByRange(normalizedStart, normalizedEnd),
      pushToPrimary: _saveIncomeToSupabase,
      pushToFallback: _saveIncomeToFirebase,
    );
  }

  Stream<List<IncomeModel>> watchByMonth(int month, int year) {
    final primaryEnabled = _supabaseUserId != null && _canUseSupabase;
    final fallbackEnabled = _canUseFirebase;
    if (!primaryEnabled && !fallbackEnabled) return Stream.value([]);

    if (!primaryEnabled) {
      return _watchFirebaseIncomeMonth(month, year);
    }

    return _buildSyncedWatchStream(
      logLabel: 'Income month $month/$year',
      primaryStream: () => _supabase.watchByMonth(month, year),
      fallbackStream: () => _watchFirebaseIncomeMonth(month, year),
      primaryFetch: () => _supabase.getByMonth(month, year),
      fallbackFetch: () => _fetchFirebaseIncomesByMonth(month, year),
      pushToPrimary: _saveIncomeToSupabase,
      pushToFallback: _saveIncomeToFirebase,
    );
  }

  Stream<List<IncomeModel>> watchByYear(int year) {
    final primaryEnabled = _supabaseUserId != null && _canUseSupabase;
    final fallbackEnabled = _canUseFirebase;
    if (!primaryEnabled && !fallbackEnabled) return Stream.value([]);

    if (!primaryEnabled) {
      return _watchFirebaseIncomeYear(year);
    }

    return _buildSyncedWatchStream(
      logLabel: 'Income year $year',
      primaryStream: () => _supabase.watchByYear(year),
      fallbackStream: () => _watchFirebaseIncomeYear(year),
      primaryFetch: () => _supabase.getByYear(year),
      fallbackFetch: () => _fetchFirebaseIncomesByYear(year),
      pushToPrimary: _saveIncomeToSupabase,
      pushToFallback: _saveIncomeToFirebase,
    );
  }

  Future<List<IncomeModel>> _loadSyncedIncomes({
    required String logLabel,
    required Future<List<IncomeModel>> Function() primaryFetch,
    required Future<List<IncomeModel>> Function() fallbackFetch,
    required Future<bool> Function(IncomeModel income) pushToPrimary,
    required Future<bool> Function(IncomeModel income) pushToFallback,
    List<IncomeModel>? primarySnapshot,
  }) async {
    final primaryEnabled = _canUseSupabase;
    final fallbackEnabled = _canUseFirebase;

    if (primaryEnabled && fallbackEnabled) {
      return reconcileBetweenSources<IncomeModel>(
        primarySourceKey: _supabaseKey,
        fallbackSourceKey: _firebaseKey,
        logLabel: logLabel,
        primaryFetch: primarySnapshot != null
            ? () async => primarySnapshot
            : primaryFetch,
        fallbackFetch: fallbackFetch,
        pushToPrimary: pushToPrimary,
        pushToFallback: pushToFallback,
        itemId: (income) => income.id,
        sortItems: _sortIncomes,
      );
    }

    if (primaryEnabled) {
      try {
        final primary = primarySnapshot ?? await primaryFetch();
        SourceCircuitBreaker.markSuccess(_supabaseKey);
        return _sortIncomes(primary);
      } catch (error) {
        debugPrint('$logLabel primary fetch failed: $error');
        SourceCircuitBreaker.markFailure(_supabaseKey);
      }
    }

    if (fallbackEnabled) {
      try {
        final fallback = await fallbackFetch();
        SourceCircuitBreaker.markSuccess(_firebaseKey);
        return _sortIncomes(fallback);
      } catch (error) {
        debugPrint('$logLabel fallback fetch failed: $error');
        SourceCircuitBreaker.markFailure(_firebaseKey);
      }
    }

    return [];
  }

  Stream<List<IncomeModel>> _buildSyncedWatchStream({
    required String logLabel,
    required Stream<List<IncomeModel>> Function() primaryStream,
    required Stream<List<IncomeModel>> Function() fallbackStream,
    required Future<List<IncomeModel>> Function() primaryFetch,
    required Future<List<IncomeModel>> Function() fallbackFetch,
    required Future<bool> Function(IncomeModel income) pushToPrimary,
    required Future<bool> Function(IncomeModel income) pushToFallback,
  }) {
    final controller = StreamController<List<IncomeModel>>.broadcast();
    StreamSubscription<List<IncomeModel>>? primarySub;
    StreamSubscription<List<IncomeModel>>? fallbackSub;
    var usingFallback = false;
    var syncInProgress = false;

    Future<void> emitSynced(List<IncomeModel> snapshot) async {
      if (controller.isClosed || syncInProgress) {
        return;
      }

      syncInProgress = true;
      try {
        final merged = await _loadSyncedIncomes(
          logLabel: logLabel,
          primaryFetch: primaryFetch,
          fallbackFetch: fallbackFetch,
          pushToPrimary: pushToPrimary,
          pushToFallback: pushToFallback,
          primarySnapshot: snapshot,
        );
        if (!controller.isClosed) {
          controller.add(merged);
        }
      } finally {
        syncInProgress = false;
      }
    }

    Future<void> attachFallback() async {
      if (usingFallback || controller.isClosed) {
        return;
      }
      usingFallback = true;
      await primarySub?.cancel();
      primarySub = null;
      fallbackSub = fallbackStream().listen(
        (data) {
          if (!controller.isClosed) {
            controller.add(_sortIncomes(data));
          }
        },
        onError: (error, stackTrace) {
          controller.addError(error, stackTrace);
        },
      );
    }

    if (_canUseSupabase) {
      primarySub = primaryStream().listen(
        (data) {
          emitSynced(data);
        },
        onError: (error, stackTrace) {
          debugPrint('$logLabel primary stream failed: $error');
          SourceCircuitBreaker.markFailure(_supabaseKey);
          attachFallback();
        },
      );
    } else {
      attachFallback();
    }

    Future(() async {
      final initial = await _loadSyncedIncomes(
        logLabel: logLabel,
        primaryFetch: primaryFetch,
        fallbackFetch: fallbackFetch,
        pushToPrimary: pushToPrimary,
        pushToFallback: pushToFallback,
      );
      if (!controller.isClosed) {
        controller.add(initial);
      }
    });

    controller.onCancel = () async {
      await primarySub?.cancel();
      await fallbackSub?.cancel();
    };

    return controller.stream;
  }

  Future<List<IncomeModel>> _fetchFirebaseIncomesByRange(
    DateTime startMonth,
    DateTime endMonth,
  ) async {
    final incomes = <IncomeModel>[];
    var cursor = startMonth;

    while (!cursor.isAfter(endMonth)) {
      final monthly = await _fetchFirebaseIncomesByMonth(
        cursor.month,
        cursor.year,
      );
      incomes.addAll(monthly);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return _dedupeIncomes(incomes);
  }

  Future<List<IncomeModel>> _fetchFirebaseIncomesByMonth(
    int month,
    int year,
  ) async {
    final primary = await _incomeCollection
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .get();

    final legacy = await _incomeCollection
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .get();

    return _dedupeIncomes([
      ...primary.docs.map(
        (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
      ),
      ...legacy.docs.map(
        (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
      ),
    ]);
  }

  Future<List<IncomeModel>> _fetchFirebaseIncomesByYear(int year) async {
    final primary = await _incomeCollection
        .where('year', isEqualTo: year)
        .get();

    final legacy = await _incomeCollection.where('year', isEqualTo: year).get();

    return _dedupeIncomes([
      ...primary.docs.map(
        (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
      ),
      ...legacy.docs.map(
        (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
      ),
    ]);
  }

  Stream<List<IncomeModel>> _watchFirebaseIncomeMonth(int month, int year) {
    final controller = StreamController<List<IncomeModel>>.broadcast();
    StreamSubscription? primarySub;
    StreamSubscription? legacySub;
    List<IncomeModel> primaryData = const [];
    List<IncomeModel> legacyData = const [];

    void emit() {
      if (!controller.isClosed) {
        controller.add(_dedupeIncomes([...primaryData, ...legacyData]));
      }
    }

    primarySub = _incomeCollection
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .snapshots()
        .listen(
          (snapshot) {
            primaryData = snapshot.docs
                .map(
                  (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
                )
                .toList();
            emit();
          },
          onError: (error, stackTrace) {
            controller.addError(error, stackTrace);
          },
        );

    legacySub = _incomeCollection
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .snapshots()
        .listen(
          (snapshot) {
            legacyData = snapshot.docs
                .map(
                  (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
                )
                .toList();
            emit();
          },
          onError: (error, stackTrace) {
            controller.addError(error, stackTrace);
          },
        );

    Future(() async {
      final initial = await _fetchFirebaseIncomesByMonth(month, year);
      if (!controller.isClosed) {
        controller.add(initial);
      }
    });

    controller.onCancel = () async {
      await primarySub?.cancel();
      await legacySub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<IncomeModel>> _watchFirebaseIncomeYear(int year) {
    final controller = StreamController<List<IncomeModel>>.broadcast();
    StreamSubscription? primarySub;
    StreamSubscription? legacySub;
    List<IncomeModel> primaryData = const [];
    List<IncomeModel> legacyData = const [];

    void emit() {
      if (!controller.isClosed) {
        controller.add(_dedupeIncomes([...primaryData, ...legacyData]));
      }
    }

    primarySub = _incomeCollection
        .where('year', isEqualTo: year)
        .snapshots()
        .listen(
          (snapshot) {
            primaryData = snapshot.docs
                .map(
                  (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
                )
                .toList();
            emit();
          },
          onError: (error, stackTrace) {
            controller.addError(error, stackTrace);
          },
        );

    legacySub = _incomeCollection
        .where('year', isEqualTo: year)
        .snapshots()
        .listen(
          (snapshot) {
            legacyData = snapshot.docs
                .map(
                  (doc) => IncomeModel.fromJson({'id': doc.id, ...doc.data()}),
                )
                .toList();
            emit();
          },
          onError: (error, stackTrace) {
            controller.addError(error, stackTrace);
          },
        );

    Future(() async {
      final initial = await _fetchFirebaseIncomesByYear(year);
      if (!controller.isClosed) {
        controller.add(initial);
      }
    });

    controller.onCancel = () async {
      await primarySub?.cancel();
      await legacySub?.cancel();
    };

    return controller.stream;
  }

  Future<List<IncomeModel>> _fetchSupabaseIncomesByRange({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final incomes = await _supabase.getByRange(
      startMonth: startMonth,
      endMonth: endMonth,
    );
    return _sortIncomes(incomes);
  }

  Future<bool> _saveIncomeToFirebase(IncomeModel income) async {
    if (_firebaseUserId == null || !_canUseFirebase) {
      return false;
    }

    try {
      final firebaseIncome = income.copyWith(userId: _firebaseUserId);
      await _incomeCollection
          .doc(income.id)
          .set(_toFirestoreData(firebaseIncome), SetOptions(merge: true));
      SourceCircuitBreaker.markSuccess(_firebaseKey);
      return true;
    } catch (error) {
      debugPrint('Firebase saveIncome failed: $error');
      SourceCircuitBreaker.markFailure(_firebaseKey);
      return false;
    }
  }

  Future<bool> _saveIncomeToSupabase(IncomeModel income) async {
    if (_supabaseUserId == null || !_canUseSupabase) {
      return false;
    }

    try {
      final supabaseIncome = income.copyWith(userId: _supabaseUserId);
      final result = await _supabase.addIncome(
        supabaseIncome,
        firebaseId: income.id,
      );
      if (result == null) {
        SourceCircuitBreaker.markFailure(_supabaseKey);
        return false;
      }
      SourceCircuitBreaker.markSuccess(_supabaseKey);
      return true;
    } catch (error) {
      debugPrint('Supabase saveIncome failed: $error');
      SourceCircuitBreaker.markFailure(_supabaseKey);
      return false;
    }
  }

  Map<String, dynamic> _toFirestoreData(IncomeModel income) {
    return {
      'user_id': income.userId,
      'userId': income.userId,
      'id': income.id,
      'type': income.type.value,
      'amount': income.amount,
      'note': income.note,
      'date': Timestamp.fromDate(income.date),
      'month': income.month,
      'year': income.year,
      if (income.createdAt != null)
        'createdAt': Timestamp.fromDate(income.createdAt!),
      if (income.updatedAt != null)
        'updatedAt': Timestamp.fromDate(income.updatedAt!),
    };
  }

  List<IncomeModel> _sortIncomes(List<IncomeModel> incomes) {
    final deduped = _dedupeIncomes(incomes);
    deduped.sort((a, b) => a.date.compareTo(b.date));
    return deduped;
  }

  List<IncomeModel> _dedupeIncomes(List<IncomeModel> incomes) {
    final byId = <String, IncomeModel>{};
    for (final income in incomes) {
      if (income.id.isEmpty) continue;
      byId[income.id] = income;
    }

    return byId.values.toList();
  }
}
