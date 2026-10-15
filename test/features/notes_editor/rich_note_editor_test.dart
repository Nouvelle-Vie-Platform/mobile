import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/format_pill.dart';
import 'package:maison_du_miracle/features/notes_editor/format_sheet.dart';
import 'package:maison_du_miracle/features/notes_editor/note_formatting.dart';
import 'package:maison_du_miracle/features/notes_editor/rich_note_editor.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

/// L'éditeur, la pilule et la feuille Format, sans base ni réseau.
///
/// La frappe passe par le contrôleur (`replaceText`) : flutter_quill n'est pas
/// un `EditableText`, et `tester.enterText` ne le trouve pas. Ce qu'on
/// vérifie est ce qui compte pour l'intégration : le Delta et le texte aplati
/// remontent, les boutons posent les attributs que le serveur accepte.
void main() {
  final key = GlobalKey<RichNoteEditorState>();
  final changes = <(String, String)>[];

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? initial,
    Widget? attachmentSlot,
  }) async {
    changes.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: RichNoteEditor(
            key: key,
            initialContentJson: initial,
            onChanged: (json, text) => changes.add((json, text)),
            attachmentSlot: attachmentSlot,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Tape [text] au curseur, comme le clavier le ferait.
  void type(String text) {
    final c = key.currentState!.controller;
    final at = c.selection.baseOffset;
    c.replaceText(
      at,
      0,
      text,
      TextSelection.collapsed(offset: at + text.length),
    );
  }

  /// Le focus s'applique dans une microtâche **après** la trame : le premier
  /// `pump` le pose, le second repeint la pilule.
  Future<void> focus(WidgetTester tester) async {
    key.currentState!.focusNode.requestFocus();
    await tester.pump();
    await tester.pump();
  }

  /// Démonte tout : les minuteurs du curseur et du débordement s'arrêtent.
  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('la saisie remonte un Delta et son texte aplati, débordés',
      (tester) async {
    await pumpEditor(tester);
    type('Bonjour');
    await tester.pump(const Duration(milliseconds: 100));
    expect(changes, isEmpty, reason: 'pas avant 300 ms');
    type(' à tous');
    await tester.pump(const Duration(milliseconds: 350));

    expect(changes, hasLength(1), reason: 'deux frappes, un seul appel');
    final (json, text) = changes.single;
    expect(text, 'Bonjour à tous');
    expect(jsonDecode(json), {
      'ops': [
        {'insert': 'Bonjour à tous\n'},
      ],
    });
    await tearDownTree(tester);
  });

  testWidgets('le contenu initial se charge, même sans retour final',
      (tester) async {
    await pumpEditor(tester, initial: '{"ops":[{"insert":"Déjà là"}]}');
    expect(key.currentState!.controller.document.toPlainText(), 'Déjà là\n');
    expect(find.text('Déjà là', findRichText: true), findsOneWidget);
    await tearDownTree(tester);
  });

  testWidgets('un JSON illisible donne une note vide, pas une exception',
      (tester) async {
    await pumpEditor(tester, initial: '{cassé');
    expect(key.currentState!.controller.document.toPlainText(), '\n');
    await tearDownTree(tester);
  });

  testWidgets('la pilule ne paraît qu\'avec le focus et porte les emplacements',
      (tester) async {
    await pumpEditor(
      tester,
      attachmentSlot: const SizedBox(key: Key('slot_n4')),
    );
    expect(find.byType(FormatPill), findsNothing);

    await focus(tester);
    expect(find.byType(FormatPill), findsOneWidget);
    expect(find.byKey(const Key('slot_n4')), findsOneWidget);

    key.currentState!.focusNode.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FormatPill), findsNothing);
    await tearDownTree(tester);
  });

  testWidgets('B de la pilule : le gras s\'allume et s\'applique à la frappe',
      (tester) async {
    await pumpEditor(tester);
    await focus(tester);
    final c = key.currentState!.controller;

    await tester.tap(find.byKey(FormatPill.boldKey));
    await tester.pump();
    expect(c.isActive(Attribute.bold), isTrue);

    type('gras');
    await tester.pump(const Duration(milliseconds: 350));
    final (json, _) = changes.last;
    expect(
      jsonDecode(json),
      {
        'ops': [
          {
            'insert': 'gras',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
      },
    );

    await tester.tap(find.byKey(FormatPill.boldKey));
    await tester.pump();
    expect(c.isActive(Attribute.bold), isFalse);
    await tearDownTree(tester);
  });

  testWidgets('case à cocher de la pilule : list unchecked, puis retirée',
      (tester) async {
    await pumpEditor(tester, initial: '{"ops":[{"insert":"tâche\\n"}]}');
    await focus(tester);
    final c = key.currentState!.controller;

    await tester.tap(find.byKey(FormatPill.checklistKey));
    await tester.pump();
    expect(c.listType, 'unchecked');
    expect(c.isChecklist, isTrue);

    await tester.tap(find.byKey(FormatPill.checklistKey));
    await tester.pump();
    expect(c.listType, isNull);
    await tearDownTree(tester);
  });

  testWidgets('T ouvre la feuille Format ; Titre pose header 1 sans la fermer',
      (tester) async {
    await pumpEditor(tester, initial: '{"ops":[{"insert":"Titre\\n"}]}');
    await focus(tester);
    final c = key.currentState!.controller;

    await tester.tap(find.byKey(FormatPill.formatKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FormatSheet), findsOneWidget);

    await tester.tap(find.byKey(FormatSheet.titleKey));
    await tester.pump();
    expect(c.getSelectionStyle().attributes['header']?.value, 1);
    expect(c.headerLevel, 1);
    expect(find.byType(FormatSheet), findsOneWidget,
        reason: 'la feuille reste ouverte, comme chez Apple');

    // La rangée des styles défile : « Corps » est le quatrième, hors champ
    // avec la police carrée des tests comme sur un téléphone étroit.
    await tester.ensureVisible(find.byKey(FormatSheet.bodyKey));
    await tester.pump();
    await tester.tap(find.byKey(FormatSheet.bodyKey));
    await tester.pump();
    expect(c.headerLevel, isNull);

    await tester.tap(find.byKey(FormatSheet.quoteKey));
    await tester.pump();
    expect(c.isActive(Attribute.blockQuote), isTrue);

    await tester.tap(find.byKey(FormatSheet.closeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FormatSheet), findsNothing);
    expect(key.currentState!.focusNode.hasFocus, isTrue,
        reason: 'la feuille rend le focus à l\'éditeur');
    await tearDownTree(tester);
  });

  testWidgets('la pastille ouvre la palette ; une couleur de la liste se pose',
      (tester) async {
    await pumpEditor(tester);
    await focus(tester);
    final c = key.currentState!.controller;

    await tester.tap(find.byKey(FormatPill.formatKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(FormatSheet.swatchKey('#e53935')), findsNothing);

    await tester.tap(find.byKey(FormatSheet.colorKey));
    // La palette se déplie (AnimatedSize) et la feuille se replace d'une
    // trame sur l'autre : plusieurs trames avant de viser une pastille.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(FormatSheet.swatchKey('#e53935')));
    await tester.pump();
    expect(c.textColor, '#e53935');

    c.setTextColor('#000000');
    expect(c.textColor, '#e53935', reason: 'hors palette : ignoré');

    await tester.tap(find.byKey(FormatSheet.highlightKey));
    await tester.pump();
    expect(c.isHighlighted, isTrue);
    expect(
      c.getSelectionStyle().attributes['background']?.value,
      '#f8d05e',
    );
    await tearDownTree(tester);
  });
}
