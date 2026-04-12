import 'package:flutter/material.dart';

enum AppThemeColor { green, blue, purple }

class ThemeState {
  final ThemeMode mode;
  final AppThemeColor color;

  ThemeState({required this.mode, required this.color});

  Color get getColorPrimary {
    switch (color) {
      case AppThemeColor.green:
        return const Color(0xff059669);
      case AppThemeColor.blue:
        return const Color(0xff3f72af);
      case AppThemeColor.purple:
        return const Color(0xffb13bff);
    }
  }

  Color get getColorSecondary {
    switch (color) {
      case AppThemeColor.green:
        return const Color(0xffffD700);
      case AppThemeColor.blue:
        return const Color(0xff10B981);
      case AppThemeColor.purple:
        return const Color(0xff1A2A80);
    }
  }
}
