import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/status_player.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/models/announcement_draft.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';
import 'package:maison_du_miracle/screens/announcements_screen.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/status/status_background.dart';
import 'package:maison_du_miracle/widgets/status/status_waveform.dart';

import '../helpers/pump_screen.dart';

/// Repository de test : la liste de statuts est fournie par le test lui-même.
///
/// Il rend un `Stream` comme le vrai — le magasin réécrit sous les pieds de
/// l'écran — et sait échouer, pour que l'état d'erreur soit exercé et non
/// supposé.
class _FakeRepository implements AnnouncementRepository {
  _FakeRepository(
    this._announcements, {
    this.member = false,
    this.options = ComposerOptions.empty,
  });

  _FakeRepository.failing()
      : _announcements = null,
        member = false,
        options = ComposerOptions.empty;

  final List<AnnouncementView>? _announcements;
  final bool member;
  final ComposerOptions options;

  @override
  Stream<List<AnnouncementView>> announcements() {
    final values = _announcements;
    if (values == null) return Stream.error(StateError('magasin illisible'));
    return Stream.value(values);
  }

  @override
  Stream<bool> canCompose() => Stream.value(member);

  @override
  Stream<ComposerOptions> composerOptions() => Stream.value(options);

  @override
  Stream<AnnouncementDraft?> draftOf(String id) => Stream.value(null);
}

/// Monte la visionneuse avec un lecteur **inerte** : sans minuterie, l'écran
/// reste déterministe et aucun timer ne survit au démontage.
Future<void> pumpViewer(
  WidgetTester tester,
  List<AnnouncementView> statuses, {
  bool member = false,
  ComposerOptions options = ComposerOptions.empty,
}) async {
  await pumpScreen(
    tester,
    const Scaffold(body: AnnouncementsScreen()),
    announcements: _FakeRepository(statuses, member: member, options: options),
    overrides: [
      statusPlayerProvider.overrideWithValue(InertStatusPlayer()),
    ],
  );
  // Une image de plus : les comptes ne sont lus **qu'une fois** l'appartenance
  // connue — la visionneuse ne fait pas tourner deux requêtes de plus sur les
  // téléphones qui ne publieront jamais. La seconde lecture arrive donc au build
  // suivant, pas au premier.
  await tester.pump();
}

/// Un fond **servi**, tel que le référentiel `status_backgrounds` le rend.
const _backdrop = StatusBackdrop(
  baseColor: 0xFF223B8C,
  topColor: 0xFF2E4CAE,
  bottomColor: 0xFF16265C,
  ink: StatusInk.light,
);

AnnouncementView _status({
  required String id,
  String? title,
  String? body,
  StatusAudio? audio,
  String? backgroundImageUrl,
  StatusBackdrop? backdrop,
  int? accountId,
  String? accountName = 'Diaconat',
  DateTime? expiresAt,
  bool isPinned = false,
  Duration age = const Duration(hours: 2),
}) {
  return AnnouncementView.resolve(
    id: id,
    publishedAt: DateTime.now().toUtc().subtract(age),
    title: title,
    body: body,
    accountId: accountId,
    accountName: accountName,
    audio: audio,
    backgroundImageUrl: backgroundImageUrl,
    backdrop: backdrop,
    expiresAt: expiresAt,
    isPinned: isPinned,
  );
}

void main() {
  group('Visionneuse de statuts', () {
    testWidgets('se monte et affiche le premier statut', (tester) async {
      await pumpViewer(tester, [
        // Le plus récent d'abord : c'est lui qu'on doit voir à l'ouverture.
        _status(
            id: 'b', body: 'Répétition décalée.', age: const Duration(days: 1)),
        _status(id: 'a', title: 'Convention annuelle', body: 'Trois jours.'),
      ]);

      expect(find.byType(AnnouncementsScreen), findsOneWidget);
      expect(find.text('Convention annuelle'), findsOneWidget);
      // L'en-tête porte le **compte officiel**, joint, jamais une chaîne
      // d'auteur recopiée dans l'annonce.
      expect(find.text('Diaconat'), findsOneWidget);
      // Horodatage relatif localisé, jamais une chaîne venue du back.
      expect(find.textContaining('Il y a 2 heures'), findsOneWidget);
    });

    testWidgets(
      'un compte absent du magasin n\'invente pas d\'en-tête',
      (tester) async {
        // La jointure est tolérante : le statut s'affiche, sa ligne d'en-tête
        // non. Jamais de « Compte inconnu » — ça ressemble à une donnée et
        // serait pris pour une erreur de saisie.
        await pumpViewer(tester, [
          _status(
              id: 'orphelin',
              body: 'Le culte débute à 14h30.',
              accountName: null),
        ]);

        expect(find.text('Le culte débute à 14h30.'), findsOneWidget);
        expect(find.textContaining('inconnu'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sans annonce, affiche l’état vide', (tester) async {
      await pumpViewer(tester, const []);

      expect(find.text('Aucune annonce'), findsOneWidget);
      expect(find.byType(StatusWaveform), findsNothing);
    });

    testWidgets(
      'une lecture de magasin en échec se lit comme une panne, pas comme un vide',
      (tester) async {
        // La distinction n'est pas cosmétique : un mur vide faute de base
        // lisible ne doit pas se lire « l'église n'a rien annoncé ».
        await pumpScreen(
          tester,
          const Scaffold(body: AnnouncementsScreen()),
          announcements: _FakeRepository.failing(),
          overrides: [
            statusPlayerProvider.overrideWithValue(InertStatusPlayer()),
          ],
        );

        expect(find.byType(AppErrorState), findsOneWidget);
        expect(find.text('Aucune annonce'), findsNothing);
      },
    );

    testWidgets(
      'un statut vocal + texte affiche le texte ET la waveform',
      (tester) async {
        await pumpViewer(tester, [
          _status(
            id: 'vocal',
            body: 'Un mot du pasteur.',
            audio: const StatusAudio(
              url: 'https://example.org/vocal.m4a',
              durationMs: 12000,
              waveform: [10, 40, 80, 30, 60],
            ),
          ),
        ]);

        expect(find.text('Un mot du pasteur.'), findsOneWidget);
        expect(find.byType(StatusWaveform), findsOneWidget);
      },
    );

    testWidgets(
      'un statut texte seul n’affiche aucune waveform',
      (tester) async {
        await pumpViewer(tester, [
          _status(id: 'texte', body: 'Collecte de dons solidaires.'),
        ]);

        expect(find.text('Collecte de dons solidaires.'), findsOneWidget);
        expect(find.byType(StatusWaveform), findsNothing);
      },
    );

    testWidgets(
      'sans fond servi, le rendu retombe sur la teinte dérivée de l’id',
      (tester) async {
        await pumpViewer(
            tester, [_status(id: 'sans-habillage', body: 'Paix.')]);

        expect(find.byType(StatusBackground), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'un fond servi est peint tel quel, sans recalcul',
      (tester) async {
        await pumpViewer(tester, [
          _status(id: 'habille', body: 'Veillée.', backdrop: _backdrop),
        ]);

        final decorated = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(StatusBackground),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .toList();

        expect(
          decorated.first.gradient,
          isA<LinearGradient>().having(
            (g) => g.colors,
            'les trois arrêts servis',
            const [Color(0xFF2E4CAE), Color(0xFF223B8C), Color(0xFF16265C)],
          ),
        );
      },
    );

    testWidgets(
      'le bouton liste ouvre la feuille et permet de sauter à un statut',
      (tester) async {
        await pumpViewer(tester, [
          _status(id: 'recent', title: 'Convention annuelle'),
          _status(
            id: 'ancien',
            title: 'Collecte solidaire',
            age: const Duration(days: 3),
          ),
        ]);

        await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
        await tester.pumpAndSettle();

        // La feuille liste bien tout l'historique, pas seulement le statut vu.
        expect(find.text('Toutes les annonces'), findsOneWidget);
        expect(find.text('Collecte solidaire'), findsOneWidget);

        await tester.tap(find.text('Collecte solidaire'));
        await tester.pumpAndSettle();

        // Retour à la visionneuse, positionnée sur le statut choisi.
        expect(find.text('Toutes les annonces'), findsNothing);
        expect(find.text('Collecte solidaire'), findsOneWidget);
      },
    );

    testWidgets('le bouton muet bascule l’état du son', (tester) async {
      await pumpViewer(tester, [_status(id: 'texte', body: 'Paix sur vous.')]);

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets(
      'une image de fond en échec réseau retombe sans lever',
      (tester) async {
        // Sous `flutter test`, toute requête réseau renvoie 400 : c'est donc le
        // chemin `errorBuilder` qui s'exécute, et il doit être couvert.
        await pumpViewer(tester, [
          _status(
            id: 'image',
            body: 'Affiche de la convention.',
            backgroundImageUrl: 'https://example.org/affiche.jpg',
          ),
        ]);
        await tester.pump(const Duration(seconds: 1));

        expect(find.byKey(StatusBackground.imageErrorKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Le cycle de vie du mur — ce que le serveur ne fait pas', () {
    test('une annonce expirée ne sort pas du provider', () async {
      // Le serveur sert `expiresAt` brut et ne retire **jamais** une annonce
      // expirée du flux delta : un statut « valable jusqu'à ce soir » doit
      // disparaître à la seconde, y compris hors-ligne.
      final container = _container([
        _status(id: 'vivante', body: 'Encore valable'),
        _status(
          id: 'perimee',
          body: 'Plus valable',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ),
      ]);

      final visible = await _resolve(container, announcementsProvider);

      expect(visible.map((a) => a.id), ['vivante']);
    });

    test('une expiration à venir reste affichée', () async {
      final container = _container([
        _status(
          id: 'jusqu-a-ce-soir',
          body: 'Collecte en cours',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 3)),
        ),
      ]);

      expect(
        (await _resolve(container, announcementsProvider)).map((a) => a.id),
        ['jusqu-a-ce-soir'],
      );
    });

    test('épinglés d\'abord, puis la date, puis l\'id en départage', () async {
      // `List.sort` n'est pas stable en Dart : sans le départage par
      // identifiant, deux statuts publiés à la même seconde changeraient
      // d'ordre d'un `build` à l'autre, et le pager sauterait sous le doigt.
      const sameAge = Duration(hours: 5);
      final container = _container([
        _status(id: 'c', body: 'Troisième', age: const Duration(days: 2)),
        _status(id: 'b', body: 'Deuxième', age: sameAge),
        _status(id: 'a', body: 'Premier', age: sameAge),
        _status(
          id: 'z',
          body: 'Épinglé',
          age: const Duration(days: 9),
          isPinned: true,
        ),
      ]);

      expect(
        (await _resolve(container, announcementsProvider)).map((a) => a.id),
        ['z', 'a', 'b', 'c'],
      );
    });

    test('un statut programmé n\'est pas re-filtré par le client', () async {
      // Le serveur ne sert au mobile ni brouillon ni annonce programmée : tout
      // ce qui arrive est publiable. Re-tester la visibilité ici reviendrait à
      // réimplémenter une règle serveur avec l'horloge de l'appareil pour
      // arbitre — et un téléphone en avance ferait disparaître une annonce.
      final container = _container([
        AnnouncementView.resolve(
          id: 'demain',
          publishedAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
          body: 'Servie par le serveur, donc publiable.',
        ),
      ]);

      expect(
        (await _resolve(container, announcementsProvider)),
        hasLength(1),
      );
    });
  });

  group('L\'affordance d\'écriture', () {
    test('absente pour qui n\'appartient à aucun compte officiel', () async {
      final container = _container(const [], member: false);

      expect(
        await _resolve(container, canComposeAnnouncementProvider),
        isFalse,
      );
    });

    test('présente dès une appartenance — un confort, pas un droit', () async {
      // Le serveur revérifie à chaque écriture : un membre retiré du bureau
      // dont le téléphone n'a pas synchronisé verra encore le bouton et
      // recevra un 403.
      final container = _container(const [], member: true);

      expect(
        await _resolve(container, canComposeAnnouncementProvider),
        isTrue,
      );
    });

    testWidgets(
      'aucun bouton de composition pour qui n\'appartient à aucun compte',
      (tester) async {
        // Pour l'écrasante majorité des fidèles, l'onglet est une visionneuse :
        // pas de bouton grisé, pas de menu caché, **aucune** trace d'écriture.
        await pumpViewer(tester, [_status(id: 'a', body: 'Paix sur vous.')]);

        expect(find.byKey(composeActionKey), findsNothing);
        expect(find.byKey(editActionKey), findsNothing);
      },
    );

    testWidgets('le bouton de composition apparaît avec une appartenance',
        (tester) async {
      await pumpViewer(
        tester,
        [_status(id: 'a', body: 'Paix sur vous.')],
        member: true,
        options: _options,
      );

      expect(find.byKey(composeActionKey), findsOneWidget);
    });

    testWidgets(
      'la modification n\'apparaît que sur les annonces de mes comptes',
      (tester) async {
        // Un compte officiel est un espace éditorial **collectif** : ce qui
        // décide n'est pas « ai-je écrit ce statut » mais « est-il signé de
        // l'un de mes comptes ». Ici, le statut affiché appartient au compte 9,
        // dont je ne suis pas membre.
        await pumpViewer(
          tester,
          [_status(id: 'a', body: 'Paix.', accountId: 9)],
          member: true,
          options: _options,
        );

        expect(find.byKey(composeActionKey), findsOneWidget);
        expect(find.byKey(editActionKey), findsNothing);
      },
    );

    testWidgets(
      'la modification apparaît sur une annonce d\'un de mes comptes',
      (tester) async {
        await pumpViewer(
          tester,
          [_status(id: 'a', body: 'Paix.', accountId: 3)],
          member: true,
          options: _options,
        );

        expect(find.byKey(editActionKey), findsOneWidget);
      },
    );
  });
}

/// Ce que le magasin propose à un membre du compte 3.
const _options = ComposerOptions(
  accounts: [ComposerAccount(id: 3, name: 'Diaconat')],
  backgrounds: [],
);

/// Résout un provider **en gardant un abonnement ouvert**.
///
/// Sans lui, Riverpod dispose l'élément aussitôt lu — les providers sont
/// `autoDispose` par défaut — et la lecture n'aboutit jamais.
Future<T> _resolve<T>(ProviderContainer container, StreamProvider<T> provider) {
  container.listen(provider, (_, __) {});
  return container.read(provider.future);
}

ProviderContainer _container(
  List<AnnouncementView> statuses, {
  bool member = false,
}) {
  return ProviderContainer.test(
    overrides: [
      announcementRepositoryProvider
          .overrideWithValue(_FakeRepository(statuses, member: member)),
    ],
  );
}
