/// **Par quoi le serveur réveille ce téléphone** — l'abstraction exigée par le
/// § 4 du PRD `notifications-push.md`, et son **double inerte**.
///
/// Elle existe pour une raison datée : la tranche 4 (UnifiedPush, #99) doit être
/// une **addition** et non une refonte. Ce qui change d'un transport à l'autre est
/// exactement ce que ce fichier déclare — la clé à annoncer au serveur, comment
/// obtenir une cible de réveil, et par où les réveils arrivent quand
/// l'application est ouverte. Tout le reste est écrit une fois et ne connaît
/// aucun transport :
///
/// | pièce | fichier | transport-agnostique ? |
/// |---|---|---|
/// | l'enregistrement (`POST /devices/tokens`) | `push_registrar.dart` | oui |
/// | le moment de l'enregistrement et la rotation | `push_enrolment.dart` | oui |
/// | la lecture d'une charge utile de réveil | `push_wake.dart` | oui |
/// | synchroniser puis notifier depuis le magasin | `push_wake_handler.dart` | oui |
/// | la notification locale | `wake_notifier.dart` | oui |
/// | **FCM** | `fcm_push_transport.dart` | non — le seul |
///
/// La tranche 4 ajoutera donc `unified_push_transport.dart` à côté, et **une
/// branche** au choix de transport de `main.dart`. Rien de ce tableau ne bouge.
///
/// ## Le double inerte n'est pas un bouchon de test
///
/// C'est le **défaut de production** (`pushTransportProvider`), exactement comme
/// `InertContentPlayer` est le défaut du lecteur : `main.dart` est le seul endroit
/// du dépôt qui sache que Firebase existe, et il ne surcharge le provider que
/// lorsqu'un transport a réellement démarré. Les plateformes sans transport — le
/// web, macOS, un Android dé-googlé avant la tranche 4, un appareil dont
/// l'utilisateur a refusé la permission — tournent donc sur l'inerte, et
/// l'application y fonctionne entièrement : les trois déclencheurs de
/// synchronisation d'ADR-0017 ne dépendent d'aucun push.
library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// La valeur que `POST /devices/tokens` attend pour FCM — et le **défaut**
/// serveur, qui l'applique quand le champ est absent. On l'envoie quand même :
/// un corps qui dit la voie qu'il enregistre se relit sans connaître le défaut.
const String kFcmTransport = 'fcm';

/// La valeur que la tranche 4 (#99) enregistrera. Nommée **ici** et non chez le
/// futur transport : c'est le jeu fermé du contrat serveur
/// (`app/devices/support/device_transport.ts`), et le lire à un seul endroit est
/// ce qui empêche deux orthographes de coexister.
const String kUnifiedPushTransport = 'unifiedpush';

/// **Demander la permission d'affichage, maintenant.**
///
/// Une fonction et non une méthode de [PushTransport], parce que ce n'est pas
/// une propriété du transport : c'est un **moment**, et un seul transport en a
/// un. Sur mobile la permission est demandée au démarrage
/// (`requestPlaybackNotificationPermission()`, une permission système pour
/// trois besoins) ; **sur le web elle est demandée dans la foulée de
/// l'installation** (#283) — un refus y est quasi définitif, et il emporte
/// tout : sans permission, pas de jeton, donc pas même le réveil silencieux.
///
/// Elle **ne lève jamais** : c'est un bandeau qui l'appelle.
/// `pushPermissionProvider` la rend, `null` partout sauf sur le web.
typedef PushPermissionRequest = Future<void> Function();

/// **Un transport de réveil.** Ne lève jamais : l'absence de push est un mode de
/// fonctionnement normal, pas une panne (PRD D4, « dégradé propre »).
abstract interface class PushTransport {
  /// `fcm` | `unifiedpush` — ce que le corps de `POST /devices/tokens` annonce.
  String get transport;

  /// **La cible de réveil**, ou `null` quand il n'y en a pas.
  ///
  /// Demande la permission si la plateforme en exige une, puis rend la cible :
  /// pour FCM le jeton d'enregistrement, pour UnifiedPush l'URL d'endpoint du
  /// distributeur. Le serveur ne distingue pas les deux — l'unicité porte sur la
  /// cible, quelle que soit sa forme.
  ///
  /// `null` couvre tous les refus, et ils sont **tous normaux** : permission
  /// refusée, pas de Play Services, pas de distributeur, réseau absent au premier
  /// lancement. Rien ne doit s'arrêter pour autant.
  Future<String?> target();

  /// **Les rotations de cible.** FCM fait tourner ses jetons (réinstallation,
  /// restauration de sauvegarde, purge des données), et chaque nouvelle valeur
  /// doit être réenregistrée — sans quoi le téléphone devient injoignable en
  /// silence, ce qui est la panne la plus difficile à constater de toute cette
  /// tranche.
  Stream<String> get targetChanges;

  /// **Les réveils reçus application ouverte**, sous la forme brute du bloc
  /// `data` du message.
  ///
  /// Une `Map` et non un [PushWake] déjà lu : la lecture d'une charge utile est
  /// écrite **une seule fois** (`push_wake.dart`), et un second transport n'a pas
  /// à la refaire. C'est aussi ce qui garde ce contrat libre de toute
  /// connaissance du vocabulaire de réveil.
  ///
  /// ⚠️ Ce flux ne porte **que** le cas « application au premier plan ».
  /// L'application fermée est réveillée dans un **autre isolate**, dont le point
  /// d'entrée est posé par le transport lui-même au démarrage — il n'y a pas de
  /// `Stream` qui traverse deux isolates.
  Stream<Map<String, Object?>> get wakes;
}

/// **Le double inerte** : aucun transport, aucun canal de plugin, aucune
/// minuterie.
///
/// Même rôle qu'`InertContentPlayer` et `InertGroupMessageSender` : le défaut du
/// provider, en production comme sous `flutter test`. Il rend `null` et deux flux
/// vides — ce qui est la vérité d'un appareil sans push, pas une simulation.
class InertPushTransport implements PushTransport {
  const InertPushTransport();

  /// `fcm` : la valeur n'a aucun effet, puisque [target] ne rend jamais rien à
  /// enregistrer. Annoncer un transport qui n'existe pas (`none`) ferait croire à
  /// un troisième membre du jeu fermé du serveur.
  @override
  String get transport => kFcmTransport;

  @override
  Future<String?> target() async => null;

  @override
  Stream<String> get targetChanges => const Stream<String>.empty();

  @override
  Stream<Map<String, Object?>> get wakes =>
      const Stream<Map<String, Object?>>.empty();
}

/// **La plateforme, telle que `POST /devices/tokens` la nomme** — `ios`,
/// `android` ou `web` —, ou `null` quand elle n'est pas du jeu.
///
/// Le jeu est **fermé côté serveur** (`DEVICE_PLATFORMS`, CHECK en base) : y
/// envoyer `macos` prendrait un 422. On rend donc `null` plutôt que de recopier
/// `AppPlatformInfo.name`, qui dit la vérité de la machine (`macos`, `linux`) et
/// non celle du contrat.
///
/// ⚠️ `web` **est désormais du jeu des deux côtés** (#283) : le projet Firebase
/// déclare une application web, et `WebPushTransport` s'y branche. La valeur
/// était déjà rendue quand ce n'était pas le cas — c'est la plateforme, pas une
/// décision —, et c'est toujours au choix de transport de `main.dart` de dire
/// quel transport elle reçoit.
String? devicePlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
}
