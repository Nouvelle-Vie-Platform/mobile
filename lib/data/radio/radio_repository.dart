/// **D'où l'application apprend où est l'antenne, et si elle émet.**
///
/// Une route publique légère, derrière une abstraction — le motif de
/// `CalendarRepository` et de `MediathequeRepository`, et pour la raison qui vaut
/// ici plus qu'ailleurs : **la route n'existe pas encore**
/// (`server-portal#493`, lancée en parallèle de #104). Le chemin et la forme de
/// la charge utile sont donc écrits à **un seul endroit**
/// (`http_radio_repository.dart`, `RadioAntenna.fromJson`), et le double de cette
/// interface fait tourner tout le reste — bouton, écran, reprise — sans qu'une
/// ligne d'écran sache qu'il attend un serveur.
library;

import 'radio_antenna.dart';

/// Le contrat : une question, une réponse, aucun état.
///
/// `Future` et non `Stream` : il n'y a **rien à observer** — pas de magasin, pas
/// de flux delta, pas de table. L'état d'antenne est lu **au lancement et au
/// retour à l'écran**, et c'est la fraîcheur retenue par la décision 3 du
/// cadrage, parce que l'information *guide* le geste sans l'interdire.
abstract interface class RadioRepository {
  /// Lit l'état de l'antenne.
  ///
  /// **Lève** quand la route ne répond pas ou répond mal : c'est l'échec
  /// lui-même qui porte la cause, et `classifyRadioFailure` la range dans l'une
  /// des deux phrases. Ne jamais rendre « hors antenne » pour un échec — ce
  /// serait affirmer une panne de l'église là où on n'a rien pu lire.
  Future<RadioAntenna> antenna();
}

/// **Le double : une réponse fixe, aucune socket.**
///
/// Deux emplois, et aucun n'est un bouchon de confort :
///
/// - les **tests** — `pumpScreen` le pose par défaut sur [RadioAntenna.unknown],
///   c'est-à-dire l'état d'une application qui n'a pas encore eu de réponse, et
///   c'est ce qu'un test qui ne parle pas de radio doit voir ;
/// - le **développement sans backend** (`AppEnv.useBackend` faux), où il porte
///   l'URL tranchée le 30/09/2026 dans `mediamtx-service/README.md`.
///
/// ⚠️ Cette URL-là vit **dans le double, et nulle part ailleurs**. La remettre
/// dans un `const` du chemin de production rendrait à `live_stream_config.dart`
/// le défaut que #104 lui retire : une adresse qu'on ne peut corriger que par une
/// livraison sur les magasins.
class FixedRadioRepository implements RadioRepository {
  const FixedRadioRepository(this._antenna);

  /// L'antenne du développement sans backend : l'adresse tranchée, en ondes.
  ///
  /// Elle ne répond **que depuis `127.0.0.1` sur le VPS** tant que le bloc Caddy
  /// de MediaMTX n'est pas posé (`context#6`) : attendre du son ici, c'est
  /// attendre un geste d'exploitation qui n'a pas eu lieu.
  const FixedRadioRepository.trenched()
      : _antenna = const RadioAntenna(
          streamUrl: 'https://stream.eenv.brainsial.com/antenne/index.m3u8',
          onAir: true,
        );

  final RadioAntenna _antenna;

  @override
  Future<RadioAntenna> antenna() async => _antenna;
}
