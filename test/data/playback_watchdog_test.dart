/// **Le chien de garde d'une lecture qui se tait sans rien dire** (issue #42).
///
/// Ce qu'il corrige ne se reproduit pas ici : sur iOS, un décrochage réseau ne
/// remonte **aucune erreur** vers Dart et il n'y a **aucune reconnexion
/// native**. Le lecteur reste indéfiniment en mise en tampon, position figée,
/// et personne ne se plaint. Ce qui se teste, c'est la règle qui le rattrape —
/// et elle se teste entièrement sans lecteur, sur des valeurs.
///
/// `testWidgets` et non `test` : c'est le harnais qui donne une horloge feinte,
/// donc des minuteries qu'on avance à la demande plutôt qu'en attendant
/// vraiment vingt-cinq secondes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/players/playback_watchdog.dart';

/// L'état d'un décrochage : la lecture est demandée, le tampon attend, et rien
/// n'avance.
ContentPlayback _stalled({
  Duration position = const Duration(minutes: 37),
}) =>
    ContentPlayback(
      contentId: 'c1',
      position: position,
      isPlaying: true,
      isBuffering: true,
      hasStarted: true,
    );

void main() {
  late List<Duration> reloads;
  late PlaybackWatchdog watchdog;

  setUp(() {
    reloads = [];
    watchdog = PlaybackWatchdog(onStalled: reloads.add);
  });
  tearDown(() => watchdog.dispose());

  testWidgets('une position figée en tampon finit par recharger', (
    tester,
  ) async {
    watchdog.observe(_stalled());

    await tester.pump(kPlaybackStallTimeout - const Duration(seconds: 1));
    expect(reloads, isEmpty,
        reason: 'une mise en tampon normale a le droit '
            'de durer : à 64 kbps sur un réseau lent, quelques secondes sont la '
            'règle');

    await tester.pump(const Duration(seconds: 2));
    // Rechargement **à la position courante** : c'est là que le fidèle en
    // était, et c'est là qu'il doit repartir.
    expect(reloads, [const Duration(minutes: 37)]);
  });

  testWidgets('une position qui avance repousse l\'échéance', (tester) async {
    watchdog.observe(_stalled());
    await tester.pump(kPlaybackStallTimeout - const Duration(seconds: 1));

    // Le tampon se remplit lentement mais il se remplit : rien n'est cassé.
    watchdog
        .observe(_stalled(position: const Duration(minutes: 37, seconds: 4)));
    await tester.pump(kPlaybackStallTimeout - const Duration(seconds: 1));
    expect(reloads, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    expect(reloads, [const Duration(minutes: 37, seconds: 4)]);
  });

  testWidgets('une pause désarme : une position figée y est normale', (
    tester,
  ) async {
    watchdog.observe(_stalled());
    watchdog.observe(_stalled().copyWith(isPlaying: false));

    await tester.pump(kPlaybackStallTimeout * 3);
    expect(reloads, isEmpty);
  });

  testWidgets('le tampon rempli désarme', (tester) async {
    watchdog.observe(_stalled());
    watchdog.observe(_stalled().copyWith(isBuffering: false));

    await tester.pump(kPlaybackStallTimeout * 3);
    expect(reloads, isEmpty);
  });

  testWidgets('une panne déjà déclarée désarme : l\'écran a la main', (
    tester,
  ) async {
    // Le bouton « Reprendre » est affiché ; recharger dans son dos ferait
    // repartir le son sans que personne ne l'ait demandé.
    watchdog.observe(_stalled());
    watchdog.observe(_stalled().copyWith(error: 'réseau coupé'));

    await tester.pump(kPlaybackStallTimeout * 3);
    expect(reloads, isEmpty);
  });

  testWidgets('il ne renonce pas : un décrochage qui dure se retente', (
    tester,
  ) async {
    // Un décrochage se répare quand le réseau revient, et personne ne peut
    // dire quand. Le prix d'une tentative est quelques requêtes toutes les
    // vingt-cinq secondes ; le prix d'un abandon est une écoute morte.
    watchdog.observe(_stalled());
    await tester.pump(kPlaybackStallTimeout + const Duration(seconds: 1));
    expect(reloads, hasLength(1));

    // Le rechargement republie une mise en tampon, à la même position.
    watchdog.observe(_stalled());
    await tester.pump(kPlaybackStallTimeout + const Duration(seconds: 1));
    expect(reloads, hasLength(2));
  });

  testWidgets('cancel ne laisse aucune minuterie derrière lui', (tester) async {
    watchdog.observe(_stalled());
    watchdog.cancel();

    // Sans ce retrait, tout test qui monte un écran de lecture rougirait sur
    // « A Timer is still pending » — la raison même pour laquelle le chien de
    // garde vit dans le lecteur et jamais dans le `State` d'un widget.
    await tester.pump(kPlaybackStallTimeout * 3);
    expect(reloads, isEmpty);
  });

  testWidgets('après libération, une émission en vol ne réarme rien', (
    tester,
  ) async {
    watchdog.dispose();
    watchdog.observe(_stalled());

    await tester.pump(kPlaybackStallTimeout * 3);
    expect(reloads, isEmpty);
  });
}
