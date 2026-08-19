/// **Le transport de réveil push, derrière une abstraction** — le contrat, et la
/// valeur d'inscription que le serveur attend.
///
/// C'est le maillon mobile de la décision **D2** du PRD `notifications-push.md` :
/// couvrir l'app **fermée** (le SSE couvre l'app ouverte). Deux transports
/// vivent derrière ce contrat, et **aucun appelant ne sait lequel tourne** —
/// exactement comme les trois `ContentPlayer` derrière `content_player.dart` :
///
/// - **FCM** — le défaut partout (iOS + Android avec Play Services + web,
///   décision **D1**) ; [token] est le jeton FCM du device ;
/// - **UnifiedPush** — l'Android dé-googlé (F-Droid, GrapheneOS, Huawei,
///   décision **D2**) ; [token] est l'**URL d'endpoint** que le distributeur
///   ntfy a fournie, POSTée telle quelle par le serveur (décision **D3**).
///
/// Ce fichier ne connaît **ni `firebase_messaging` ni `unifiedpush`**, et c'est
/// la condition pour qu'il se teste sur la VM et pour que le vrai câblage natif
/// (dépendances interdites ici — iOS est SPM-only, Firebase n'est pas encore
/// debout, voir `CLAUDE.md`) s'ajoute plus tard **sans qu'un seul appelant
/// change**. Le défaut, hors backend et en test, est [InertPushTransport].
///
/// **Le payload de réveil ne passe jamais par ici.** Ce contrat ne fait
/// qu'**obtenir l'inscription** et signaler ses **rotations** ; la réception du
/// réveil, la sync ciblée et la notification locale (décision **D6**) sont un
/// autre maillon. Ici on ne produit que ce qu'il faut **envoyer au serveur**
/// pour être joignable.
library;

import 'package:flutter/foundation.dart';

/// **Nom du transport FCM**, tel que le serveur l'attend dans la colonne
/// `device_tokens.transport` (décision **D3**, CHECK `IN ('fcm','unifiedpush')`).
///
/// Nommé une seule fois : le sélecteur (`transport_selector.dart`), les
/// implémentations réelles et le corps d'enregistrement (`POST /devices`)
/// doivent tous s'accorder sur cette chaîne exacte — une divergence donnerait un
/// `transport` que le CHECK serveur refuse.
const String kPushTransportFcm = 'fcm';

/// **Nom du transport UnifiedPush**, valeur jumelle de [kPushTransportFcm].
const String kPushTransportUnifiedPush = 'unifiedpush';

/// **L'inscription d'un appareil à envoyer au serveur** pour être réveillé.
///
/// Valeur immuable, volontairement plate : c'est très exactement le corps que la
/// route d'enregistrement mobile attend (`POST /devices`, décision **D3/§4** du
/// PRD) — `{ token, platform, transport }`. Le serveur range [token] dans la
/// colonne `token` (élargie en `text` pour l'endpoint UnifiedPush qui dépasse
/// 512), et c'est [transport], **pas** [platform], qui décide du pusher.
///
/// L'égalité est fidèle parce que le déclencheur d'un ré-enregistrement est
/// « l'inscription a-t-elle *changé* ? » : sans `operator ==`, une rotation qui
/// rend le **même** endpoint reposterait pour rien.
@immutable
class PushRegistration {
  const PushRegistration({
    required this.token,
    required this.platform,
    required this.transport,
  });

  /// **Le jeton FCM OU l'endpoint UnifiedPush**, selon [transport].
  ///
  /// - `fcm` → le jeton d'enregistrement FCM du device ;
  /// - `unifiedpush` → l'**URL d'endpoint** fournie par le distributeur ntfy,
  ///   que le serveur `POST` telle quelle pour réveiller l'app (décision **D3**).
  ///
  /// C'est la **cible** qui identifie l'appareil côté serveur (colonne `UNIQUE`),
  /// et elle est **inguessable** et **jamais loggée** (décision **D5**).
  final String token;

  /// La plateforme du device : `ios` | `android` | `web`.
  ///
  /// Inchangée par UnifiedPush — un device UnifiedPush reste `android`
  /// (décision **D3**). Elle ne choisit pas le pusher ; elle documente l'OS.
  final String platform;

  /// Le transport visé : [kPushTransportFcm] ou [kPushTransportUnifiedPush].
  ///
  /// **Un seul transport par appareil** (décision **D4**). C'est cette valeur
  /// que la couche de dispatch serveur lit pour grouper les cibles par pusher.
  final String transport;

  @override
  bool operator ==(Object other) =>
      other is PushRegistration &&
      other.token == token &&
      other.platform == platform &&
      other.transport == transport;

  @override
  int get hashCode => Object.hash(token, platform, transport);

  /// **Ne journalise jamais [token]** : l'endpoint UnifiedPush est un secret de
  /// capacité (décision **D5**), et un jeton FCM permet d'envoyer des pushs.
  @override
  String toString() =>
      'PushRegistration(platform: $platform, transport: $transport, token: <redacted>)';
}

/// **Transport de réveil push d'un appareil.**
///
/// Contrat unique dont dépendent l'enregistrement et sa purge. Il ne peint rien
/// et ne reçoit rien : il **obtient une inscription** et **signale ses
/// rotations**. Ce que le device fait du réveil (sync + notif locale, décision
/// **D6**) vit ailleurs.
///
/// Trois membres, et le partage entre eux est une frontière de responsabilité,
/// pas un hasard :
///
/// - [obtainRegistration] — l'inscription **à un instant** (à poster au
///   serveur), ou `null` quand **cet appareil n'a pas de push** (dégradé propre
///   de la décision **D4** : pas de GMS et pas de distributeur → l'app marche,
///   SSE + sync au premier plan, aucune inscription à envoyer) ;
/// - [onRefresh] — les **rotations** ultérieures du jeton/endpoint : FCM fait
///   tourner ses jetons, un distributeur UnifiedPush peut ré-émettre un endpoint.
///   L'appelant réenregistre la nouvelle cible et laisse tomber l'ancienne ;
/// - [dispose] — relâche l'abonnement natif. **Ne purge pas** l'inscription
///   côté serveur (`DELETE /devices` à la déconnexion est une action explicite,
///   pas un effet de bord d'un `dispose`).
abstract interface class PushTransport {
  /// **L'inscription à envoyer au serveur**, ou `null` si pas de push ici.
  ///
  /// `null` n'est pas une panne : c'est le cas dégradé **assumé** de la décision
  /// **D4** (Android sans GMS ni distributeur). L'appelant qui reçoit `null` ne
  /// poste rien et n'affiche aucune erreur — l'app reste pleinement utilisable.
  ///
  /// Asynchrone parce qu'obtenir un jeton FCM ou négocier un endpoint avec le
  /// distributeur est un aller-retour qui peut prendre son temps.
  Future<PushRegistration?> obtainRegistration();

  /// **Les rotations du jeton/endpoint**, après la première inscription.
  ///
  /// FCM émet ici sur `onTokenRefresh` ; UnifiedPush sur un nouvel endpoint du
  /// distributeur. Chaque émission est une inscription **complète et fraîche**,
  /// prête à reposter. Un transport qui ne tourne jamais (l'inerte) rend un flux
  /// **vide** — jamais une erreur.
  Stream<PushRegistration> get onRefresh;

  /// Relâche les ressources natives (abonnements). Sûr et idempotent.
  ///
  /// **N'annule pas l'inscription serveur** : la purge est `DELETE /devices`,
  /// décidée à la déconnexion, jamais déduite d'un cycle de vie.
  Future<void> dispose();
}
