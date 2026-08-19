import 'package:flutter/foundation.dart';

import 'media_preferences.dart';

/// **Le contrat de téléchargement hors ligne d'un enseignement** (ADR-0038).
///
/// C'est la contrepartie client de `teachings.download` (JSONB serveur,
/// `app/mediatheque/support/download_info.ts`) : ce que l'enseignement porte
/// pour être **écouté hors ligne** — l'identité du transcodage, la durée, et
/// une entrée par qualité produite (URL absolue stable + taille en octets).
///
/// Ces métadonnées transitent dans le flux de synchronisation et se rangent
/// dans le magasin **en même temps** que `playlistUrl` (ADR-0038, ADR-0034) :
/// le moteur de téléchargement connaît donc URLs et tailles **avant de toucher
/// au réseau**, ce qui rend possibles le pourcentage de progression, la
/// validation de reprise `Range` et le pré-check d'espace disque — trois usages
/// qui n'ont pas d'autre source.
///
/// **On stocke ce que le serveur envoie** (ADR-0026, décision 3) : l'objet
/// entier, la carte `renditions` complète — jamais la seule qualité choisie, qui
/// dépend d'un réglage que le fidèle peut changer.
///
/// [version] recopie l'identité du transcode : c'est **la** valeur que le mobile
/// lit pour distinguer une **révision** (la version change sur un enseignement
/// complet livré par la sync → garder le fichier, proposer la mise à jour) d'un
/// **retrait** (une rétractation `{id, deletedAt}` → purger). Deux gestes
/// opposés, un seul signal chacun (ADR-0039). Le cycle de vie badge/purge est le
/// périmètre de #194 ; ici on ne fait que **stocker** de quoi le trancher.
@immutable
class TeachingDownload {
  const TeachingDownload({
    required this.version,
    required this.durationSeconds,
    required this.renditions,
  });

  /// L'identité du transcodage (`id` du webhook côté serveur). La clé de
  /// « révision ≠ retrait » (ADR-0039).
  final String version;

  /// La durée de l'enseignement, **en secondes**. Même unité que le contrat
  /// serveur (`duration`) ; la convertir en [Duration] appartient à la lecture.
  final int durationSeconds;

  /// Une entrée par qualité produite. Clés d'aujourd'hui : `low` (64k),
  /// `mid` (128k), `high` (192k) — les mêmes que [MediaQuality.key], recopiées
  /// mot pour mot de l'échelle du transcodeur. Une clé inconnue est **conservée
  /// telle quelle** : le choix et le repli appartiennent à la lecture, pas au
  /// stockage.
  final Map<String, DownloadRendition> renditions;

  Duration get duration => Duration(seconds: durationSeconds);

  /// La rendition **exactement** de cette qualité, ou `null`.
  ///
  /// [MediaQuality.auto] n'a pas de fichier propre : le téléchargement se fait
  /// toujours à une qualité concrète (le réglage « Téléchargement » a pour
  /// défaut `mid`). Résoudre `auto` en un palier concret appartient à l'appelant
  /// (`DownloadManager`), pas à ce modèle.
  DownloadRendition? renditionFor(MediaQuality quality) =>
      renditions[quality.key];

  @override
  bool operator ==(Object other) =>
      other is TeachingDownload &&
      other.version == version &&
      other.durationSeconds == durationSeconds &&
      mapEquals(other.renditions, renditions);

  @override
  int get hashCode => Object.hash(
        version,
        durationSeconds,
        Object.hashAllUnordered(
          renditions.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// Un fichier `.aac` téléchargeable : son URL et sa taille.
@immutable
class DownloadRendition {
  const DownloadRendition({required this.url, required this.bytes});

  /// L'URL **absolue et stable** du fichier `.aac`, versionnée par
  /// `transcodeId` (streaming ADR-0009) et répondant au `Range` de bout en bout.
  final String url;

  /// La taille **en octets** du fichier. Sa seule source : le streaming-service
  /// la connaît en produisant le fichier (ADR-0038). Elle sert au pourcentage,
  /// à la validation de reprise `Range` et au pré-check d'espace disque.
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is DownloadRendition && other.url == url && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(url, bytes);
}
