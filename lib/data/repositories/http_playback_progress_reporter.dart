import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'playback_progress_reporter.dart';

/// Implémentation HTTP de [PlaybackProgressReporter].
///
/// ```
/// POST /teachings/:teachingId/progress   guard `api`
/// { "id": "<uuidv7>", "positionSeconds": 942, "completed": false }
/// ```
///
/// Corps en **`camelCase`** — la convention des corps de cette API, dont le
/// `snake_case` est réservé aux **query strings** et au protocole `/sync`. Le
/// Bearer est injecté par `ApiClient`.
///
/// L'écriture est un **upsert owner-scopé idempotent** (ADR-0018) : un rejeu
/// est un no-op — `created_at` n'est jamais réécrit —, une ligne appartenant à
/// quelqu'un d'autre donne un **409**, et un tombstone n'est jamais ressuscité.
///
/// **Il n'y a aucun endpoint REST de lecture** : on ne peut pas demander « où
/// en étais-je sur cet enseignement ? ». La seule lecture est
/// `GET /sync/playback_progress`. C'est pour cela que ce fichier ne lit pas la
/// réponse — il n'y a rien à en tirer que le flux delta n'apporterait mieux.
///
/// **Un rassemblement passe par cette même route** : `teachings` et
/// `gatherings` sont la même table serveur, discriminée par `family`. Le point
/// est démontré par le code serveur mais **prouvé par aucun test** (question
/// ouverte de l'issue #43, PRD serveur `miracle-house-server#151`) : à faire
/// épingler côté serveur avant de s'y adosser complètement.
///
/// ## Le silence
///
/// **Aucun échec ne sort d'ici.** Ni exception, ni bandeau, ni relance visible.
/// Hors ligne et 5xx sont des régimes **normaux** de cette route : elle est
/// appelée pendant qu'un fidèle écoute un prêche, souvent en 3G intermittente,
/// souvent écran éteint. Une progression perdue coûte quelques minutes de
/// réécoute ; une erreur affichée au milieu d'un enseignement est une panne.
///
/// Le 401 lui-même est avalé, à la différence du composeur d'annonces — et la
/// nuance est celle du geste : l'auteur d'une annonce **attend** que son envoi
/// aboutisse et doit savoir qu'il a échoué, alors que personne n'a demandé ce
/// rapport-ci. L'intercepteur d'`ApiClient` a de toute façon déjà purgé le
/// token et ramènera l'utilisateur à `/auth` de son côté.
///
/// [lastFailure] existe pour le diagnostic et pour les tests — c'est le seul
/// endroit où l'échec est visible, et il n'est lu par aucun écran.
class HttpPlaybackProgressReporter implements PlaybackProgressReporter {
  HttpPlaybackProgressReporter({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Le dernier échec avalé, `null` si le dernier rapport est passé.
  ///
  /// Ni un état d'application, ni un compteur de relance : rien ne le lit hors
  /// des tests. Il est là pour qu'un silence puisse être **prouvé** — sans lui,
  /// un rapporteur qui n'enverrait plus rien du tout passerait pour un
  /// rapporteur discret.
  @visibleForTesting
  Object? lastFailure;

  @override
  Future<bool> report(PlaybackProgressReport report) async {
    // **Un invité n'a pas de progression serveur** : la route est sous le seul
    // guard `api` (server-portal, `app/mediatheque/routes.ts`), donc un jeton
    // d'appareil y prend un 401 à coup sûr — et chaque 401 coûte en plus un
    // renouvellement de jeton et un rejeu. Sans ce garde, un invité qui
    // écoutait un enseignement envoyait des milliers de requêtes à l'heure.
    // Sa progression reste locale, et la fusion de la connexion la porte au
    // compte. « Rien à envoyer » se rend comme un rapport parti : il n'y a rien
    // à retenter.
    if (!await _carriesMemberToken()) return true;
    try {
      await _api.dio.post<void>(
        '/teachings/${report.contentId}/progress',
        data: playbackProgressPayload(report),
      );
      lastFailure = null;
      return true;
    } on DioException catch (e) {
      // Avalé, délibérément : voir l'en-tête de cette classe. L'échec se
      // retente au déclencheur suivant — pause, sortie, complétion, ou les
      // trente secondes de temps joué d'après. Le `false` rendu est tout ce que
      // l'appelant en apprend : de quoi retenter, jamais de quoi composer une
      // phrase à l'écran.
      lastFailure = e;
      return false;
    }
  }

  /// Un porteur absent est un invité, comme pour `UnauthorizedInterceptor`.
  Future<bool> _carriesMemberToken() async =>
      await _api.readToken() != null &&
      await _api.readTokenKind() == AuthTokenKind.member;
}

/// **Le corps du rapport**, en `camelCase`.
///
/// Trois clés, et pas une de plus : le validateur serveur est
/// `{ id: uuidV7(), positionSeconds: number().min(0), completed: boolean().optional() }`,
/// et VineJS refuserait chaque clé écrite en `snake_case`. `teachingId` n'y est
/// **pas** — il voyage dans le chemin de la route.
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester testable
/// sans réseau : `flutter test` répond 400 à tout accès réel.
@visibleForTesting
Map<String, Object?> playbackProgressPayload(PlaybackProgressReport report) {
  return <String, Object?>{
    'id': report.progressId,
    'positionSeconds': report.positionSeconds,
    // Envoyé explicitement bien qu'optionnel côté serveur : l'omettre
    // signifierait `false` de toute façon, mais dire « pas terminé » et « je ne
    // me prononce pas » de la même façon rendrait indistinguables un client qui
    // décide et un client qui ne sait pas.
    'completed': report.completed,
  };
}
