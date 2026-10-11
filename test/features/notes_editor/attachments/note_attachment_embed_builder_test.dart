/// **Les quatre blocs d'une pièce jointe** (N4, mobile#192) — photo pleine
/// largeur, cartes vidéo / audio / fichier — et leurs états, sans base ni
/// réseau : la ligne en attente est un flux posé par le test.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/media/media_outbox.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_composer.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_dao.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_providers.dart';
import 'package:maison_du_miracle/features/notes_editor/attachments/note_attachment_embed_builder.dart';
import 'package:maison_du_miracle/features/notes_editor/rich_note_editor.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import '../../../data/local/local_database_fixtures.dart';
import 'note_media_doubles.dart';

/// Un composeur qui ne fait que noter « Réessayer ».
class _SpyComposer extends NoteMediaComposer {
  _SpyComposer(AppDatabase db)
      : super(
          dao: NoteMediaDao(db),
          transport: ScriptedNoteTransport(),
          preparer: CopyPreparer(),
          outbox: MediaOutbox(),
          resendNotes: () async {},
        );

  final List<String> retried = [];

  @override
  Future<bool> retry(String embedId) async {
    retried.add(embedId);
    return true;
  }
}

void main() {
  late AppDatabase db;
  late _SpyComposer composer;

  setUpAll(() => db = openTestDatabase());
  tearDownAll(() => db.close());
  setUp(() => composer = _SpyComposer(db));

  List<Override> overrides(PendingNoteMediaRow? row) => [
        pendingNoteMediaProvider.overrideWith((ref, id) => Stream.value(row)),
        noteMediaUrlsProvider.overrideWithValue(FakeNoteMediaUrls()),
        noteMediaComposerProvider.overrideWithValue(composer),
      ];

  Widget app(Widget child, PendingNoteMediaRow? row) => ProviderScope(
        overrides: overrides(row),
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: child),
        ),
      );

  Future<void> pumpBlock(
    WidgetTester tester,
    Map<String, dynamic> data, {
    PendingNoteMediaRow? row,
  }) async {
    await tester.pumpWidget(
      app(ListView(children: [NoteAttachmentBlock(data: data)]), row),
    );
    await tester.pump();
  }

  testWidgets('photo : pleine largeur, au ratio de ses dimensions',
      (tester) async {
    await pumpBlock(tester, {
      'kind': 'image',
      'key': 'note-media/o/p.jpg',
      'name': 'p.jpg',
      'mime': 'image/jpeg',
      'size': 1000,
      'width': 1600,
      'height': 800,
    });
    final ratio = tester.widget<AspectRatio>(find.descendant(
      of: find.byKey(NoteAttachmentBlock.imageKey),
      matching: find.byType(AspectRatio),
    ));
    expect(ratio.aspectRatio, 2.0);
    expect(find.byType(ClipRRect), findsWidgets);
    expect(find.byKey(NoteAttachmentBlock.retryKey), findsNothing);
  });

  testWidgets('vidéo : carte avec nom, durée et taille', (tester) async {
    await pumpBlock(tester, {
      'kind': 'video',
      'key': 'note-media/o/v.mp4',
      'name': 'clip.mp4',
      'mime': 'video/mp4',
      'size': 3400000,
      'duration': 42,
    });
    expect(find.byKey(NoteAttachmentBlock.cardKey), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.text('0:42 · 3,4 Mo'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('audio : carte avec durée et bouton de lecture', (tester) async {
    await pumpBlock(tester, {
      'kind': 'audio',
      'key': 'note-media/o/a.m4a',
      'name': 'Enregistrement audio',
      'mime': 'audio/mp4',
      'size': 48000,
      'duration': 12,
    });
    expect(find.text('Enregistrement audio'), findsOneWidget);
    expect(find.text('0:12 · 48 ko'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('fichier : carte avec icône de famille et taille',
      (tester) async {
    await pumpBlock(tester, {
      'kind': 'document',
      'key': 'note-media/o/b.pdf',
      'name': 'budget.pdf',
      'mime': 'application/pdf',
      'size': 840000,
    });
    expect(find.text('budget.pdf'), findsOneWidget);
    expect(find.text('840 ko'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('en envoi : l’état remplace la taille', (tester) async {
    await pumpBlock(
      tester,
      {
        'kind': 'document',
        'name': 'budget.pdf',
        'mime': 'application/pdf',
        'localId': 'e-1',
      },
      row: const PendingNoteMediaRow(
        noteId: 'n-1',
        embedId: 'e-1',
        kind: 'document',
        localPath: '/nulle/part.pdf',
        mime: 'application/pdf',
      ),
    );
    expect(find.text('Envoi…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('en échec définitif : la cause, et « Réessayer » relance',
      (tester) async {
    await pumpBlock(
      tester,
      {
        'kind': 'document',
        'name': 'gros.pdf',
        'mime': 'application/pdf',
        'localId': 'e-1',
      },
      row: const PendingNoteMediaRow(
        noteId: 'n-1',
        embedId: 'e-1',
        kind: 'document',
        localPath: '/nulle/part.pdf',
        mime: 'application/pdf',
        error: 'tooLarge',
      ),
    );
    expect(find.text('Fichier trop volumineux.'), findsOneWidget);
    await tester.tap(find.byKey(NoteAttachmentBlock.retryKey));
    await tester.pump();
    expect(composer.retried, ['e-1']);
  });

  testWidgets('photo en échec réseau : la phrase générique sur l’image',
      (tester) async {
    await pumpBlock(
      tester,
      {'kind': 'image', 'name': 'p.jpg', 'localId': 'e-2'},
      row: const PendingNoteMediaRow(
        noteId: 'n-1',
        embedId: 'e-2',
        kind: 'image',
        localPath: '/nulle/part.jpg',
        mime: 'image/jpeg',
        error: 'network',
      ),
    );
    expect(find.text("Échec de l'envoi"), findsOneWidget);
    expect(find.byKey(NoteAttachmentBlock.retryKey), findsOneWidget);
  });

  testWidgets('branché dans l’éditeur, il remplace la carte d’attente',
      (tester) async {
    await tester.pumpWidget(app(
      RichNoteEditor(
        initialContentJson: jsonEncode({
          'ops': [
            {
              'insert': {
                'nvAttachment': {
                  'kind': 'document',
                  'key': 'note-media/o/b.pdf',
                  'name': 'budget.pdf',
                  'mime': 'application/pdf',
                  'size': 840000,
                },
              },
            },
            {'insert': '\n'},
          ],
        }),
        onChanged: (_, __) {},
        embedBuilders: const [NoteAttachmentEmbedBuilder()],
      ),
      null,
    ));
    await tester.pump();
    expect(find.text('Pièce jointe : budget.pdf'), findsNothing);
    expect(find.byKey(NoteAttachmentBlock.cardKey), findsOneWidget);
    expect(find.text('budget.pdf'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(RichNoteEditor.debounce);
  });
}
