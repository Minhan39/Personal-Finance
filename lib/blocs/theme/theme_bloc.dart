import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:personal_finance/blocs/theme/theme_event.dart';
import 'package:personal_finance/blocs/theme/theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc()
    : super(ThemeState(mode: ThemeMode.system, color: AppThemeColor.green)) {
    on<ChangeThemeMode>((event, emit) {
      emit(ThemeState(mode: event.mode, color: state.color));
    });
    on<ChangeThemeColor>((event, emit) {
      emit(ThemeState(mode: state.mode, color: event.color));
    });
  }
}
