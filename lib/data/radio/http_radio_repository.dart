/// **La route publique d'antenne, côté client.**
///
/// ```
/// GET /radio/antenna
/// aucune garde — les invités écoutent (décision 7 du cadrage)
/// 200 → { data: { streamUrl: "https://…/antenne/index.m3u8", onAir: true,
///                  listeners: 128 | null, live: { startedAt } | null } }
/// ```
///
/// Deux choses dont cette classe **n'a pas** à s'occuper, traitées une fois dans
/// `ApiClient` : l'enveloppe `data` (déballée par un intercepteur — le corps
/// arrive ici à plat) et la conséquence du **401**. Un 401 n'a de toute façon rien
/// à dire ici : la route est publique, et le porteur d'appareil part quand même
/// sur toutes les requêtes.
///
/// ⚠️ **Ni le chemin ni les clés ne sont tranchés** : `server-portal#493` écrit la
/// route en parallèle de cette tranche, et son cadrage ne nomme que ce qu'elle
/// rend (« l'URL publique du flux et un booléen d'antenne »). Ce fichier porte
/// donc **l'hypothèse**, à un seul endroit, et la PR dit sur quoi elle s'est
/// réglée :
///
/// - le **chemin** suit les sept routes `/radio/*` déjà servies au diffuseur
///   (`app/radio/routes.ts`), hors `/admin/` et sans `middleware.auth()` ;
/// - les **clés** suivent la convention REST du serveur — corps en `camelCase`
///   de bout en bout (le `snake_case` n'y concerne que les query strings et
///   l'enveloppe `/sync`) ; `RadioAntenna.fromJson` accepte en plus une poignée
///   de synonymes nommés, pour qu'un mot deviné de travers ne rende pas la radio
///   muette en silence.
///
/// Le jour où la route est fusionnée : une constante et un tableau de synonymes
/// à réduire, et rien d'autre dans tout le dépôt.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'radio_antenna.dart';
import 'radio_repository.dart';

/// Le chemin de la route publique d'antenne — **l'hypothèse de cette tranche**.
///
/// Écrit ici, une seule fois, et nulle part ailleurs : c'est ce qui rend la
/// réconciliation avec `server-portal#493` une édition d'une ligne.
const String kRadioAntennaPath = '/radio/antenna';

class HttpRadioRepository implements RadioRepository {
  HttpRadioRepository({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  /// **Lève telle quelle la [DioException]**, sans la traduire en code de
  /// domaine.
  ///
  /// C'est une rupture assumée avec `HttpCalendarRepository`, qui range ses
  /// échecs dans un `CalendarErrorCode` : ici, l'échec de la route et l'échec du
  /// lecteur doivent se ranger dans **les deux mêmes phrases**, et c'est
  /// `classifyRadioFailure` qui en décide — pour les deux. Traduire ici donnerait
  /// deux tables de correspondance à tenir d'accord, et la seconde n'a pas de
  /// `DioException` à lire.
  /// Le corps est lu en `dynamic` et non en `Map<String, dynamic>`, et ce n'est
  /// pas de la prudence de style : **une page HTML servie à la place d'une
  /// réponse** — proxy mal configuré, portail captif qui répond 200 — ferait
  /// lever un `CastError` dont le message ne dit rien de la cause, et l'auditeur
  /// lirait « vérifiez votre connexion » devant un serveur qui a parfaitement
  /// répondu. Un corps illisible rend [RadioAntenna.unknown], donc aucune URL,
  /// donc « antenne indisponible » — la phrase juste.
  @override
  Future<RadioAntenna> antenna() async {
    final res = await _client.get<dynamic>(kRadioAntennaPath);
    final body = res.data;
    if (body is! Map) return RadioAntenna.unknown;
    return RadioAntenna.fromJson(body.cast<String, dynamic>());
  }
}
