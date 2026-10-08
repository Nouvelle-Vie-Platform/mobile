/// **Le battement d'écoute** (M2 du plan radio adaptative) : sa cadence, ses
/// silences, et l'identifiant de séance.
///
/// `testWidgets` pour son horloge factice — aucun widget, aucun flux Drift :
/// `tester.pump(durée)` avance le temps et fait tourner les minuteries.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_heartbeat.dart';
import 'package:maison_du_miracle/data/radio/radio_status.dart';

void main() {
  late List<String> beats;
  late int minted;

  RadioHeartbeat heartbeat({Future<void> Function(String)? send}) {
    beats = [];
    minted = 0;
    return RadioHeartbeat(
      send: send ??
          (id) async {
            beats.add(id);
          },
      mintListenId: () => 'id-${++minted}',
    );
  }

  testWidgets('un battement dès le son, puis toutes les 60 s', (tester) async {
    final hb = heartbeat();
    hb.onStatus(RadioStatus.connecting);
    await tester.pump();
    expect(beats, isEmpty, reason: 'la connexion n\'est pas une écoute');

    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    expect(beats, ['id-1']);

    await tester.pump(const Duration(seconds: 59));
    expect(beats, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(beats, ['id-1', 'id-1']);
    await tester.pump(const Duration(seconds: 60));
    expect(beats, ['id-1', 'id-1', 'id-1']);

    hb.dispose();
  });

  testWidgets('la même valeur répétée ne bat pas deux fois', (tester) async {
    final hb = heartbeat();
    hb.onStatus(RadioStatus.playing);
    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    expect(beats, hasLength(1));
    hb.dispose();
  });

  testWidgets(
      'pendant une reprise, il se tait et garde son identifiant — '
      'sans rafale au retour', (tester) async {
    final hb = heartbeat();
    hb.onStatus(RadioStatus.playing);
    await tester.pump();

    hb.onStatus(RadioStatus.unstable);
    hb.onStatus(RadioStatus.retrying);
    await tester.pump(const Duration(seconds: 120));
    expect(hb.listenId, 'id-1', reason: 'une reprise garde la séance');
    expect(beats, ['id-1'], reason: 'un échec n\'est pas une écoute');

    // Retour du son : pas de battement immédiat (une antenne qui hoquette
    // ferait sinon répondre 429), la cadence reprend, même identifiant.
    hb.onStatus(RadioStatus.connecting);
    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    expect(beats, ['id-1']);
    await tester.pump(const Duration(seconds: 60));
    expect(beats, ['id-1', 'id-1']);
    expect(minted, 1);

    hb.dispose();
  });

  testWidgets(
      'la pause ou l\'arrêt ferme la séance ; le démarrage suivant a un id '
      'neuf', (tester) async {
    final hb = heartbeat();
    hb.onStatus(RadioStatus.playing);
    await tester.pump();

    hb.onStatus(RadioStatus.idle);
    expect(hb.listenId, isNull);
    await tester.pump(const Duration(minutes: 5));
    expect(beats, ['id-1'], reason: 'plus rien après la fermeture');

    hb.onStatus(RadioStatus.connecting);
    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    expect(beats, ['id-1', 'id-2']);

    hb.dispose();
  });

  testWidgets('un échec d\'envoi est muet et ne casse pas la cadence',
      (tester) async {
    var calls = 0;
    final hb = heartbeat(send: (_) async {
      calls++;
      throw StateError('429');
    });
    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    expect(calls, 2);
    expect(tester.takeException(), isNull);
    hb.dispose();
  });

  testWidgets('même une levée synchrone de l\'envoi reste muette',
      (tester) async {
    final hb = heartbeat(send: (_) => throw StateError('conteneur jeté'));
    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    expect(tester.takeException(), isNull);
    hb.dispose();
  });

  testWidgets('dispose arrête tout', (tester) async {
    final hb = heartbeat();
    hb.onStatus(RadioStatus.playing);
    await tester.pump();
    hb.dispose();
    await tester.pump(const Duration(minutes: 3));
    expect(beats, hasLength(1));
  });

  test('l\'identifiant par défaut est un UUID v4', () {
    String? sent;
    final hb = RadioHeartbeat(send: (id) async => sent = id);
    hb.onStatus(RadioStatus.playing);
    expect(
      sent,
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      )),
    );
    hb.dispose();
  });
}
