import 'package:flutter/material.dart';
import 'package:personal_finance/blocs/theme/theme_state.dart';

abstract class ThemeEvent {}

class ChangeThemeMode extends ThemeEvent {
  final ThemeMode mode;
  ChangeThemeMode(this.mode);
}

class ChangeThemeColor extends ThemeEvent {
  final AppThemeColor color;
  ChangeThemeColor(this.color);
}
