import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/expense.dart';
import '../../service/expense_service.dart';
import 'expense_event.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  static final List<String> categoryKeys = ExpenseCategory.allKeys;

  ExpenseBloc() : super(ExpenseInitial()) {
    on<AddExpenseEvent>(_onAddExpense);
    on<LoadExpenseDataEvent>(_onLoadExpenseData);
    on<LoadMonthlyDataEvent>(_onLoadMonthlyData);
    on<LoadExpensesByMonthEvent>(_onLoadExpensesByMonth);
    on<DeleteExpenseEvent>(_onDeleteExpense);
  }

  Future<void> _onDeleteExpense(
    DeleteExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    try {
      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        emit(
          ExpenseLoadingData(
            categoryData: currentState.categoryData,
            monthlyData: currentState.monthlyData,
            expenses: currentState.expenses,
          ),
        );
      } else {
        emit(ExpenseLoading());
      }

      final success = await ExpenseService.deleteExpense(event.id);

      if (success) {
        emit(ExpenseDeleteSuccess(message: 'Đã xoá chi tiêu thành công!'));
        add(
          LoadExpenseDataEvent(month: event.date.month, year: event.date.year),
        );
        add(LoadMonthlyDataEvent(year: event.date.year));
      } else {
        emit(ExpenseError(message: 'Có lỗi xảy ra khi xoá chi tiêu!'));
      }
    } catch (e) {
      emit(ExpenseError(message: 'Có lỗi xảy ra: ${e.toString()}'));
    }
  }

  Future<void> _onAddExpense(
    AddExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    try {
      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        emit(
          ExpenseLoadingData(
            categoryData: currentState.categoryData,
            monthlyData: currentState.monthlyData,
            expenses: currentState.expenses,
          ),
        );
      } else {
        emit(ExpenseLoading());
      }

      final success = await ExpenseService.addExpense(
        category: event.category,
        amount: event.amount,
        description: event.description,
        date: event.date,
      );

      if (success) {
        emit(const ExpenseAddSuccess(message: 'Đã thêm chi tiêu thành công!'));
        add(
          LoadExpenseDataEvent(month: event.date.month, year: event.date.year),
        );
        add(LoadMonthlyDataEvent(year: event.date.year));
      } else {
        emit(const ExpenseError(message: 'Có lỗi xảy ra khi thêm chi tiêu!'));
      }
    } catch (e) {
      emit(ExpenseError(message: 'Có lỗi xảy ra: ${e.toString()}'));
    }
  }

  Future<void> _onLoadExpenseData(
    LoadExpenseDataEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    try {
      List<double> currentMonthlyData = [];
      if (state is ExpenseLoaded) {
        currentMonthlyData = (state as ExpenseLoaded).monthlyData;
      } else if (state is ExpenseLoadingData) {
        currentMonthlyData = (state as ExpenseLoadingData).monthlyData;
      }

      final categoryTotals = await ExpenseService.getCategoryTotalsByMonth(
        month: event.month,
        year: event.year,
      );
      final Map<String, double> updatedCategoryData = {};
      for (String category in categoryKeys) {
        updatedCategoryData[category] = categoryTotals[category] ?? 0.0;
      }

      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        emit(currentState.copyWith(categoryData: updatedCategoryData));
      } else {
        emit(
          ExpenseLoaded(
            categoryData: updatedCategoryData,
            monthlyData: currentMonthlyData,
          ),
        );
      }
    } catch (e) {
      emit(
        ExpenseError(message: 'Lỗi khi tải dữ liệu danh mục: ${e.toString()}'),
      );
    }
  }

  Future<void> _onLoadMonthlyData(
    LoadMonthlyDataEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    try {
      Map<String, double> currentCategoryData = {};
      if (state is ExpenseLoaded) {
        currentCategoryData = (state as ExpenseLoaded).categoryData;
      } else if (state is ExpenseLoadingData) {
        currentCategoryData = (state as ExpenseLoadingData).categoryData;
      }

      final monthlyTotals = await ExpenseService.getMonthlyTotalsByYear(
        event.year,
      );

      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        emit(currentState.copyWith(monthlyData: monthlyTotals));
      } else {
        emit(
          ExpenseLoaded(
            categoryData: currentCategoryData,
            monthlyData: monthlyTotals,
          ),
        );
      }
    } catch (e) {
      emit(ExpenseError(message: 'Lỗi khi tải dữ liệu tháng: ${e.toString()}'));
    }
  }

  Future<void> _onLoadExpensesByMonth(
    LoadExpensesByMonthEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    try {
      final expenses = await ExpenseService.getExpensesByMonth(
        month: event.month,
        year: event.year,
      );

      if (state is ExpenseLoaded) {
        final currentState = state as ExpenseLoaded;
        emit(currentState.copyWith(expenses: expenses));
      } else {
        emit(
          ExpenseLoaded(
            categoryData: const {},
            monthlyData: const [],
            expenses: expenses,
          ),
        );
      }
    } catch (e) {
      emit(ExpenseError(message: 'Lỗi khi tải chi tiêu: ${e.toString()}'));
    }
  }
}
