import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/theme/app_palette.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_button.dart';
import 'package:maison_du_miracle/widgets/app_card.dart';
import 'package:maison_du_miracle/widgets/app_empty_state.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/app_list_skeleton.dart';

/// Monte un état isolé, dans une luminosité donnée, avec les traductions.
///
/// `pump()` et non `pumpAndSettle` : le squelette anime en boucle et ne se
/// stabilise jamais.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: const Locale('fr'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('AppListSkeleton', () {
    testWidgets('se monte et peint une carte fantôme par élément demandé',
        (tester) async {
      await _pump(tester, const AppListSkeleton(itemCount: 4));

      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(find.byType(AppCard), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('anime en boucle sans lever ni fuir son contrôleur',
        (tester) async {
      await _pump(tester, const AppListSkeleton());

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);

      // Remplacer le squelette doit disposer proprement le contrôleur : un
      // ticker resté actif ferait échouer le teardown du test.
      await _pump(tester, const SizedBox.shrink());
      expect(find.byType(AppListSkeleton), findsNothing);
    });

    testWidgets('cas limites : zéro élément, sans pastille, sans ligne',
        (tester) async {
      await _pump(tester, const AppListSkeleton(itemCount: 0));
      expect(find.byType(AppCard), findsNothing);

      await _pump(
        tester,
        const AppListSkeleton(itemCount: 2, leading: false, lines: 0),
      );
      expect(find.byType(AppCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('se monte en thème sombre', (tester) async {
      await _pump(
        tester,
        const AppListSkeleton(),
        theme: AppTheme.dark,
      );
      expect(find.byType(AppListSkeleton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppEmptyState', () {
    testWidgets('variante « rien » : bloc carte, titre, message, aucune action',
        (tester) async {
      await _pump(
        tester,
        const AppEmptyState(
          title: 'Aucun événement ce mois-ci',
          message: 'Rien n\'est prévu pour cette période.',
        ),
      );

      expect(find.text('Aucun événement ce mois-ci'), findsOneWidget);
      expect(
          find.text('Rien n\'est prévu pour cette période.'), findsOneWidget);
      expect(find.byType(AppCard), findsOneWidget);
      // Un état vide ne propose rien à faire : c'est ce qui le sépare de
      // l'erreur.
      expect(find.byType(AppButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'variante « fin d\'horizon » : marqueur discret à filets, sans carte',
        (tester) async {
      await _pump(
        tester,
        const AppEmptyState(
          title: 'Fin du calendrier',
          message: 'Les événements plus lointains ne sont pas encore annoncés.',
          variant: AppEmptyStateVariant.endOfRange,
        ),
      );

      expect(find.text('Fin du calendrier'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.byType(AppCard), findsNothing);
      expect(find.byType(AppButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les deux variantes ne se ressemblent pas', (tester) async {
      await _pump(tester, const AppEmptyState(title: 'Vide'));
      final nothingIcon = tester.widget<Icon>(find.byType(Icon)).icon;
      expect(find.byType(AppCard), findsOneWidget);

      await _pump(
        tester,
        const AppEmptyState(
          title: 'Fin',
          variant: AppEmptyStateVariant.endOfRange,
        ),
      );
      final endIcon = tester.widget<Icon>(find.byType(Icon)).icon;
      expect(find.byType(AppCard), findsNothing);

      expect(nothingIcon, isNot(equals(endIcon)));
    });

    testWidgets('accepte un pictogramme fourni et un message absent',
        (tester) async {
      await _pump(
        tester,
        const AppEmptyState(title: 'Vide', icon: Icons.star_outline),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.star_outline);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se monte en thème sombre, dans les deux variantes',
        (tester) async {
      for (final variant in AppEmptyStateVariant.values) {
        await _pump(
          tester,
          AppEmptyState(title: 'Titre', message: 'Message', variant: variant),
          theme: AppTheme.dark,
        );
        expect(find.text('Titre'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AppErrorState', () {
    testWidgets('affiche titre, cause et action par défaut, en français',
        (tester) async {
      await _pump(tester, AppErrorState(onRetry: () {}));

      expect(find.text('Connexion perdue'), findsOneWidget);
      expect(
        find.text(
          'Impossible de charger le contenu. '
          'Vérifiez votre connexion internet, puis réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Réessayer » appelle le callback fourni', (tester) async {
      var calls = 0;
      await _pump(tester, AppErrorState(onRetry: () => calls++));

      expect(calls, 0);
      await tester.tap(find.byKey(AppErrorState.retryKey));
      await tester.pump();
      expect(calls, 1);

      await tester.tap(find.byKey(AppErrorState.retryKey));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('les textes fournis remplacent les valeurs par défaut',
        (tester) async {
      await _pump(
        tester,
        AppErrorState(
          onRetry: () {},
          title: 'Agenda indisponible',
          message: 'Le serveur ne répond pas pour l\'instant.',
          retryLabel: 'Relancer',
        ),
      );

      expect(find.text('Agenda indisponible'), findsOneWidget);
      expect(find.text('Le serveur ne répond pas pour l\'instant.'),
          findsOneWidget);
      expect(find.text('Relancer'), findsOneWidget);
      expect(find.text('Connexion perdue'), findsNothing);
    });

    testWidgets('se monte en thème sombre', (tester) async {
      await _pump(tester, AppErrorState(onRetry: () {}), theme: AppTheme.dark);
      expect(find.text('Connexion perdue'), findsOneWidget);
      expect(
        tester.widget<AppCard>(find.byType(AppCard)).color,
        AppPalette.dark.dangerBg,
      );
    });
  });

  // Le point qui commande tout le reste : un agenda vide faute de réseau ne
  // doit pas ressembler à un mois sans événement.
  group('Erreur vs vide : distinction visuelle', () {
    testWidgets('la carte d\'erreur est teintée, la carte vide est neutre',
        (tester) async {
      await _pump(tester, AppErrorState(onRetry: () {}));
      final errorCard = tester.widget<AppCard>(find.byType(AppCard));
      expect(errorCard.color, AppPalette.light.dangerBg);
      // Une action, donc une issue.
      expect(find.byType(AppButton), findsOneWidget);

      await _pump(tester, const AppEmptyState(title: 'Aucun événement'));
      final emptyCard = tester.widget<AppCard>(find.byType(AppCard));
      // Pas de teinte imposée : la carte garde l'habillage verre dépoli.
      expect(emptyCard.color, isNull);
      expect(emptyCard.color, isNot(AppPalette.light.dangerBg));
      expect(find.byType(AppButton), findsNothing);
    });
  });
}
