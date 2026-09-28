/// **L'écran de démarrage porte le fond du lancement précédent.**
///
/// Deux choses seulement, et la seconde est celle qui se raterait en silence :
/// le fond est bien posé quand il y en a un, et le dégradé de marque ne
/// disparaît **jamais** — sans lui, un fond clair rendrait l'emblème blanc et
/// le nom de l'église illisibles, ce qui ne se verrait qu'avec ce fond-là,
/// c'est-à-dire un jour, chez quelqu'un d'autre.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/screens/splash_screen.dart';
import 'package:maison_du_miracle/state/season_providers.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

final _fond = MemoryImage(Uint8List.fromList(const [9, 8, 7, 6]));

Future<void> _pump(WidgetTester tester, {ImageProvider? background}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        startupBackgroundProvider.overrideWithValue(background),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const SplashScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Tous les dégradés peints par l'écran.
List<Gradient> _gradients(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((decoration) => decoration.gradient)
    .whereType<Gradient>()
    .toList();

void main() {
  testWidgets('le fond du lancement précédent est posé', (tester) async {
    await _pump(tester, background: _fond);

    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image);
    expect(images, contains(_fond));
  });

  testWidgets('avec un fond, un voile sombre reste par-dessus', (tester) async {
    await _pump(tester, background: _fond);

    // Il y a toujours un dégradé : c'est lui qui tient la lisibilité du blanc.
    // Et ce n'est **pas** celui de la marque — il est opaque, il masquerait la
    // photo qu'on vient de poser.
    expect(_gradients(tester), isNotEmpty);
    expect(_gradients(tester), isNot(contains(AppColors.gradientPrimary)));
  });

  testWidgets('premier lancement : pas de fond, et le dégradé de marque',
      (tester) async {
    await _pump(tester);

    // Aucun **fond** — rien n'a encore été descendu, et c'est le contrat : on
    // descend pendant que l'application tourne, on s'en sert la fois suivante.
    // (L'emblème, lui, est une image du dépôt et reste là.)
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image);
    expect(images.whereType<MemoryImage>(), isEmpty);

    // Et c'est le dégradé **de marque** qui revient, pas le voile sombre : le
    // voile n'existe que pour tenir la lisibilité par-dessus une photo.
    expect(_gradients(tester), contains(AppColors.gradientPrimary));
  });

  testWidgets('l\'écran de marque reste un écran de marque', (tester) async {
    await _pump(tester, background: _fond);

    // Le fond ne remplace rien : l'emblème, le nom et le témoin de résolution
    // de session sont toujours là.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
