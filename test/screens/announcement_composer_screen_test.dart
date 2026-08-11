// **Le composeur d'annonce**, vu de l'écran.
//
// Ce que ces tests protègent n'est pas le formulaire : c'est ce qui se passe
// quand l'envoi **échoue**. Hors ligne et 403 sont les deux chemins normaux de
// cet écran — l'écriture exige le réseau (ADR-0031) et l'appartenance connue du
// téléphone n'est jamais une autorisation —, et dans les deux cas la promesse
// est la même : un message lisible, aucun plantage, et **la saisie toujours à
// l'écran**.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/pickers/status_image_picker.dart';
import 'package:maison_du_miracle/data/repositories/announcement_composer.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/models/announcement_draft.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';
import 'package:maison_du_miracle/screens/announcement_composer_screen.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../helpers/pump_screen.dart';

/// Le magasin, côté composeur : un compte et un fond, et le brouillon que
/// l'écran de modification prérremplit.
class _FakeRepository implements AnnouncementRepository {
  _FakeRepository({this.options = _options, this.draft});

  final ComposerOptions options;
  final AnnouncementDraft? draft;

  @override
  Stream<List<AnnouncementView>> announcements() => Stream.value(const []);

  @override
  Stream<bool> canCompose() => Stream.value(options.accounts.isNotEmpty);

  @override
  Stream<ComposerOptions> composerOptions() => Stream.value(options);

  @override
  Stream<AnnouncementDraft?> draftOf(String id) => Stream.value(draft);
}

/// Le composeur réseau, remplacé par ce qu'on veut qu'il réponde.
class _FakeComposer implements AnnouncementComposer {
  _FakeComposer({this.failure});

  /// Refus à lever, ou `null` pour réussir.
  final AnnouncementWriteException? failure;

  final List<AnnouncementDraft> created = [];
  final List<String> updated = [];
  final List<String> removed = [];

  @override
  Future<void> create(AnnouncementDraft draft) async {
    created.add(draft);
    if (failure != null) throw failure!;
  }

  @override
  Future<void> update({
    required String id,
    required AnnouncementDraft draft,
  }) async {
    updated.add(id);
    if (failure != null) throw failure!;
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    if (failure != null) throw failure!;
  }
}

const _options = ComposerOptions(
  accounts: [ComposerAccount(id: 3, name: 'Diaconat', backgroundId: 5)],
  backgrounds: [
    StatusBackgroundOption(
      id: 5,
      label: 'Bleu nuit',
      backdrop: StatusBackdrop(
        baseColor: 0xFF223B8C,
        topColor: 0xFF2E4CAE,
        bottomColor: 0xFF16265C,
        ink: StatusInk.light,
      ),
    ),
  ],
);

Future<void> _pumpComposer(
  WidgetTester tester, {
  required _FakeComposer composer,
  _FakeRepository? repository,
  String? announcementId,
}) async {
  // Une fenêtre de la hauteur d'un téléphone réel. La surface de test par
  // défaut (800×600) est plus courte que le formulaire : ses derniers champs ne
  // seraient jamais construits, et les tests échoueraient sur une limitation du
  // banc d'essai plutôt que sur l'écran.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    AnnouncementComposerScreen(announcementId: announcementId),
    announcements: repository ?? _FakeRepository(),
    overrides: [
      announcementComposerProvider.overrideWithValue(composer),
      // Sans ça, le composeur toucherait la photothèque de la machine.
      statusImagePickerProvider
          .overrideWithValue(const InertStatusImagePicker()),
      // Après une écriture réussie, l'écran déclenche un cycle de
      // synchronisation. En test, le laisser passer ouvrirait une base Drift sur
      // le disque de la machine : on le remplace par un appel inerte, dont
      // l'existence même est ce qu'on vérifie plus bas.
      pullToRefreshProvider.overrideWithValue(() async {}),
    ],
  );
  await tester.pump();
}

void main() {
  group('Composer une annonce', () {
    testWidgets('publie le brouillon saisi', (tester) async {
      final composer = _FakeComposer();
      await _pumpComposer(tester, composer: composer);

      await tester.enterText(
        find.byKey(composerBodyKey),
        'Le culte débute à 9h.',
      );
      await tester.tap(find.byKey(composerSubmitKey));
      await tester.pump();

      expect(composer.created, hasLength(1));
      expect(composer.created.single.accountId, 3);
      expect(composer.created.single.body, 'Le culte débute à 9h.');
      // Le compte prérremplit son fond par défaut : le cas dominant est un
      // membre d'un seul compte, qui n'a alors rien à choisir.
      expect(composer.created.single.backgroundId, 5);
    });

    testWidgets(
      'un brouillon sans titre, sans corps et sans image ne part pas',
      (tester) async {
        // La règle est vérifiée **avant** l'appel réseau : faire l'aller-retour
        // pour apprendre qu'on n'a rien écrit gaspille la connexion de
        // quelqu'un qui, par définition, en a une mauvaise.
        final composer = _FakeComposer();
        await _pumpComposer(tester, composer: composer);

        await tester.tap(find.byKey(composerSubmitKey));
        await tester.pump();

        expect(composer.created, isEmpty);
        expect(
          find.textContaining('Ajoutez au moins un titre'),
          findsOneWidget,
        );
      },
    );
  });

  group('Les deux refus normaux de cet écran', () {
    testWidgets(
      'hors ligne : l\'écriture est refusée, expliquée, et la saisie reste',
      (tester) async {
        // Pas de file d'envoi, pas de brouillon local : l'application doit
        // **dire** qu'elle a besoin du réseau, pas échouer en silence.
        final composer = _FakeComposer(
          failure: const AnnouncementWriteException(
            AnnouncementWriteErrorCode.network,
          ),
        );
        await _pumpComposer(tester, composer: composer);

        await tester.enterText(
          find.byKey(composerBodyKey),
          'Répétition décalée à 18h.',
        );
        await tester.tap(find.byKey(composerSubmitKey));
        await tester.pump();

        expect(find.text('Connexion requise'), findsOneWidget);
        expect(
          find.textContaining('demande une connexion internet'),
          findsOneWidget,
        );
        // Ce qui compte autant que le message : le texte est toujours là.
        expect(find.text('Répétition décalée à 18h.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '403 : un membre retiré du bureau lit une phrase, pas un code HTTP',
      (tester) async {
        // Le chemin normal, pas un cas exotique : la collection
        // d'appartenances est un confort d'affichage, jamais une autorisation.
        final composer = _FakeComposer(
          failure: const AnnouncementWriteException(
            AnnouncementWriteErrorCode.forbidden,
            'E_OUTSIDE_SCOPE',
          ),
        );
        await _pumpComposer(tester, composer: composer);

        await tester.enterText(find.byKey(composerBodyKey), 'Collecte.');
        await tester.tap(find.byKey(composerSubmitKey));
        await tester.pump();

        expect(
            find.text('Vous ne publiez plus pour ce compte'), findsOneWidget);
        // Jamais le code du serveur, jamais un `toString()` d'exception.
        expect(find.textContaining('E_OUTSIDE_SCOPE'), findsNothing);
        expect(find.textContaining('403'), findsNothing);
        expect(find.text('Collecte.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '422 : le message du serveur est repris, parce qu\'il parle du contenu',
      (tester) async {
        final composer = _FakeComposer(
          failure: const AnnouncementWriteException(
            AnnouncementWriteErrorCode.rejected,
            'La fin de publication doit suivre la publication.',
          ),
        );
        await _pumpComposer(tester, composer: composer);

        await tester.enterText(find.byKey(composerBodyKey), 'Veillée.');
        await tester.tap(find.byKey(composerSubmitKey));
        await tester.pump();

        expect(
          find.text('La fin de publication doit suivre la publication.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Modifier et supprimer', () {
    testWidgets('le formulaire se prérremplit depuis le magasin',
        (tester) async {
      final composer = _FakeComposer();
      await _pumpComposer(
        tester,
        composer: composer,
        announcementId: 'a-1',
        repository: _FakeRepository(
          draft: AnnouncementDraft(
            accountId: 3,
            title: 'Convention annuelle',
            body: 'Trois jours.',
            backgroundId: 5,
            timing: PublicationTiming.scheduled,
            publishedAt: DateTime.utc(2026, 8, 1, 9),
          ),
        ),
      );

      expect(find.text('Convention annuelle'), findsOneWidget);
      expect(find.text('Trois jours.'), findsOneWidget);

      await tester.tap(find.byKey(composerSubmitKey));
      await tester.pump();

      expect(composer.updated, ['a-1']);
    });

    testWidgets('une annonce retirée entre-temps se lit comme une absence',
        (tester) async {
      await _pumpComposer(
        tester,
        composer: _FakeComposer(),
        announcementId: 'a-1',
        repository: _FakeRepository(draft: null),
      );

      expect(find.text('Annonce introuvable'), findsOneWidget);
      expect(find.byKey(composerSubmitKey), findsNothing);
    });

    testWidgets('la suppression demande confirmation avant de partir',
        (tester) async {
      final composer = _FakeComposer();
      await _pumpComposer(
        tester,
        composer: composer,
        announcementId: 'a-1',
        repository: _FakeRepository(
          draft: AnnouncementDraft(accountId: 3, body: 'Trois jours.'),
        ),
      );

      await tester.ensureVisible(find.byKey(composerDeleteKey));
      await tester.tap(find.byKey(composerDeleteKey));
      // `pump()` et jamais `pumpAndSettle` (convention du dépôt) : la
      // confirmation ouvre une boîte animée, et le succès pose ensuite un
      // `SnackBar` dont la minuterie d'effacement ne se stabilise jamais.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Supprimer cette annonce ?'), findsOneWidget);
      // Rien n'est parti tant que la question n'a pas reçu de réponse.
      expect(composer.removed, isEmpty);

      await tester.tap(find.text('Supprimer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(composer.removed, ['a-1']);
    });
  });

  group('Quand le magasin n\'a pas encore livré les comptes', () {
    testWidgets('l\'écran le dit comme une attente, pas comme une panne',
        (tester) async {
      // L'affordance est montée sur les **appartenances**, la liste sur les
      // **comptes** : les deux collections se synchronisent séparément.
      await _pumpComposer(
        tester,
        composer: _FakeComposer(),
        repository: _FakeRepository(options: ComposerOptions.empty),
      );

      expect(find.text('Aucun compte disponible'), findsOneWidget);
      expect(find.byKey(composerSubmitKey), findsNothing);
    });
  });
}
