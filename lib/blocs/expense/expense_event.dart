import 'package:equatable/equatable.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object> get props => [];
}

class AddExpenseEvent extends ExpenseEvent {
  final String category;
  final double amount;
  final String description;
  final DateTime date;

  const AddExpenseEvent({
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
  });

  @override
  List<Object> get props => [category, amount, description, date];
}

class DeleteExpenseEvent extends ExpenseEvent {
  final String id;
  final DateTime date;

  const DeleteExpenseEvent({required this.id, required this.date});

  @override
  List<Object> get props => [id, date];
}

class LoadExpenseDataEvent extends ExpenseEvent {
  final int month;
  final int year;

  const LoadExpenseDataEvent({required this.month, required this.year});

  @override
  List<Object> get props => [month, year];
}

class LoadMonthlyDataEvent extends ExpenseEvent {
  final int year;

  const LoadMonthlyDataEvent({required this.year});

  @override
  List<Object> get props => [year];
}

class LoadExpensesByMonthEvent extends ExpenseEvent {
  final int month;
  final int year;

  const LoadExpensesByMonthEvent({required this.month, required this.year});

  @override
  List<Object> get props => [month, year];
}
