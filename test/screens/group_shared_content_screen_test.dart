/// **« Médias, liens et docs »** d'un groupe : la ligne de la fiche, et
/// l'écran à trois onglets. Lu sur le double en mémoire du repository — qui
/// applique les mêmes exclusions que le magasin (voir
/// `group_dao_media_test.dart` pour le magasin lui-même).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/external_link_launcher.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/message_media.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/group_info_screen.dart';
import 'package:maison_du_miracle/screens/group_shared_content_screen.dart';
import 'package:maison_du_miracle/state/menu_providers.dart';
import 'package:maison_du_miracle/widgets/chat/media/group_shared_media.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

final _fr = AppLocalizationsFr();
const _groupId = 'g-1';

const _group = GroupDetailView(
  groupId: _groupId,
  title: 'Chorale Harmonie',
  isDirect: false,
  memberCount: 3,
  canWrite: true,
  myRole: 'member',
);

int _minute = 0;

GroupMessageView _msg(
  String id, {
  String? body,
  MessageMedia? media,
  bool deleted = false,
  MessageDelivery delivery = MessageDelivery.sent,
}) =>
    GroupMessageView(
      id: id,
      groupId: _groupId,
      body: body,
      origin: MessageOrigin.member,
      mine: false,
      delivery: delivery,
      authorId: 'u-2',
      createdAt: DateTime.utc(2026, 10, 1, 9, _minute++),
      deleted: deleted,
      media: media,
    );

/// Le fil, du plus ancien au plus récent.
List<GroupMessageView> _thread() => [
      _msg('img', media: const MessageMedia(kind: MessageMediaKind.image)),
      _msg(
        'vid',
        media: const MessageMedia(
          kind: MessageMediaKind.video,
          durationSeconds: 75,
        ),
      ),
      _msg(
        'doc',
        media: const MessageMedia(
          kind: MessageMediaKind.document,
          name: 'Programme.pdf',
          sizeBytes: 2048,
        ),
      ),
      _msg(
        'song',
        media: const MessageMedia(
          kind: MessageMediaKind.audio,
          name: 'Chant.mp3',
        ),
      ),
      _msg('voice', media: const MessageMedia(kind: MessageMediaKind.voice)),
      _msg('txt', body: 'Bonjour à tous'),
      _msg('lnk',
          body: 'Le direct : https://youtu.be/abc et https://eglise.fr.'),
      _msg('gone', body: 'https://retire.fr', deleted: true),
      _msg(
        'echo',
        body: 'https://pas-parti.fr',
        delivery: MessageDelivery.sending,
      ),
    ];

Future<RecordingExternalLinkLauncher> _pumpScreen(
  WidgetTester tester,
  List<GroupMessageView> thread,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final launcher = RecordingExternalLinkLauncher();
  await pumpScreen(
    tester,
    const GroupSharedContentScreen(groupId: _groupId),
    auth: SignedInAuthRepository(),
    echanges: InMemoryEchangesRepository(
      groups: {_groupId: _group},
      threads: {_groupId: thread},
    ),
    overrides: [externalLinkLauncherProvider.overrideWithValue(launcher)],
  );
  await tester.pumpAndSettle();
  return launcher;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('trois onglets ; Médias : images et vidéos seulement',
      (tester) async {
    await _pumpScreen(tester, _thread());

    expect(find.text('Chorale Harmonie'), findsOneWidget);
    expect(find.widgetWithText(Tab, _fr.sharedContentMedia), findsOneWidget);
    expect(find.widgetWithText(Tab, _fr.sharedContentLinks), findsOneWidget);
    expect(find.widgetWithText(Tab, _fr.sharedContentDocs), findsOneWidget);

    expect(find.byKey(GroupSharedContentScreen.mediaGridKey), findsOneWidget);
    expect(find.byKey(const Key('m4_image_tile')), findsOneWidget);
    expect(find.byKey(const Key('m4_video_tile')), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget, reason: 'la durée de la vidéo');
  });

  testWidgets(
      'Liens : une ligne par adresse, et le toucher ouvre le navigateur',
      (tester) async {
    final launcher = await _pumpScreen(tester, _thread());
    await _openTab(tester, _fr.sharedContentLinks);

    expect(find.text('youtu.be'), findsOneWidget);
    expect(find.text('eglise.fr'), findsOneWidget);
    expect(find.text('https://eglise.fr'), findsOneWidget);
    expect(find.textContaining('retire.fr'), findsNothing);
    expect(find.textContaining('pas-parti.fr'), findsNothing);

    await tester.tap(find.text('youtu.be'));
    await tester.pump();
    expect(launcher.opened, ['https://youtu.be/abc']);
  });

  testWidgets('Docs : documents et fichiers audio, jamais les vocaux',
      (tester) async {
    await _pumpScreen(tester, _thread());
    await _openTab(tester, _fr.sharedContentDocs);

    expect(find.text('Programme.pdf'), findsOneWidget);
    expect(find.text('Chant.mp3'), findsOneWidget);
    expect(find.byKey(const Key('m4_document_tile')), findsOneWidget);
    expect(find.byKey(const Key('m4_audio_play_song')), findsOneWidget);
    expect(find.byKey(const Key('m4_audio_play_voice')), findsNothing);
  });

  testWidgets('chaque onglet vide le dit, sans erreur', (tester) async {
    await _pumpScreen(tester, [_msg('txt', body: 'Bonjour')]);

    expect(find.text(_fr.sharedContentMediaEmpty), findsOneWidget);
    await _openTab(tester, _fr.sharedContentLinks);
    expect(find.text(_fr.sharedContentLinksEmpty), findsOneWidget);
    await _openTab(tester, _fr.sharedContentDocs);
    expect(find.text(_fr.sharedContentDocsEmpty), findsOneWidget);
  });

  group('la ligne de la fiche du groupe', () {
    Future<void> pumpInfo(
      WidgetTester tester,
      List<GroupMessageView> thread,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const GroupInfoScreen(groupId: _groupId),
          ),
          GoRoute(
            name: AppRoute.groupSharedContent,
            path: '/group-info/:id/media',
            builder: (_, state) => Text('écran ${state.pathParameters['id']}'),
          ),
        ],
      );
      await pumpRouter(
        tester,
        router,
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          groups: {_groupId: _group},
          threads: {_groupId: thread},
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('compte médias, liens et docs, et ouvre l’écran',
        (tester) async {
      await pumpInfo(tester, _thread());

      expect(find.text(_fr.sharedContentTitle), findsOneWidget);
      // img, vid, doc, song + deux liens — ni le vocal, ni le supprimé.
      expect(
        tester.widget<Text>(find.byKey(const Key('shared_content_count'))).data,
        '6',
      );
      // L'aperçu : l'image et la vidéo.
      expect(find.byKey(const Key('m4_image_tile')), findsOneWidget);
      expect(find.byKey(const Key('m4_video_tile')), findsOneWidget);

      await tester.tap(find.byKey(GroupSharedMedia.openKey));
      await tester.pumpAndSettle();
      expect(find.text('écran $_groupId'), findsOneWidget);
    });

    testWidgets('absente quand il n’y a rien', (tester) async {
      await pumpInfo(tester, [
        _msg('txt', body: 'Bonjour'),
        _msg('voice', media: const MessageMedia(kind: MessageMediaKind.voice)),
      ]);

      expect(find.byKey(GroupSharedMedia.openKey), findsNothing);
      expect(find.text(_fr.sharedContentTitle), findsNothing);
    });
  });
}
