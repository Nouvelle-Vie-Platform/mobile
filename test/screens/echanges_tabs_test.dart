/// **La page Échanges en deux onglets** (#148) : « Messages » puis
/// « Requêtes », au toucher comme au balayage — et mes requêtes avec leur
/// suivi.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/my_requests_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/my_request_view.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/new_request_screen.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/widgets/community/my_requests_tab.dart';
import 'package:maison_du_miracle/widgets/menu_tile.dart';

import '../helpers/guest_app.dart';
import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

final _fr = AppLocalizationsFr();

/// Le libellé d'un onglet de la barre de la page — et non un texte homonyme
/// ailleurs (« Requêtes » est aussi le titre de la route `/requests`).
Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

MyRequestView _request(
  String id, {
  RequestKind kind = RequestKind.suggestion,
  RequestStatus status = RequestStatus.received,
  String? title,
  bool anonymous = false,
  DateTime? sentAt,
}) =>
    MyRequestView(
      id: id,
      kind: kind,
      status: status,
      title: title ?? 'Objet $id',
      content: 'Le message de $id.',
      isAnonymous: anonymous,
      sentAt: sentAt ?? DateTime.utc(2026, 10, 5, 9),
    );

/// Un envoyeur qui retient ce qu'on lui confie.
class _RecordingSubmitter implements RequestSubmitter {
  final drafts = <RequestDraft>[];

  @override
  Future<void> submit(RequestDraft draft) async => drafts.add(draft);
}

/// Un double dont la liste change sous les yeux de l'écran — ce que fait le
/// magasin quand la synchronisation ramène une ligne.
class _LiveRequests implements MyRequestsRepository {
  final _controller = StreamController<List<MyRequestView>>.broadcast();
  List<MyRequestView> _current = const [];

  void push(List<MyRequestView> requests) {
    _current = requests;
    _controller.add(requests);
  }

  @override
  Stream<List<MyRequestView>> mine() async* {
    yield _current;
    yield* _controller.stream;
  }
}

/// Un écran assez haut pour que le formulaire entier soit construit : la
/// `ListView` ne monte que ce qui est visible, et un bouton hors champ ne
/// se touche pas.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('Les deux onglets', () {
    testWidgets('« Messages » puis « Requêtes », Messages ouvert',
        (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: SignedInAuthRepository(),
      );

      expect(_tab(_fr.echangesTabMessages), findsOneWidget);
      expect(_tab(_fr.echangesTabRequests), findsOneWidget);
      expect(
        tester.getCenter(_tab(_fr.echangesTabMessages)).dx,
        lessThan(tester.getCenter(_tab(_fr.echangesTabRequests)).dx),
      );
      // L'onglet ouvert est Messages : la liste des discussions, vide ici.
      expect(find.text(_fr.echangesEmptyTitle), findsOneWidget);
      expect(find.byType(MyRequestsTab), findsNothing);
    });

    testWidgets('le bouton Requêtes du bandeau a disparu', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: SignedInAuthRepository(),
      );

      expect(find.byIcon(Icons.assignment_outlined), findsNothing);
      expect(find.byTooltip(_fr.requestsTitle), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('toucher l\'onglet ouvre Requêtes, et revient', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: SignedInAuthRepository(),
      );

      await tester.tap(_tab(_fr.echangesTabRequests));
      await tester.pumpAndSettle();
      expect(find.byType(MyRequestsTab), findsOneWidget);
      expect(find.text(_fr.requestsEmptyTitle), findsOneWidget);

      await tester.tap(_tab(_fr.echangesTabMessages));
      await tester.pumpAndSettle();
      expect(find.byType(MyRequestsTab), findsNothing);
      expect(find.text(_fr.echangesEmptyTitle), findsOneWidget);
    });

    testWidgets('balayer passe d\'un onglet à l\'autre', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: SignedInAuthRepository(),
      );

      await tester.fling(find.byType(TabBarView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(MyRequestsTab), findsOneWidget);
      expect(find.text(_fr.requestsEmptyTitle), findsOneWidget);

      await tester.fling(find.byType(TabBarView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(MyRequestsTab), findsNothing);
      expect(find.text(_fr.echangesEmptyTitle), findsOneWidget);
    });

    testWidgets('un invité n\'a pas l\'onglet Requêtes — ni grisé, ni rien',
        (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: GuestAuthRepository(),
      );

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
      expect(find.text(_fr.echangesTabRequests), findsNothing);
      expect(find.byType(MyRequestsTab), findsNothing);
    });
  });

  group('Mes requêtes', () {
    testWidgets('vide : on le dit, et on propose d\'en écrire une',
        (tester) async {
      await pumpScreen(tester, const Scaffold(body: MyRequestsTab()));

      expect(find.text(_fr.requestsEmptyTitle), findsOneWidget);
      expect(find.text(_fr.requestsEmpty), findsOneWidget);
      expect(find.byKey(MyRequestsTab.addButtonKey), findsOneWidget);
      expect(find.text(_fr.requestsAdd), findsOneWidget);
    });

    testWidgets('chaque requête dit son genre, son état et sa date',
        (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: MyRequestsTab()),
        myRequests: InMemoryMyRequestsRepository([
          _request('a',
              kind: RequestKind.prayer,
              status: RequestStatus.received,
              title: 'Pour ma mère',
              anonymous: true),
          _request('b',
              kind: RequestKind.suggestion,
              status: RequestStatus.inProgress,
              title: 'Horaires du culte'),
          _request('c',
              kind: RequestKind.complaint,
              status: RequestStatus.resolved,
              title: 'Parking'),
          _request('d',
              kind: RequestKind.suggestion,
              status: RequestStatus.archived,
              title: 'Chorale'),
        ]),
      );

      // Les quatre états du cycle de traitement.
      expect(find.text(_fr.requestStatusNew), findsOneWidget);
      expect(find.text(_fr.requestStatusInProgress), findsOneWidget);
      expect(find.text(_fr.requestStatusResolved), findsOneWidget);
      expect(find.text(_fr.requestStatusArchived), findsOneWidget);
      // Les genres.
      expect(find.text(_fr.requestTypePrayer), findsOneWidget);
      expect(find.text(_fr.requestTypeSuggestion), findsNWidgets(2));
      expect(find.text(_fr.requestTypeComplaint), findsOneWidget);
      // L'objet et l'extrait.
      expect(find.text('Pour ma mère'), findsOneWidget);
      expect(find.text('Le message de a.'), findsOneWidget);
      // La date, et l'anonymat — qui ne me masque jamais à moi-même.
      expect(
        find.text(
            '${_fr.requestSentOn('5 oct. 2026')} · ${_fr.anonymousLabel}'),
        findsOneWidget,
      );
      // Pas d'état vide quand la liste a quelque chose.
      expect(find.text(_fr.requestsEmptyTitle), findsNothing);
      expect(find.byKey(MyRequestsTab.addButtonKey), findsOneWidget);
    });

    testWidgets('un état inconnu n\'invente pas d\'étiquette', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: MyRequestsTab()),
        myRequests: InMemoryMyRequestsRepository([
          _request('x',
              kind: RequestKind.unknown, status: RequestStatus.unknown),
        ]),
      );

      expect(find.text('Objet x'), findsOneWidget);
      for (final label in [
        _fr.requestStatusNew,
        _fr.requestStatusInProgress,
        _fr.requestStatusResolved,
        _fr.requestStatusArchived,
      ]) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('une requête envoyée apparaît dans la liste', (tester) async {
      _tallView(tester);
      final requests = _LiveRequests();
      final submitter = _RecordingSubmitter();
      var refreshes = 0;

      await pumpScreen(
        tester,
        // L'onglet et le formulaire, empilés comme dans l'application : le
        // formulaire se ferme sur un envoi réussi.
        Builder(
          builder: (context) => Scaffold(
            body: const MyRequestsTab(),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NewRequestScreen(),
                ),
              ),
            ),
          ),
        ),
        myRequests: requests,
        requestSubmitter: submitter,
        overrides: [
          // Le cycle de synchronisation qui suit l'envoi : ici, il « ramène »
          // la ligne, comme le ferait le magasin.
          pullToRefreshProvider.overrideWithValue(() async {
            refreshes++;
            final sent = submitter.drafts.last;
            requests.push([
              _request('neuve',
                  kind: sent.kind,
                  title: sent.title,
                  anonymous: sent.isAnonymous),
            ]);
          }),
        ],
      );
      expect(find.text(_fr.requestsEmptyTitle), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestScreen), findsOneWidget);

      await tester.tap(find.text(_fr.requestTypeSuggestion));
      await tester.enterText(find.byType(TextField).at(0), 'Horaires du culte');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Un culte le samedi soir ?',
      );
      await tester.ensureVisible(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.tap(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.pumpAndSettle();

      // Ce qui est parti : le genre choisi, l'objet, le message, l'anonymat.
      final draft = submitter.drafts.single;
      expect(draft.kind, RequestKind.suggestion);
      expect(draft.title, 'Horaires du culte');
      expect(draft.content, 'Un culte le samedi soir ?');
      expect(draft.isAnonymous, isTrue);
      // Un cycle a été demandé, le formulaire s'est fermé, et la requête est
      // dans la liste.
      expect(refreshes, 1);
      expect(find.byType(NewRequestScreen), findsNothing);
      expect(find.text('Horaires du culte'), findsOneWidget);
      expect(find.text(_fr.requestStatusNew), findsOneWidget);
      expect(find.text(_fr.requestsEmptyTitle), findsNothing);
    });
  });

  group('Le formulaire', () {
    testWidgets('trois genres, ceux que le serveur connaît', (tester) async {
      _tallView(tester);
      await pumpScreen(tester, const NewRequestScreen());

      expect(find.text(_fr.requestTypePrayer), findsOneWidget);
      expect(find.text(_fr.requestTypeSuggestion), findsOneWidget);
      expect(find.text(_fr.requestTypeComplaint), findsOneWidget);
      // Le partage au mur n'a de sens que pour une prière.
      expect(find.text(_fr.newRequestShareLabel), findsOneWidget);
      await tester.tap(find.text(_fr.requestTypeComplaint));
      await tester.pump();
      expect(find.text(_fr.newRequestShareLabel), findsNothing);
    });

    testWidgets('un objet trop court et un message vide ne partent pas',
        (tester) async {
      _tallView(tester);
      final submitter = _RecordingSubmitter();
      await pumpScreen(
        tester,
        const NewRequestScreen(),
        requestSubmitter: submitter,
      );

      await tester.enterText(find.byType(TextField).at(0), 'ab');
      await tester.ensureVisible(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.tap(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.pump();

      expect(submitter.drafts, isEmpty);
      expect(find.text(_fr.newRequestTitleTooShort), findsOneWidget);
      expect(find.text(_fr.newRequestContentEmpty), findsOneWidget);
    });

    testWidgets('une prière gardée privée part en `private`', (tester) async {
      _tallView(tester);
      final submitter = _RecordingSubmitter();
      await pumpScreen(
        tester,
        const NewRequestScreen(),
        requestSubmitter: submitter,
        // Le cycle qui suit un envoi réussi : muet ici, ce test ne parle que du
        // corps envoyé.
        overrides: [pullToRefreshProvider.overrideWithValue(() async {})],
      );

      await tester.enterText(find.byType(TextField).at(0), 'Pour ma mère');
      await tester.enterText(find.byType(TextField).at(1), 'Sa guérison.');
      // Le second interrupteur — le premier est l'anonymat.
      final share = find.descendant(
        of: find.ancestor(
          of: find.text(_fr.newRequestShareLabel),
          matching: find.byType(LabeledSwitch),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(share);
      await tester.pump();
      await tester.ensureVisible(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.tap(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.pump();

      final draft = submitter.drafts.single;
      expect(draft.kind, RequestKind.prayer);
      expect(
        draft.toJson(id: 'id', now: DateTime.utc(2026))['visibility'],
        'private',
      );
      // Laisse la confirmation expirer : sa minuterie survivrait au test.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un échec d\'envoi se dit, et le formulaire reste ouvert',
        (tester) async {
      _tallView(tester);
      await pumpScreen(tester, const NewRequestScreen());

      await tester.enterText(find.byType(TextField).at(0), 'Pour ma mère');
      await tester.enterText(find.byType(TextField).at(1), 'Sa guérison.');
      await tester.ensureVisible(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.tap(find.byKey(NewRequestScreen.sendButtonKey));
      await tester.pump();

      // Le double par défaut est indisponible : une panne réseau.
      expect(find.text(_fr.newRequestErrorNetwork), findsOneWidget);
      expect(find.byType(NewRequestScreen), findsOneWidget);
    });
  });
}
