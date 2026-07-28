import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/sample_data.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/event_detail_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/utils/i18n_text.dart';
import 'package:maison_du_miracle/widgets/app_card.dart';
import 'package:maison_du_miracle/widgets/app_chip.dart';
import 'package:maison_du_miracle/widgets/cards/event_card.dart';

import '../helpers/pump_screen.dart';

/// Évènement complet : catégorie, fin annoncée, lieu et description.
///
/// Fuseau du Togo (UTC+0 toute l'année) : l'heure affichée est celle de la
/// branche, sans conversion.
final _fullEvent = ChurchEvent(
  id: 'evt-test-complet',
  startsAt: DateTime.utc(2024, 5, 26, 9),
  endsAt: DateTime.utc(2024, 5, 26, 11),
  timezone: 'Africa/Lome',
  branchId: 1,
  title: const {'fr': 'Culte de Gloire', 'en': 'Glory Service'},
  body: const {'fr': 'Un temps de louange et d\'enseignement.'},
  place: 'Temple Central',
  category: const EventCategory(
    id: 1,
    label: {'fr': 'Culte', 'en': 'Service'},
    tone: 'culte',
  ),
);

/// Le cas courant, et non un cas limite : une prière hebdomadaire n'a ni
/// description, ni lieu distinct, ni catégorie déclarée.
final _bareEvent = ChurchEvent(
  id: 'evt-test-nu',
  startsAt: DateTime.utc(2024, 5, 27, 17, 30),
  timezone: 'Africa/Lome',
  title: const {'fr': 'Prière de zone'},
);

/// Occurrences servies à l'agenda, **posées dans le mois courant**.
///
/// L'agenda ne charge que le mois affiché : des dates figées (mai 2024) n'y
/// apparaîtraient jamais, et les dates relatives de `SampleData` (« dimanche
/// prochain ») basculent dans le mois suivant une semaine par mois. Les 5 et 12
/// existent dans tous les mois, y compris février.
final _agendaEvents = [
  ChurchEvent(
    id: 'evt-agenda-1',
    startsAt: DateTime.utc(DateTime.now().year, DateTime.now().month, 5, 9),
    timezone: 'Africa/Lome',
    title: const {'fr': 'Culte du mois'},
  ),
  ChurchEvent(
    id: 'evt-agenda-2',
    startsAt: DateTime.utc(DateTime.now().year, DateTime.now().month, 12, 18),
    timezone: 'Africa/Lome',
    title: const {'fr': 'Veillée du mois'},
  ),
];

/// Occurrences **à venir**, pour la section « À venir » de l'accueil.
///
/// Ancrées relativement à maintenant, et non à un quantième fixe : l'accueil
/// filtre sur `from = maintenant`, si bien qu'une fixture datée du 5 du mois
/// serait vide vingt-cinq jours sur trente. Le décalage horaire les garde à
/// venir quelle que soit l'heure d'exécution.
final _upcomingEvents = [
  ChurchEvent(
    id: 'evt-upcoming-1',
    startsAt: DateTime.now().toUtc().add(const Duration(days: 2)),
    timezone: 'Africa/Lome',
    title: const {'fr': 'Culte à venir'},
  ),
  ChurchEvent(
    id: 'evt-upcoming-2',
    startsAt: DateTime.now().toUtc().add(const Duration(days: 5)),
    timezone: 'Africa/Lome',
    title: const {'fr': 'Veillée à venir'},
  ),
];

/// Repository d'auth déjà connecté : le routeur n'ouvre les routes internes
/// qu'une fois la session résolue (garde `redirect`).
class _SignedInAuthRepository extends InMemoryAuthRepository {
  static const _user = User(
    id: 'u_test',
    email: 'test@example.com',
    firstName: 'Test',
    branchId: 1,
    profileComplete: true,
  );

  @override
  Future<User?> cachedUser() async => _user;

  @override
  Future<User?> currentUser() async => _user;
}

void main() {
  group('EventDetailScreen', () {
    testWidgets('affiche titre, catégorie, date, heure, lieu et description',
        (tester) async {
      await pumpScreen(tester, EventDetailScreen(event: _fullEvent));

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Culte de Gloire'), findsOneWidget);
      expect(find.text('Culte'), findsOneWidget);
      // Date complète, en français, dans le fuseau de la branche.
      expect(find.text('Dimanche 26 mai 2024'), findsOneWidget);
      // Début et fin ; pas de suffixe de fuseau, le lecteur de test est en
      // UTC comme la branche.
      expect(find.text('09:00 - 11:00'), findsOneWidget);
      expect(find.text('Temple Central'), findsOneWidget);
      expect(find.text('À propos'), findsOneWidget);
      expect(
        find.text('Un temps de louange et d\'enseignement.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'sans description, sans lieu et sans catégorie : aucun bloc vide',
        (tester) async {
      await pumpScreen(tester, EventDetailScreen(event: _bareEvent));

      expect(find.text('Prière de zone'), findsOneWidget);
      expect(find.text('Lundi 27 mai 2024'), findsOneWidget);
      // Pas de fin annoncée : l'heure de début seule.
      expect(find.text('17:30'), findsOneWidget);

      // Aucune puce de catégorie, aucun en-tête de section orphelin.
      expect(find.byType(AppChip), findsNothing);
      expect(find.text('À propos'), findsNothing);
      // Aucune ligne « lieu » : l'icône du lieu n'est pas dans l'arbre.
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      // La carte « quand / où » reste, elle : la date et l'heure existent
      // toujours. Elle ne contient que ces deux lignes.
      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('affiche une traduction absente via le repli français',
        (tester) async {
      // Locale de test = fr, mais le contenu peut n'exister qu'en anglais :
      // c'est `pick` qui tranche, l'écran ne fait aucun repli local.
      final onlyEnglish = ChurchEvent(
        id: 'evt-test-en',
        startsAt: DateTime.utc(2024, 5, 26, 9),
        timezone: 'Africa/Lome',
        title: const {'en': 'Glory Service'},
      );
      await pumpScreen(tester, EventDetailScreen(event: onlyEnglish));

      expect(find.text('Glory Service'), findsOneWidget);
    });

    testWidgets('se monte en thème sombre', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: EventDetailScreen(event: _fullEvent),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Culte de Gloire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Route /event', () {
    testWidgets('accès direct sans `extra` : repli sur le premier évènement',
        (tester) async {
      final router = await _pumpApp(tester);

      // Aucun `extra` : exactement ce que produit un lien direct ou une
      // restauration d'état. L'écran doit s'ouvrir quand même.
      router.pushNamed(AppRoute.eventDetail);
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventDetailScreen),
          matching: find.text(pick(SampleData.events.first.title, 'fr')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('depuis l\'agenda, la carte ouvre son propre évènement',
        (tester) async {
      final router = await _pumpApp(tester);
      router.go('/agenda');
      await _settle(tester);

      // Deuxième carte : c'est ce qui distingue « le bon évènement » de
      // « le premier de la liste ».
      final title = pick(_agendaEvents[1].title, 'fr');
      await tester.ensureVisible(find.byType(EventCard).at(1));
      await tester.pump();
      await tester.tap(find.byType(EventCard).at(1));
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(EventDetailScreen),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
    });

    testWidgets('depuis « À venir », la carte ouvre son propre évènement',
        (tester) async {
      // Fixture propre à ce test : l'accueil lit `upcomingEventsProvider`
      // (`from = maintenant`), alors que `_agendaEvents` est ancré aux 5 et 12
      // du mois courant — donc dans le passé la plupart du mois. Une fixture
      // relative à maintenant est la seule qui ne dépende pas du jour où la
      // suite tourne.
      final router = await _pumpApp(tester, events: _upcomingEvents);
      router.go('/home');
      await _settle(tester);

      final second = _upcomingEvents[1];
      final title = pick(second.title, 'fr');
      await tester.ensureVisible(find.text(title));
      await tester.pump();
      await tester.tap(find.text(title));
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(EventDetailScreen),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
    });
  });
}

/// Monte l'application réelle (routeur compris), session déjà ouverte.
///
/// Indispensable pour ces tests : c'est le `builder` de la route — et sa garde
/// `redirect` — qu'on vérifie, pas un routeur reconstruit pour l'occasion.
Future<GoRouter> _pumpApp(WidgetTester tester,
    {List<ChurchEvent>? events}) async {
  // Écran haut : les listes de l'app sont paresseuses, et une carte jamais
  // construite ne peut pas être tapée. On agrandit plutôt que de simuler des
  // défilements, qui déplaceraient la cible sous la barre de titre.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      // L'agenda **et** la section « À venir » de l'accueil passent par
      // `CalendarRepository`, dont l'implémentation par défaut est HTTP
      // (`AppEnv.useBackend`) : sans ce double, ces routes ouvriraient une
      // socket (400 en test) et n'afficheraient qu'un état d'erreur.
      calendarRepositoryProvider.overrideWithValue(
        InMemoryCalendarRepository(events: events ?? _agendaEvents),
      ),
    ],
  );
  final router = container.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
      ),
    ),
  );
  await _settle(tester);
  return router;
}

/// Laisse passer transitions et minuteries — `pump` et jamais `pumpAndSettle`,
/// plusieurs écrans de l'app animant en boucle (splash, squelettes).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
