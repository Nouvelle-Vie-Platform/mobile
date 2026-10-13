import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/external_link_launcher.dart';
import 'package:maison_du_miracle/features/notes_editor/links/note_link_opener.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/state/menu_providers.dart';
import 'package:maison_du_miracle/state/notes_providers.dart';

import 'link_test_helpers.dart';

const _known = '0192a5b4-0000-7000-8000-000000000002';
const _gone = '0192a5b4-0000-7000-8000-000000000009';
const _teaching = '0192a5b4-0000-7000-8000-0000000000aa';

void main() {
  late RecordingExternalLinkLauncher launcher;

  Future<void> openLink(
    WidgetTester tester,
    String url, {
    bool browserWorks = true,
  }) async {
    launcher = RecordingExternalLinkLauncher(succeeds: browserWorks);
    final router = linkTestRouter(
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => NoteLinkOpener.open(context, ref, url),
          child: const Text('ouvrir'),
        ),
      ),
    );
    await tester.pumpWidget(linkTestApp(router, [
      noteProvider.overrideWith(
        (ref, id) => Stream.value(id == _known ? fakeNote(_known) : null),
      ),
      externalLinkLauncherProvider.overrideWithValue(launcher),
      routerProvider.overrideWithValue(router),
    ]));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('une note existante ouvre son éditeur', (tester) async {
    await openLink(tester, 'nv://note/$_known');
    expect(find.text('note $_known'), findsOneWidget);
  });

  testWidgets('une note absente : un toast, aucune navigation', (tester) async {
    await openLink(tester, 'nv://note/$_gone');
    expect(find.text('Cette note n\'existe plus'), findsOneWidget);
    expect(find.text('ouvrir'), findsOneWidget);
  });

  testWidgets('un enseignement ouvre le lecteur', (tester) async {
    await openLink(tester, 'nv://teaching/$_teaching');
    expect(find.text('teaching $_teaching'), findsOneWidget);
  });

  testWidgets('une adresse web part au navigateur', (tester) async {
    await openLink(tester, 'https://example.org/a');
    expect(launcher.opened, ['https://example.org/a']);
    expect(find.text('ouvrir'), findsOneWidget);
  });

  testWidgets('navigateur indisponible : un toast', (tester) async {
    await openLink(tester, 'https://example.org', browserWorks: false);
    expect(find.text('Impossible d\'ouvrir ce lien'), findsOneWidget);
  });

  testWidgets('une référence biblique ouvre le lecteur au verset (#199)',
      (tester) async {
    await openLink(tester, 'nv://bible/John/3/16-18');
    expect(find.text('reader John 3 16-18'), findsOneWidget);
  });

  for (final url in [
    'javascript:alert(1)',
    'nv://autre/x',
    'nv://note/',
    'nv://note/a/b',
    'pas une adresse',
    '::',
  ]) {
    testWidgets('un lien hors contrat n\'ouvre rien : $url', (tester) async {
      await openLink(tester, url);
      expect(launcher.opened, isEmpty);
      expect(find.text('ouvrir'), findsOneWidget);
      expect(find.text('Impossible d\'ouvrir ce lien'), findsOneWidget);
    });
  }
}
