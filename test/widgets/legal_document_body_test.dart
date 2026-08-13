import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/legal_document_body.dart';

/// Le corps partagé d'un document légal — celui que la consultation et la
/// barrière d'acceptation (#56) se partageront.
///
/// Ce qu'on vérifie ici est ce qu'aucun test de modèle ne peut dire : que les
/// puces se dessinent, que les liens se distinguent, et surtout que **rien
/// n'est écrit en couleur en dur**. C'est l'écran le plus dense en texte de
/// l'application : un `Colors.black` oublié y donnerait trente articles
/// illisibles en thème sombre, sans faire rougir un seul test de contenu.

Future<void> pumpBody(
  WidgetTester tester,
  LegalDocumentView document, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: const Locale('fr'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: LegalDocumentBody(document: document),
        ),
      ),
    ),
  );
  await tester.pump();
}

LegalDocumentView document(List<LegalSection> sections) =>
    LegalDocumentView.resolve(
      kind: LegalDocumentKind.terms,
      version: 1,
      locale: 'fr',
      sections: sections,
    );

/// Tous les `Text` rendus, du plus haut au plus bas.
List<Text> textsOf(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).toList();

void main() {
  testWidgets('une puce se dessine, et le tiret ne reste pas', (tester) async {
    await pumpBody(
      tester,
      document(const [
        LegalSection(
          key: 'donnees',
          heading: {'fr': 'Vos données'},
          body: {'fr': 'Nous collectons :\n- votre nom\n- votre e-mail'},
        ),
      ]),
    );

    expect(find.text('•'), findsNWidgets(2));
    expect(find.textContaining('- votre nom'), findsNothing);
    expect(find.textContaining('votre nom'), findsOneWidget);
  });

  testWidgets('un lien se distingue du corps, et reste inerte', (tester) async {
    await pumpBody(
      tester,
      document(const [
        LegalSection(
          key: 'contact',
          heading: {'fr': 'Contact'},
          body: {'fr': 'Écrivez à [notre adresse](mailto:a@b.tg).'},
        ),
      ]),
    );

    final riche = tester.widget<Text>(find.textContaining('Écrivez à'));
    final morceaux = <TextSpan>[];
    (riche.textSpan! as TextSpan).visitChildren((span) {
      if (span is TextSpan) morceaux.add(span);
      return true;
    });

    final lien = morceaux.firstWhere((s) => s.text == 'notre adresse');
    expect(lien.style!.color, AppColors.accent);
    expect(lien.style!.decoration, TextDecoration.underline);
    // `url_launcher` n'est pas une dépendance du dépôt : le lien se voit, il
    // ne s'ouvre pas (§7 de la spécification).
    expect(morceaux.every((s) => s.recognizer == null), isTrue);
  });

  testWidgets('une section sans titre ne réserve pas de place vide',
      (tester) async {
    await pumpBody(
      tester,
      document(const [
        LegalSection(key: 'sans-titre', heading: {}, body: {'fr': 'Un corps.'}),
      ]),
    );

    // L'absence se dessine comme une absence : pas de `Text('')` fantôme.
    expect(textsOf(tester).any((t) => t.data == ''), isFalse);
    expect(find.text('Un corps.'), findsOneWidget);
  });

  /// Un document d'une seule section, pour comparer les deux thèmes.
  final unDocument = document(const [
    LegalSection(
      key: 'objet',
      heading: {'fr': 'Objet'},
      body: {'fr': 'Le service.'},
    ),
  ]);

  testWidgets('en thème clair, titre et corps sont sombres', (tester) async {
    await pumpBody(tester, unDocument);

    final titre = tester.widget<Text>(find.text('Objet')).style!.color!;
    final corps = tester
        .widget<Text>(find.textContaining('Le service.'))
        .textSpan!
        .style!
        .color!;

    expect(titre.computeLuminance(), lessThan(0.5));
    expect(corps.computeLuminance(), lessThan(0.5));
  });

  testWidgets('en thème sombre, ils basculent — aucune couleur en dur',
      (tester) async {
    // C'est l'écran le plus dense en texte de l'application : un `Colors.black`
    // oublié y donnerait trente articles illisibles, sans faire rougir un seul
    // test de contenu.
    await pumpBody(tester, unDocument, theme: AppTheme.dark);

    final titre = tester.widget<Text>(find.text('Objet')).style!.color!;
    final corps = tester
        .widget<Text>(find.textContaining('Le service.'))
        .textSpan!
        .style!
        .color!;

    expect(titre.computeLuminance(), greaterThan(0.5));
    expect(corps.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('la largeur de ligne est bornée', (tester) async {
    // Sur une tablette, un texte pleine largeur devient illisible bien avant
    // d'être long : l'œil perd sa ligne en revenant à gauche.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpBody(
      tester,
      document(const [
        LegalSection(
          key: 'objet',
          heading: {'fr': 'Objet'},
          body: {'fr': 'Le service.'},
        ),
      ]),
    );

    final largeur =
        tester.getSize(find.byKey(LegalDocumentBody.contentKey)).width;
    expect(largeur, lessThanOrEqualTo(LegalDocumentBody.maxLineWidth + 1));
  });
}
