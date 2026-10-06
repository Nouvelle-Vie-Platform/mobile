/// **La lecture du média d'un message** (M4, #143) : les colonnes du magasin
/// deviennent un objet typé, et rien ne lève — une méta illisible donne un
/// média sans détail, jamais une exception qui ferait échouer tout le fil.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/models/message_media.dart';

void main() {
  group('MessageMedia.fromColumns', () {
    test('pas de forme, pas de média', () {
      expect(MessageMedia.fromColumns(kind: null), isNull);
    });

    test('un audio sans méta est un VOCAL ; `voice: false` un fichier', () {
      expect(
        MessageMedia.fromColumns(kind: 'audio')!.kind,
        MessageMediaKind.voice,
      );
      final file = MessageMedia.fromColumns(
        kind: 'audio',
        metaJson: '{"voice":false,"name":"Cantique.mp3"}',
      )!;
      expect(file.kind, MessageMediaKind.audio);
      expect(file.name, 'Cantique.mp3');
    });

    test('la forme d’onde est bornée à 0..100, les intrus sautés', () {
      final voice = MessageMedia.fromColumns(
        kind: 'audio',
        metaJson: '{"waveform":[0, 50.4, 140, "x", -3]}',
      )!;
      expect(voice.waveform, [0, 50, 100, 0]);
    });

    test('une position lit ses coordonnées et son libellé', () {
      final location = MessageMedia.fromColumns(
        kind: 'location',
        metaJson: '{"latitude":6.1319,"longitude":1.2228,"label":"Temple"}',
      )!;
      expect(location.kind, MessageMediaKind.location);
      expect(location.latitude, 6.1319);
      expect(location.longitude, 1.2228);
      expect(location.label, 'Temple');
      expect(location.kind.hasFile, isFalse);
    });

    test('un contact lit son nom et ses numéros, rien d’autre', () {
      final contact = MessageMedia.fromColumns(
        kind: 'contact',
        metaJson:
            '{"name":"Diacre Kossi","phones":[{"number":"+228 90 11 22 33",'
            '"label":"mobile"},{"nope":1}]}',
      )!;
      expect(contact.contactName, 'Diacre Kossi');
      expect(contact.name, isNull,
          reason: 'le nom d’un contact n’est pas un nom de fichier');
      expect(contact.phones, [
        const ContactPhone(number: '+228 90 11 22 33', label: 'mobile'),
      ]);
    });

    test('une image garde ses dimensions — la bulle réserve sa place', () {
      final image = MessageMedia.fromColumns(
        kind: 'image',
        key: 'group-media/g/x.jpg',
        metaJson: '{"width":1600,"height":1200}',
        size: 240000,
      )!;
      expect(image.aspectRatio, closeTo(4 / 3, 0.001));
      expect(image.key, 'group-media/g/x.jpg');
      expect(image.sizeBytes, 240000);
    });

    test('une forme inconnue se lit « inconnue », jamais une erreur', () {
      expect(
        MessageMedia.fromColumns(kind: 'sticker')!.kind,
        MessageMediaKind.unknown,
      );
    });

    test('une méta illisible donne un média sans détail', () {
      final document =
          MessageMedia.fromColumns(kind: 'document', metaJson: '{pas du json')!;
      expect(document.kind, MessageMediaKind.document);
      expect(document.name, isNull);
    });
  });

  group('groupMessageRowOf — le média du fil', () {
    test('les sept champs sont rangés, la méta ré-encodée en JSON', () {
      final row = groupMessageRowOf({
        'id': 'm-1',
        'groupId': 'g-1',
        'authorId': 'u-1',
        'isSystem': false,
        'body': null,
        'mediaKey': 'group-media/g-1/a.pdf',
        'mediaKind': 'document',
        'mediaDuration': null,
        'mediaMeta': {'name': 'Bulletin.pdf'},
        'mediaSize': 1234567,
        'mediaMime': 'application/pdf',
        'mediaThumbnailKey': null,
        'createdAt': '2026-10-06T10:00:00.000Z',
      });

      expect(row.mediaKind, const Value('document'));
      expect(row.mediaKey, const Value('group-media/g-1/a.pdf'));
      expect(row.mediaMeta, const Value('{"name":"Bulletin.pdf"}'));
      expect(row.mediaSize, const Value(1234567));
      expect(row.mediaMime, const Value('application/pdf'));
      expect(row.body, const Value<String?>(null));
    });

    test('un serveur en retard (sans champs média) ne rejette pas la ligne',
        () {
      final row = groupMessageRowOf({
        'id': 'm-2',
        'groupId': 'g-1',
        'authorId': 'u-1',
        'isSystem': false,
        'body': 'Amen',
      });
      expect(row.mediaKind, const Value<String?>(null));
      expect(row.mediaMeta, const Value<String?>(null));
    });

    test('une méta qui n’est pas un objet est ignorée, pas une erreur', () {
      final row = groupMessageRowOf({
        'id': 'm-3',
        'groupId': 'g-1',
        'isSystem': false,
        'mediaKind': 'location',
        'mediaMeta': [1, 2],
        'mediaDuration': 12.0,
      });
      expect(row.mediaMeta, const Value<String?>(null));
      expect(row.mediaDuration, const Value(12));
    });
  });

  group('formatage', () {
    test('formatByteSize, en unités décimales et à la française', () {
      expect(formatByteSize(2300000, 'fr'), '2,3 Mo');
      expect(formatByteSize(840000, 'fr'), '840 ko');
      expect(formatByteSize(2300000, 'en'), '2.3 MB');
    });

    test('formatMediaDuration', () {
      expect(formatMediaDuration(const Duration(seconds: 42)), '0:42');
      expect(formatMediaDuration(const Duration(minutes: 12, seconds: 5)),
          '12:05');
    });
  });
}
