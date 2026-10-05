/// **La remontée d'écoute vue de l'écran de lecture.**
///
/// Ce que les tests unitaires du traqueur ne peuvent pas prouver : que la
/// position lui est bien **poussée**, une fois par ouverture, que le direct n'est
/// pas compté, et surtout que **rien ne relie les deux mesures** — un
/// enregistreur de progression en panne ne doit pas emporter l'audience avec
/// lui.
///
/// Depuis #115, ce n'est plus l'écran qui pousse : c'est le contrôleur global,
/// qui suit ce qui est **chargé**. La fiche n'y est plus que le geste qui charge
/// — un appui sur lecture —, et ces tests vérifient qu'en passant par elle la
/// mesure se comporte exactement comme avant. Les mêmes règles hors de la fiche
/// se vérifient dans `test/state/playback_tracking_test.dart`.
///
/// Tout se joue sur l'[InertContentPlayer] : aucun canal de plugin, aucune
/// minuterie, la position ne bouge que si le test la pousse.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/measurement_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';

import '../helpers/playback_doubles.dart';

const _url = 'https://exemple.test/enseignement/master.m3u8';
const _id = '019f7000-0000-7000-8000-000000000001';

const _view = TeachingView(
  id: _id,
  title: 'La foi qui déplace',
  color: 0xFF223B8C,
  authorName: 'Pasteur Samuel',
  playlistUrl: _url,
);

class _ContentNotifier extends Notifier<AsyncValue<ContentView?>> {
  @override
  AsyncValue<ContentView?> build() => const AsyncValue.loading();

  void set(AsyncValue<ContentView?> value) => state = value;
}

final _contentProvider =
    NotifierProvider<_ContentNotifier, AsyncValue<ContentView?>>(
  _ContentNotifier.new,
);

void main() {
  late FakePlayReporter plays;
  late FakePlaySpool spool;
  late FakePlaybackProgressReporter progress;

  setUp(() {
    plays = FakePlayReporter();
    spool = FakePlaySpool();
    progress = FakePlaybackProgressReporter();
  });

  /// Joue [seconds] secondes en poussant la position au lecteur, par pas de
  /// deux — le rythme d'un lecteur réel, sous `kPlayAdvanceTolerance`.
  Future<void> play(
    WidgetTester tester,
    InertContentPlayer player,
    int seconds,
  ) async {
    for (var at = 0; at <= seconds; at += 2) {
      player.emit(
        player.value.copyWith(
          contentId: _id,
          position: Duration(seconds: at),
          duration: const Duration(minutes: 45),
          isPlaying: true,
        ),
      );
      await tester.pump();
    }
  }

  /// **La prémisse « le contenu est chargé », posée par le geste d'un fidèle.**
  ///
  /// Ouvrir la fiche ne charge plus rien (sauf le direct) ; le suivi s'ouvre au
  /// chargement, dans le contrôleur global. Sans cet appui, les positions
  /// poussées plus bas ne trouveraient aucune session — et ces tests passeraient
  /// au vert sur une mesure qui n'existe pas.
  Future<void> start(WidgetTester tester, InertContentPlayer player) async {
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    // Résolution du téléchargement et lecture de la reprise : deux requêtes au
    // magasin avant que le média ne soit chargé.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(player.value.contentId, _id,
        reason: 'prémisse : le contenu est chargé');
    expect(player.value.isPlaying, isTrue, reason: 'prémisse : le son joue');
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required InertContentPlayer player,
    bool isLive = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentPlayerProvider.overrideWithValue(player),
        playbackProgressReporterProvider.overrideWithValue(progress),
        playReporterProvider.overrideWithValue(plays),
        playSpoolProvider.overrideWithValue(spool),
        // Le contrôleur surveille la rétractation du contenu chargé : des
        // catalogues en mémoire, plutôt que des flux Drift ouverts pour rien.
        mediathequeRepositoryProvider
            .overrideWithValue(InMemoryMediathequeRepository()),
        gatheringRepositoryProvider
            .overrideWithValue(InMemoryGatheringRepository()),
      ],
    );
    container.read(_contentProvider.notifier).set(const AsyncData(_view));

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
            chromeTitle: 'MESSAGE',
            retractedTitle: 'Ce message n\'est plus disponible',
            retractedMessage: 'Il a été retiré du catalogue.',
            onRetry: () {},
            isLive: isLive,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  testWidgets('ouvrir la fiche ne compte pas une écoute', (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);

    await pump(tester, player: player);

    // L'ouverture ne joue plus (sauf le direct) : compter ici compterait des
    // coups d'œil. C'est aussi ce qui rend la mesure indépendante de la règle
    // d'ouverture — elle suit ce qui **sonne**, pas ce qu'on affiche.
    expect(plays.reported, isEmpty);
  });

  testWidgets('une écoute part au seuil, une seule fois par ouverture',
      (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);
    await pump(tester, player: player);
    await start(tester, player);

    await play(tester, player, 28);
    expect(plays.reported, isEmpty, reason: 'le seuil n\'est pas atteint');

    await play(tester, player, 600);
    expect(plays.reported, [_id]);
  });

  testWidgets('le direct n\'est pas compté', (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);
    await pump(tester, player: player, isLive: true);

    await play(tester, player, 600);

    // Il n'y a pas d'enseignement derrière un flux, et la route veut un
    // identifiant de contenu. Compter le direct enverrait des écoutes sur
    // l'identifiant de la vignette du live.
    expect(plays.reported, isEmpty);
  });

  testWidgets('un échec de remontée ne se voit pas', (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);
    plays.delivered = false;

    await pump(tester, player: player);
    await start(tester, player);
    await play(tester, player, 120);

    // L'écoute continue : le lecteur joue toujours, à la position poussée.
    expect(player.value.isPlaying, isTrue);
    expect(player.value.position, const Duration(seconds: 120));
    // Rien à l'écran — ni bandeau, ni `SnackBar`, ni état d'erreur. La
    // télémétrie n'a pas le droit de se voir : personne ne l'a demandée, et une
    // ligne rouge au milieu d'un prêche est une panne.
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('rreur'), findsNothing);
    // Et l'événement est classé pour plus tard, pas perdu.
    expect((await spool.pending()).map((p) => p.contentId), [_id]);
  });

  testWidgets('la remontée d\'écoute n\'écrit rien dans la reprise de lecture',
      (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);
    final container = await pump(tester, player: player);
    final db = container.read(appDatabaseProvider);
    await start(tester, player);

    await play(tester, player, 120);

    expect(plays.reported, [_id]);
    // Les positions locales écrites pendant ces deux minutes viennent de
    // l'enregistreur de progression, pas du traqueur — et surtout, le traqueur
    // n'a produit **aucune** ligne de progression au serveur qui lui soit
    // imputable : les deux listes sont indépendantes.
    expect(progress.reports, isNotEmpty);
    expect(progress.reports.map((r) => r.contentId), everyElement(_id));
    // La collection répliquée reste vide : l'application n'y écrit jamais, et
    // la mesure d'audience moins que personne.
    expect(await db.select(db.playbackProgress).get(), isEmpty);
  });

  testWidgets('une progression qui échoue ne fait pas taire la mesure',
      (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);
    progress.delivered = false;

    await pump(tester, player: player);
    await start(tester, player);
    await play(tester, player, 60);

    // Les deux mesures sont **indépendantes en panne aussi**. C'est ce que la
    // garde séparée de `_trackPlay` protège : sous une garde commune, un
    // enregistreur absent aurait emporté l'audience avec lui, et le chiffre
    // aurait baissé sans que rien ne le signale.
    expect(plays.reported, [_id]);
  });

  testWidgets('quitter la fiche ne coupe plus la mesure', (tester) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);
    await pump(tester, player: player);
    await start(tester, player);
    await play(tester, player, 10);

    // La fiche se ferme, le son continue — le lecteur est global. Avant #115,
    // la mesure mourait avec l'écran, et ces vingt secondes de plus ne
    // comptaient jamais.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var at = 12; at <= 40; at += 2) {
      player.emit(player.value.copyWith(position: Duration(seconds: at)));
    }
    await tester.pump();

    expect(plays.reported, [_id]);
  });
}
