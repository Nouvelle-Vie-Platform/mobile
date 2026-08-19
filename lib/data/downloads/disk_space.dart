import 'dart:io';

/// **L'espace disque libre**, derrière une abstraction — pour la même raison que
/// tout le reste : le pré-check d'espace (F9) doit se vérifier sur la VM Dart,
/// et les tests posent un [FixedDiskSpace].
///
/// Le contrat est délibérément lâche : [freeBytes] rend `null` quand la valeur
/// est **inconnue**. Le manager traite l'inconnu en **fail-open** — il laisse
/// passer plutôt que de bloquer un téléchargement sur une plateforme qu'on ne
/// sait pas mesurer. Un pré-check qui bloque à tort est pire qu'un pré-check
/// absent : le disque plein se rattrape en cours (échec disque → `failed` +
/// partiel conservé), une donnée manquante ne doit pas condamner la fonction.
abstract interface class DiskSpace {
  /// Les octets libres à l'endroit où les téléchargements sont stockés, ou
  /// `null` si la plateforme ne le dit pas.
  Future<int?> freeBytes();
}

/// L'implémentation réelle — best-effort.
///
/// **Il n'existe aujourd'hui aucune API Dart multiplateforme** pour l'espace
/// libre : `dart:io` ne l'expose pas, et y répondre exigerait un canal natif par
/// plateforme. Plutôt que d'ajouter une dépendance pour un socle, cette
/// implémentation rend `null` (inconnu) — le manager laisse alors passer, et la
/// **logique** de pré-check, elle, est complète et testée. Câbler une vraie
/// mesure (plugin, canal de méthode) est un point laissé ouvert, sans toucher au
/// manager : il suffira de faire rendre un nombre à [freeBytes].
class BestEffortDiskSpace implements DiskSpace {
  const BestEffortDiskSpace();

  @override
  Future<int?> freeBytes() async {
    // Placeholder honnête : inconnu. Voir l'en-tête — on ne devine pas, on ne
    // bloque pas. `Directory` est importé pour l'implémentation future (statvfs
    // via canal natif) ; le laisser ici documente où la mesure se branchera.
    // ignore: unused_local_variable
    final _ = Directory.systemTemp;
    return null;
  }
}

/// Espace **figé**, pour les tests : le pré-check se prouve sans disque réel.
class FixedDiskSpace implements DiskSpace {
  const FixedDiskSpace(this.free);

  /// Octets libres à annoncer, ou `null` pour simuler l'inconnu.
  final int? free;

  @override
  Future<int?> freeBytes() async => free;
}
