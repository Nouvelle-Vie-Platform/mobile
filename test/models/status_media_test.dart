// **Les cinq champs `media*`, lus en un média de statut — ou en aucun** (#130).
//
// `readStatusMedia` est le seul endroit où le contrat de
// `announcement_transformer.ts` se lit. Ces tests en fixent chaque règle : un
// genre inconnu ou sans URL n'est pas un média, au plus un des deux sort,
// l'affiche se replie sur l'image de fond, et les URL se résolvent.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';

void main() {
  group('readStatusMedia', () {
    test('un audio porte son URL, sa durée et sa forme d\'onde servies', () {
      final media = readStatusMedia(
        kind: 'audio',
        url: 'https://media.example.test/a/master.m3u8',
        durationMs: 42000,
        waveform: const [10, 50, 90],
      );

      expect(media.video, isNull);
      expect(media.audio?.url, 'https://media.example.test/a/master.m3u8');
      expect(media.audio?.durationMs, 42000);
      expect(media.audio?.waveform, [10, 50, 90]);
    });

    test('un audio sans forme d\'onde servie en porte une vide — le repli', () {
      // Vide et non `null` : c'est `StatusWaveform` qui décide du repli
      // déterministe dérivé de l'identifiant, à l'affichage.
      final media = readStatusMedia(
        kind: 'audio',
        url: 'https://media.example.test/a/master.m3u8',
      );

      expect(media.audio?.waveform, isEmpty);
    });

    test('une vidéo porte son affiche, résolue contre l\'hôte de l\'API', () {
      final media = readStatusMedia(
        kind: 'video',
        url: 'https://media.example.test/v/master.m3u8',
        posterUrl: '/uploads/announcements/affiche.webp',
        durationMs: 58000,
        // La forme d'onde ne concerne que l'audio : elle est ignorée ici.
        waveform: const [1, 2, 3],
      );

      expect(media.audio, isNull);
      expect(media.video?.url, 'https://media.example.test/v/master.m3u8');
      expect(
        media.video?.poster,
        'https://eenv.brainsial.com/uploads/announcements/affiche.webp',
      );
      expect(media.video?.durationMs, 58000);
    });

    test(
        'une vidéo sans affiche se replie sur l\'image de fond — une image, '
        'deux rôles', () {
      final media = readStatusMedia(
        kind: 'video',
        url: 'https://media.example.test/v/master.m3u8',
        backgroundImageUrl: 'https://cdn.example.test/fond.webp',
      );

      expect(media.video?.poster, 'https://cdn.example.test/fond.webp');
    });

    test('une vidéo sans aucune image reste une vidéo, sans affiche', () {
      final media = readStatusMedia(
        kind: 'video',
        url: 'https://media.example.test/v/master.m3u8',
      );

      expect(media.video, isNotNull);
      expect(media.video?.poster, isNull);
    });

    test('une URL relative de média est résolue', () {
      final media = readStatusMedia(
        kind: 'audio',
        url: '/media/sparks/a/master.m3u8',
      );

      expect(
        media.audio?.url,
        'https://eenv.brainsial.com/media/sparks/a/master.m3u8',
      );
    });

    test('un genre sans URL n\'est pas un média', () {
      // Le serveur ne laisse jamais transiter une telle annonce — mais un
      // lecteur à qui l'on donnerait une URL vide n'aurait rien à jouer.
      for (final url in [null, '', '   ']) {
        final media = readStatusMedia(kind: 'video', url: url);
        expect(media.audio, isNull, reason: 'url: $url');
        expect(media.video, isNull, reason: 'url: $url');
      }
    });

    test('un genre inconnu n\'est pas un média, et ne lève pas', () {
      // Un genre que ce client ne connaît pas encore : le statut s'affiche
      // avec ce qu'il a d'autre, plutôt que de disparaître du mur.
      final media = readStatusMedia(
        kind: 'hologramme',
        url: 'https://media.example.test/x/master.m3u8',
      );

      expect(media.audio, isNull);
      expect(media.video, isNull);
    });

    test('aucun genre, aucun média — le cas d\'un statut texte', () {
      final media = readStatusMedia(kind: null, url: null);

      expect(media.audio, isNull);
      expect(media.video, isNull);
    });

    test('une durée nulle ou négative vaut inconnue', () {
      // Elle passerait sinon devant le défaut par type et ferait finir le
      // statut à la seconde où il commence.
      final media = readStatusMedia(
        kind: 'audio',
        url: 'https://media.example.test/a/master.m3u8',
        durationMs: 0,
      );

      expect(media.audio?.durationMs, isNull);
    });
  });

  group('AnnouncementView.kind', () {
    test('se déduit du média lu', () {
      final audio = readStatusMedia(
        kind: 'audio',
        url: 'https://media.example.test/a/master.m3u8',
      );
      final video = readStatusMedia(
        kind: 'video',
        url: 'https://media.example.test/v/master.m3u8',
      );

      AnnouncementView view(({StatusAudio? audio, StatusVideo? video}) media) =>
          AnnouncementView.resolve(
            id: 'a',
            publishedAt: DateTime.utc(2026, 10, 5),
            body: 'Paix.',
            audio: media.audio,
            video: media.video,
          );

      expect(view(audio).kind, StatusKind.audio);
      expect(view(video).kind, StatusKind.video);
    });
  });
}
