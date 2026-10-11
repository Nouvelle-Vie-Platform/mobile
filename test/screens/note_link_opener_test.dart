import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/external_link_launcher.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/notes/note_link_opener.dart';

/// Les quatre formes de lien d'une note, chacune vers sa destination — et un
/// schéma inconnu vers rien. Un routeur réduit aux routes nommées que
/// l'ouvreur pousse, un lanceur qui retient.
void main() {
  late GoRouter router;
  late RecordingExternalLinkLauncher external;
  late NoteLinkOpener opener;

  Future<void> pump(WidgetTester tester) async {
    Widget page(BuildContext _, GoRouterState __) => const SizedBox();
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: page),
        GoRoute(name: AppRoute.noteEditor, path: '/notes/:id', builder: page),
        GoRoute(
          name: AppRoute.teachingDetail,
          path: '/teaching/:id',
          builder: page,
        ),
        GoRoute(path: '/bible', builder: page),
      ],
    );
    addTearDown(router.dispose);
    external = RecordingExternalLinkLauncher();
    opener = NoteLinkOpener(router: router, external: external);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  Future<void> open(WidgetTester tester, String url) async {
    await opener.open(url);
    await tester.pumpAndSettle();
  }

  testWidgets('https → le navigateur, sans toucher à la pile', (tester) async {
    await pump(tester);
    await open(tester, ' https://exemple.org/page ');
    expect(external.opened, ['https://exemple.org/page']);
    expect(router.state.matchedLocation, '/');
  });

  testWidgets('nv://note/<id> → l\'éditeur', (tester) async {
    await pump(tester);
    await open(tester, 'nv://note/019f8000-0000-7000-8000-00000000000a');
    expect(router.state.matchedLocation,
        '/notes/019f8000-0000-7000-8000-00000000000a');
    expect(external.opened, isEmpty);
  });

  testWidgets('nv://teaching/<id> → le lecteur', (tester) async {
    await pump(tester);
    await open(tester, 'nv://teaching/42');
    expect(router.state.matchedLocation, '/teaching/42');
  });

  testWidgets('nv://bible/... → l\'onglet Bible', (tester) async {
    await pump(tester);
    await open(tester, 'nv://bible/John/3/16');
    expect(router.state.matchedLocation, '/bible');
    expect(router.state.uri.queryParameters['tab'], 'bible');
  });

  testWidgets('inconnu, illisible ou sans identifiant → rien', (tester) async {
    await pump(tester);
    await open(tester, 'javascript:alert(1)');
    await open(tester, 'nv://autre/x');
    await open(tester, 'nv://note/');
    await open(tester, 'nv://note/a/b');
    await open(tester, 'pas une adresse');
    await open(tester, '::');
    expect(router.state.matchedLocation, '/');
    expect(external.opened, isEmpty);
  });
}
