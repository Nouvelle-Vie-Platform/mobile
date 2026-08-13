/// **L'écran de lecture pilote le lecteur** (issue #40).
///
/// Tout se joue sur l'[InertContentPlayer] : aucun canal de plugin, aucune
/// minuterie, la position ne bouge que si le test la pousse. Ce que ces tests
/// vérifient n'est donc jamais « est-ce que ça sonne » — c'est **ce que l'écran
/// demande au lecteur**, qui est précisément ce qu'aucun test ne regardait
/// tant que le lecteur était feint.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';
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

/// **Publié sans média** (issue #41) — un état courant, et non un résidu : la
/// portée de publication du serveur ne teste aujourd'hui que `published_at`.
///
/// Sa couleur n'est **pas** celle de la marque, et c'est délibéré : elle est ce
/// qui distingue à l'écran « le contenu existe, seul son enregistrement
/// manque » d'une rétractation, où la couleur est perdue avec la donnée.
const _sansMedia = TeachingView(
  id: _id,
  title: 'Publié sans fichier',
  color: 0xFF8C2233,
  authorName: 'Pasteur Samuel',
);

/// Le contenu **piloté par le test** : les quatre états de l'`AsyncValue` se
/// posent à la main, y compris le retour à « chargement » que rien d'autre ne
/// sait reproduire à volonté.
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
  group('Le branchement', () {
    testWidgets('charger le contenu à l\'ouverture, et démarrer', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await _pump(tester, player: player);

      expect(player.loadedUrl, _url);
      expect(player.loadedTitle, 'La foi qui déplace');
      expect(player.loadCount, 1);
      // L'auto-lecture à l'ouverture est un **choix** : elle coûte désormais du
      // réseau. Elle est pinnée par les tests des deux écrans de détail, et le
      // bouton de pause en est la trace visible.
      expect(player.value.isPlaying, isTrue);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('un contenu déjà chargé ne repart pas de zéro', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      // Ce que voit un fidèle qui revient sur l'écran d'un prêche en cours : le
      // lecteur est global, il n'a jamais cessé de jouer.
      await player.load(contentId: _id, url: _url, title: 'La foi qui déplace');
      player.emit(player.value.copyWith(position: const Duration(minutes: 12)));
      player.play();

      await _pump(tester, player: player);

      expect(player.loadCount, 1, reason: 'aucun rechargement');
      expect(player.value.position, const Duration(minutes: 12));
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('quitter l\'écran n\'arrête pas la lecture', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      // `context.pop()` : l'écran s'en va, le lecteur est global et le son
      // continue. C'est le sens même de l'écoute en arrière-plan — et la raison
      // pour laquelle `contentPlayerProvider` n'est pas `autoDispose`.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(player.value.isPlaying, isTrue);
      expect(player.value.contentId, _id);
    });

    testWidgets('sans média, rien n\'est chargé', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await _pump(tester, player: player, content: _sansMedia);

      // Aucune URL nulle ne part dans le lecteur, et rien ne joue.
      expect(player.loadCount, 0);
      expect(player.value.isPlaying, isFalse);
    });
  });

  group('Publié sans média', () {
    testWidgets('« Enregistrement à venir », dans le cadre du lecteur', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await _pump(tester, player: player, content: _sansMedia);

      // Le même échafaudage que la lecture : le surtitre est là, le fidèle
      // n'a pas été déplacé, et il a une porte de sortie.
      expect(find.text('ENSEIGNEMENT'), findsOneWidget);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.byKey(ContentAbsenceView.backKey), findsOneWidget);
      // Le libellé existant convient tel quel : il dit une attente.
      expect(find.text('Enregistrement à venir'), findsOneWidget);
      expect(find.byIcon(ContentAbsence.noMedia.icon), findsOneWidget);
      // Aucune commande : il n'y a rien à piloter.
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('« pas encore disponible » n\'est pas « contenu retiré »', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await _pump(tester, player: player, content: _sansMedia);

      // Réutiliser `retracted` ferait croire à une suppression : le fidèle
      // cesserait d'attendre un enregistrement qui arrive.
      expect(
          find.text('Cet enseignement n\'est plus disponible'), findsNothing);
      expect(find.byIcon(ContentAbsence.retracted.icon), findsNothing);
    });

    testWidgets('la couleur reste celle du contenu', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await _pump(tester, player: player, content: _sansMedia);

      // L'inverse exact de la rétractation, qui retombe sur le bleu de marque
      // faute de contenu d'où tirer une teinte. Ici le contenu est là, son
      // habillage aussi ; seul son enregistrement manque.
      expect(_scaffoldBase(tester), const Color(0xFF8C2233));
    });

    testWidgets('la rétractation, elle, retombe sur la couleur de repli', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = await _pump(tester, player: player);

      container.read(_contentProvider.notifier).set(const AsyncData(null));
      await tester.pump();

      expect(_scaffoldBase(tester), const Color(kBrandFallbackColor));
    });
  });

  group('Les commandes', () {
    testWidgets('lecture/pause pilote le lecteur, pas un booléen local', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(player.value.isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('le bouton suit le lecteur, même piloté d\'ailleurs', (
      tester,
    ) async {
      // La notification et l'écran verrouillé pilotent le même lecteur : l'état
      // du bouton se lit dans la valeur, il ne se mémorise pas.
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      player.pause();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('le curseur déplace vraiment la tête de lecture', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);
      player.emit(player.value.copyWith(duration: const Duration(minutes: 40)));
      await tester.pump();

      final slider = tester.getRect(find.byType(Slider));
      await tester.dragFrom(slider.centerLeft, Offset(slider.width / 2, 0));
      await tester.pump();

      // Au milieu d'un média de quarante minutes : la valeur locale ne suffit
      // plus, c'est le lecteur qui a bougé.
      expect(player.value.position.inMinutes, closeTo(20, 3));
    });

    testWidgets('un glissement n\'est pas écrasé par les émissions de position',
        (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);
      player.emit(player.value.copyWith(duration: const Duration(minutes: 40)));
      await tester.pump();

      final rect = tester.getRect(find.byType(Slider));
      final gesture = await tester.startGesture(rect.centerLeft);
      await gesture.moveTo(rect.center);
      await tester.pump();

      // Le lecteur continue d'émettre pendant le geste — plusieurs fois par
      // seconde. Le curseur doit rester sous le doigt.
      player.emit(player.value.copyWith(position: const Duration(seconds: 3)));
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.5, 0.15),
      );

      await gesture.up();
      await tester.pump();
      expect(player.value.position.inMinutes, closeTo(20, 3));
    });
  });

  group('Le compteur de temps', () {
    testWidgets('une durée connue s\'affiche des deux côtés', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      player.emit(
        player.value.copyWith(
          position: const Duration(minutes: 3, seconds: 7),
          duration: const Duration(minutes: 41, seconds: 2),
        ),
      );
      await tester.pump();

      expect(find.text('03:07'), findsOneWidget);
      expect(find.text('41:02'), findsOneWidget);
    });

    testWidgets('une durée inconnue n\'invente pas de 00:00', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      // Le cas **courant** en HLS sur iOS, pas l'exception : la durée arrive
      // après le manifeste, et peut ne jamais arriver.
      player.emit(
        player.value.copyWith(position: const Duration(seconds: 12)),
      );
      await tester.pump();

      expect(find.text('00:12'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
      // Affichage dégradé : le temps écoulé seul, et un curseur qui ne prétend
      // pas savoir où l'on en est.
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    });
  });

  group('Le coût de reconstruction', () {
    testWidgets('la position qui avance ne reconstruit pas tout l\'écran', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      final titreAvant = tester.widget<Text>(find.text('La foi qui déplace'));
      player.emit(player.value.copyWith(position: const Duration(seconds: 1)));
      await tester.pump();
      player.emit(player.value.copyWith(position: const Duration(seconds: 2)));
      await tester.pump();

      // Le titre, le dégradé, le `Hero` et l'image sont **le même widget**
      // qu'avant : seul le bloc qui affiche la position s'est redessiné. Sans
      // cette isolation, tout l'arbre du lecteur se reconstruirait plusieurs
      // fois par seconde, pendant toute une écoute.
      final titreApres = tester.widget<Text>(find.text('La foi qui déplace'));
      expect(identical(titreAvant, titreApres), isTrue);
      expect(find.text('00:02'), findsOneWidget);
    });
  });

  group('La rétractation coupe le son', () {
    testWidgets('stop, et l\'écran verrouillé est vidé', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = await _pump(tester, player: player);
      expect(player.value.isPlaying, isTrue);

      // `{ id, deletedAt }` dans le flux delta : le contenu quitte le magasin
      // pendant l'écoute.
      container.read(_contentProvider.notifier).set(const AsyncData(null));
      await tester.pump();

      // Couper l'état du widget ne suffisait que tant que rien ne jouait. Avec
      // un service de premier plan derrière, l'enseignement retiré continuerait
      // de jouer, écran éteint, son titre affiché sur l'écran verrouillé.
      expect(player.value, const ContentPlayback());
      expect(player.value.isPlaying, isFalse);
      expect(player.loadedTitle, isNull, reason: 'plus rien à afficher');
      expect(player.loadedUrl, isNull);
      expect(find.byType(ContentAbsenceView), findsOneWidget);
    });

    testWidgets('un simple retour à « chargement » ne coupe rien', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = await _pump(tester, player: player);

      // Une resynchronisation repasse par « chargement ». Le déclencheur est la
      // **valeur**, jamais l'`AsyncValue` : couper ici serait couper le son à
      // chaque cycle de synchronisation.
      container.read(_contentProvider.notifier).set(const AsyncLoading());
      await tester.pump();

      expect(player.value.isPlaying, isTrue);
      expect(player.value.contentId, _id);
      expect(player.loadedTitle, 'La foi qui déplace');
    });

    testWidgets('un contenu qui réapparaît ne relance pas le son tout seul', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = await _pump(tester, player: player);

      container.read(_contentProvider.notifier).set(const AsyncData(null));
      await tester.pump();
      container.read(_contentProvider.notifier).set(const AsyncData(_view));
      await tester.pump();

      // Une rétractation suivie d'une republication est courante. Reprendre le
      // son sans que personne ne l'ait demandé serait une surprise sonore.
      expect(player.value.isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Le geste explicite, lui, recharge : l'écran n'est pas mort.
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(player.value.isPlaying, isTrue);
      expect(player.loadCount, 2);
    });
  });

  group('La panne en cours d\'écoute', () {
    /// Ce que pousse le lecteur quand le réseau lâche au milieu d'un prêche :
    /// le son avait commencé, la position est loin, et la panne arrive.
    void interrompre(InertContentPlayer player) {
      player.emit(
        player.value.copyWith(
          position: const Duration(minutes: 37),
          duration: const Duration(minutes: 58),
          hasStarted: true,
          isPlaying: false,
          error: 'réseau coupé',
        ),
      );
    }

    testWidgets('elle se dit « Lecture interrompue », et propose de reprendre',
        (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      interrompre(player);
      await tester.pump();

      expect(find.text('Lecture interrompue'), findsOneWidget);
      // Et surtout pas le message du catalogue : « Impossible de charger le
      // contenu » parlerait d'un chargement qui a pourtant réussi.
      expect(find.textContaining('Impossible de charger'), findsNothing);
      // **« Reprendre », jamais « Réessayer »** : le mot doit promettre de
      // repartir d'où on en était. Sur un prêche d'une heure, la crainte d'un
      // retour à zéro suffit à ce que le fidèle ne touche pas au bouton.
      expect(find.text('Reprendre'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
    });

    testWidgets('le titre du prêche ne disparaît pas sous la panne', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      interrompre(player);
      await tester.pump();

      // Basculer sur un écran d'allure différente reviendrait à déplacer le
      // fidèle sans le lui dire — et à effacer ce qu'il était en train
      // d'écouter.
      expect(find.text('La foi qui déplace'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('« Reprendre » reprend à la position, sans tout recharger', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      interrompre(player);
      await tester.pump();
      await tester.tap(find.byKey(AppErrorState.retryKey));
      await tester.pump();

      expect(player.resumeCount, 1);
      // Le contrat du mot : la tête de lecture est restée où elle était.
      expect(player.value.position, const Duration(minutes: 37));
      expect(player.value.hasError, isFalse);
      expect(player.value.isPlaying, isTrue);
      // Et ce n'est pas un nouveau chargement : c'est la même écoute.
      expect(player.loadCount, 1);
    });

    testWidgets('un échec avant tout son dit qu\'il faut du réseau', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      // Le manifeste n'a jamais répondu : rien n'a jamais joué. Il n'y a
      // aucune position à défendre, donc rien à « reprendre ».
      player.emit(player.value.copyWith(error: 'hôte injoignable'));
      await tester.pump();

      expect(find.byType(ContentAbsenceView), findsOneWidget);
      expect(find.text('Lecture interrompue'), findsNothing);
      expect(find.text('Reprendre'), findsNothing);
    });

    testWidgets('la panne d\'un autre contenu ne peint pas cet écran', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      // Le lecteur est **global** : il peut porter la panne d'un contenu
      // ouvert ailleurs, et cet écran-ci n'a rien à en dire.
      player.emit(
        const ContentPlayback(contentId: 'un-autre', error: 'réseau coupé'),
      );
      await tester.pump();

      expect(find.text('Lecture interrompue'), findsNothing);
      expect(find.byType(ContentAbsenceView), findsNothing);
    });
  });

  group('La mise en tampon', () {
    testWidgets('elle se pose au-dessus du visuel, sans remplacer l\'écran', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      player.emit(
        player.value.copyWith(
          isBuffering: true,
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 58),
        ),
      );
      await tester.pump();

      expect(find.byKey(ContentPlayerView.bufferingKey), findsOneWidget);
      // Basculer sur l'état « chargement » perdrait le titre et les commandes,
      // et ressemblerait à un redémarrage. Ce n'en est pas un : c'est une
      // attente au milieu d'une écoute.
      expect(find.text('La foi qui déplace'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('elle disparaît dès que le son revient', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      player.emit(player.value.copyWith(isBuffering: true));
      await tester.pump();
      player.emit(player.value.copyWith(isBuffering: false));
      await tester.pump();

      expect(find.byKey(ContentPlayerView.bufferingKey), findsNothing);
    });

    testWidgets('une panne n\'est pas une attente', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      await _pump(tester, player: player);

      player.emit(
        player.value.copyWith(hasStarted: true, error: 'réseau coupé'),
      );
      await tester.pump();

      // Un indicateur qui tourne à côté d'un bouton « Reprendre » dirait deux
      // choses contraires.
      expect(find.byKey(ContentPlayerView.bufferingKey), findsNothing);
    });
  });

  group('La reprise de lecture', () {
    testWidgets('rouvrir un contenu reprend où on s\'était arrêté', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.playbackDao.saveLocalPosition(
        contentId: _id,
        progressId: '019f7000-0000-7000-8000-0000000000ff',
        positionSeconds: 754,
      );

      await _pump(tester, player: player, database: database);

      expect(player.value.position, const Duration(seconds: 754));
    });

    testWidgets('la pause rapporte la position', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final reporter = FakePlaybackProgressReporter();

      await _pump(tester, player: player, reporter: reporter);
      // Douze secondes : sous le pas du rapport périodique (30 s de temps
      // joué). Ce qui part ensuite ne peut donc venir que de la pause.
      player.emit(player.value.copyWith(position: const Duration(seconds: 12)));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single.contentId, _id);
      expect(reporter.reports.single.positionSeconds, 12);
    });

    testWidgets('écran éteint : on rapporte, on n\'arrête pas', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final reporter = FakePlaybackProgressReporter();

      await _pump(tester, player: player, reporter: reporter);
      player.emit(player.value.copyWith(position: const Duration(seconds: 12)));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(reporter.reports.single.positionSeconds, 12);
      // Le cas le plus fréquent de tout ce lot : le fidèle range son téléphone
      // dans sa poche. Couper ici serait la panne la plus visible.
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('à la fin, le lecteur est remis d\'aplomb', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final reporter = FakePlaybackProgressReporter();

      await _pump(tester, player: player, reporter: reporter);
      player.emit(
        player.value.copyWith(
          position: const Duration(minutes: 40),
          duration: const Duration(minutes: 40),
          isCompleted: true,
        ),
      );
      await tester.pump();

      // Sans ça, le bouton affiche « pause » sur un silence, curseur en fin.
      expect(player.value.isPlaying, isFalse);
      expect(player.value.position, Duration.zero);
      expect(reporter.reports.last.completed, isTrue);
    });
  });
}

/// La couleur d'où part le dégradé du cadre du lecteur.
///
/// Elle n'est lisible que là : le cadre est privé au fichier de production, et
/// c'est bien ce qu'on veut vérifier — la teinte que porte l'écran, pas la
/// valeur qu'on lui a passée.
Color _scaffoldBase(WidgetTester tester) {
  final gradient = tester
      .widgetList<Container>(find.byType(Container))
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.gradient)
      .whereType<LinearGradient>()
      .first;
  return gradient.colors.first;
}

/// Monte le lecteur seul, sur un contenu piloté par le test.
///
/// Rend le conteneur : c'est par lui que le test fait varier l'`AsyncValue`.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required InertContentPlayer player,
  ContentView? content,
  AppDatabase? database,
  FakePlaybackProgressReporter? reporter,
}) async {
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);

  final container = ProviderContainer.test(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      contentPlayerProvider.overrideWithValue(player),
      playbackProgressReporterProvider
          .overrideWithValue(reporter ?? FakePlaybackProgressReporter()),
    ],
  );
  // Posé **avant** le montage : l'écran doit trouver son contenu dès le premier
  // build, comme lorsqu'il revient sur un provider déjà résolu.
  container.read(_contentProvider.notifier).set(AsyncData(content ?? _view));

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
          chromeTitle: 'ENSEIGNEMENT',
          retractedTitle: 'Cet enseignement n\'est plus disponible',
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
