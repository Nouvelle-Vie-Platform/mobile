import 'package:flutter/foundation.dart';

/// **Les trois usages réglables** de la médiathèque.
///
/// Deux d'entre eux ne pilotent rien aujourd'hui, et c'est assumé : le direct
/// est un écran sans lecteur (`LiveScreen` affiche une vignette décorative), et
/// le téléchargement n'existe pas — `docs/mediatheque-en-ligne.md` §2 en fait un
/// refus **documenté**, pas un reste-à-faire. Leur préférence est néanmoins
/// enregistrée : le jour où l'un des deux existera, le réglage sera déjà là et
/// il n'y aura rien à changer ici.
enum MediaUsage {
  /// L'écoute d'un enseignement ou d'un rassemblement. **Le seul branché.**
  streaming('streaming'),

  /// Le direct. Sans effet tant que `LiveScreen` n'a pas de lecteur.
  live('live'),

  /// Le téléchargement. Sans effet, et sans fonction derrière.
  download('download');

  const MediaUsage(this.key);

  /// Clé de rangement dans `app_settings`. Stable : la renommer changerait le
  /// réglage de tous les appareils déjà installés en un défaut silencieux.
  final String key;
}

/// **Un palier de l'échelle du serveur**, ou le choix de le laisser décider.
///
/// Les trois débits ne sont pas inventés ici : ils reprennent exactement les
/// trois rendus que le transcodeur produit
/// (`streaming-service/app/transcodes/support/hls.ts`) — `low 64k`, `mid 128k`,
/// `high 192k`, AAC, **audio seul**. Ajouter une valeur ici sans l'ajouter
/// là-bas donnerait un plafond qu'aucun rendu ne peut satisfaire, et le lecteur
/// retomberait silencieusement sur le palier le plus bas disponible.
enum MediaQuality {
  /// Le défaut. **`low` en données mobiles, adaptatif en wifi.**
  ///
  /// Le seul réglage qui distingue les deux réseaux — les trois autres
  /// s'appliquent partout, parce que les avoir choisis est un choix explicite
  /// qu'on n'a pas à corriger dans le dos de qui l'a fait.
  auto('auto', null),

  low('low', 64000),
  mid('mid', 128000),
  high('high', 192000);

  const MediaQuality(this.key, this.bitsPerSecond);

  /// Clé de rangement, stable pour la même raison que [MediaUsage.key].
  final String key;

  /// Plafond à poser sur le lecteur, en bits par seconde. `null` pour [auto] :
  /// il n'y a pas de plafond fixe, c'est le transport qui décide.
  final int? bitsPerSecond;

  /// Coût approximatif d'une heure d'écoute, en mégaoctets.
  ///
  /// Sert la phrase d'impact du sélecteur, et c'est **le chiffre qui décide**
  /// dans un contexte où la donnée se compte. Volontairement arrondi : le
  /// surcoût de segmentation HLS (~5 %) et les entêtes réseau rendent une
  /// décimale malhonnête, pas plus précise. [auto] rend le coût de [low] — le
  /// pire cas en données mobiles, qui est celui qu'on veut annoncer.
  int get megabytesPerHour {
    final bits = (bitsPerSecond ?? MediaQuality.low.bitsPerSecond)!;
    return (bits * 3600 / 8 / 1000000).round();
  }

  /// Relit une valeur stockée. **Tolérante** : une clé inconnue — réglage écrit
  /// par une version plus récente, base bricolée — retombe sur [auto] plutôt
  /// que de faire échouer la lecture de tout l'écran.
  static MediaQuality parse(String? raw) {
    for (final value in MediaQuality.values) {
      if (value.key == raw) return value;
    }
    return MediaQuality.auto;
  }
}

/// L'état des trois réglages, tel qu'un écran le lit.
@immutable
class MediaPreferences {
  const MediaPreferences({
    this.streaming = MediaQuality.auto,
    this.live = MediaQuality.auto,
    this.download = MediaQuality.auto,
  });

  final MediaQuality streaming;
  final MediaQuality live;
  final MediaQuality download;

  MediaQuality of(MediaUsage usage) => switch (usage) {
        MediaUsage.streaming => streaming,
        MediaUsage.live => live,
        MediaUsage.download => download,
      };

  @override
  bool operator ==(Object other) =>
      other is MediaPreferences &&
      other.streaming == streaming &&
      other.live == live &&
      other.download == download;

  @override
  int get hashCode => Object.hash(streaming, live, download);
}

/// Le plafond **effectif**, une fois le transport connu.
///
/// C'est ici que vit toute la règle du mode automatique, et à un seul endroit :
/// l'écran l'affiche, le lecteur l'applique, et aucun des deux ne la
/// réinterprète.
///
/// `null` = aucun plafond, le lecteur choisit librement (adaptation HLS).
int? effectiveBitrateCap(MediaQuality quality, {required bool onCellular}) {
  if (quality != MediaQuality.auto) return quality.bitsPerSecond;
  return onCellular ? MediaQuality.low.bitsPerSecond : null;
}
