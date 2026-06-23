import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() => runApp(const MaisonDuMiracleApp());

/// Point d'entrée de l'application « Maison du Miracle ».
class MaisonDuMiracleApp extends StatelessWidget {
  const MaisonDuMiracleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Maison du Miracle',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.table,
        );
      },
    );
  }
}
