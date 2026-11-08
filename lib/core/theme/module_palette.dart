import 'package:flutter/material.dart';

/// Each feature module has its own identity color, used for its icon on the
/// home screen and for its accents, while buttons keep the user's theme color.
enum AppModule {
  savings(Color(0xFF0F9D77)),
  spending(Color(0xFFD85A30)),
  income(Color(0xFF6C5CE7)),
  report(Color(0xFFBA7517));

  const AppModule(this.seed);

  final Color seed;
}

/// Light/dark-aware tones derived from a module's seed color.
class ModuleTone {
  const ModuleTone({
    required this.accent,
    required this.container,
    required this.onContainer,
  });

  /// Strong color for bars, highlighted values and icons on plain surfaces.
  final Color accent;

  /// Soft background for icon badges and chips.
  final Color container;

  /// Text and icon color on top of [container].
  final Color onContainer;

  static final Map<(AppModule, Brightness), ModuleTone> _cache = {};

  static ModuleTone of(BuildContext context, AppModule module) {
    final brightness = Theme.of(context).brightness;
    return _cache.putIfAbsent((module, brightness), () {
      final scheme = ColorScheme.fromSeed(
        seedColor: module.seed,
        brightness: brightness,
      );
      return ModuleTone(
        accent: scheme.primary,
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
      );
    });
  }

  /// Tones for an arbitrary color (expense category, income type...).
  static ModuleTone fromColor(BuildContext context, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ModuleTone(
      accent: color,
      container: color.withValues(alpha: dark ? 0.28 : 0.14),
      onContainer: dark
          ? Color.lerp(color, Colors.white, 0.45)!
          : Color.lerp(color, Colors.black, 0.35)!,
    );
  }
}
