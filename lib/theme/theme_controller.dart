import 'package:flutter/material.dart';

/// Mode de thème courant, partagé à l'échelle de l'application.
///
/// Porté par un [ValueNotifier] pour rester sans `StatefulWidget` :
/// `MaterialApp` y réagit via un `ValueListenableBuilder`, et n'importe quel
/// écran peut le faire basculer.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

/// Indique si le mode sombre est actif (en tenant compte du réglage système).
bool isDarkMode(BuildContext context) {
  final mode = themeModeNotifier.value;
  if (mode == ThemeMode.system) {
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
  return mode == ThemeMode.dark;
}

/// Bascule entre clair et sombre.
void toggleTheme(BuildContext context) {
  themeModeNotifier.value =
      isDarkMode(context) ? ThemeMode.light : ThemeMode.dark;
}
