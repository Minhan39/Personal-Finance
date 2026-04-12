import 'package:equatable/equatable.dart';

abstract class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object> get props => [];
}

class ExpenseInitial extends ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpenseLoadingData extends ExpenseState {
  final Map<String, double> categoryData;
  final List<double> monthlyData;
  final List<Map<String, dynamic>> expenses;

  const ExpenseLoadingData({
    this.categoryData = const {},
    this.monthlyData = const [],
    this.expenses = const [],
  });

  @override
  List<Object> get props => [categoryData, monthlyData, expenses];
}

class ExpenseLoaded extends ExpenseState {
  final Map<String, double> categoryData;
  final List<double> monthlyData;
  final List<Map<String, dynamic>> expenses;

  const ExpenseLoaded({
    required this.categoryData,
    required this.monthlyData,
    this.expenses = const [],
  });

  @override
  List<Object> get props => [categoryData, monthlyData, expenses];

  ExpenseLoaded copyWith({
    Map<String, double>? categoryData,
    List<double>? monthlyData,
    List<Map<String, dynamic>>? expenses,
  }) {
    return ExpenseLoaded(
      categoryData: categoryData ?? this.categoryData,
      monthlyData: monthlyData ?? this.monthlyData,
      expenses: expenses ?? this.expenses,
    );
  }
}

class ExpenseAddSuccess extends ExpenseState {
  final String message;

  const ExpenseAddSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

class ExpenseError extends ExpenseState {
  final String message;

  const ExpenseError({required this.message});

  @override
  List<Object> get props => [message];
}

class ExpenseDeleteSuccess extends ExpenseState {
  final String message;

  const ExpenseDeleteSuccess({required this.message});

  @override
  List<Object> get props => [message];
}
