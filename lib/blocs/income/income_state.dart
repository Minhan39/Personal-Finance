import 'package:equatable/equatable.dart';

import '../../models/income_model.dart';

class MonthlyTotal extends Equatable {
  const MonthlyTotal({
    required this.month,
    required this.year,
    required this.byType,
  });

  final int month;
  final int year;
  final Map<IncomeType, double> byType;

  double get total =>
      byType.values.fold<double>(0, (sum, value) => sum + value);

  @override
  List<Object> get props => [month, year, byType];
}

abstract class IncomeState extends Equatable {
  const IncomeState();

  @override
  List<Object?> get props => [];
}

class IncomeInitial extends IncomeState {}

class IncomeLoading extends IncomeState {}

class IncomeLoaded extends IncomeState {
  const IncomeLoaded({
    required this.incomes,
    required this.selectedMonth,
    required this.selectedYear,
    required this.totalByType,
    required this.grandTotal,
    required this.monthlyTotals,
  });

  final List<IncomeModel> incomes;
  final int selectedMonth;
  final int selectedYear;
  final Map<IncomeType, double> totalByType;
  final double grandTotal;
  final List<MonthlyTotal> monthlyTotals;

  IncomeLoaded copyWith({
    List<IncomeModel>? incomes,
    int? selectedMonth,
    int? selectedYear,
    Map<IncomeType, double>? totalByType,
    double? grandTotal,
    List<MonthlyTotal>? monthlyTotals,
  }) {
    return IncomeLoaded(
      incomes: incomes ?? this.incomes,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      totalByType: totalByType ?? this.totalByType,
      grandTotal: grandTotal ?? this.grandTotal,
      monthlyTotals: monthlyTotals ?? this.monthlyTotals,
    );
  }

  @override
  List<Object> get props => [
    incomes,
    selectedMonth,
    selectedYear,
    totalByType,
    grandTotal,
    monthlyTotals,
  ];
}

class IncomeError extends IncomeState {
  const IncomeError(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}
