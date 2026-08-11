import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/announcement_draft.dart';
import 'announcement_composer.dart';

/// Implémentation HTTP d'[AnnouncementComposer].
///
/// ```
/// POST   /announcements       guard `api`
/// PUT    /announcements/:id   guard `api`
/// DELETE /announcements/:id   guard `api`   (soft-delete côté serveur)
/// ```
///
/// Corps en **`camelCase`** — la convention des corps de cette API, dont le
/// `snake_case` est réservé aux **query strings** et au protocole `/sync` (voir
/// [announcementPayload]) —, image de fond en **`multipart`**. Le Bearer est
/// injecté par `ApiClient`, et deux choses ne sont donc pas l'affaire de cette
/// classe : l'enveloppe `data` (déballée par un intercepteur) et la conséquence
/// du **401** (purge du token + retour à `/auth`). Le 401 est malgré tout
/// **remonté** ici : l'écriture en cours a échoué, l'auteur doit le savoir.
///
/// **La réponse n'est pas lue.** Ni l'`id` créé, ni la ligne renvoyée : le
/// composeur n'écrit pas dans le magasin local, c'est un cycle de
/// synchronisation qui ramène l'annonce par le flux delta (ADR-0026 — le réseau
/// ne peint jamais). Ça a un effet de bord heureux : le format exact de la
/// réponse d'écriture, que le contrat serveur n'a pas encore figé, ne peut pas
/// nous casser.
///
/// ⚠️ **Aucun de ces trois endpoints n'est déployé** (issue serveur #142,
/// tranche 7 du PRD `annonces-comptes-officiels.md`). Le contrat ci-dessus fait
/// foi, et les tests l'écrivent sur un `HttpClientAdapter` factice — comme l'ont
/// été le socle de synchronisation (#28) et la lecture du mur (#35).
class HttpAnnouncementComposer implements AnnouncementComposer {
  HttpAnnouncementComposer({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  /// Chemin de collection — le seul endroit où il est écrit.
  static const String _path = '/announcements';

  @override
  Future<void> create(AnnouncementDraft draft) async {
    try {
      await _client.post<void>(
        _path,
        data: _requestBody(draft),
        options: _optionsFor(draft),
      );
    } on DioException catch (e) {
      throw mapAnnouncementWriteError(e);
    }
  }

  @override
  Future<void> update({
    required String id,
    required AnnouncementDraft draft,
  }) async {
    try {
      await _client.put<void>(
        '$_path/$id',
        data: _requestBody(draft),
        options: _optionsFor(draft),
      );
    } on DioException catch (e) {
      throw mapAnnouncementWriteError(e);
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      await _client.delete<void>('$_path/$id');
    } on DioException catch (e) {
      throw mapAnnouncementWriteError(e);
    }
  }

  /// JSON tant qu'il n'y a pas d'image, `FormData` dès qu'il y en a une.
  Object _requestBody(AnnouncementDraft draft) {
    final payload = announcementPayload(draft);
    final image = draft.image;
    if (image == null) return payload;
    return multipartBody(payload, image);
  }

  /// Le `Content-Type` par défaut d'`ApiClient` est `application/json` : il faut
  /// le remplacer explicitement quand on dépose un fichier, sinon le serveur lit
  /// un corps multipart comme du JSON et répond 422 sur tout.
  Options? _optionsFor(AnnouncementDraft draft) => draft.image == null
      ? null
      : Options(contentType: Headers.multipartFormDataContentType);
}

/// **Le corps d'écriture d'une annonce**, en `camelCase`.
///
/// La convention n'est pas celle du protocole de synchronisation, et c'est
/// normal : **le `snake_case` de ce serveur ne concerne que les query strings**
/// (`?branch_id=`, `?from=`) et l'enveloppe `/sync`. Les **corps** de son API
/// REST sont en `camelCase` de bout en bout — `create_announcement_controller`
/// valide `branchId`, `update_profile_controller` valide `firstName`, et
/// `HttpAuthRepository` poste déjà `firstName` / `branchId`. Un corps en
/// `snake_case` serait refusé par le validateur VineJS sur chaque clé.
///
/// Ce que le client envoie : `accountId`, `title`, `body`, `backgroundId`,
/// `publishedAt`, `expiresAt` — et l'image, à part, en multipart.
///
/// **Ce qu'il n'envoie jamais, et que le serveur refuse en 422 pour un membre de
/// compte.** Ces quatre absences sont la moitié du contrat, et chacune protège
/// une décision qui n'appartient pas à l'auteur :
///
/// - **`branchId`** — dérivé du compte, jamais accepté d'un client (PRD §19).
///   L'envoyer permettrait à un membre du bureau de Lomé de signer une annonce
///   *nationale* du nom de son comité local. Deux champs indépendants décrivant
///   la même portée finissent toujours par diverger ; ici le compte **est** la
///   portée, et le sélecteur de branche n'existe donc pas dans le composeur.
/// - **`audienceId`** — restreindre la visibilité d'un contenu (ADR-0022) est
///   un acte d'administration, pas une option de publication.
/// - **`isPinned`** — l'épinglage est un arbitrage **entre** comptes (PRD §17).
///   Le bureau d'un compte ignore ce que les autres publient : le premier écran
///   de l'église reviendrait à qui épingle en dernier.
/// - **`notify`** — faire sonner tous les téléphones de l'église est une
///   prérogative éditoriale du portail (PRD §16), et elle est de toute façon
///   impossible sur une annonce programmée, faute d'ordonnanceur serveur.
///
/// Les valeurs `null` sont envoyées **explicitement** (et non omises) : sur un
/// `PUT`, effacer un titre est une intention, et une clé absente ne peut pas
/// l'exprimer. Seul `publishedAt` fait exception en mode
/// [PublicationTiming.now], où l'omission **est** le message : « pose l'instant
/// courant, celui de ton horloge et pas de la mienne ».
@visibleForTesting
Map<String, Object?> announcementPayload(AnnouncementDraft draft) {
  return <String, Object?>{
    'accountId': draft.accountId,
    'title': draft.title,
    'body': draft.body,
    'backgroundId': draft.backgroundId,
    // Trois modes, un seul champ : omis = maintenant, `null` = brouillon, un
    // instant futur = programmé.
    if (draft.timing != PublicationTiming.now)
      'publishedAt': draft.timing == PublicationTiming.scheduled
          ? draft.publishedAt?.toUtc().toIso8601String()
          : null,
    // Toujours **en UTC** sur le fil : le serveur reçoit un instant, pas l'heure
    // murale du téléphone de l'auteur.
    'expiresAt': draft.expiresAt?.toUtc().toIso8601String(),
  };
}

/// Nom du champ de fichier du dépôt d'image.
///
/// `camelCase`, comme le reste du corps et comme les dépôts d'image existants du
/// serveur (`save_teaching_controller` reçoit `imageLandscape` /
/// `imagePortrait`). Il ne porte **pas** le suffixe `Url` de la colonne
/// `background_image_url` : ce qui monte est un fichier, ce que la colonne garde
/// est le chemin que le serveur en dérive.
@visibleForTesting
const String kAnnouncementImageField = 'backgroundImage';

/// Le même corps, en `multipart`, avec l'image jointe.
///
/// **La chaîne vide vaut `null`, et c'est une règle du contrat, pas un
/// contournement du multipart.** Le PRD §18 la pose déjà pour `title` / `body`
/// (« vides après `trim` valent `NULL`, jamais `''` ») et elle s'étend à
/// `publishedAt` — donc une chaîne vide **fait un brouillon** —, `expiresAt` et
/// `backgroundId`.
///
/// C'est ce qui permet aux trois modes de publication de rester repliés sur le
/// **seul** `publishedAt`, en JSON comme en multipart. L'alternative — un booléen
/// `draft` de plus, uniquement pour le cas où un fichier est joint — ferait
/// diverger le mobile du portail, qui exprime déjà les trois modes sur ce seul
/// champ, et introduirait deux façons de dire « brouillon » dont une seule serait
/// jamais testée.
@visibleForTesting
FormData multipartBody(Map<String, Object?> payload, StatusImageUpload image) {
  return FormData.fromMap({
    for (final entry in payload.entries)
      entry.key: entry.value?.toString() ?? '',
    kAnnouncementImageField: MultipartFile.fromBytes(
      image.bytes,
      filename: image.filename,
    ),
  });
}

/// Traduit une [DioException] en [AnnouncementWriteException].
///
/// | Situation | code |
/// | --- | --- |
/// | pas de réponse (timeout, DNS, coupure, TLS) | `network` |
/// | **401** | `unauthorized` |
/// | **403** | `forbidden` — plus membre de ce compte |
/// | **404 / 410** | `gone` — l'annonce a disparu entre-temps |
/// | **422** | `rejected` + message du validateur |
/// | autre réponse HTTP (5xx…) | `server` |
/// | requête annulée, reste | `unknown` |
///
/// Le partage se fait d'abord sur **l'existence d'une réponse**, pas sur le
/// statut : « le serveur n'a rien dit » et « le serveur a dit non » sont deux
/// choses différentes pour l'auteur — l'une se règle en retrouvant du réseau,
/// l'autre jamais.
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester testable
/// sans réseau — `flutter test` répond 400 à tout accès réel.
@visibleForTesting
AnnouncementWriteException mapAnnouncementWriteError(DioException e) {
  if (e.type == DioExceptionType.cancel) {
    return const AnnouncementWriteException(
      AnnouncementWriteErrorCode.unknown,
    );
  }

  final response = e.response;
  if (response == null) {
    return AnnouncementWriteException(
      AnnouncementWriteErrorCode.network,
      'Impossible de joindre le serveur (${e.message})',
    );
  }

  final body = response.data;
  final message = body is Map ? body['message'] as String? : null;

  return switch (response.statusCode) {
    401 => AnnouncementWriteException(
        AnnouncementWriteErrorCode.unauthorized, message),
    403 =>
      AnnouncementWriteException(AnnouncementWriteErrorCode.forbidden, message),
    404 ||
    410 =>
      AnnouncementWriteException(AnnouncementWriteErrorCode.gone, message),
    422 =>
      AnnouncementWriteException(AnnouncementWriteErrorCode.rejected, message),
    _ => AnnouncementWriteException(
        AnnouncementWriteErrorCode.server, message ?? e.message),
  };
}
