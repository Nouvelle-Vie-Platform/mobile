/// **La page Bible à deux onglets, et l'onglet Notes** (#190), à travers le
/// vrai routeur : les pilules, le glissement, la mémoire de l'onglet, la porte
/// de session d'un invité, la redirection de `/notes`, la liste d'un membre,
/// l'éditeur et la feuille Catégorie.
///
/// Tout ce qui touche le magasin Drift vit dans **un seul** `runAsync` par
/// test (un flux ou un `Future` Drift attendu sous l'horloge factice fige le
/// montage).
library;

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
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/repositories/notes_repository.dart';
import 'package:maison_du_miracle/features/notes_editor/format_pill.dart';
import 'package:maison_du_miracle/features/notes_editor/rich_note_editor.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/note_view.dart';
import 'package:maison_du_miracle/screens/bible_screen.dart';
import 'package:maison_du_miracle/screens/notes/note_category_sheet.dart';
import 'package:maison_du_miracle/screens/notes/note_editor_screen.dart';
import 'package:maison_du_miracle/screens/notes/notes_tab.dart';
import 'package:maison_du_miracle/state/notes_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/note_palette.dart';

import '../helpers/fake_api.dart';
import '../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

const _pinnedId = '019f8000-0000-7000-8000-00000000000b';
const _plainId = '019f8000-0000-7000-8000-00000000000a';
const _categoryId = '019f8000-0000-7000-8000-0000000000c1';

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

  group('La page Bible', () {
    testWidgets('deux pilules, la Bible d\'abord, et le glissement',
        (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible');
        await _settle(tester);

        expect(find.byType(BibleScreen), findsOneWidget);
        expect(find.byKey(BibleScreen.tabsKey), findsOneWidget);
        expect(find.text(_fr.pageUnderConstruction), findsOneWidget);
        expect(find.byType(NotesTab), findsNothing);

        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await _settle(tester);

        expect(find.byType(NotesTab), findsOneWidget);
        expect(find.text(_fr.pageUnderConstruction), findsNothing);
        // La page nue, sans session : **rien** n'est parti sur le fil.
        expect(_wire.requests, isEmpty);
      });
    });

    testWidgets('`?tab=notes` ouvre les notes, et `/notes` y redirige',
        (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/notes');
        await _settle(tester);

        expect(router.state.matchedLocation, '/bible');
        expect(router.state.uri.queryParameters['tab'], 'notes');
        expect(find.byType(NotesTab), findsOneWidget);
      });
    });

    testWidgets('le dernier onglet est mémorisé, et rouvert sans paramètre',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible');
        await _settle(tester);

        await tester.tap(find.text(_fr.notesTab));
        await _settle(tester);
        expect(find.byType(NotesTab), findsOneWidget);
        expect(
          await container.read(appDatabaseProvider).settingsDao.bibleTab(),
          'notes',
        );

        router.pop();
        await _settle(tester);
        router.push('/bible');
        await _settle(tester);

        expect(find.byType(NotesTab), findsOneWidget);
        expect(find.text(_fr.pageUnderConstruction), findsNothing);
      });
    });
  });

  group('L\'onglet Notes, pour un invité', () {
    testWidgets('la porte de session, et aucune liste', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
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
          extra: [_radioOff],
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
          extra: [_radioOff, notesRepositoryProvider.overrideWithValue(repo)],
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
          extra: [_radioOff, notesRepositoryProvider.overrideWithValue(repo)],
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
          extra: [_radioOff, notesRepositoryProvider.overrideWithValue(repo)],
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
            _radioOff,
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
            _radioOff,
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
          extra: [_radioOff, notesRepositoryProvider.overrideWithValue(repo)],
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
          extra: [_radioOff, notesRepositoryProvider.overrideWithValue(repo)],
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
