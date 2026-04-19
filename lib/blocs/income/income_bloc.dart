import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/income_model.dart';
import '../../service/income_service.dart';
import 'income_event.dart';
import 'income_state.dart';

class IncomeBloc extends Bloc<IncomeEvent, IncomeState> {
  IncomeBloc({required IncomeService incomeService})
    : _incomeService = incomeService,
      _selectedMonth = DateTime.now().month,
      _selectedYear = DateTime.now().year,
      super(IncomeInitial()) {
    on<IncomeSubscribeByMonth>(_onSubscribeByMonth);
    on<IncomeSubscribeByYear>(_onSubscribeByYear);
    on<IncomeAdded>(_onIncomeAdded);
    on<IncomeUpdated>(_onIncomeUpdated);
    on<IncomeDeleted>(_onIncomeDeleted);
    on<IncomeMonthChanged>(_onIncomeMonthChanged);
    on<IncomeMonthDataChanged>(_onIncomeMonthDataChanged);
    on<IncomeYearDataChanged>(_onIncomeYearDataChanged);
    on<IncomeSubscriptionFailed>(_onIncomeSubscriptionFailed);

    add(IncomeMonthChanged(_selectedMonth, _selectedYear));
  }

  final IncomeService _incomeService;

  StreamSubscription<List<IncomeModel>>? _monthSubscription;
  StreamSubscription<List<IncomeModel>>? _yearSubscription;
  int _selectedMonth;
  int _selectedYear;
  List<IncomeModel> _monthIncomes = const [];
  List<IncomeModel> _yearIncomes = const [];

  Future<void> _onSubscribeByMonth(
    IncomeSubscribeByMonth event,
    Emitter<IncomeState> emit,
  ) async {
    await _monthSubscription?.cancel();
    _monthSubscription = _incomeService
        .watchByMonth(event.month, event.year)
        .listen(
          (incomes) => add(IncomeMonthDataChanged(incomes)),
          onError: (error) => add(
            IncomeSubscriptionFailed(
              'Không thể tải danh sách thu nhập: $error',
            ),
          ),
        );
  }

  Future<void> _onSubscribeByYear(
    IncomeSubscribeByYear event,
    Emitter<IncomeState> emit,
  ) async {
    await _yearSubscription?.cancel();
    _yearSubscription = _incomeService
        .watchByYear(event.year)
        .listen(
          (incomes) => add(IncomeYearDataChanged(incomes)),
          onError: (error) => add(
            IncomeSubscriptionFailed(
              'Không thể tải dữ liệu biểu đồ thu nhập: $error',
            ),
          ),
        );
  }

  Future<void> _onIncomeAdded(
    IncomeAdded event,
    Emitter<IncomeState> emit,
  ) async {
    try {
      await _incomeService.addIncome(event.income);
    } catch (error) {
      emit(IncomeError('Không thể thêm thu nhập: $error'));
      _emitLoadedState(emit);
    }
  }

  Future<void> _onIncomeUpdated(
    IncomeUpdated event,
    Emitter<IncomeState> emit,
  ) async {
    try {
      await _incomeService.updateIncome(event.income);
    } catch (error) {
      emit(IncomeError('Không thể cập nhật thu nhập: $error'));
      _emitLoadedState(emit);
    }
  }

  Future<void> _onIncomeDeleted(
    IncomeDeleted event,
    Emitter<IncomeState> emit,
  ) async {
    try {
      await _incomeService.deleteIncome(event.id);
    } catch (error) {
      emit(IncomeError('Không thể xoá thu nhập: $error'));
      _emitLoadedState(emit);
    }
  }

  Future<void> _onIncomeMonthChanged(
    IncomeMonthChanged event,
    Emitter<IncomeState> emit,
  ) async {
    _selectedMonth = event.month;
    _selectedYear = event.year;

    _monthIncomes = const [];

    emit(IncomeLoading());

    add(IncomeSubscribeByMonth(event.month, event.year));
    add(IncomeSubscribeByYear(event.year));
  }

  void _onIncomeMonthDataChanged(
    IncomeMonthDataChanged event,
    Emitter<IncomeState> emit,
  ) {
    _monthIncomes = event.incomes;
    _emitLoadedState(emit);
  }

  void _onIncomeYearDataChanged(
    IncomeYearDataChanged event,
    Emitter<IncomeState> emit,
  ) {
    _yearIncomes = event.incomes;
    _emitLoadedState(emit);
  }

  void _onIncomeSubscriptionFailed(
    IncomeSubscriptionFailed event,
    Emitter<IncomeState> emit,
  ) {
    emit(IncomeError(event.message));
  }

  void _emitLoadedState(Emitter<IncomeState> emit) {
    emit(
      IncomeLoaded(
        incomes: _monthIncomes,
        selectedMonth: _selectedMonth,
        selectedYear: _selectedYear,
        totalByType: _monthIncomes.totalByType(),
        grandTotal: _monthIncomes.grandTotal(),
        monthlyTotals: _buildMonthlyTotals(),
      ),
    );
  }

  List<MonthlyTotal> _buildMonthlyTotals() {
    final selectedDate = DateTime(_selectedYear, _selectedMonth);
    final totals = <MonthlyTotal>[];

    for (int offset = 5; offset >= 0; offset--) {
      final monthDate = DateTime(
        selectedDate.year,
        selectedDate.month - offset,
      );
      final monthIncomes = _yearIncomes.where(
        (income) =>
            income.month == monthDate.month && income.year == monthDate.year,
      );

      final byType = {for (final type in IncomeType.values) type: 0.0};

      for (final income in monthIncomes) {
        byType[income.type] = (byType[income.type] ?? 0) + income.amount;
      }

      totals.add(
        MonthlyTotal(
          month: monthDate.month,
          year: monthDate.year,
          byType: byType,
        ),
      );
    }

    return totals;
  }

  @override
  Future<void> close() async {
    await _monthSubscription?.cancel();
    await _yearSubscription?.cancel();
    return super.close();
  }
}
