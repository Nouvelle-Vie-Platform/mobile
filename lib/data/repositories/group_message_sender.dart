/// **L'écriture d'un message de groupe** (#96) — séparée de sa lecture, comme le
/// composeur d'annonces l'est d'`AnnouncementRepository`, et pour les trois mêmes
/// raisons : ni la même source (serveur / magasin), ni la même forme
/// (`Future` / `Stream`), ni le même régime hors-ligne.
///
/// La différence avec les annonces est le **régime hors-ligne**, et c'est la
/// rupture assumée du cadrage (décision 2) : écrire une annonce **exige** le
/// réseau (ADR-0031, pas de file d'envoi), écrire un message **ne l'exige pas** —
/// il paraît à l'écran avant d'être parti. Les fondre donnerait un objet dont la
/// moitié des méthodes marchent en avion.
library;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';

/// Contrat d'envoi d'un message.
abstract interface class GroupMessageSender {
  /// Poste le message et dit **s'il est parti**.
  ///
  /// ## Pourquoi un booléen et non un code de refus
  ///
  /// C'est le choix du rapporteur de progression (#43), pas celui du composeur
  /// d'annonces, et pour une raison qui tient à ce que l'écran peut faire :
  /// réseau absent, 401, 403, 422, 5xx — aucune de ces causes n'est actionnable
  /// par le fidèle, et toutes disent la même chose au bas de son fil, « ce message
  /// n'est pas parti ». Six phrases pour un seul geste possible (réessayer, ou
  /// abandonner) seraient six occasions de se tromper de phrase.
  ///
  /// Le refus qui *aurait* mérité son mot — « ce groupe est en diffusion, vous ne
  /// pouvez pas y écrire » — est traité **avant** l'envoi : `ConversationView.canWrite`
  /// retire la barre de saisie. Un 403 ici veut donc dire que le magasin était en
  /// retard sur le serveur, c'est-à-dire exactement un cas où l'on n'a rien de
  /// mieux à dire que « ça n'est pas parti ».
  ///
  /// [clientMessageId] est **obligatoire**, et c'est le point de la décision 2 :
  /// sans clé d'idempotence, le double appui que l'écho évite à l'écran se produit
  /// quand même au réseau. Le serveur l'attend déjà — unicité
  /// `(group_id, author_id, client_message_id)` — et renvoie l'existant plutôt que
  /// de créer un doublon.
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
  });
}

/// **Fabrique une clé d'idempotence** : un UUIDv7, comme l'identifiant de
/// progression de #43.
///
/// Un v7 et non un v4, pour la raison qui vaut déjà là-bas : il trie
/// temporellement, donc deux clés frappées par le même appareil gardent l'ordre
/// dans lequel on a tapé, même si le réseau les livre dans l'autre sens.
String mintClientMessageId() => const Uuid().v7();

/// Implémentation HTTP de [GroupMessageSender].
///
/// ```
/// POST /groups/:id/messages   guard `api`
/// { "body": "…", "clientMessageId": "<uuidv7>", "clientCreatedAt": "<iso UTC>" }
/// → 201 { … }   (enveloppe `data` déballée par ApiClient)
/// ```
///
/// Trois points relevés sur
/// `app/groups/controllers/send_group_message_controller.ts`, et non supposés :
///
/// 1. **le corps est en `camelCase`** — le `snake_case` de ce serveur ne concerne
///    que les query strings et l'enveloppe `/sync`. Le validateur VineJS
///    refuserait chaque clé en `snake_case` ;
/// 2. **`body` est borné à 4000 caractères** et refusé vide après `trim()`. On
///    coupe ici plutôt que de laisser partir un corps qui prendra un 422 : la
///    borne est une donnée du contrat, pas une devinette ;
/// 3. **`clientCreatedAt` est attendu en UTC** (`vine.date({ formats: { utc:
///    true } })`). Un instant local partirait avec un décalage que le serveur
///    refuserait, ou — pire — accepterait en le lisant de travers.
///
/// **Rien n'est écrit dans le magasin ici**, et la réponse n'est même pas lue :
/// le réseau ne peint jamais. Ce qui paraît à l'écran est l'écho local, et c'est
/// le flux delta qui ramène la ligne autoritaire — y compris sur un **rejeu**, où
/// le serveur renvoie le message déjà persisté avec son `id` d'origine. C'est
/// exactement ce que fait le composeur d'annonces après un envoi réussi.
class HttpGroupMessageSender implements GroupMessageSender {
  HttpGroupMessageSender({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  /// La borne du validateur serveur, nommée **une fois**.
  static const int maxBodyLength = 4000;

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;

    try {
      await _client.post<Object?>(
        '/groups/$groupId/messages',
        data: {
          'body': trimmed.length > maxBodyLength
              ? trimmed.substring(0, maxBodyLength)
              : trimmed,
          'clientMessageId': clientMessageId,
          'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
        },
      );
      return true;
    } on DioException {
      // **Muet, et délibérément.** Voir [GroupMessageSender.send] : il n'y a rien
      // à composer d'un refus ici, seulement un écho à marquer « pas parti ».
      return false;
    }
  }
}

/// Double **inerte** : n'envoie rien et dit que c'est parti.
///
/// Sert aux tests d'écran, et à `AppEnv.useBackend == false`. L'implémentation
/// HTTP ouvrirait une socket que `flutter test` refuse (400 sur tout accès
/// réseau), et laisserait la minuterie de Dio derrière elle.
class InertGroupMessageSender implements GroupMessageSender {
  const InertGroupMessageSender();

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
  }) async =>
      true;
}
