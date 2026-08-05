import '../../models/models.dart';
import '../sample_data.dart';

/// Nature d'un échec de chargement des enseignements.
///
/// Ces codes existent pour une seule raison : **un écran vide parce que le
/// réseau a coupé ne se dit pas comme un serveur en panne, ni comme une
/// session expirée**. `AppErrorState` distingue déjà `stateErrorMessage`
/// (réseau) de `stateErrorServerMessage` (serveur) ; c'est l'écran qui choisit
/// le texte, mais il ne peut choisir que si la couche données lui dit **quoi**
/// a échoué. D'où un code, jamais un `DioException` remonté brut ni un message
/// déjà rédigé ici.
enum TeachingErrorCode {
  /// Le serveur n'a **pas répondu** : coupure, DNS, timeout, TLS.
  network,

  /// **401** — le token n'est plus valide (révoqué, ou 90 jours d'inactivité).
  ///
  /// Distinct de [server] : la purge du token et le retour à `/auth` ont déjà
  /// été déclenchés globalement par `UnauthorizedInterceptor`. L'écran n'a donc
  /// pas à proposer « Réessayer » comme si ça pouvait marcher.
  unauthorized,

  /// Le serveur a répondu, mais en erreur (5xx, 422, 404…). Il est joignable :
  /// ce n'est pas la connexion du lecteur qui est en cause.
  server,

  /// Ni l'un ni l'autre (requête annulée, cas non prévu).
  unknown,
}

/// Échec de chargement des enseignements, tel que le voit l'appelant.
class TeachingException implements Exception {
  TeachingException(this.code, [this.message]);

  final TeachingErrorCode code;

  /// Message **déjà localisé par le serveur** quand il en a fourni un.
  ///
  /// À réserver au diagnostic : les écrans affichent les clés `stateError*`,
  /// écrites pour un non-technicien. Un message serveur n'est pas un texte
  /// d'interface.
  final String? message;

  @override
  String toString() => 'TeachingException(${code.name}'
      '${message == null ? '' : ': $message'})';
}

/// Médiathèque — **repository dédié et asynchrone**.
///
/// Hors de [ChurchRepository] à dessein : ce contrat-là est **synchrone** et ne
/// couvre plus que des domaines fictifs. Le passer en `Future` pour brancher la
/// médiathèque casserait les autres d'un coup. Le motif du dépôt est l'inverse :
/// un domaine servi par le back **sort** vers sa propre abstraction, comme
/// `AuthRepository`, `BranchRepository` et `CalendarRepository` avant lui.
abstract interface class TeachingRepository {
  /// Enseignements publiés, du plus récent au plus ancien.
  ///
  /// [limit] plafonne le nombre d'éléments — 20 par défaut, 50 maximum.
  ///
  /// Lève une [TeachingException] : réseau, 401 et erreur serveur se
  /// distinguent par [TeachingException.code].
  Future<List<Teaching>> teachings({int limit = 20});
}

/// Implémentation **en mémoire** : aucun réseau, aucun plugin.
///
/// Deux usages, un seul code : le mode maquette (`AppEnv.useBackend` faux) et
/// les tests. Les données viennent de [SampleData.teachings] par défaut.
///
/// Le tri imite le serveur : du plus récent ([Teaching.publishedAt] décroissant)
/// au plus ancien. Le plafond [limit] est borné entre 1 et 50 (`clamp`).
class InMemoryTeachingRepository implements TeachingRepository {
  InMemoryTeachingRepository({List<Teaching>? teachings})
      : _teachings = teachings ?? SampleData.teachings;

  final List<Teaching> _teachings;

  @override
  Future<List<Teaching>> teachings({int limit = 20}) async {
    // Miroir du serveur : du plus récent (publishedAt) au plus ancien.
    final sorted = [..._teachings]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final clamped = limit.clamp(1, 50);
    return List<Teaching>.unmodifiable(
      sorted.length > clamped ? sorted.sublist(0, clamped) : sorted,
    );
  }
}
