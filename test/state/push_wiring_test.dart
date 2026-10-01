import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/push/push_transport.dart';
import 'package:maison_du_miracle/data/push/wake_notifier.dart';
import 'package:maison_du_miracle/state/push_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

/// **Le défaut du réveil push est l'inerte**, et c'est ce qui fait tourner
/// l'application sans aucun transport.
///
/// Même patron que `contentPlayerProvider` : le provider rend le double, et
/// `main.dart` — seul endroit du dépôt qui sache que Firebase existe — le surcharge
/// quand un transport a réellement démarré. Conséquence vérifiée ici : lire toute la
/// chaîne de providers n'ouvre **aucun** canal de greffon, et le harnais n'a rien à
/// surcharger pour qu'un écran monte.
void main() {
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('le transport par défaut est inerte, et il ne rend aucune cible',
      () async {
    final transport = container.read(pushTransportProvider);

    expect(transport, isA<InertPushTransport>());
    expect(await transport.target(), isNull);
    // `fcm` et non un troisième membre du jeu fermé du serveur : annoncer `none`
    // laisserait croire qu'il existe.
    expect(transport.transport, kFcmTransport);
    await expectLater(transport.targetChanges.toList(), completion(isEmpty));
    await expectLater(transport.wakes.toList(), completion(isEmpty));
  });

  test('l\'affichage du premier plan est inerte, et ce n\'est pas un oubli',
      () {
    // Application ouverte, les écrans se repeignent du magasin que le cycle vient de
    // remplir. Une bannière par-dessus l'écran qu'on regarde serait du bruit, et
    // l'immédiateté d'un fil **ouvert** est le sujet du temps réel SSE (#101).
    expect(container.read(wakeNotifierProvider), isA<InertWakeNotifier>());
    expect(container.read(wakeTapsProvider), isA<InertWakeTaps>());
  });

  test('l\'enrôlement se lit et ne tient aucune cible', () {
    final enrolment = container.read(pushEnrolmentProvider);
    expect(enrolment.target, isNull);
  });

  test('le handler du premier plan se monte sans toucher un canal', () async {
    final handler = container.read(pushWakeHandlerProvider);

    // Un type inconnu : il ne synchronise rien et n'affiche rien, donc il n'ouvre ni
    // socket ni canal. C'est la seule charge utile qu'on puisse passer sans backend.
    await expectLater(
      handler.handle(const {'type': 'inconnu'}),
      completes,
    );
  });

  test('`devicePlatform` ne rend jamais autre chose que le jeu du serveur', () {
    // Le jeu est **fermé côté serveur** (`DEVICE_PLATFORMS`, CHECK en base) : y
    // envoyer `macos` prendrait un 422. On ne recopie donc pas
    // `AppPlatformInfo.name`, qui dit la vérité de la machine et non celle du
    // contrat — et hors du jeu, on rend `null`, ce qui n'enregistre rien.
    expect(devicePlatform(), anyOf(isNull, isIn(['ios', 'android', 'web'])));
  });

  test(
      "garde-fou de source : le cycle de fond ne persiste pas la `scope_version`",
      () {
    // ⚠️ **Cette ligne de production n'est atteignable par aucun test de
    // comportement.** `push_background.dart` est le point d'entrée d'un *autre
    // isolate*, monté par le service natif FCM sur une application fermée : rien
    // dans la suite ne l'exécute. Les deux tests qui encadrent le drapeau
    // (`push_wake_handler_test.dart`) construisent leur **propre** moteur — ils
    // prouvent que le moteur se comporte bien, jamais que l'isolate le câble
    // ainsi.
    //
    // Sans cette garde, remplacer `false` par `true` dans `push_background.dart`
    // laisse **toute la suite verte**. Et la panne serait silencieuse et
    // définitive : la `scope_version` est globale (ADR-0027), donc la persister
    // après un cycle restreint à quatre collections éteindrait pour toujours le
    // resync des autres — le manifeste ne le redemanderait jamais.
    //
    // Même procédé que `lib/data/realtime/`, pour la même raison : ce qu'aucun
    // test ne peut atteindre, une lecture du source le tient.
    // On lit le **code**, pas les commentaires : l'en-tête du fichier cite la
    // valeur en prose, et une recherche naïve passerait donc même après
    // l'inversion. C'est le piège que cette garde est censée fermer.
    final code = File('lib/data/push/push_background.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code.contains('persistsScopeVersion: false'),
      isTrue,
      reason: "le cycle de l'isolate de fond est restreint : persister la "
          "`scope_version` y éteindrait le resync des collections non tirées",
    );
    expect(code.contains('persistsScopeVersion: true'), isFalse);
  });
}
