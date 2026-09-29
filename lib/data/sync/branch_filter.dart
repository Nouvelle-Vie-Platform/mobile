/// **Les collections que la préférence de branche filtre** — quatre, et la
/// liste est écrite **une seule fois**, ici.
///
/// `branch_id` est un paramètre de `GET /sync` et de `GET /sync/{collection}`.
/// C'est un **filtre d'affichage, jamais une autorisation** : une branche
/// inconnue rend **422**, jamais 403, et sans paramètre **toutes** les branches
/// arrivent. Rien de ce que le client fait ici ne peut lui donner accès à quoi
/// que ce soit : il peut seulement s'en priver.
///
/// C'est exactement ce qui autorise à confier au client le nettoyage que le
/// serveur ne fait pas — voir `branch_scope_store.dart`.
///
/// ## Pourquoi une liste et non un drapeau par collection
///
/// La liste sert **trois** consommateurs qui doivent être d'accord au caractère
/// près : ce que `SyncApi` envoie, ce que `SyncEngine` filtre, et ce que le
/// magasin remet à zéro quand la préférence change. Trois copies seraient trois
/// occasions d'en oublier une — et l'oubli le plus coûteux n'échouerait nulle
/// part, il laisserait simplement des lignes hors périmètre à l'écran.
///
/// ## Ce qui n'y est pas, et n'y entrera pas
///
/// - **`events`** (l'agenda) et le **mur de prière** : le serveur y garde son
///   propre cloisonnement, et un filtre client par-dessus le sien donnerait
///   deux règles pour une. Ni l'un ni l'autre n'est d'ailleurs une collection
///   répliquée de ce client — l'agenda a sa route REST, qui porte son propre
///   `branch_id` (`HttpCalendarRepository`) et qui n'a rien à voir avec cette
///   préférence-ci ;
/// - **`official_account_memberships`** : elle est scopée sur l'acteur, pas sur
///   une branche. La filtrer par branche retirerait à quelqu'un ses propres
///   appartenances ;
/// - **`branches`, `teaching_types`, `gathering_types`, `contributors`,
///   `status_backgrounds`, `legal_documents`** : des référentiels. Filtrer
///   `branches` serait particulièrement drôle — la liste où l'on choisit sa
///   branche ne contiendrait plus que celle qu'on a choisie ;
/// - **`playback_progress`** : une collection `private`. C'est *ma* progression,
///   elle ne relève d'aucune branche ;
/// - **`teaching_guests`** (#77) : un **pivot**, `partition: 'reference'` côté
///   serveur — il ne porte pas de `branch_id`. Le filtrer exigerait une jointure
///   sur son parent pour un résultat que le client obtient gratuitement en
///   joignant contre sa copie de `teachings` : un crédit dont l'enseignement a
///   été filtré ne s'affiche nulle part, puisque c'est l'enseignement qui ouvre
///   l'écran. La contrepartie est assumée — quelques lignes de pivot de contenus
///   qu'un appareil n'affichera pas, deux identifiants et un rang.
library;

import '../local/sync_dao.dart';

/// Les quatre collections filtrées par `branch_id`, et la raison de chacune.
///
/// - [SyncCollectionKey.teachings] / [SyncCollectionKey.gatherings] — les deux
///   familles de contenu : un prêche et un concert appartiennent à une
///   assemblée ;
/// - [SyncCollectionKey.announcements] — le mur de statuts, publié sous un
///   compte d'église lui-même rattaché à une branche ;
/// - [SyncCollectionKey.officialAccounts] — ces comptes eux-mêmes. Elle est
///   dans la liste **parce que** les annonces y sont : garder des comptes dont
///   plus aucune annonce n'arrive laisserait un référentiel qui grossit sans
///   rien peindre, et le retirer de la liste sans retirer les annonces
///   afficherait des statuts **sans en-tête**, ce qu'un fidèle lit comme une
///   donnée perdue.
const List<String> kBranchScopedCollections = [
  SyncCollectionKey.officialAccounts,
  SyncCollectionKey.teachings,
  SyncCollectionKey.gatherings,
  SyncCollectionKey.announcements,
];

/// Cette collection est-elle filtrée par la préférence de branche ?
bool isBranchScoped(String collectionKey) =>
    kBranchScopedCollections.contains(collectionKey);
