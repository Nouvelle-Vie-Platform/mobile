/// **Les invités s'affichent sur l'écran de détail, et nulle part ailleurs**
/// (#77).
///
/// Deux moitiés, et la seconde compte autant que la première :
///
/// 1. la **feuille d'info** crédite les invités, dans l'ordre saisi, et ne rend
///    **aucune ligne** quand il n'y en a pas ;
/// 2. ce qui ne doit **pas** bouger ne bouge pas — les cartes d'accueil, la
///    ligne de liste et la **notification d'écran verrouillé** continuent
///    d'afficher le seul animateur.
///
/// La seconde moitié n'est pas décorative : `ContentView.authorName` est une
/// chaîne nullable unique, partagée avec les rassemblements, le lecteur et les
/// trois cartes d'accueil. Rien n'empêcherait quelqu'un d'y verser les invités
/// « pour faire court » — sinon ce fichier.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/cards/teaching_tile.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';
import 'package:maison_du_miracle/widgets/home/home_content_cards.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/playback_doubles.dart';

const _id = '019f7000-0000-7000-8000-000000000001';
const _url = 'https://exemple.test/enseignement/master.m3u8';

/// L'enseignement rendu par l'écran : **un seul animateur**, comme toujours.
const _view = TeachingView(
  id: _id,
  title: 'La foi qui déplace',
  color: 0xFF223B8C,
  authorName: 'Pasteur Samuel',
  playlistUrl: _url,
  description: 'Message du dimanche.',
);

/// Le contenu, posé par le test — même patron que `content_player_view_test`.
class _ContentNotifier extends Notifier<AsyncValue<ContentView?>> {
  @override
  AsyncValue<ContentView?> build() => const AsyncValue.loading();

  void set(AsyncValue<ContentView?> value) => state = value;
}

final _contentProvider =
    NotifierProvider<_ContentNotifier, AsyncValue<ContentView?>>(
  _ContentNotifier.new,
);

/// **Les invités, par leur propre chemin.** Un provider distinct du contenu : ce
/// que l'écran de détail reçoit en plus, et que rien d'autre ne branche.
class _GuestsNotifier extends Notifier<AsyncValue<List<String>>> {
  @override
  AsyncValue<List<String>> build() => const AsyncValue.data([]);

  void set(AsyncValue<List<String>> value) => state = value;
}

final _guestsProvider =
    NotifierProvider<_GuestsNotifier, AsyncValue<List<String>>>(
  _GuestsNotifier.new,
);

void main() {
  group('La feuille d\'info crédite les invités', () {
    testWidgets('« Avec Y et Z » à deux, dans l\'ordre reçu', (tester) async {
      await _pump(tester, guests: const ['Pasteur Kossi', 'Sœur Afi']);
      await _openInfoSheet(tester);

      // Le libellé ne nomme **que** les invités. « Animé par X, avec Y et Z »
      // lirait faux sur un message du dimanche auquel un invité a été crédité —
      // et « animé par » ne se dit pas d'un prédicateur. L'animateur est de
      // toute façon déjà sous le titre.
      expect(find.text('Avec Pasteur Kossi et Sœur Afi'), findsOneWidget);
      expect(find.textContaining('Animé par'), findsNothing);
    });

    testWidgets('« Avec Y, Z et W » à trois — virgules, puis conjonction', (
      tester,
    ) async {
      await _pump(
        tester,
        guests: const ['Pasteur Kossi', 'Sœur Afi', 'Frère Yao'],
      );
      await _openInfoSheet(tester);

      // La jonction se fait en Dart : un ARB sait accueillir une liste, il ne
      // sait pas l'énumérer, et une clé par cardinalité plafonnerait le nombre
      // d'invités à ce que le fichier de traduction a prévu.
      expect(
        find.text('Avec Pasteur Kossi, Sœur Afi et Frère Yao'),
        findsOneWidget,
      );
    });

    testWidgets('un seul invité : ni virgule, ni conjonction', (tester) async {
      await _pump(tester, guests: const ['Pasteur Kossi']);
      await _openInfoSheet(tester);

      expect(find.text('Avec Pasteur Kossi'), findsOneWidget);
    });

    testWidgets('l\'ordre affiché est celui de la liste, pas l\'alphabet', (
      tester,
    ) async {
      // L'ordre vient de `position`, saisi au portail. Le retrier ici
      // remplacerait une donnée par une convention.
      await _pump(tester, guests: const ['Zoé Abalo', 'Ami Bodjona']);
      await _openInfoSheet(tester);

      expect(find.text('Avec Zoé Abalo et Ami Bodjona'), findsOneWidget);
    });

    testWidgets('pas d\'invité : **aucune ligne** ne se rend', (tester) async {
      await _pump(tester, guests: const []);
      await _openInfoSheet(tester);

      // La règle du dépôt : l'absence s'affiche comme une absence, jamais un
      // libellé de remplacement. Ni « Avec », ni tiret, ni « aucun invité » —
      // c'est l'état de presque tout le catalogue.
      expect(find.byKey(ContentPlayerView.guestsLineKey), findsNothing);
      expect(find.textContaining('Avec'), findsNothing);
      // Le reste de la feuille, lui, est bien là — cherché **dans la
      // feuille**. Le titre se rend deux fois à l'écran, une fois dans
      // l'habillage du lecteur et une fois ici : le chercher dans l'arbre
      // entier compterait deux widgets et ne dirait rien de la feuille.
      expect(_inSheet(find.text('La foi qui déplace')), findsOneWidget);
      expect(_inSheet(find.text('Message du dimanche.')), findsOneWidget);
    });

    testWidgets('liste pas encore arrivée : aucune ligne, aucun message', (
      tester,
    ) async {
      // Le magasin peut n'avoir pas encore livré les crédits quand la feuille
      // s'ouvre. Un « chargement… » au milieu d'une fiche de prêche serait pire
      // que le silence, et la ligne paraîtra sous les doigts du fidèle.
      await _pump(tester, guestsValue: const AsyncValue.loading());
      await _openInfoSheet(tester);

      expect(find.byKey(ContentPlayerView.guestsLineKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('lecture du magasin en panne : la fiche reste lisible', (
      tester,
    ) async {
      await _pump(
        tester,
        guestsValue: AsyncValue.error(
          StateError('base illisible'),
          StackTrace.empty,
        ),
      );
      await _openInfoSheet(tester);

      // Une panne de lecture des crédits ne met pas un message d'erreur dans la
      // fiche : elle se lit comme une absence de crédit.
      expect(find.byKey(ContentPlayerView.guestsLineKey), findsNothing);
      expect(_inSheet(find.text('La foi qui déplace')), findsOneWidget);
    });

    testWidgets('la ligne paraît quand le magasin livre les crédits', (
      tester,
    ) async {
      final container = await _pump(tester, guests: const []);
      await _openInfoSheet(tester);
      expect(find.byKey(ContentPlayerView.guestsLineKey), findsNothing);

      container
          .read(_guestsProvider.notifier)
          .set(const AsyncValue.data(['Pasteur Kossi']));
      await tester.pump();

      // C'est pour ça que la feuille écoute un provider au lieu de recevoir une
      // liste à l'ouverture : elle aurait figé ce qu'elle savait au moment du
      // clic.
      expect(find.text('Avec Pasteur Kossi'), findsOneWidget);
    });
  });

  group('Ce qui ne doit pas bouger', () {
    testWidgets('la notification n\'annonce que l\'animateur', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await _pump(
        tester,
        player: player,
        guests: const ['Pasteur Kossi', 'Sœur Afi'],
      );
      // Ce qui part au système ne part qu'à l'appui sur lecture : depuis
      // d777833, ouvrir la fiche ne charge plus rien dans le lecteur.
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump();

      // Ce qui part au système (notification, écran verrouillé) : le titre et
      // **l'animateur seul**. Une notification n'a pas la place d'une
      // énumération, et aucune règle de troncature n'y serait honnête.
      expect(player.loadedTitle, 'La foi qui déplace');
      expect(player.loadedAuthor, 'Pasteur Samuel');
      expect(player.loadedAuthor, isNot(contains('Kossi')));
      expect(player.loadedAuthor, isNot(contains('Afi')));
    });

    testWidgets('le titre du lecteur n\'affiche que l\'animateur', (
      tester,
    ) async {
      await _pump(tester, guests: const ['Pasteur Kossi', 'Sœur Afi']);

      // Sous le titre, avant même d'ouvrir la feuille : l'animateur, et lui
      // seul. C'est aussi la raison pour laquelle la ligne de crédit ne le
      // renomme pas — ce serait une redite.
      expect(find.text('Pasteur Samuel'), findsOneWidget);
      expect(find.textContaining('Kossi'), findsNothing);
      expect(find.textContaining('Avec'), findsNothing);
    });

    testWidgets(
        'les cartes d\'accueil et la ligne de liste ignorent les invités', (
      tester,
    ) async {
      // **Le magasin porte vraiment un invité** : le verrou ne vaut que lu
      // depuis la vraie lecture. Si quelqu'un versait un jour les invités dans
      // `authorName`, ou ajoutait une ligne de crédit aux cartes, c'est ici que
      // ça rougirait.
      final db = AppDatabase(NativeDatabase.memory());
      final repository = StoreMediathequeRepository(db.mediathequeDao);

      // **Le magasin travaille en asynchrone réel, donc sous `runAsync`.**
      // `testWidgets` fait tourner son corps dans une horloge factice : une
      // minuterie n'y part que si le test avance le temps lui-même. Drift en
      // pose — pour servir un flux, et pour finir de se fermer. Lire
      // `guestNames(...).first` puis `close()` dans l'horloge factice ne rend
      // donc **jamais** la main : le test ne se termine pas, `flutter test`
      // n'écrit pas sa ligne de synthèse, et le processus reste en vie sans
      // verdict. C'est vérifié : la même lecture suivie d'un `close()` hors
      // `runAsync` bloque indéfiniment.
      //
      // La base se ferme donc **ici**, dans le même bloc, et non par un
      // `addTearDown` — un `tearDown` ne peut pas rouvrir une fenêtre
      // d'asynchrone réel, et c'est précisément lui qui bloquait.
      final lu = await tester.runAsync(() async {
        final SyncDao sync = db.syncDao;

        await sync.applyPage(
          sync.contributorsCollection,
          upserts: [
            contributorRow(7, 'Pasteur Samuel'),
            contributorRow(4, 'Sœur Afi'),
          ],
          cursor: 'c1',
        );
        await sync.applyPage(
          sync.teachingsCollection,
          upserts: [
            teachingRow('t-1', title: 'La foi qui déplace', contributorId: 7),
          ],
          cursor: 'c1',
        );
        await sync.applyPage(
          sync.teachingGuestsCollection,
          upserts: [teachingGuestRow(1, contributorId: 4)],
          cursor: 'c1',
        );

        final view =
            (await repository.latestTeachings(locale: 'fr').first).single;
        final guests = await repository.guestNames('t-1').first;
        await db.close();
        return (view: view, guests: guests);
      });

      // `runAsync` rend `null` si le corps n'a pas tourné : l'exiger évite de
      // conclure sur une lecture qui n'a pas eu lieu.
      expect(lu, isNotNull);
      final view = lu!.view;

      // La lecture du contenu ne ramasse pas les invités : le chemin est
      // distinct, et `authorName` reste l'animateur.
      expect(view.authorName, 'Pasteur Samuel');
      // Les crédits existent bien — le magasin n'est pas vide, c'est la lecture
      // du contenu qui ne les regarde pas.
      expect(lu.guests, ['Sœur Afi']);

      // Sous un `ProviderScope` : depuis d777833, les cartes et la tuile
      // écoutent le lecteur global pour montrer l'indicateur « en lecture ».
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(
              body: ListView(
                children: [
                  HomeHeroCard(content: view),
                  HomeCarouselCard(content: view),
                  HomeListRow(content: view),
                  TeachingTile(teaching: view),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Afi'), findsNothing);
      expect(find.textContaining('Avec'), findsNothing);
      expect(find.text('Pasteur Samuel'), findsWidgets);
    });
  });
}

/// Cherche **dans la feuille d'info**, et pas dans l'arbre entier.
///
/// La feuille est un `showModalBottomSheet`, donc un `BottomSheet` posé
/// au-dessus du lecteur : le titre de l'enseignement se rend **deux fois** à
/// l'écran, une fois dans l'habillage du lecteur et une fois dans la feuille.
/// Un `find.text` non resserré en compte deux — ce qui est le comportement
/// attendu, pas un défaut. Les assertions qui parlent de la feuille descendent
/// donc dans son sous-arbre.
Finder _inSheet(Finder matching) => find.descendant(
      of: find.byType(BottomSheet),
      matching: matching,
    );

/// Ouvre la feuille d'info par le bouton de la barre du lecteur.
///
/// Pas de `pumpAndSettle` : l'écran porte des animations que rien n'arrête
/// (indicateurs, mise en tampon), et l'attente ne se stabiliserait jamais.
Future<void> _openInfoSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_book_outlined));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Monte le lecteur d'un enseignement, invités branchés.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  InertContentPlayer? player,
  List<String>? guests,
  AsyncValue<List<String>>? guestsValue,
}) async {
  final actualPlayer = player ?? InertContentPlayer();
  if (player == null) addTearDown(actualPlayer.dispose);

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  final container = ProviderContainer.test(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      contentPlayerProvider.overrideWithValue(actualPlayer),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
    ],
  );
  container.read(_contentProvider.notifier).set(const AsyncData(_view));
  container
      .read(_guestsProvider.notifier)
      .set(guestsValue ?? AsyncValue.data(guests ?? const []));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: ContentPlayerView(
          content: _contentProvider,
          guests: _guestsProvider,
          chromeTitle: 'MESSAGE',
          retractedTitle: 'Ce message n\'est plus disponible',
          retractedMessage: 'Il a été retiré du catalogue.',
          onRetry: () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return container;
}
