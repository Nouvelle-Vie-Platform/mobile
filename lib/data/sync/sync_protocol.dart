/// **Les formes du protocole delta, telles que le serveur les sert.**
///
/// Deux règles de casse cohabitent, et c'est voulu (PRD §2.1) :
///
/// - **enveloppe et protocole en `snake_case`** — `scope_version`,
///   `current_cursor`, `has_changes`, `from_zero`, `full_resync_required`,
///   `next_cursor`, `has_more`, `full_resync` ; c'est ce fichier ;
/// - **lignes en `camelCase`** — `ownerId`, `branchId`, `visibleOnHome`,
///   `deletedAt` ; c'est `sync_rows.dart`.
///
/// Un désérialiseur à convention unique se trompe sur la moitié des clés : les
/// deux conventions vivent donc dans deux fichiers, et jamais dans une fonction
/// commune qui « normaliserait » les noms.
///
/// La lecture est **tolérante** partout où l'inconnu est possible : une
/// partition non prévue, une clé de collection non prévue, un `items` absent.
/// Un client qui lève sur une nouveauté du serveur est un client qui cesse de
/// synchroniser le jour d'un déploiement.
library;

import 'package:flutter/foundation.dart';

/// Périmètre dont relève une collection (`GET /sync`, champ `partition`).
///
/// Elle n'est pas décorative : le garde-fou « périmètre modifié » ne lève
/// `full_resync_required` que sur les collections [branch] — une privée
/// (`user_id = soi`) et un référentiel ne dépendent pas du périmètre visible.
/// Le client n'a pourtant **pas** à recalculer cette règle : il obéit au
/// drapeau, collection par collection. La partition n'est lue ici que pour le
/// diagnostic et pour les tests.
enum SyncPartition {
  branch,
  private,
  reference,

  /// Partition que ce client ne connaît pas encore. Le serveur peut en
  /// introduire une ; ce n'est pas une raison d'échouer une synchronisation.
  unknown;

  static SyncPartition parse(Object? raw) => switch (raw) {
        'branch' => SyncPartition.branch,
        'private' => SyncPartition.private,
        'reference' => SyncPartition.reference,
        _ => SyncPartition.unknown,
      };
}

/// Une entrée du manifeste — l'état d'**une** collection vu par le serveur.
@immutable
class ManifestEntry {
  const ManifestEntry({
    required this.key,
    required this.partition,
    required this.currentCursor,
    required this.hasChanges,
    required this.fromZero,
    required this.fullResyncRequired,
  });

  factory ManifestEntry.fromJson(Map<String, Object?> json) => ManifestEntry(
        key: json['key']! as String,
        partition: SyncPartition.parse(json['partition']),
        currentCursor: json['current_cursor'] as String?,
        hasChanges: json['has_changes'] == true,
        fromZero: json['from_zero'] == true,
        fullResyncRequired: json['full_resync_required'] == true,
      );

  /// Clé de collection du protocole (`teachings`, `teaching_types`, …).
  final String key;

  final SyncPartition partition;

  /// Curseur de la dernière ligne **visible dans le périmètre de l'acteur** :
  /// la borne haute du périmètre, **pas un accusé de réception**.
  ///
  /// Le client ne l'adopte jamais comme sien : seul un `next_cursor` rendu par
  /// un tirage, appliqué avec ses lignes, a le droit de devenir le curseur
  /// local (ADR-0026).
  final String? currentCursor;

  /// `false` = rien à tirer pour cette collection.
  final bool hasChanges;

  /// `true` = le client n'a présenté aucun curseur pour cette collection.
  final bool fromZero;

  /// Resync complet réclamé — curseur périmé (toute partition) ou périmètre
  /// modifié (collections `branch` seulement), combinés en OU par le serveur.
  final bool fullResyncRequired;
}

/// Réponse de `GET /sync`.
@immutable
class SyncManifest {
  const SyncManifest({required this.scopeVersion, required this.collections});

  factory SyncManifest.fromJson(Map<String, Object?> json) {
    final raw = json['collections'];
    return SyncManifest(
      scopeVersion: json['scope_version'] as int?,
      collections: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map)
              ManifestEntry.fromJson(entry.cast<String, Object?>()),
      ],
    );
  }

  /// Version de périmètre **courante du porteur**, jamais l'écho de celle
  /// transmise (ADR-0027). Le client la retient en mémoire pendant tout le
  /// cycle et ne la persiste qu'après ; voir `SyncEngine`.
  final int? scopeVersion;

  /// Les treize collections du registre, pas seulement celles qui ont bougé.
  final List<ManifestEntry> collections;

  /// L'entrée de [key], ou `null` si le serveur ne connaît pas cette
  /// collection — ce qui arrive pendant qu'un client devance le registre.
  ManifestEntry? entryFor(String key) {
    for (final entry in collections) {
      if (entry.key == key) return entry;
    }
    return null;
  }
}

/// Réponse de `GET /sync/{collection}` — une page de tirage.
@immutable
class DeltaPage {
  const DeltaPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.fullResync,
  });

  factory DeltaPage.fromJson(Map<String, Object?> json) {
    final raw = json['items'];
    return DeltaPage(
      items: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) item.cast<String, Object?>(),
      ],
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] == true,
      fullResync: json['full_resync'] == true,
    );
  }

  /// Les éléments **bruts**, jamais désérialisés ici : chacun est soit une
  /// ligne, soit une rétractation, et c'est [readsAsRetraction] qui tranche.
  final List<Map<String, Object?>> items;

  /// Position de la dernière ligne livrée. Sur une page vide il **conserve** le
  /// curseur entrant ; il vaut `null` sur un tirage depuis zéro d'une
  /// collection vide, et sur un `full_resync`.
  final String? nextCursor;

  /// `true` = reboucler. C'est ce drapeau qui arrête la boucle, jamais un
  /// tableau vide.
  final bool hasMore;

  /// **Un resync forcé se lit dans un `200`, jamais dans une erreur.**
  ///
  /// Avec `items` vide et `has_more` faux, la page ressemble trait pour trait à
  /// « rien de neuf » : seul ce drapeau les sépare. Un client qui ne lit que
  /// `items` garde indéfiniment un cache dont il a raté des suppressions, et
  /// rien ne le réveillera — le serveur répondra la même chose au tour suivant.
  final bool fullResync;
}

/// **« Rétractation ou ligne », décidé avant toute construction d'objet.**
///
/// Un élément du flux `teachings` vaut soit un enseignement complet, soit une
/// rétractation réduite à `{ id, deletedAt }` (ADR-0025) ; les autres
/// collections envoient leurs tombstones avec toutes leurs colonnes. Un seul
/// mécanisme create/update/delete, deux formes de charge utile.
///
/// C'est la **seule** question posée à un élément avant de le désérialiser. Un
/// `fromJson` unique et strict, qui exige `title`, `recordedAt` et `color`,
/// lèverait sur la première rétractation reçue — et emporterait toute la page,
/// lignes valides comprises.
bool readsAsRetraction(Map<String, Object?> item) => item['deletedAt'] != null;
