import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/sample_data.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/repository_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';

/// Enseignements de test **sans image** : `flutter test` répond 400 à tout
/// accès réseau, et un visuel distant ne prouverait rien de plus ici.
/// `final` et non `const` : les dates ne sont pas constructibles en constante.
final _teachings = [
  Teaching(
    id: '01940000-0000-7000-8000-000000000001',
    title: 'Le premier de la liste',
    author: 'Pasteur Un',
    duration: '10:00',
    rubric: TeachingRubric.dimanche,
    recordedAt: DateTime.utc(2026, 4, 12),
    publishedAt: DateTime.utc(2026, 4, 12, 8),
  ),
  Teaching(
    id: '01940000-0000-7000-8000-000000000002',
    title: 'Celui du milieu',
    author: 'Pasteur Deux',
    duration: '20:00',
    rubric: TeachingRubric.etude,
    recordedAt: DateTime.utc(2026, 4, 5),
    publishedAt: DateTime.utc(2026, 4, 5, 8),
  ),
  Teaching(
    id: '01940000-0000-7000-8000-000000000003',
    title: 'Le dernier de la liste',
    author: 'Pasteur Trois',
    duration: '30:00',
    rubric: TeachingRubric.priere,
    recordedAt: DateTime.utc(2026, 3, 29),
    publishedAt: DateTime.utc(2026, 3, 29, 8),
  ),
];

/// Magasin d'enseignements **mutable**, pour rejouer une rétractation reçue
/// pendant que l'écran est ouvert — le scénario qui justifie tout ce ticket.
class _TeachingStore extends Notifier<List<Teaching>> {
  @override
  List<Teaching> build() => _teachings;

  /// Ce que produit `{ id, deletedAt }` dans le flux delta (ADR-0025) : le
  /// contenu quitte le magasin.
  void retract(String id) =>
      state = state.where((t) => t.id != id).toList(growable: false);
}

final _storeProvider =
    NotifierProvider<_TeachingStore, List<Teaching>>(_TeachingStore.new);

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
  group('SampleData.teachings', () {
    test('chaque enseignement porte un identifiant unique et non vide', () {
      final ids = SampleData.teachings.map((t) => t.id).toList();

      expect(ids.where((id) => id.trim().isEmpty), isEmpty);
      expect(ids.toSet(), hasLength(ids.length),
          reason: 'deux enseignements partageant un id sont indiscernables '
              'depuis la route');
    });

    test('les identifiants sont écrits en dur, donc stables', () {
      // Deux lectures de la même constante : un `Uuid().v7()` appelé dans la
      // liste passerait ce test, mais pas d'un lancement à l'autre. Le vrai
      // garde-fou est l'assertion ci-dessous, qui fige un identifiant connu.
      expect(
        SampleData.teachings.map((t) => t.id),
        SampleData.teachings.map((t) => t.id),
      );
      expect(
        SampleData.teachings.first.id,
        '0195cfbf-ac00-7a60-9eb6-46f7b38cf45a',
        reason: 'changer un id casse tout lien déjà partagé ou notifié',
      );
    });
  });

  group('Route /teaching/:id', () {
    testWidgets('ouvre l\'enseignement désigné, et pas le premier',
        (tester) async {
      final router = await _pumpApp(tester);

      // Le troisième : c'est ce qui distingue « celui qu'on a demandé » de
      // l'ancien repli `.first`.
      router.pushNamed(
        AppRoute.teachingDetail,
        pathParameters: {'id': _teachings[2].id},
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.text('Le dernier de la liste'), findsOneWidget);
      expect(find.text('Le premier de la liste'), findsNothing);
    });

    testWidgets('s\'ouvre par URL directe — ce que permet un lien FCM',
        (tester) async {
      final router = await _pumpApp(tester);

      // Aucun objet transmis : exactement ce dont dispose une notification ou
      // un lien partagé. C'était impossible avant, faute d'identifiant.
      router.go('/teaching/${_teachings[1].id}');
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Celui du milieu'), findsOneWidget);
    });

    testWidgets('identifiant inconnu : écran « contenu retiré », sans plantage',
        (tester) async {
      final router = await _pumpApp(tester);

      router.go('/teaching/01940000-0000-7000-8000-00000000dead');
      await _settle(tester);

      expect(tester.takeException(), isNull);
      // L'écran s'ouvre quand même : on ne renvoie personne d'où il vient.
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(
          find.text('Cet enseignement n\'est plus disponible'), findsOneWidget);
      // Aucun contenu emprunté à un autre enseignement.
      expect(find.text('Le premier de la liste'), findsNothing);
    });

    testWidgets('magasin vide : plus de repli `.first`, donc plus de crash',
        (tester) async {
      // Le premier lancement, magasin local encore vide : `.first` levait ici.
      final router = await _pumpApp(tester, teachings: const []);

      router.go('/teaching/${_teachings.first.id}');
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
    });

    testWidgets('depuis la médiathèque, la carte ouvre son propre enseignement',
        (tester) async {
      final router = await _pumpApp(tester);
      router.go('/media');
      await _settle(tester);

      // Dernière occurrence du titre : la liste « Recommandés », en bas.
      await tester.ensureVisible(find.text('Celui du milieu').last);
      await tester.pump();
      await tester.tap(find.text('Celui du milieu').last);
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(TeachingDetailScreen),
          matching: find.text('Celui du milieu'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Visuel de l\'enseignement', () {
    testWidgets('un visuel injoignable retombe sur le placeholder',
        (tester) async {
      // `flutter test` répond 400 à tout accès réseau — comme un téléphone
      // hors ligne. Sans repli, le lecteur lèverait au lieu de s'afficher.
      final withImage = Teaching(
        id: '01940000-0000-7000-8000-0000000000ff',
        title: 'Avec visuel distant',
        author: 'Pasteur Quatre',
        duration: '40:00',
        rubric: TeachingRubric.dimanche,
        recordedAt: DateTime.utc(2026, 4, 12),
        publishedAt: DateTime.utc(2026, 4, 12, 8),
        imageLandscapeUrl: 'https://example.invalid/cover.jpg',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teachingsProvider.overrideWithValue([withImage]),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: TeachingDetailScreen(teachingId: withImage.id),
          ),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Avec visuel distant'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });
  });

  group('Rétractation pendant la lecture', () {
    testWidgets('le contenu retiré remplace le lecteur, sans fermer l\'écran',
        (tester) async {
      final container = _container();
      await _pumpDetail(tester, container, _teachings[1].id);

      // On est bien en lecture : le bouton affiche « pause ».
      expect(find.text('Celui du milieu'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Le serveur rétracte pendant l'écoute.
      container.read(_storeProvider.notifier).retract(_teachings[1].id);
      await tester.pump();

      // L'écran reste ouvert — on n'éjecte pas quelqu'un en pleine lecture.
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      // La copie n'est pas gelée : plus de titre, plus de lecteur.
      expect(find.text('Celui du milieu'), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byType(Slider), findsNothing);
      // Et on dit ce qui s'est passé, avec une porte de sortie.
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.byKey(ContentAbsenceView.backKey), findsOneWidget);
    });

    testWidgets('la lecture ne redémarre pas si le contenu réapparaît',
        (tester) async {
      final container = _container();
      await _pumpDetail(tester, container, _teachings[1].id);

      container.read(_storeProvider.notifier).retract(_teachings[1].id);
      await tester.pump();
      // Une resynchronisation le rend : l'écran le réaffiche, à l'arrêt.
      // Reprendre le son tout seul serait une surprise sonore.
      container.read(_storeProvider.notifier).state = _teachings;
      await tester.pump();

      expect(find.text('Celui du milieu'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });
  });
}

/// Conteneur partagé par les tests de rétractation : le magasin y est mutable.
ProviderContainer _container() => ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
        branchRepositoryProvider
            .overrideWithValue(const InMemoryBranchRepository()),
        teachingsProvider.overrideWith((ref) => ref.watch(_storeProvider)),
      ],
    );

/// Monte l'écran de détail seul, adossé au magasin mutable.
Future<void> _pumpDetail(
  WidgetTester tester,
  ProviderContainer container,
  String id,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: TeachingDetailScreen(teachingId: id),
      ),
    ),
  );
  await _settle(tester);
}

/// Monte l'application réelle (routeur compris), session déjà ouverte.
///
/// C'est le `builder` de la route qu'on vérifie — le vrai, avec sa garde
/// `redirect` — et non un routeur reconstruit pour l'occasion.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  List<Teaching>? teachings,
}) async {
  final data = teachings ?? _teachings;
  // Écran haut : les listes de l'app sont paresseuses, et une carte jamais
  // construite ne peut pas être tapée.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      teachingsProvider.overrideWithValue(data),
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

/// `pump` et jamais `pumpAndSettle` : plusieurs écrans de l'app animent en
/// boucle (splash, squelettes) et ne se stabilisent jamais.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
