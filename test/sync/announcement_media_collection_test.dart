// **Le média des annonces, du flux delta jusqu'au modèle de lecture** (#130).
//
// Le serveur sert cinq champs `media*` à plat depuis `server-portal#477`, et le
// client les déclarait sans jamais les peupler. Ces tests suivent une ligne
// servie d'un bout à l'autre : désérialisée (`announcementRowOf`), stockée telle
// quelle, puis lue par le repository du magasin en `StatusAudio` /
// `StatusVideo`. Les fixtures sont relevées sur `announcement_transformer.ts`,
// jamais sur une hypothèse du client.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/converters/waveform_converter.dart';
import 'package:maison_du_miracle/data/repositories/store_announcement_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/sync_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<AnnouncementView> stored(Map<String, Object?> payload) async {
    await db.into(db.announcements).insert(announcementRowOf(payload));
    final views = await StoreAnnouncementRepository(db.announcementDao)
        .announcements()
        .first;
    return views.singleWhere((view) => view.id == payload['id']);
  }

  group('announcementRowOf — le média se stocke brut', () {
    test('une annonce audio garde ses cinq champs', () async {
      await db
          .into(db.announcements)
          .insert(announcementRowOf(audioAnnouncementPayload));

      final row = (await db.select(db.announcements).get()).single;
      expect(row.mediaKind, 'audio');
      expect(
        row.mediaUrl,
        'https://media.example.test/sparks/019f5a00/master.m3u8',
      );
      expect(row.mediaPosterUrl, isNull);
      expect(row.mediaDurationMs, 42000);
      expect(row.mediaWaveform, hasLength(36));
      expect(row.mediaWaveform!.first, 12);
    });

    test('une annonce texte les porte tous à `null`', () async {
      await db
          .into(db.announcements)
          .insert(announcementRowOf(fullAnnouncementPayload));

      final row = (await db.select(db.announcements).get()).single;
      expect(row.mediaKind, isNull);
      expect(row.mediaUrl, isNull);
      expect(row.mediaWaveform, isNull);
    });

    test('un genre inconnu se stocke tel quel, sans coûter la page', () async {
      // Le magasin stocke ce que le serveur envoie ; c'est la lecture qui
      // décide qu'un genre inconnu n'est pas un média.
      await db.into(db.announcements).insert(
            announcementRowOf({
              ...audioAnnouncementPayload,
              'mediaKind': 'hologramme',
            }),
          );

      final row = (await db.select(db.announcements).get()).single;
      expect(row.mediaKind, 'hologramme');
    });
  });

  group('La forme d\'onde servie', () {
    test('est bornée à 0..100 et arrondie', () {
      expect(WaveformConverter.decode([-5, 42.4, 42.6, 140]), [0, 42, 43, 100]);
    });

    test('saute ce qui n\'est pas un nombre, sans inventer de hauteur', () {
      expect(WaveformConverter.decode([10, 'fort', null, 30]), [10, 30]);
    });

    test('rend `null` quand le serveur ne sert pas de liste', () {
      expect(WaveformConverter.decode(null), isNull);
      expect(WaveformConverter.decode({'0': 10}), isNull);
    });

    test('un JSON corrompu en base se lit vide, jamais en exception', () {
      // Une exception ferait échouer la requête qui peint tout le mur.
      expect(const WaveformConverter().fromSql('pas du json'), isEmpty);
      expect(const WaveformConverter().fromSql('{"a":1}'), isEmpty);
    });

    test('fait l\'aller-retour en base sans perte', () {
      const converter = WaveformConverter();
      expect(converter.fromSql(converter.toSql([0, 50, 100])), [0, 50, 100]);
    });
  });

  group('Le repository du magasin peuple `audio` et `video`', () {
    test(
      'une annonce audio devient un StatusAudio, forme d\'onde comprise',
      () async {
        final view = await stored(audioAnnouncementPayload);

        expect(view.kind, StatusKind.audio);
        expect(view.video, isNull);
        expect(
          view.audio?.url,
          'https://media.example.test/sparks/019f5a00/master.m3u8',
        );
        expect(view.audio?.durationMs, 42000);
        expect(view.audio?.waveform, hasLength(36));
        // Le texte reste : le rendu empile ce qui existe.
        expect(view.body, 'Un mot du pasteur pour la semaine.');
      },
    );

    test('une annonce vidéo devient un StatusVideo, affiche résolue', () async {
      final view = await stored(videoAnnouncementPayload);

      expect(view.kind, StatusKind.video);
      expect(view.audio, isNull);
      expect(
        view.video?.url,
        'https://media.example.test/sparks/019f5a01/master.m3u8',
      );
      expect(
        view.video?.poster,
        'https://eenv.brainsial.com/uploads/announcements/convention-affiche.webp',
      );
      expect(view.video?.durationMs, 58000);
    });

    test('une annonce texte n\'a ni l\'un ni l\'autre', () async {
      final view = await stored(fullAnnouncementPayload);

      expect(view.audio, isNull);
      expect(view.video, isNull);
      expect(view.kind, StatusKind.text);
    });

    test('un genre sans URL s\'affiche comme un statut sans média', () async {
      final view = await stored({
        ...videoAnnouncementPayload,
        'mediaUrl': null,
      });

      expect(view.video, isNull);
      // L'annonce n'a pas disparu du mur pour autant.
      expect(view.title, 'Convention 2026');
    });
  });
}
