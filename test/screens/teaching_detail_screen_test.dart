import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/data/sample_data.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/teaching_detail_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';

import '../helpers/playback_doubles.dart';

/// Enseignements de test **sans image** : `flutter test` répond 400 à tout
/// accès réseau, et un visuel distant ne prouverait rien de plus ici.
/// `final` et non `const` : les dates ne sont pas constructibles en constante.
///
/// **Avec `playlistUrl`, sauf le dernier**, et les deux moitiés de cette phrase
/// sont voulues. Depuis #40 le lecteur charge cette URL : une fixture qui n'en
/// porte pas décrit un enseignement **publié sans média**, ce qui est un cas
/// réel — et qui bascule tout l'écran sur la branche « média absent » (#41).
/// Les deux premiers en ont donc une, pour que les assertions de lecture
/// portent bien sur la lecture ; le troisième s'en passe exprès, et c'est lui
/// le cas de test de cette branche-là.
final _teachings = [
  Teaching(
    id: '01940000-0000-7000-8000-000000000001',
    title: 'Le premier de la liste',
    author: 'Pasteur Un',
    teachingTypeId: 1,
    recordedAt: DateTime.utc(2026, 4, 12),
    publishedAt: DateTime.utc(2026, 4, 12, 8),
    playlistUrl: 'https://exemple.test/premier/master.m3u8',
  ),
  Teaching(
    id: '01940000-0000-7000-8000-000000000002',
    title: 'Celui du milieu',
    author: 'Pasteur Deux',
    teachingTypeId: 2,
    recordedAt: DateTime.utc(2026, 4, 5),
    publishedAt: DateTime.utc(2026, 4, 5, 8),
    playlistUrl: 'https://exemple.test/milieu/master.m3u8',
  ),
  Teaching(
    id: '01940000-0000-7000-8000-000000000003',
    title: 'Le dernier de la liste',
    author: 'Pasteur Trois',
    teachingTypeId: 3,
    recordedAt: DateTime.utc(2026, 3, 29),
    publishedAt: DateTime.utc(2026, 3, 29, 8),
    // **Gardé sans média, délibérément** — voir le commentaire ci-dessus.
  ),
];

/// Médiathèque **pilotée par le test**, et surtout **rejouable** : son flux
/// ré-émet, ce qui est le seul moyen de reproduire ce qui justifie tout ce
/// ticket — une rétractation qui arrive pendant que l'écran est ouvert.
class _FakeMediatheque implements MediathequeRepository {
  _FakeMediatheque(List<Teaching> teachings)
      : _teachings = StreamController<List<Teaching>>.broadcast() {
    _latest = teachings;
  }

  final StreamController<List<Teaching>> _teachings;
  late List<Teaching> _latest;

  /// Échec de lecture du magasin, quand le test veut une panne.
  Object? failure;

  void dispose() => _teachings.close();

  /// Ce que produit `{ id, deletedAt }` dans le flux delta (ADR-0025) : le
  /// contenu quitte le magasin, et les écrans ouverts l'apprennent.
  void retract(String id) =>
      emit(_latest.where((t) => t.id != id).toList(growable: false));

  void emit(List<Teaching> teachings) {
    _latest = teachings;
    _teachings.add(teachings);
  }

  /// Rejoue la dernière valeur connue puis suit les suivantes — c'est le
  /// comportement d'un `watch()` Drift, qui émet immédiatement.
  Stream<List<Teaching>> get _stream async* {
    if (failure != null) throw failure!;
    yield _latest;
    yield* _teachings.stream;
  }

  @override
  Stream<List<TeachingView>> latestTeachings({
    required String locale,
    int? limit,
  }) =>
      _stream.map((rows) => rows.map((t) => _view(t, locale)).toList());

  @override
  Stream<List<TeachingView>> teachingsOfType(
    int teachingTypeId, {
    required String locale,
  }) =>
      _stream.map(
        (rows) => rows
            .where((t) => t.teachingTypeId == teachingTypeId)
            .map((t) => _view(t, locale))
            .toList(),
      );

  @override
  Stream<TeachingView?> teachingById(String id, {required String locale}) =>
      _stream.map((rows) {
        for (final teaching in rows) {
          if (teaching.id == id) return _view(teaching, locale);
        }
        return null;
      });

  @override
  Stream<List<HomeSectionView>> homeSections({required String locale}) =>
      _stream.map((_) => const <HomeSectionView>[]);

  TeachingView _view(Teaching teaching, String locale) => TeachingView.resolve(
        id: teaching.id,
        title: teaching.title,
        locale: locale,
        contributorName: teaching.author,
        teachingTypeId: teaching.teachingTypeId,
        color: teaching.color,
        imageLandscapeUrl: teaching.imageLandscapeUrl,
        playlistUrl: teaching.playlistUrl,
        publishedAt: teaching.publishedAt,
        recordedAt: teaching.recordedAt,
      );
}

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

    test('chaque rubrique désignée existe dans le référentiel fictif', () {
      final known = SampleData.teachingTypes.map((t) => t.id).toSet();
      final designated = SampleData.teachings
          .map((t) => t.teachingTypeId)
          .whereType<int>()
          .toSet();

      // Pas une contrainte du magasin — l'entier y est nu, exprès — mais une
      // exigence de la maquette : un jeu de démonstration dont les rubriques
      // ne résolvent rien ne montrerait jamais un libellé.
      expect(designated.difference(known), isEmpty);
    });
  });

  group('Route /teaching/:id', () {
    testWidgets('ouvre l\'enseignement désigné, et pas le premier',
        (tester) async {
      final router = await _pumpApp(tester);

      // Le **deuxième** : c'est ce qui distingue « celui qu'on a demandé » de
      // l'ancien repli `.first`. Le troisième ne conviendrait plus ici — il
      // est publié sans média, et son écran n'affiche donc aucun titre à
      // comparer (voir « Publié sans média » plus bas).
      router.pushNamed(
        AppRoute.teachingDetail,
        pathParameters: {'id': _teachings[1].id},
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.text('Celui du milieu'), findsOneWidget);
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

  group('Ce que l\'AsyncValue a ajouté', () {
    testWidgets(
        'une lecture qui échoue se dit comme une panne, pas une absence',
        (tester) async {
      // Un magasin illisible n'est pas un contenu retiré : il y a quelque
      // chose à réessayer, et l'écran doit le proposer.
      final repository = _FakeMediatheque(_teachings)
        ..failure = StateError('magasin illisible');
      addTearDown(repository.dispose);

      await _pumpDetail(tester, _container(repository), _teachings[1].id);

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsNothing);
      expect(find.byKey(AppErrorState.retryKey), findsOneWidget);
    });

    testWidgets('l\'écran reste le même dans les quatre états', (tester) async {
      final repository = _FakeMediatheque(_teachings);
      addTearDown(repository.dispose);

      await _pumpDetail(tester, _container(repository), _teachings[1].id);
      expect(find.byType(TeachingDetailScreen), findsOneWidget);

      repository.retract(_teachings[1].id);
      await tester.pump();
      // Ni fermeture, ni redirection : le fidèle n'est pas déplacé.
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
    });
  });

  group('Rétractation pendant la lecture', () {
    testWidgets('le contenu retiré remplace le lecteur, sans fermer l\'écran',
        (tester) async {
      final repository = _FakeMediatheque(_teachings);
      addTearDown(repository.dispose);
      await _pumpDetail(tester, _container(repository), _teachings[1].id);

      // On est bien en lecture : le bouton affiche « pause ».
      expect(find.text('Celui du milieu'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Le serveur rétracte pendant l'écoute. Deux `pump` : le premier livre
      // l'évènement du flux au `StreamProvider`, le second reconstruit l'écran.
      repository.retract(_teachings[1].id);
      await tester.pump();
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
      final repository = _FakeMediatheque(_teachings);
      addTearDown(repository.dispose);
      await _pumpDetail(tester, _container(repository), _teachings[1].id);

      repository.retract(_teachings[1].id);
      await tester.pump();
      // Une resynchronisation le rend : l'écran le réaffiche, à l'arrêt.
      // Reprendre le son tout seul serait une surprise sonore.
      repository.emit(_teachings);
      await tester.pump();

      expect(find.text('Celui du milieu'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });
  });

  group('Publié sans média', () {
    testWidgets('l\'écran dit « Enregistrement à venir »', (tester) async {
      // Un contenu publié sans média est un état **courant** : la portée de
      // publication du serveur ne teste aujourd'hui que `published_at`.
      final repository = _FakeMediatheque(_teachings);
      addTearDown(repository.dispose);

      await _pumpDetail(tester, _container(repository), _teachings[2].id);

      expect(tester.takeException(), isNull);
      // Le cadre du lecteur, le surtitre, la porte de sortie : on n'éjecte
      // personne et on ne le déplace pas.
      expect(find.byType(TeachingDetailScreen), findsOneWidget);
      expect(find.text('ENSEIGNEMENT'), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.byKey(ContentAbsenceView.backKey), findsOneWidget);
      expect(find.text('Enregistrement à venir'), findsOneWidget);
      // Rien à piloter : aucune commande de lecture.
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('ce n\'est pas « contenu retiré »', (tester) async {
      final repository = _FakeMediatheque(_teachings);
      addTearDown(repository.dispose);

      await _pumpDetail(tester, _container(repository), _teachings[2].id);

      // Confondre les deux ferait croire à une suppression, et le fidèle
      // cesserait d'attendre un enregistrement qui arrive.
      expect(
          find.text('Cet enseignement n\'est plus disponible'), findsNothing);
      expect(find.byIcon(ContentAbsence.retracted.icon), findsNothing);
    });
  });

  group('L\'absence s\'affiche comme une absence', () {
    testWidgets('un enseignement sans intervenant s\'affiche quand même',
        (tester) async {
      // Le cas normal du magasin : `teachings` et `contributors` se
      // synchronisent séparément, l'un peut arriver sans l'autre.
      final orphan = Teaching(
        id: '01940000-0000-7000-8000-0000000000aa',
        title: 'Sans intervenant',
        author: '',
        recordedAt: DateTime.utc(2026, 4, 12),
        publishedAt: DateTime.utc(2026, 4, 12, 8),
        playlistUrl: 'https://exemple.test/orphelin/master.m3u8',
      );
      final repository = _FakeMediatheque([orphan]);
      addTearDown(repository.dispose);

      await _pumpDetail(tester, _container(repository), orphan.id);

      expect(tester.takeException(), isNull);
      // Le contenu est là — la jointure tolérante l'a laissé passer.
      expect(find.text('Sans intervenant'), findsOneWidget);
      // Et **rien** n'a été inventé à la place du nom.
      expect(find.textContaining('inconnu'), findsNothing);
      expect(find.textContaining('Inconnu'), findsNothing);
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
        teachingTypeId: 1,
        recordedAt: DateTime.utc(2026, 4, 12),
        publishedAt: DateTime.utc(2026, 4, 12, 8),
        imageLandscapeUrl: 'https://example.invalid/cover.jpg',
        playlistUrl: 'https://exemple.test/visuel/master.m3u8',
      );
      final repository = _FakeMediatheque([withImage]);
      addTearDown(repository.dispose);

      await _pumpDetail(tester, _container(repository), withImage.id);

      expect(tester.takeException(), isNull);
      expect(find.text('Avec visuel distant'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });
  });
}

/// Conteneur branché sur une médiathèque pilotée par le test.
///
/// Le magasin est posé **en mémoire** : l'écran de lecture ouvre un
/// enregistreur de progression (#43), qui lit et écrit son `PlaybackDao` sans
/// passer par un repository. Sans cette surcharge, le test ouvrirait un fichier
/// de base sur la machine — quand il ne lèverait pas, faute de canal de plugin.
ProviderContainer _container(MediathequeRepository repository) {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return ProviderContainer.test(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      mediathequeRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

/// Monte l'écran de détail seul, adossé à la médiathèque fournie.
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
  final repository = _FakeMediatheque(teachings ?? _teachings);
  addTearDown(repository.dispose);
  // Écran haut : les listes de l'app sont paresseuses, et une carte jamais
  // construite ne peut pas être tapée.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = _container(repository);
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
///
/// Trois passes depuis #40 : l'écran de lecture demande sa **reprise** au
/// magasin avant de charger le média, et cette lecture est asynchrone. Deux
/// frames livraient le contenu mais pas toujours le son.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}
