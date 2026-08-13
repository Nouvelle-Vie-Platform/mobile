/// **L'écriture du consentement** — `POST /legal/accept`, et rien d'autre.
///
/// Séparé de `LegalRepository` exactement comme `AnnouncementComposer` l'est
/// d'`AnnouncementRepository`, et pour les mêmes trois raisons :
///
/// | | `LegalRepository` | `LegalAcceptanceRecorder` |
/// |---|---|---|
/// | source | le magasin local | le serveur |
/// | forme | `Stream` (le magasin réécrit sous l'écran) | `Future` (un acte, une réponse) |
/// | hors-ligne | régime **normal** | **impossible**, et ça se dit |
///
/// C'est la moitié qui exige le réseau d'un écran dont l'autre moitié — le
/// texte à accepter — vient du magasin et se lit en avion (ADR-0036,
/// décision 2). Les fondre donnerait un objet dont une méthode marche hors
/// ligne et l'autre pas.
library;

import 'package:flutter/foundation.dart';

/// Nature d'un refus d'enregistrement du consentement.
///
/// Mêmes motifs que `AnnouncementWriteErrorCode` : **la couche données ne
/// rédige pas de message**, elle dit *quoi* a échoué, l'écran choisit la
/// phrase. Jamais un code HTTP à l'écran, jamais un `toString()` d'exception —
/// et ici moins qu'ailleurs : c'est l'écran dont personne ne peut sortir.
enum LegalAcceptanceErrorCode {
  /// Le serveur n'a **pas répondu** : coupure, DNS, timeout, TLS.
  ///
  /// Le cas hors-ligne, et le chemin **normal** de cet écran pour le fidèle de
  /// Lomé au réseau intermittent : il a pu lire le document (il vient du
  /// magasin), il ne peut pas encore l'accepter. Pas de file d'envoi, pas
  /// d'état « accepté, non confirmé » (ADR-0036, décision 2).
  network,

  /// **401** — la session n'est plus valide. La purge du token et le retour à
  /// `/auth` ont déjà été déclenchés globalement par `UnauthorizedInterceptor`,
  /// et la garde de route s'en chargera : l'écran annonce, il ne navigue pas.
  unauthorized,

  /// **422** — la version envoyée n'est pas celle que le serveur attend
  /// (`E_LEGAL_VERSION_OUTDATED`, `E_LEGAL_VERSION_NOT_FOUND`).
  ///
  /// Le document affiché est en retard sur le serveur : une révision a été
  /// publiée entre le moment où la synchronisation a rempli le magasin et
  /// l'appui sur « Continuer ». Réessayer à l'identique échouerait toujours —
  /// ce qu'il faut, c'est **recharger le document**.
  ///
  /// Les deux autres 422 de la route se rangent ici, faute de mieux et sans
  /// conséquence : `E_LEGAL_KIND_NOT_ACCEPTABLE` ne peut pas arriver — la
  /// barrière n'envoie que `LegalDocumentKind.acceptable` —, et
  /// `accepts.distinct` non plus, un genre n'y figurant qu'une fois.
  outdated,

  /// Le serveur a répondu, mais en erreur (5xx, ou un statut non prévu). Il est
  /// joignable : ce n'est pas la connexion du fidèle qui est en cause.
  server,
}

/// Un accord donné : « j'accepte ce genre, à cette édition ».
///
/// La **version** est celle du document affiché, jamais son plancher : c'est le
/// texte lu qui s'accepte. Le serveur refuse d'ailleurs toute version qui n'est
/// pas la dernière publiée (`E_LEGAL_VERSION_OUTDATED`) — c'est ce qui empêche
/// d'enregistrer un accord sur un texte périmé.
@immutable
class LegalAcceptance {
  const LegalAcceptance({required this.kind, required this.version});

  /// `cgu` ou `privacy`. **Jamais `about`** : le serveur le refuse en toutes
  /// lettres (`E_LEGAL_KIND_NOT_ACCEPTABLE`), et accepter une présentation n'a
  /// pas de sens.
  final String kind;

  /// Numéro d'édition, ≥ 1 — il n'existe pas de version 0 à accepter.
  final int version;

  Map<String, Object?> toJson() => {'kind': kind, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is LegalAcceptance &&
      other.kind == kind &&
      other.version == version;

  @override
  int get hashCode => Object.hash(kind, version);

  @override
  String toString() => 'LegalAcceptance($kind v$version)';
}

/// Échec d'enregistrement du consentement, tel que le voit l'appelant.
class LegalAcceptanceException implements Exception {
  const LegalAcceptanceException(this.code, [this.message]);

  final LegalAcceptanceErrorCode code;

  /// Message **déjà localisé par le serveur** quand il en a fourni un.
  ///
  /// Il ne s'affiche **jamais** : les quatre codes ont chacun leur phrase côté
  /// app. Il est retenu pour les journaux et les tests — un message serveur
  /// n'est pas un texte d'interface, et celui-ci le serait sur l'écran le plus
  /// contraignant de l'application.
  final String? message;

  @override
  String toString() => 'LegalAcceptanceException(${code.name}'
      '${message == null ? '' : ': $message'})';
}

/// Le contrat d'écriture du registre de consentement.
///
/// **Une seule route**, `POST /legal/accept` : les documents, eux, voyagent par
/// le flux delta. Il n'y a pas de `GET /legal/:kind` et il n'y en aura pas —
/// c'est ce qui rend le texte lisible hors ligne.
abstract interface class LegalAcceptanceRecorder {
  /// Enregistre un ou plusieurs accords, et rend le **résumé à jour**
  /// (`{cgu: 3, privacy: 2}`) que porte la réponse.
  ///
  /// Rendre le résumé plutôt que rien n'est un confort : c'est ce qui permet à
  /// la barrière de se lever sans un `GET /auth/me` de plus, donc sans écran
  /// d'attente entre « Continuer » et l'application (ADR-0036).
  ///
  /// **Un seul appel pour tous les documents cochés.** Le serveur écrit dans
  /// une transaction : un corps dont une entrée est refusée n'écrit rien du
  /// tout, plutôt que de laisser le fidèle devant une barrière à moitié levée
  /// sans savoir laquelle des deux cases est passée.
  ///
  /// Lève une [LegalAcceptanceException] — réseau, 401, 422 et panne serveur
  /// s'y distinguent par leur code.
  Future<Map<String, int>> accept(List<LegalAcceptance> accepts);
}

/// L'enregistreur du **mode maquette** : il refuse tout, et il le dit.
///
/// Servi quand `AppEnv.useBackend` est faux. Ce n'est pas un bouchon paresseux :
/// c'est le comportement exact, parce qu'il n'y a rien à quoi bouchonner. Un
/// double qui « réussirait » en mémoire mentirait deux fois — sur le succès, et
/// sur l'existence d'un chemin hors-ligne dont ADR-0036 dit qu'il n'existe pas.
///
/// [LegalAcceptanceErrorCode.network] et non un code dédié : du point de vue du
/// fidèle, un serveur absent parce qu'il n'y en a pas et un serveur absent
/// parce que le réseau a coupé donnent le même écran, et c'est le bon.
class UnavailableLegalAcceptanceRecorder implements LegalAcceptanceRecorder {
  const UnavailableLegalAcceptanceRecorder();

  @override
  Future<Map<String, int>> accept(List<LegalAcceptance> accepts) =>
      Future.error(
        const LegalAcceptanceException(LegalAcceptanceErrorCode.network),
      );
}
