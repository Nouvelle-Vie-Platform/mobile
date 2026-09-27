// **Quand une écoute est comptée, et combien de fois.**
//
// Le choix vérifié ici est révocable, et le test est écrit pour qu'on le voie :
// une écoute part quand `kPlayCountThreshold` de temps **joué** est franchi, une
// seule fois par ouverture. Ramener la constante à zéro doit suffire à passer à
// « au démarrage réel de la lecture » — l'autre candidat crédible.
//
// Le fichier verrouille quatre règles, et la quatrième est celle qui compte le
// plus pour la suite du chantier : **la mesure n'écrit rien dans la reprise de
// lecture, et réciproquement.** Elle ne se vérifie pas en relisant du code mais
// en montant les deux objets sur la même base et en regardant ce que chacun a
// touché.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/measurement/play_reporter.dart';
import 'package:maison_du_miracle/data/measurement/play_spool.dart';
import 'package:maison_du_miracle/data/measurement/play_tracker.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_recorder.dart';

import '../helpers/playback_doubles.dart';

const String _contentId = '019f2c40-0000-7000-8000-000000000001';

void main() {
  late FakePlayReporter reporter;
  late FakePlaySpool spool;

  setUp(() {
    reporter = FakePlayReporter();
    spool = FakePlaySpool();
  });

  PlayTracker openTracker({String contentId = _contentId}) => PlayTracker.open(
        reporter: reporter,
        spool: spool,
        contentId: contentId,
      );

  /// Joue [seconds] secondes, par pas de deux — le rythme d'un lecteur réel,
  /// sous [kPlayAdvanceTolerance].
  Future<void> play(PlayTracker tracker, int seconds) async {
    for (var at = 0; at <= seconds; at += 2) {
      await tracker.onPosition(Duration(seconds: at), isPlaying: true);
    }
  }

  group('Le seuil', () {
    test('rien ne part avant trente secondes de temps joué', () async {
      final tracker = openTracker();

      await play(tracker, 28);

      expect(tracker.playedTime, const Duration(seconds: 28));
      expect(tracker.emitted, isFalse);
      expect(reporter.reported, isEmpty);
    });

    test('l\'écoute part au franchissement, et une seule fois', () async {
      final tracker = openTracker();

      await play(tracker, 30);
      expect(reporter.reported, [_contentId]);
      expect(tracker.emitted, isTrue);

      // Dix minutes de plus ne rappellent pas le serveur. Il déduplique déjà,
      // donc le chiffre serait juste de toute façon — mais une requête par
      // poussée de position pendant un prêche d'une heure se paie en batterie et
      // en forfait, et c'est ça qu'on protège.
      for (var at = 32; at <= 600; at += 2) {
        await tracker.onPosition(Duration(seconds: at), isPlaying: true);
      }
      expect(reporter.reported, hasLength(1));
    });

    test('une pause n\'avance pas le temps joué', () async {
      final tracker = openTracker();

      // La tête de lecture avance de dix minutes… mais `isPlaying` est faux.
      // C'est le cas du fidèle qui déplace le curseur sans lancer le son.
      for (var at = 0; at <= 600; at += 2) {
        await tracker.onPosition(Duration(seconds: at), isPlaying: false);
      }

      expect(tracker.playedTime, Duration.zero);
      expect(reporter.reported, isEmpty);
    });

    test('tirer le curseur jusqu\'au bout ne fabrique pas une écoute',
        () async {
      final tracker = openTracker();

      // Deux poussées : zéro, puis une heure. C'est un **déplacement**, pas une
      // écoute — et c'est la différence délibérée avec le rapport de progression,
      // qui compte un saut comme du temps joué parce qu'il *veut* rapporter
      // après un saut.
      await tracker.onPosition(Duration.zero, isPlaying: true);
      await tracker.onPosition(const Duration(hours: 1), isPlaying: true);

      expect(tracker.playedTime, Duration.zero);
      expect(reporter.reported, isEmpty);
    });

    test('un retour en arrière ne décompte rien et ne compte rien', () async {
      final tracker = openTracker();

      await play(tracker, 10);
      await tracker.onPosition(const Duration(seconds: 4), isPlaying: true);

      expect(tracker.playedTime, const Duration(seconds: 10));
    });

    test('le seuil est un paramètre, pas une fatalité', () async {
      // Le repli documenté — « au démarrage réel de la lecture » — se joue en
      // changeant une constante, et rien d'autre.
      final tracker = PlayTracker.open(
        reporter: reporter,
        spool: spool,
        contentId: _contentId,
        threshold: Duration.zero,
      );

      await tracker.onPosition(Duration.zero, isPlaying: true);
      await tracker.onPosition(const Duration(seconds: 1), isPlaying: true);

      expect(reporter.reported, [_contentId]);
    });
  });

  group('Le silence', () {
    test('un échec ne lève pas, et les poussées suivantes se déroulent',
        () async {
      reporter.delivered = false;
      final tracker = openTracker();

      // Aucune exception : les quinze poussées d'après l'échec passent toutes.
      // Que la **lecture** continue vraiment se prouve à l'écran et non ici —
      // `test/widgets/content_player_plays_test.dart` le vérifie sur le lecteur.
      await play(tracker, 60);

      expect(tracker.emitted, isTrue);
      // **Le compteur est figé au seuil, et c'est voulu** : `onPosition` sort
      // aussitôt dès que l'écoute est émise. Ce n'est pas une remise à zéro par
      // l'échec — ça, ce serait un défaut, et un éventuel second franchissement
      // repartirait de loin. C'est un compteur qui n'a plus de question à
      // laquelle répondre : le rattrapage d'un échec est un **drainage** de la
      // file, jamais un nouveau franchissement de seuil.
      expect(tracker.playedTime, kPlayCountThreshold);
    });

    test('un échec est classé, pas retenté à chaque poussée', () async {
      reporter.delivered = false;
      final tracker = openTracker();

      await play(tracker, 120);

      // **Une** tentative, puis la file d'attente. Retenter à chaque poussée
      // rappellerait le serveur plusieurs fois par seconde pendant tout le reste
      // du prêche, et précisément quand le réseau est mauvais.
      expect(reporter.reported, hasLength(1));
      final pending = await spool.pending();
      expect(pending.map((p) => p.contentId), [_contentId]);
    });

    test('un rapporteur qui lève est avalé', () async {
      final tracker = PlayTracker.open(
        reporter: _ThrowingPlayReporter(),
        spool: spool,
        contentId: _contentId,
        threshold: Duration.zero,
      );

      await tracker.onPosition(Duration.zero, isPlaying: true);
      await tracker.onPosition(const Duration(seconds: 1), isPlaying: true);

      // Un rapporteur est muet **par contrat** ; ce test prouve la seconde
      // ceinture, celle qui protège d'une erreur de programmation.
      expect(tracker.emitted, isTrue);
    });
  });

  group('La file d\'attente', () {
    test('ouvrir un contenu vide ce qui attendait', () async {
      await spool.add('019f2c40-0000-7000-8000-00000000000a');
      await spool.add('019f2c40-0000-7000-8000-00000000000b');

      openTracker();
      // `open` est synchrone et lance le drainage sans l'attendre : la
      // télémétrie ne retarde pas le chargement d'un média.
      await Future<void>.delayed(Duration.zero);

      expect(spool.drains, 1);
      expect(reporter.reported, [
        '019f2c40-0000-7000-8000-00000000000a',
        '019f2c40-0000-7000-8000-00000000000b',
      ]);
      expect(await spool.pending(), isEmpty);
    });
  });

  group('La file d\'attente rangée dans le magasin', () {
    late AppDatabase db;
    late SettingsPlaySpool stored;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      stored = SettingsPlaySpool(
        db.settingsDao,
        clock: () => DateTime.utc(2026, 9, 27, 10),
      );
    });

    test('une écoute classée survit à un redémarrage', () async {
      await stored.add(_contentId);

      // Une autre instance, comme après une relance de l'application : la file
      // vit dans `app_settings`, donc dans le fichier de base.
      final reopened = SettingsPlaySpool(
        db.settingsDao,
        clock: () => DateTime.utc(2026, 9, 27, 11),
      );
      expect((await reopened.pending()).map((p) => p.contentId), [_contentId]);
    });

    test('le même contenu ne se classe pas deux fois', () async {
      await stored.add(_contentId);
      await stored.add(_contentId);

      expect(await stored.pending(), hasLength(1));
    });

    test('ce qui a trop vieilli est jeté, pas remonté', () async {
      await stored.add(_contentId, at: DateTime.utc(2026, 9, 1));

      // Au-delà de `kPlaySpoolMaxAge`, imputer l'écoute au jour du renvoi
      // n'apprendrait plus rien : on préfère perdre l'unité que fausser la
      // courbe.
      expect(await stored.pending(), isEmpty);
      expect(await stored.drain(reporter), 0);
      expect(reporter.reported, isEmpty);
    });

    test('le drainage s\'arrête au premier échec et garde le reste', () async {
      await stored.add('019f2c40-0000-7000-8000-00000000000a');
      await stored.add('019f2c40-0000-7000-8000-00000000000b');
      reporter.delivered = false;

      expect(await stored.drain(reporter), 0);
      expect(reporter.reported, hasLength(1));
      expect(await stored.pending(), hasLength(2));
    });

    test('la file est bornée', () async {
      for (var i = 0; i < kPlaySpoolCapacity + 10; i++) {
        await stored.add('contenu-$i');
      }

      final pending = await stored.pending();
      expect(pending, hasLength(kPlaySpoolCapacity));
      // Ce qui tombe est le plus **ancien** : sa date de remontée serait déjà la
      // plus fausse.
      expect(pending.first.contentId, 'contenu-10');
      expect(pending.last.contentId, 'contenu-${kPlaySpoolCapacity + 9}');
    });

    test('une file illisible vaut une file vide, jamais une exception',
        () async {
      await db.settingsDao.setPendingPlays('{ceci n\'est pas du JSON');

      expect(await stored.pending(), isEmpty);
      expect(await stored.drain(reporter), 0);
    });
  });

  group('La séparation des deux mesures', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('la remontée d\'écoute n\'écrit rien dans la reprise de lecture',
        () async {
      final tracker = openTracker();
      await play(tracker, 60);

      expect(reporter.reported, [_contentId]);
      // Ni la table locale à chaud, ni la collection répliquée. Le traqueur ne
      // connaît aucun DAO de lecture — c'est une absence d'importation, pas une
      // consigne —, et voici la preuve côté magasin.
      expect(await db.playbackDao.resumeFor(_contentId), isNull);
      expect(await db.select(db.localPlaybackPositions).get(), isEmpty);
      expect(await db.select(db.playbackProgress).get(), isEmpty);
    });

    test('la reprise de lecture ne remonte aucune écoute', () async {
      final progress = FakePlaybackProgressReporter();
      final recorder = await PlaybackProgressRecorder.open(
        dao: db.playbackDao,
        reporter: progress,
        contentId: _contentId,
        mintId: () => '019f6b00-0000-7000-8000-000000000001',
      );

      // Les cinq déclencheurs de la reprise de lecture, sollicités à fond.
      for (var at = 0; at <= 120; at += 2) {
        await recorder.onPosition(
          Duration(seconds: at),
          duration: const Duration(minutes: 40),
          isPlaying: true,
        );
      }
      await recorder.onPaused();
      await recorder.onAppPaused();
      await recorder.onLeft();

      // La progression est partie…
      expect(progress.reports, isNotEmpty);
      // …et pas **une** écoute n'a été comptée. Une reprise de lecture est un
      // confort personnel ; une écoute est une statistique d'église. Les fondre
      // donnerait un compteur d'audience qui monte à chaque pause.
      expect(reporter.reported, isEmpty);
      expect(await spool.pending(), isEmpty);
    });
  });
}

/// Rapporteur qui **lève**, pour prouver la seconde ceinture du traqueur.
///
/// Une implémentation à part et non un drapeau sur [FakePlayReporter] : le
/// contrat dit qu'un rapporteur ne lève **jamais**, et un double qui pourrait
/// lever sur demande inviterait à écrire des tests contre un contrat qui
/// n'existe pas.
class _ThrowingPlayReporter implements PlayReporter {
  @override
  Future<bool> report(String contentId) async =>
      throw StateError('panne de programmation');
}
