/// **L'onglet Notes du module Bible** (#190, #199), à travers le vrai
/// routeur : la porte de session d'un invité, la redirection de `/notes`, la
/// liste d'un membre, l'éditeur et la feuille Catégorie.
///
/// Tout ce qui touche le magasin Drift vit dans **un seul** `runAsync` par
/// test (un flux ou un `Future` Drift attendu sous l'horloge factice fige le
/// montage).
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/media/media_outbox.dart';
import 'package:maison_du_miracle/data/messaging/media/voice_recorder.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_composer.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_picker.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_providers.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/repositories/notes_repository.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_browser.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_shell.dart';
import 'package:maison_du_miracle/features/notes_editor/attachments/note_attachment_button.dart';
import 'package:maison_du_miracle/features/notes_editor/attachments/note_attachment_embed_builder.dart';
import 'package:maison_du_miracle/features/notes_editor/format_pill.dart';
import 'package:maison_du_miracle/features/notes_editor/links/add_link_sheet.dart';
import 'package:maison_du_miracle/features/notes_editor/links/linked_teaching_chip.dart';
import 'package:maison_du_miracle/features/notes_editor/rich_note_editor.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/note_view.dart';
import 'package:maison_du_miracle/screens/notes/note_category_sheet.dart';
import 'package:maison_du_miracle/screens/notes/note_editor_screen.dart';
import 'package:maison_du_miracle/screens/notes/notes_tab.dart';
import 'package:maison_du_miracle/state/chat_media_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/notes_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/note_palette.dart';

import '../features/notes_editor/attachments/note_media_doubles.dart';
import '../helpers/fake_api.dart';
import '../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

const _pinnedId = '019f8000-0000-7000-8000-00000000000b';
const _plainId = '019f8000-0000-7000-8000-00000000000a';
const _categoryId = '019f8000-0000-7000-8000-0000000000c1';
const _newId = '019f8000-0000-7000-8000-00000000000e';
const _teachingId = '019f8000-0000-7000-8000-0000000000aa';

/// Deux notes et une catégorie, posées **par la synchronisation** — jamais par
/// un insert applicatif dans une collection.
Future<void> _seed(AppDatabase db) async {
  await db.syncDao.applyPage(
    db.syncDao.noteCategoriesCollection,
    upserts: [
      NoteCategoriesCompanion.insert(
        id: _categoryId,
        name: 'Important',
        color: 'pink',
      ),
    ],
    cursor: 'c-cat',
  );
  await db.syncDao.applyPage(
    db.syncDao.spiritualNotesCollection,
    upserts: [
      SpiritualNotesCompanion.insert(
        id: _plainId,
        title: const Value('Courses'),
        body: const Value('Lait d\'avoine, bananes'),
        updatedAt: Value(DateTime.utc(2026, 10, 3)),
      ),
      SpiritualNotesCompanion.insert(
        id: _pinnedId,
        title: const Value('Sociologie'),
        body: const Value('Lire les pages 102-120'),
        categoryId: const Value(_categoryId),
        pinned: const Value(true),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
      ),
    ],
    cursor: 'c-notes',
  );
}

/// **L'antenne, doublée** : `guestContainer` ne la double pas, et l'accueil la
/// demande au premier frame par le vrai `Dio`. Sous `runAsync` l'erreur du
/// canal natif (`flutter_secure_storage`, lu par l'en-tête de version) arrive
/// **après** la fin du test et le fait rougir.
final Override _radioOff = radioRepositoryProvider.overrideWithValue(
  const FixedRadioRepository(RadioAntenna.unknown),
);

/// **Les doublures de tout le fichier** : l'antenne, et le délai du brouillon
/// de note poussé à une heure — sous `runAsync` sa minuterie de 2 s est
/// réelle, et une machine chargée la laissait partir au milieu d'un parcours
/// (« supprimer » voyait alors un envoi de trop). Les envois testés ici sont
/// ceux de la sortie, immédiats.
final List<Override> _quiet = [
  _radioOff,
  noteDraftDebounceProvider.overrideWithValue(const Duration(hours: 1)),
];

/// **Aucune requête ne doit partir** d'ici : l'adaptateur note tout ce qui
/// atteint le fil, et lève. Posé sur le singleton, il vaut pour tout le
/// fichier.
late FakeAdapter _wire;

/// `settle`, avec des tours de **vraie** boucle d'événements entre les images :
/// sous `runAsync`, Drift ouvre la base et sert ses flux sur la vraie boucle,
/// que les `pump` à horloge factice ne font pas avancer.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Un appui long, sous `runAsync` : le `Timer` de 500 ms du
/// `LongPressGestureRecognizer` est **réel** (le geste part de la zone du
/// test), et le `longPress` du testeur ne fait avancer que l'horloge factice
/// avant de relâcher. On tient donc le doigt le temps réel qu'il faut.
Future<void> _longPress(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await Future<void>.delayed(kLongPressTimeout + kPressTimeout);
  await tester.pump();
  await gesture.up();
  await _settle(tester);
}

/// L'éditeur riche de l'écran, par sa clé.
RichNoteEditorState _editor(WidgetTester tester) =>
    tester.state(find.byKey(NoteEditorScreen.bodyFieldKey));

/// Tape [text] au curseur de l'éditeur riche, puis laisse passer son
/// débordement. flutter_quill n'est pas un `EditableText` : `enterText` ne le
/// trouve pas, la frappe passe par le contrôleur (comme
/// `rich_note_editor_test`). Sous `runAsync`, le minuteur de 300 ms de
/// l'éditeur est **réel** : on l'attend en vrai temps.
Future<void> _type(WidgetTester tester, String text) async {
  final c = _editor(tester).controller;
  final at = c.selection.baseOffset;
  c.replaceText(at, 0, text, TextSelection.collapsed(offset: at + text.length));
  await Future<void>.delayed(RichNoteEditor.debounce * 1.2);
  await tester.pump();
}

/// **La feuille de partage et le dossier temporaire, doublés au canal** :
/// `share_plus` écrit le PDF dans le dossier que `path_provider` lui donne,
/// puis appelle `share` avec le chemin. Sous `flutter test` ni l'un ni l'autre
/// n'a de greffon ; on répond à leur place. Rend les appels reçus par le
/// partage ; [shareFails] fait lever la feuille, comme un système qui refuse.
List<MethodCall> _mockShareSheet(WidgetTester tester,
    {bool shareFails = false}) {
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  final tmp = Directory.systemTemp.createTempSync('nv-notes-share');
  addTearDown(() => tmp.deleteSync(recursive: true));
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => tmp.path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/share'),
    (call) async {
      calls.add(call);
      if (shareFails) throw PlatformException(code: 'refused');
      return 'dev.fluttercommunity.plus/share/success';
    },
  );
  return calls;
}

/// Attend, en vrai temps, que [done] soit vrai — le PDF se rend dans un autre
/// isolate, que l'horloge factice ne fait pas avancer.
Future<void> _untilReal(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'le partage n\'a pas abouti à temps');
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    _wire = FakeAdapter(
      (options) => throw StateError(
        'requête HTTP interdite : ${options.method} ${options.path}',
      ),
    );
    ApiClient.instance.dio.httpClientAdapter = _wire;
  });

  // La coquille du module (cinq onglets, mémoire, retour) se teste dans
  // `test/features/bible/bible_module_test.dart` (#199).
  group('La route des notes', () {
    testWidgets('`/notes` redirige sur l\'onglet Notes du module Bible',
        (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [..._quiet]));
        router.push('/notes');
        await _settle(tester);

        expect(router.state.matchedLocation, '/bible');
        expect(router.state.uri.queryParameters['tab'], 'notes');
        expect(find.byType(NotesTab), findsOneWidget);
      });
    });
  });

  group('L\'onglet Notes, pour un invité', () {
    testWidgets('la porte de session, et aucune liste', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [..._quiet]));
        router.push('/bible?tab=notes');
        await _settle(tester);

        expect(find.text(_fr.notesGuestTitle), findsOneWidget);
        expect(find.byKey(NotesTab.signInButtonKey), findsOneWidget);
        expect(find.byKey(NotesTab.addButtonKey), findsNothing);

        // Aucune lecture privée, aucun `GET /notes` : rien sur le fil.
        expect(_wire.requests, isEmpty);

        await tester.tap(find.byKey(NotesTab.signInButtonKey));
        await _settle(tester);
        expect(router.state.matchedLocation, '/auth');
      });
    });
  });

  group('L\'onglet Notes, pour un membre', () {
    testWidgets('la liste : épinglée en tête, puces, filtre et recherche',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [..._quiet],
        );
        await _seed(container.read(appDatabaseProvider));
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/bible?tab=notes');
        await _settle(tester);

        expect(find.byKey(NotesTab.signInButtonKey), findsNothing);
        expect(find.byKey(NotesTab.addButtonKey), findsOneWidget);
        expect(find.byKey(NotesTab.allChipKey), findsOneWidget);
        expect(find.byKey(NotesTab.chipKey(_categoryId)), findsOneWidget);
        expect(find.text('Important'), findsOneWidget);

        // L'épinglée d'abord, bien qu'elle soit la plus ancienne.
        final pinned =
            tester.getTopLeft(find.byKey(NotesTab.cardKey(_pinnedId)));
        final plain = tester.getTopLeft(find.byKey(NotesTab.cardKey(_plainId)));
        expect(pinned.dx, lessThan(plain.dx));
        expect(find.byIcon(Icons.push_pin), findsOneWidget);

        // Le filtre de catégorie.
        await tester.tap(find.byKey(NotesTab.chipKey(_categoryId)));
        await _settle(tester);
        expect(find.byKey(NotesTab.cardKey(_pinnedId)), findsOneWidget);
        expect(find.byKey(NotesTab.cardKey(_plainId)), findsNothing);

        await tester.tap(find.byKey(NotesTab.allChipKey));
        await _settle(tester);

        // La recherche, sur le corps, sans la casse.
        await tester.enterText(find.byType(TextField), 'BANANES');
        await _settle(tester);
        expect(find.byKey(NotesTab.cardKey(_plainId)), findsOneWidget);
        expect(find.byKey(NotesTab.cardKey(_pinnedId)), findsNothing);

        await tester.enterText(find.byType(TextField), 'rien');
        await _settle(tester);
        expect(find.text(_fr.notesEmptyTitle), findsOneWidget);
      });
    });

    testWidgets(
        'le + ouvre un brouillon, la frappe l\'écrit, la sortie l\'envoie',
        (tester) async {
      await tester.runAsync(() async {
        final repo = _RecordingNotesRepository();
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [..._quiet, notesRepositoryProvider.overrideWithValue(repo)],
        );
        final db = container.read(appDatabaseProvider);
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/bible?tab=notes');
        await _settle(tester);

        await tester.tap(find.byKey(NotesTab.addButtonKey));
        await _settle(tester);
        expect(router.state.matchedLocation, startsWith('/notes/'));
        expect(find.byType(NoteEditorScreen), findsOneWidget);
        final id = router.state.pathParameters['id']!;

        await tester.enterText(
          find.byKey(NoteEditorScreen.titleFieldKey),
          'Objectifs',
        );
        await _type(tester, 'Envoyer la proposition');
        await _settle(tester);

        // Le brouillon porte le Delta **et** son texte aplati.
        final row = (await db.notesDao.localNote(id))!;
        expect(row.title, 'Objectifs');
        expect(row.body, 'Envoyer la proposition');
        expect(row.content, '{"ops":[{"insert":"Envoyer la proposition\\n"}]}');
        expect(row.dirty, isTrue);

        // La pilule de format paraît avec le focus du corps, et la coche
        // ferme le clavier : plus de focus, plus de pilule.
        _editor(tester).focusNode.requestFocus();
        await _settle(tester);
        expect(find.byType(FormatPill), findsOneWidget);
        expect(find.byKey(NoteEditorScreen.doneButtonKey), findsOneWidget);
        await tester.tap(find.byKey(NoteEditorScreen.doneButtonKey));
        await _settle(tester);
        expect(find.byKey(NoteEditorScreen.doneButtonKey), findsNothing);
        expect(find.byType(FormatPill), findsNothing);

        // L'épingle.
        await tester.tap(find.byKey(NoteEditorScreen.pinButtonKey));
        await _settle(tester);
        expect((await db.notesDao.localNote(id))!.pinned, isTrue);

        // La sortie envoie, sans attendre les 2 s : `content` est le Delta,
        // `body` son texte aplati.
        router.pop();
        await _settle(tester);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(repo.upserts.map((u) => u.id), contains(id));
        expect(repo.upserts.last.pinned, isTrue);
        expect(repo.upserts.last.body, 'Envoyer la proposition');
        expect(
          repo.upserts.last.content,
          '{"ops":[{"insert":"Envoyer la proposition\\n"}]}',
        );
        // La carte vient du brouillon, tant que le delta n'a rien ramené.
        expect(find.byKey(NotesTab.cardKey(id)), findsOneWidget);
        expect(find.text('Objectifs'), findsOneWidget);
      });
    });

    testWidgets('un brouillon laissé vide s\'efface sans partir',
        (tester) async {
      await tester.runAsync(() async {
        final repo = _RecordingNotesRepository();
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [..._quiet, notesRepositoryProvider.overrideWithValue(repo)],
        );
        final db = container.read(appDatabaseProvider);
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/bible?tab=notes');
        await _settle(tester);
        await tester.tap(find.byKey(NotesTab.addButtonKey));
        await _settle(tester);

        await tester.enterText(find.byKey(NoteEditorScreen.titleFieldKey), 'x');
        await tester.enterText(find.byKey(NoteEditorScreen.titleFieldKey), '');
        await _settle(tester);
        router.pop();
        await _settle(tester);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repo.upserts, isEmpty);
        expect(await db.select(db.localNotes).get(), isEmpty);
        expect(find.text(_fr.notesEmptyTitle), findsOneWidget);
      });
    });

    testWidgets('la feuille Catégorie : choisir, créer, valider',
        (tester) async {
      await tester.runAsync(() async {
        final repo = _RecordingNotesRepository();
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [..._quiet, notesRepositoryProvider.overrideWithValue(repo)],
        );
        final db = container.read(appDatabaseProvider);
        await _seed(db);
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_plainId');
        await _settle(tester);
        expect(find.text('Courses'), findsOneWidget);

        await tester.tap(find.byKey(NoteEditorScreen.menuButtonKey));
        await _settle(tester);
        await tester.tap(find.byKey(NoteEditorScreen.menuCategoryKey));
        await _settle(tester);

        expect(find.text(_fr.notesCategoryTitle), findsOneWidget);
        expect(find.byKey(NoteCategorySheetKeys.option(_categoryId)),
            findsOneWidget);

        // Créer : nom + couleur, la nouvelle est cochée tout de suite.
        await tester.tap(find.byKey(NoteCategorySheetKeys.addRow));
        await _settle(tester);
        await tester.enterText(
          find.byKey(NoteCategorySheetKeys.nameField),
          'Prières',
        );
        await _settle(tester);
        await tester
            .tap(find.byKey(NoteCategorySheetKeys.color(NoteColor.green)));
        await tester.tap(find.byKey(NoteCategorySheetKeys.createButton));
        await _settle(tester);
        expect(repo.categories.single.name, 'Prières');
        expect(repo.categories.single.color, NoteColor.green);
        expect(find.text('Prières'), findsOneWidget);

        await tester.tap(find.byKey(NoteCategorySheetKeys.validateButton));
        await _settle(tester);

        final row = (await db.notesDao.localNote(_plainId))!;
        expect(row.categoryId, repo.categories.single.id);

        // On referme l'éditeur : sa minuterie d'envoi ne doit pas survivre au
        // test.
        router.pop();
        await _settle(tester);
        expect(find.byType(NoteEditorScreen), findsNothing);
      });
    });

    testWidgets('partager : un PDF part à la feuille système, sous le pastel',
        (tester) async {
      await tester.runAsync(() async {
        final calls = _mockShareSheet(tester);
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [
            ..._quiet,
            notesRepositoryProvider
                .overrideWithValue(_RecordingNotesRepository()),
          ],
        );
        await _seed(container.read(appDatabaseProvider));
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_pinnedId');
        await _settle(tester);

        // La note porte la catégorie « Important », rose : l'écran aussi.
        final scaffold = tester.widget<Scaffold>(find.descendant(
          of: find.byType(NoteEditorScreen),
          matching: find.byType(Scaffold),
        ));
        final context = tester.element(find.byType(NoteEditorScreen));
        expect(
          scaffold.backgroundColor,
          NotePalette.of(context, NoteColor.pink),
        );

        await tester.tap(find.byKey(NoteEditorScreen.menuButtonKey));
        await _settle(tester);
        await tester.tap(find.byKey(NoteEditorScreen.menuShareKey));
        await tester.pump();
        // Le rendu est en cours : l'indicateur remplace le menu.
        expect(find.byKey(NoteEditorScreen.shareProgressKey), findsOneWidget);

        await _untilReal(tester, () => calls.isNotEmpty);
        final args = calls.single.arguments as Map;
        expect(calls.single.method, 'share');
        expect(args['subject'], 'Sociologie');
        expect(args['mimeTypes'], ['application/pdf']);
        final path = (args['paths'] as List).single as String;
        expect(path, endsWith('/sociologie.pdf'));
        final bytes = File(path).readAsBytesSync();
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');

        await _untilReal(
          tester,
          () =>
              find.byKey(NoteEditorScreen.shareProgressKey).evaluate().isEmpty,
        );
        expect(find.byKey(NoteEditorScreen.menuButtonKey), findsOneWidget);
        router.pop();
        await _settle(tester);
      });
    });

    testWidgets('partager : la feuille refuse, l\'écran le dit sans rougir',
        (tester) async {
      await tester.runAsync(() async {
        final calls = _mockShareSheet(tester, shareFails: true);
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [
            ..._quiet,
            notesRepositoryProvider
                .overrideWithValue(_RecordingNotesRepository()),
          ],
        );
        await _seed(container.read(appDatabaseProvider));
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_plainId');
        await _settle(tester);

        await tester.tap(find.byKey(NoteEditorScreen.menuButtonKey));
        await _settle(tester);
        await tester.tap(find.byKey(NoteEditorScreen.menuShareKey));
        await _untilReal(tester, () => calls.isNotEmpty);
        await _untilReal(
          tester,
          () => find.text(_fr.notesShareFailed).evaluate().isNotEmpty,
        );
        expect(find.byKey(NoteEditorScreen.menuButtonKey), findsOneWidget);
        router.pop();
        await _settle(tester);
      });
    });

    testWidgets('supprimer : confirmation, DELETE, retour à la liste',
        (tester) async {
      await tester.runAsync(() async {
        final repo = _RecordingNotesRepository();
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [..._quiet, notesRepositoryProvider.overrideWithValue(repo)],
        );
        final db = container.read(appDatabaseProvider);
        await _seed(db);
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/bible?tab=notes');
        await _settle(tester);
        await tester.tap(find.byKey(NotesTab.cardKey(_plainId)));
        await _settle(tester);
        await tester.enterText(find.byKey(NoteEditorScreen.titleFieldKey), 'C');
        await _settle(tester);
        expect(await db.notesDao.localNote(_plainId), isNotNull);

        await tester.tap(find.byKey(NoteEditorScreen.menuButtonKey));
        await _settle(tester);
        await tester.tap(find.byKey(NoteEditorScreen.menuDeleteKey));
        await _settle(tester);
        expect(find.text(_fr.notesDeleteConfirmTitle), findsOneWidget);
        await tester.tap(find.text(_fr.notesDelete).last);
        await _settle(tester);

        expect(repo.deleted, [_plainId]);
        expect(await db.notesDao.localNote(_plainId), isNull);
        expect(find.byType(NoteEditorScreen), findsNothing);
        expect(find.byType(NotesTab), findsOneWidget);
        // Rien n'est reparti pour la note supprimée.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(repo.upserts.where((u) => u.id == _plainId), isEmpty);
      });
    });

    testWidgets('appui long sur une puce : renommer, recolorer, supprimer',
        (tester) async {
      await tester.runAsync(() async {
        final repo = _RecordingNotesRepository();
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [..._quiet, notesRepositoryProvider.overrideWithValue(repo)],
        );
        await _seed(container.read(appDatabaseProvider));
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/bible?tab=notes');
        await _settle(tester);

        await _longPress(tester, find.byKey(NotesTab.chipKey(_categoryId)));
        expect(find.text(_fr.notesCategoryEditTitle), findsOneWidget);

        await tester.enterText(
          find.byKey(NoteCategorySheetKeys.nameField),
          'Essentiel',
        );
        await _settle(tester);
        await tester
            .tap(find.byKey(NoteCategorySheetKeys.color(NoteColor.purple)));
        await tester.tap(find.byKey(NoteCategorySheetKeys.validateButton));
        await _settle(tester);
        expect(repo.categories.single.id, _categoryId);
        expect(repo.categories.single.name, 'Essentiel');
        expect(repo.categories.single.color, NoteColor.purple);

        await _longPress(tester, find.byKey(NotesTab.chipKey(_categoryId)));
        await tester.tap(find.byKey(NoteCategorySheetKeys.deleteButton));
        await _settle(tester);
        await tester.tap(find.text(_fr.notesDelete).last);
        await _settle(tester);
        expect(repo.deletedCategories, [_categoryId]);
      });
    });
  });

  group('L\'éditeur : pièces jointes et liens (#192, #193)', () {
    testWidgets(
        'le trombone ouvre son menu ; la photo paraît, puis part avec sa clé',
        (tester) async {
      await tester.runAsync(() async {
        final repo = _RecordingNotesRepository();
        final transport = ScriptedNoteTransport();
        final outboxRoot = Directory.systemTemp.createTempSync('nv-note-out');
        final sources = Directory.systemTemp.createTempSync('nv-note-src');
        addTearDown(() {
          outboxRoot.deleteSync(recursive: true);
          sources.deleteSync(recursive: true);
        });
        final photo = File('${sources.path}/IMG_7.jpg')
          ..writeAsBytesSync(List<int>.filled(500, 7));
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [
            ..._quiet,
            notesRepositoryProvider.overrideWithValue(repo),
            noteMediaPickerProvider.overrideWithValue(_OnePhotoPicker(photo)),
            noteMediaTransportProvider.overrideWithValue(transport),
            mediaPreparerProvider.overrideWithValue(CopyPreparer()),
            noteMediaOutboxProvider.overrideWithValue(
              MediaOutbox(root: () async => outboxRoot),
            ),
            noteMediaUrlsProvider.overrideWithValue(FakeNoteMediaUrls()),
            // Lu au toucher du trombone : le vrai ouvre un canal de greffon.
            voiceRecorderProvider.overrideWith((ref) => FakeVoiceRecorder()),
          ],
        );
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_newId');
        await _settle(tester);

        _editor(tester).focusNode.requestFocus();
        await _settle(tester);
        await tester.tap(find.byKey(NoteAttachmentButton.buttonKey));
        await _settle(tester);
        expect(find.byKey(NoteAttachmentButton.takeKey), findsOneWidget);
        expect(find.byKey(NoteAttachmentButton.chooseKey), findsOneWidget);
        expect(find.byKey(NoteAttachmentButton.recordKey), findsOneWidget);
        expect(find.byKey(NoteAttachmentButton.fileKey), findsOneWidget);

        await tester.tap(find.byKey(NoteAttachmentButton.chooseKey));
        await _settle(tester);
        // Dans le fil, à la place du curseur — et montée par le faux PUT.
        expect(find.byKey(NoteAttachmentBlock.imageKey), findsOneWidget);
        expect(transport.uploads, hasLength(1));
        await _settle(tester);

        // La sortie envoie : `POST /notes` porte l'embed **avec** sa clé, sans
        // rien de local.
        router.pop();
        await _settle(tester);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final sent = repo.upserts.where((u) => u.id == _newId).last;
        final payload = noteUpsertPayload(sent);
        final ops = (payload['content']! as Map)['ops'] as List;
        final embeds = [
          for (final op in ops)
            if ((op as Map)['insert'] case {'nvAttachment': final Map data})
              data,
        ];
        expect(embeds, hasLength(1));
        expect(embeds.single['key'], transport.uploads.single);
        expect(embeds.single.containsKey('localId'), isFalse);
        expect(jsonEncode(payload), isNot(contains('localId')));
      });
    });

    testWidgets('le bouton lien : quatre choix, la Bible active',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [
            ..._quiet,
            notesRepositoryProvider
                .overrideWithValue(_RecordingNotesRepository()),
          ],
        );
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_newId');
        await _settle(tester);

        _editor(tester).focusNode.requestFocus();
        await _settle(tester);
        await tester.tap(find.byKey(NoteLinkButton.buttonKey));
        await _settle(tester);
        for (final key in [
          AddLinkSheet.noteOptionKey,
          AddLinkSheet.teachingOptionKey,
          AddLinkSheet.webOptionKey,
          AddLinkSheet.bibleOptionKey,
        ]) {
          expect(find.byKey(key), findsOneWidget);
        }
        expect(
          tester
              .widget<ListTile>(find.byKey(AddLinkSheet.bibleOptionKey))
              .enabled,
          isTrue,
        );
        router.pop();
        await _settle(tester);
        router.pop();
        await _settle(tester);
      });
    });

    testWidgets(
        'la Bible : mode sélection, Jean 3:16-18, et le lien revient dans la '
        'note (#199)', (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [
            ..._quiet,
            notesRepositoryProvider
                .overrideWithValue(_RecordingNotesRepository()),
          ],
        );
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_newId');
        await _settle(tester);

        _editor(tester).focusNode.requestFocus();
        await _settle(tester);
        await tester.tap(find.byKey(NoteLinkButton.buttonKey));
        await _settle(tester);
        await tester.tap(find.byKey(AddLinkSheet.bibleOptionKey));
        await _settle(tester);

        // Le module, en mode sélection : l'onglet Bible seul, sans barre.
        expect(router.state.matchedLocation, '/bible/select');
        expect(find.byType(BibleShell), findsOneWidget);
        expect(find.byKey(BibleShell.navKey), findsNothing);
        expect(find.byKey(BibleShell.insertKey), findsNothing);

        await tester.tap(find.text(_fr.bibleNewTestament));
        await _settle(tester);
        await tester.tap(find.byKey(BibleBrowser.bookKey('John')));
        await _settle(tester);
        await tester.tap(find.byKey(BibleBrowser.chapterKey(3)));
        await _settle(tester);
        // Le chapitre seul s'insère déjà.
        expect(find.text(_fr.bibleInsertReference('Jean 3')), findsOneWidget);
        for (final v in [16, 17, 18]) {
          await tester.ensureVisible(find.byKey(BibleBrowser.verseKey(v)));
          await tester.tap(find.byKey(BibleBrowser.verseKey(v)));
          await _settle(tester);
        }
        expect(
          find.text(_fr.bibleInsertReference('Jean 3:16-18')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(BibleShell.insertKey));
        await _settle(tester);

        // De retour dans l'éditeur, la feuille refermée, le lien posé.
        expect(router.state.matchedLocation, '/notes/$_newId');
        expect(find.byType(AddLinkSheet), findsNothing);
        final controller = _editor(tester).controller;
        expect(controller.document.toPlainText(), contains('Jean 3:16-18'));
        final ops = controller.document.toDelta().toJson();
        expect(
          ops.any((op) =>
              op['insert'] == 'Jean 3:16-18' &&
              (op['attributes'] as Map?)?['link'] == 'nv://bible/John/3/16-18'),
          isTrue,
        );
        router.pop();
        await _settle(tester);
      });
    });

    testWidgets('la puce de l\'enseignement lié, sous le titre',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: [
            ..._quiet,
            notesRepositoryProvider
                .overrideWithValue(_RecordingNotesRepository()),
            teachingByIdProvider.overrideWith(
              (ref, id) => Stream.value(
                id == _teachingId
                    ? const TeachingView(
                        id: _teachingId,
                        title: 'La foi qui déplace',
                        color: 0xFF336699,
                      )
                    : null,
              ),
            ),
          ],
        );
        final db = container.read(appDatabaseProvider);
        await db.syncDao.applyPage(
          db.syncDao.spiritualNotesCollection,
          upserts: [
            SpiritualNotesCompanion.insert(
              id: _newId,
              title: const Value('Prédication'),
              body: const Value('Notes'),
              teachingId: const Value(_teachingId),
              updatedAt: Value(DateTime.utc(2026, 10, 3)),
            ),
          ],
          cursor: 'c-linked',
        );
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);
        router.push('/notes/$_newId');
        await _settle(tester);

        expect(find.byKey(LinkedTeachingChip.chipKey), findsOneWidget);
        expect(find.text('La foi qui déplace'), findsOneWidget);
        router.pop();
        await _settle(tester);
      });
    });
  });
}

/// La galerie, doublée : elle rend toujours la même photo.
class _OnePhotoPicker extends InertNoteMediaPicker {
  const _OnePhotoPicker(this.photo);

  final File photo;

  @override
  Future<NoteMediaSource?> chooseMedia() async => mediaSourceOf(photo.path);
}

class _RecordingNotesRepository implements NotesRepository {
  final upserts = <NoteUpsert>[];
  final deleted = <String>[];
  final categories = <({String id, String name, NoteColor color})>[];
  final deletedCategories = <String>[];

  @override
  Future<bool> upsertNote(NoteUpsert note) async {
    upserts.add(note);
    return true;
  }

  @override
  Future<bool> deleteNote(String id) async {
    deleted.add(id);
    return true;
  }

  @override
  Future<bool> upsertCategory({
    required String id,
    required String name,
    required NoteColor color,
    required DateTime clientCreatedAt,
  }) async {
    categories.add((id: id, name: name, color: color));
    return true;
  }

  @override
  Future<bool> deleteCategory(String id) async {
    deletedCategories.add(id);
    return true;
  }
}
