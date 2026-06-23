import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gère le [ThemeMode] courant de l'application.
///
/// Remplace l'ancien `ValueNotifier` global par un provider Riverpod, testable
/// et accessible sans `BuildContext`.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Force un mode précis.
  void set(ThemeMode mode) => state = mode;

  /// Bascule entre clair et sombre.
  ///
  /// [platformIsDark] permet de partir de la luminosité système lorsque le
  /// mode courant est [ThemeMode.system].
  void toggle({required bool platformIsDark}) {
    final isDark = switch (state) {
      ThemeMode.system => platformIsDark,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    };
    state = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

/// Mode de thème courant, partagé à l'échelle de l'application.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Indique si le mode sombre est effectivement actif (en tenant compte du
/// réglage système lorsque le mode est [ThemeMode.system]).
bool isDarkModeActive(ThemeMode mode, BuildContext context) {
  if (mode == ThemeMode.system) {
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
  return mode == ThemeMode.dark;
}
