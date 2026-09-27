/// **La remontée d'écoute** — `POST /teachings/:teachingId/plays`.
///
/// C'est de la **mesure d'audience**, et c'est tout ce que c'est. Elle est
/// délibérément **séparée** de la reprise de lecture
/// (`POST /teachings/:teachingId/progress`), et la séparation n'est pas une
/// commodité d'implémentation :
///
/// | | reprise de lecture | écoute comptée |
/// |---|---|---|
/// | à qui ça sert | au fidèle, c'est **son** confort | à l'église, c'est une **statistique** |
/// | porteur | un compte | un compte **ou** un appareil anonyme |
/// | durée de vie | celle du compte | celle de la mesure |
/// | RGPD | donnée personnelle, effacée avec le compte | donnée d'usage, agrégée |
/// | fréquence | cinq déclencheurs par écoute | **une fois** par ouverture |
///
/// Les fondre donnerait un seul appel qui porte deux régimes de conservation,
/// et une suppression de compte qui efface des chiffres d'audience.
///
/// ## Le silence, plus strict qu'ailleurs
///
/// La reprise de lecture est muette parce qu'une erreur pendant un prêche est
/// une panne. La remontée d'écoute l'est pour une raison de plus : **personne
/// ne l'a demandée**. Le fidèle n'attend rien d'elle, il ne saurait même pas
/// quoi faire d'un message d'échec. Un envoi perdu coûte **une unité dans un
/// compteur** — c'est le coût le plus bas de toute l'application.
///
/// [PlayReporter.report] rend donc un booléen — *parti* / *pas parti* — et
/// jamais autre chose. Il n'existe que pour décider s'il faut **classer
/// l'événement pour plus tard** (voir `play_spool.dart`) ; il ne compose aucune
/// phrase à l'écran, et aucun écran ne le lit.
library;

/// **Ce qui poste une écoute**, et rien d'autre.
///
/// Séparé de [PlayTracker] (`play_tracker.dart`) comme
/// `HttpPlaybackProgressReporter` est séparé de `PlaybackProgressRecorder` : le
/// *quand* est une décision de produit qui se relit, le *comment* est une
/// requête HTTP qui se double dans un test.
abstract interface class PlayReporter {
  /// Signale une écoute de [contentId] — enseignement **ou** rassemblement :
  /// les deux familles sont la même table côté serveur, discriminée par
  /// `family`, et passent par la même route.
  ///
  /// Ne lève **jamais**. Rend `true` si le serveur a pris l'événement, `false`
  /// s'il s'est perdu.
  ///
  /// **`true` ne veut pas dire « compté ».** Le serveur déduplique au plus une
  /// écoute par porteur, par contenu et par jour, et répond `200` avec
  /// `counted: false` sur un rejeu. Ce booléen-ci ne dit que « l'événement est
  /// arrivé à destination » — ce qui est exactement ce qu'il faut savoir pour
  /// décider de retenter, et rien de plus. Lire `counted` ici donnerait au
  /// client une opinion sur un chiffre qui ne lui appartient pas.
  Future<bool> report(String contentId);
}

/// Rapporteur **inerte** : il accepte tout et n'envoie rien.
///
/// Le défaut du mode maquette (`AppEnv.useBackend == false`). Rend `true` —
/// « c'est parti » — délibérément : sans backend il n'y a rien à retenter, et
/// rendre `false` remplirait la file d'attente d'événements qui ne partiront
/// jamais. Même raisonnement que `_InertPlaybackProgressReporter`.
class InertPlayReporter implements PlayReporter {
  const InertPlayReporter();

  @override
  Future<bool> report(String contentId) async => true;
}
