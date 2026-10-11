import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/links/add_link_sheet.dart';
import 'package:maison_du_miracle/features/notes_editor/links/note_link.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/notes_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

import 'link_test_helpers.dart';

const _current = '0192a5b4-0000-7000-8000-000000000001';
const _other = '0192a5b4-0000-7000-8000-000000000002';
const _untitled = '0192a5b4-0000-7000-8000-000000000003';
const _teaching = '0192a5b4-0000-7000-8000-0000000000aa';

/// Le lien porté par l'opération du Delta dont le texte est exactement
/// [text] ; `null` si elle n'en porte pas. Échoue si aucune opération n'a ce
/// texte : l'insertion a coupé ailleurs qu'attendu.
String? linkOf(QuillController c, String text) {
  final op = c.document.toDelta().toList().firstWhere(
        (op) => op.data == text,
        orElse: () =>
            fail('aucune opération « $text » : ${c.document.toDelta()}'),
      );
  return op.attributes?[Attribute.link.key] as String?;
}

QuillController controllerWith(String text) => QuillController(
      document: text.isEmpty ? Document() : (Document()..insert(0, text)),
      selection: const TextSelection.collapsed(offset: 0),
    );

void main() {
  group('insertNoteLink', () {
    test('la sélection devient le lien, rien n\'est inséré', () {
      final c = controllerWith('Lire Jean ce soir');
      insertNoteLink(c, const NoteRefLink(_other), 'Ignoré',
          selection: const TextSelection(baseOffset: 5, extentOffset: 9));
      expect(c.document.toPlainText(), 'Lire Jean ce soir\n');
      expect(linkOf(c, 'Jean'), 'nv://note/$_other');
      expect(linkOf(c, 'Lire '), isNull);
    });

    test('sans sélection, le titre est inséré au curseur et lié', () {
      final c = controllerWith('Voir ');
      insertNoteLink(c, const TeachingLink(_teaching), 'La foi',
          selection: const TextSelection.collapsed(offset: 5));
      expect(c.document.toPlainText(), 'Voir La foi\n');
      expect(linkOf(c, 'La foi'), 'nv://teaching/$_teaching');
      expect(linkOf(c, 'Voir '), isNull);
    });

    test('une adresse web sans sélection s\'insère elle-même', () {
      final c = controllerWith('');
      final link = WebLink.fromInput('example.org')!;
      insertNoteLink(c, link, link.url);
      expect(c.document.toPlainText(), 'https://example.org\n');
      expect(linkOf(c, 'https://example.org'), 'https://example.org');
    });
  });

  group('la feuille', () {
    late QuillController controller;

    Future<void> pumpButton(
      WidgetTester tester, {
      TextSelection selection = const TextSelection.collapsed(offset: 8),
    }) async {
      controller = controllerWith('Bonjour ');
      controller.updateSelection(selection, ChangeSource.local);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesListProvider.overrideWith(
              (ref, q) => Stream.value([
                fakeNote(_current, title: 'Celle-ci'),
                fakeNote(_other, title: 'Prière du matin'),
                fakeNote(_untitled, body: 'sans titre'),
              ]
                  .where((n) => '${n.title ?? ''} ${n.body}'
                      .toLowerCase()
                      .contains(q.query.toLowerCase()))
                  .toList()),
            ),
            allTeachingsProvider.overrideWith(
              (ref) => Stream.value([
                fakeTeaching(_teaching, 'La foi qui déplace'),
                fakeTeaching('0192a5b4-0000-7000-8000-0000000000bb', 'Grâce'),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(
              body: Center(
                child: ColoredBox(
                  color: Colors.black,
                  child: NoteLinkButton(
                    controller: controller,
                    currentNoteId: _current,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(NoteLinkButton.buttonKey));
      await tester.pumpAndSettle();
    }

    testWidgets('quatre choix, la Bible grisée « bientôt »', (tester) async {
      await pumpButton(tester);
      expect(find.text('Une note'), findsOneWidget);
      expect(find.text('Un enseignement'), findsOneWidget);
      expect(find.text('Une adresse web'), findsOneWidget);
      expect(find.text('La Bible'), findsOneWidget);
      expect(find.text('bientôt'), findsOneWidget);
      final bible =
          tester.widget<ListTile>(find.byKey(AddLinkSheet.bibleOptionKey));
      expect(bible.enabled, isFalse);

      await tester.tap(find.byKey(AddLinkSheet.bibleOptionKey));
      await tester.pumpAndSettle();
      expect(find.text('Une note'), findsOneWidget, reason: 'rien ne bouge');
    });

    testWidgets('une note : la courante exclue, le titre inséré et lié',
        (tester) async {
      await pumpButton(tester);
      await tester.tap(find.byKey(AddLinkSheet.noteOptionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(AddLinkSheet.noteItemKey(_current)), findsNothing);
      expect(find.text('Prière du matin'), findsOneWidget);
      expect(find.text('Nouvelle note'), findsOneWidget);

      await tester.enterText(find.byKey(AddLinkSheet.searchFieldKey), 'prière');
      await tester.pumpAndSettle();
      expect(find.byKey(AddLinkSheet.noteItemKey(_untitled)), findsNothing);

      await tester.tap(find.byKey(AddLinkSheet.noteItemKey(_other)));
      await tester.pumpAndSettle();
      expect(find.byType(AddLinkSheet), findsNothing);
      expect(controller.document.toPlainText(), 'Bonjour Prière du matin\n');
      expect(linkOf(controller, 'Prière du matin'), 'nv://note/$_other');
    });

    testWidgets('un enseignement : recherche et sélection liée',
        (tester) async {
      // Une sélection existe : elle devient le lien, sans insertion.
      await pumpButton(
        tester,
        selection: const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      await tester.tap(find.byKey(AddLinkSheet.teachingOptionKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AddLinkSheet.searchFieldKey), 'foi');
      await tester.pumpAndSettle();
      expect(find.text('Grâce'), findsNothing);

      await tester.tap(find.byKey(AddLinkSheet.teachingItemKey(_teaching)));
      await tester.pumpAndSettle();
      expect(controller.document.toPlainText(), 'Bonjour \n');
      expect(linkOf(controller, 'Bonjour'), 'nv://teaching/$_teaching');
    });

    testWidgets('une adresse web : refus, puis https ajouté', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.byKey(AddLinkSheet.webOptionKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AddLinkSheet.urlFieldKey), 'deux mots');
      await tester.tap(find.byKey(AddLinkSheet.urlSubmitKey));
      await tester.pumpAndSettle();
      expect(find.text('Adresse web invalide'), findsOneWidget);

      await tester.enterText(
          find.byKey(AddLinkSheet.urlFieldKey), 'nouvellevie.org');
      await tester.tap(find.byKey(AddLinkSheet.urlSubmitKey));
      await tester.pumpAndSettle();
      expect(controller.document.toPlainText(),
          'Bonjour https://nouvellevie.org\n');
      expect(
        linkOf(controller, 'https://nouvellevie.org'),
        'https://nouvellevie.org',
      );
    });
  });
}
