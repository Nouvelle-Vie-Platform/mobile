/// **Les bulles de média** (M4, #143 — reprend #98) : une par forme, l'état
/// d'envoi (progression, échec et sa cause), et la bulle qui **empile** texte
/// et média sans jamais peindre de ligne vide.
///
/// Discipline du dépôt : `pump()` + `pump(1s)`, jamais `pumpAndSettle`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/media/chat_media_picker.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_urls.dart';
import 'package:maison_du_miracle/data/messaging/media/media_upload_progress.dart';
import 'package:maison_du_miracle/data/players/chat_audio_player.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/message_media.dart';
import 'package:maison_du_miracle/state/chat_media_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/chat/chat_bubble.dart';
import 'package:maison_du_miracle/widgets/chat/media/media_labels.dart';
import 'package:maison_du_miracle/widgets/chat/message_quote.dart';
import 'package:maison_du_miracle/widgets/status/status_waveform.dart';

final AppLocalizations _fr = lookupAppLocalizations(const Locale('fr'));

class _FakeUrls implements GroupMediaUrls {
  final List<String> resolved = [];

  /// Faux pour les images : un `Image.network` ne doit jamais partir sous
  /// `flutter test` — la bulle peint alors son gabarit.
  bool give = true;

  @override
  Future<String?> resolve({
    required String groupId,
    required String messageId,
    bool thumbnail = false,
  }) async {
    resolved.add(messageId);
    return give ? 'https://store.test/$messageId' : null;
  }

  @override
  Future<String?> download({
    required String groupId,
    required String messageId,
    required String fileName,
  }) async =>
      '/tmp/$fileName';
}

class _RecordingOpener implements MediaOpener {
  final List<String> calls = [];

  @override
  Future<bool> openMap({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    calls.add('map $latitude,$longitude $label');
    return true;
  }

  @override
  Future<bool> openFile(String path, {String? mime}) async {
    calls.add('file $path $mime');
    return true;
  }

  @override
  Future<bool> dial(String number) async {
    calls.add('dial $number');
    return true;
  }
}

GroupMessageView _message(
  String id, {
  MessageMedia? media,
  String? body,
  bool mine = false,
  MessageDelivery delivery = MessageDelivery.sent,
  MediaSendError? error,
  bool deleted = false,
}) =>
    GroupMessageView(
      id: id,
      groupId: 'g-1',
      body: body,
      origin: MessageOrigin.member,
      mine: mine,
      delivery: delivery,
      authorId: mine ? 'u-me' : 'u-2',
      authorName: mine ? null : 'Afi',
      createdAt: DateTime.utc(2026, 10, 6, 10),
      media: media,
      mediaError: error,
      deleted: deleted,
    );

void main() {
  late FakeChatAudioEngine engine;
  late _FakeUrls urls;
  late _RecordingOpener opener;
  late MediaUploadProgress progress;

  setUp(() {
    engine = FakeChatAudioEngine();
    urls = _FakeUrls();
    opener = _RecordingOpener();
    progress = MediaUploadProgress();
  });

  Future<void> pump(
      WidgetTester tester, List<GroupMessageView> messages) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupMediaUrlsProvider.overrideWithValue(urls),
          mediaOpenerProvider.overrideWithValue(opener),
          mediaUploadProgressProvider.overrideWithValue(progress),
          chatAudioControllerProvider.overrideWith((ref) {
            final controller = ChatAudioController(engine);
            ref.onDispose(controller.dispose);
            return controller;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final m in messages)
                    ChatBubble(key: Key(m.id), message: m),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('Le vocal', () {
    const voice = MessageMedia(
      kind: MessageMediaKind.voice,
      key: 'group-media/g-1/v.m4a',
      durationSeconds: 42,
      waveform: [10, 80, 40],
    );

    testWidgets('forme d’onde et durée, sans ligne de texte vide',
        (tester) async {
      await pump(tester, [_message('m-1', media: voice)]);

      expect(find.byKey(const Key('m4_voice_waveform_m-1')), findsOneWidget);
      expect(
        tester.widget<StatusWaveform>(find.byType(StatusWaveform)).bars,
        [10, 80, 40],
      );
      expect(find.text('0:42'), findsOneWidget);
      // Ni mention « non pris en charge », ni texte vide.
      expect(find.text(_fr.chatMediaUnsupported), findsNothing);
      expect(find.text(''), findsNothing);
    });

    testWidgets('lire un vocal, puis un second : le premier s’arrête',
        (tester) async {
      await pump(tester, [
        _message('m-1', media: voice),
        _message('m-2', media: voice),
      ]);

      await tester.tap(find.byKey(const Key('m4_audio_play_m-1')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(engine.calls, contains('load https://store.test/m-1'));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('m4_audio_play_m-2')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(engine.calls,
          containsAllInOrder(['stop', 'load https://store.test/m-2']));
      // Un seul bouton « pause » : celui du second.
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('m4_audio_play_m-2')),
          matching: find.byIcon(Icons.pause_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la vitesse se change pendant la lecture : 1× → 1,5×',
        (tester) async {
      await pump(tester, [_message('m-1', media: voice)]);
      await tester.tap(find.byKey(const Key('m4_audio_play_m-1')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1×'), findsOneWidget);
      await tester.tap(find.byKey(const Key('m4_audio_speed')));
      await tester.pump();
      expect(find.text('1,5×'), findsOneWidget);
      expect(engine.calls.last, 'speed 1.5');
    });
  });

  testWidgets('un fichier audio montre son nom', (tester) async {
    await pump(tester, [
      _message(
        'm-1',
        media: const MessageMedia(
          kind: MessageMediaKind.audio,
          key: 'k',
          name: 'Cantique 12.mp3',
          durationSeconds: 125,
        ),
      ),
    ]);
    expect(find.text('Cantique 12.mp3'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(find.byType(StatusWaveform), findsNothing);
  });

  group('L’image', () {
    const image = MessageMedia(
      kind: MessageMediaKind.image,
      key: 'group-media/g-1/p.jpg',
      width: 1600,
      height: 1200,
    );

    testWidgets('texte ET image : la bulle empile les deux', (tester) async {
      urls.give = false;
      await pump(tester, [
        _message('m-1', media: image, body: 'Le culte de dimanche'),
      ]);
      expect(find.byKey(const Key('m4_image_tile')), findsOneWidget);
      expect(find.text('Le culte de dimanche'), findsOneWidget);
      // L'URL de lecture a été demandée — jamais une clé collée dans l'image.
      expect(urls.resolved, ['m-1']);
    });

    testWidgets('une image sans légende ne peint pas de ligne de texte',
        (tester) async {
      urls.give = false;
      await pump(tester, [_message('m-1', media: image)]);
      expect(find.byKey(const Key('m4_image_tile')), findsOneWidget);
      expect(find.text(_fr.chatMediaUnsupported), findsNothing);
      expect(find.text(''), findsNothing);
    });
  });

  testWidgets('une vidéo montre sa durée', (tester) async {
    urls.give = false;
    await pump(tester, [
      _message(
        'm-1',
        media: const MessageMedia(
          kind: MessageMediaKind.video,
          key: 'k',
          thumbnailKey: 't',
          durationSeconds: 65,
        ),
      ),
    ]);
    expect(find.byKey(const Key('m4_video_tile')), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('un document : nom, taille, icône ; le toucher l’ouvre',
      (tester) async {
    await pump(tester, [
      _message(
        'm-1',
        media: const MessageMedia(
          kind: MessageMediaKind.document,
          key: 'k',
          name: 'Bulletin.pdf',
          sizeBytes: 2300000,
          mime: 'application/pdf',
        ),
      ),
    ]);
    expect(find.text('Bulletin.pdf'), findsOneWidget);
    expect(find.text('2,3 Mo · PDF'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);

    await tester.tap(find.byKey(const Key('m4_document_tile')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(opener.calls, ['file /tmp/Bulletin.pdf application/pdf']);
  });

  testWidgets('une position : libellé, coordonnées ; le toucher ouvre Cartes',
      (tester) async {
    await pump(tester, [
      _message(
        'm-1',
        media: const MessageMedia(
          kind: MessageMediaKind.location,
          latitude: 6.1319,
          longitude: 1.2228,
          label: 'Temple de Bè',
        ),
      ),
    ]);
    expect(find.text('Temple de Bè'), findsOneWidget);
    expect(find.text('6.13190, 1.22280'), findsOneWidget);

    await tester.tap(find.byKey(const Key('m4_location_tile')));
    await tester.pump();
    expect(opener.calls, ['map 6.1319,1.2228 Temple de Bè']);
    // Aucune URL de magasin pour une position.
    expect(urls.resolved, isEmpty);
  });

  testWidgets('un contact : nom, numéros, et « Appeler »', (tester) async {
    await pump(tester, [
      _message(
        'm-1',
        media: const MessageMedia(
          kind: MessageMediaKind.contact,
          contactName: 'Diacre Kossi',
          phones: [ContactPhone(number: '+228 90 11 22 33', label: 'mobile')],
        ),
      ),
    ]);
    expect(find.text('Diacre Kossi'), findsOneWidget);
    expect(find.text('+228 90 11 22 33 · mobile'), findsOneWidget);

    await tester.tap(find.byKey(const Key('m4_contact_call')));
    await tester.pump();
    expect(opener.calls, ['dial +228 90 11 22 33']);
  });

  testWidgets('une forme inconnue se dit, jamais une bulle vide',
      (tester) async {
    await pump(tester, [
      _message('m-1',
          media: const MessageMedia(kind: MessageMediaKind.unknown)),
    ]);
    expect(find.text(_fr.m4MediaUnsupportedKind), findsOneWidget);
  });

  testWidgets(
      'supprimé pour tous (M2) : aucun média peint, seulement la mention',
      (tester) async {
    await pump(tester, [
      _message(
        'm-1',
        deleted: true,
        media: const MessageMedia(
          kind: MessageMediaKind.location,
          latitude: 6.1319,
          longitude: 1.2228,
          label: 'Temple de Bè',
        ),
      ),
    ]);
    expect(find.text(_fr.chatMessageDeleted), findsOneWidget);
    expect(find.text('Temple de Bè'), findsNothing);
    expect(find.byKey(const Key('m4_location_tile')), findsNothing);
  });

  testWidgets('la citation d’un média M4 sans légende dit sa forme',
      (tester) async {
    final said = <String, String>{};
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            for (final kind in ['video', 'document', 'location', 'contact']) {
              said[kind] = MessageQuote.quoteText(
                context,
                MessageQuoteView(messageId: 'm-0', mediaKind: kind),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
    expect(said, {
      'video': _fr.m4QuoteVideo,
      'document': _fr.m4QuoteDocument,
      'location': _fr.m4QuoteLocation,
      'contact': _fr.m4QuoteContact,
    });
  });

  group('L’état d’envoi', () {
    const echo = MessageMedia(
      kind: MessageMediaKind.document,
      name: 'Bulletin.pdf',
      localPath: '/outbox/c-1-src.pdf',
    );

    testWidgets('en cours : l’anneau de la montée suit la progression',
        (tester) async {
      await pump(tester, [
        _message('c-1',
            media: echo, mine: true, delivery: MessageDelivery.sending),
      ]);
      expect(find.byKey(const Key('m4_upload_progress')), findsOneWidget);

      progress.report('c-1', 0.4);
      await tester.pump();
      final ring = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('m4_upload_progress')),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(ring.value, 0.4);
    });

    testWidgets('en échec : la cause se dit, et le geste « réessayer » reste',
        (tester) async {
      await pump(tester, [
        _message(
          'c-1',
          media: echo,
          mine: true,
          delivery: MessageDelivery.failed,
          error: MediaSendError.tooLarge,
        ),
      ]);
      expect(find.text(_fr.m4MediaErrorTooLarge), findsOneWidget);
      expect(find.text(_fr.chatMessageFailed), findsOneWidget);
      expect(find.byKey(const Key('m4_upload_progress')), findsNothing);
    });
  });

  test('les aperçus de la liste, une mention par forme', () {
    expect(mediaPreviewLabel(_fr, MessageMediaKind.voice), '🎤 Message vocal');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.audio), '🎵 Audio');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.image), '📷 Photo');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.video), '🎥 Vidéo');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.document), '📄 Document');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.location), '📍 Position');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.contact), '👤 Contact');
    expect(mediaPreviewLabel(_fr, MessageMediaKind.unknown), isNull);
  });
}
