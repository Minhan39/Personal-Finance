import 'package:equatable/equatable.dart';

import '../../models/income_model.dart';

abstract class IncomeEvent extends Equatable {
  const IncomeEvent();

  @override
  List<Object?> get props => [];
}

class IncomeSubscribeByMonth extends IncomeEvent {
  const IncomeSubscribeByMonth(this.month, this.year);

  final int month;
  final int year;

  @override
  List<Object> get props => [month, year];
}

class IncomeSubscribeByYear extends IncomeEvent {
  const IncomeSubscribeByYear(this.year);

  final int year;

  @override
  List<Object> get props => [year];
}

class IncomeAdded extends IncomeEvent {
  const IncomeAdded(this.income);

  final IncomeModel income;

  @override
  List<Object> get props => [income];
}

class IncomeUpdated extends IncomeEvent {
  const IncomeUpdated(this.income);

  final IncomeModel income;

  @override
  List<Object> get props => [income];
}

class IncomeDeleted extends IncomeEvent {
  const IncomeDeleted(this.id);

  final String id;

  @override
  List<Object> get props => [id];
}

class IncomeMonthChanged extends IncomeEvent {
  const IncomeMonthChanged(this.month, this.year);

  final int month;
  final int year;

  @override
  List<Object> get props => [month, year];
}

class IncomeMonthDataChanged extends IncomeEvent {
  const IncomeMonthDataChanged(this.incomes);

  final List<IncomeModel> incomes;

  @override
  List<Object> get props => [incomes];
}

class IncomeYearDataChanged extends IncomeEvent {
  const IncomeYearDataChanged(this.incomes);

  final List<IncomeModel> incomes;

  @override
  List<Object> get props => [incomes];
}

class IncomeSubscriptionFailed extends IncomeEvent {
  const IncomeSubscriptionFailed(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}
