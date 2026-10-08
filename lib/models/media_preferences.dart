import 'package:flutter/foundation.dart';

/// **Les usages réglables** de la médiathèque, et la radio.
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

  /// **New Life Radio.** Le seul usage qui ne se règle pas sur l'échelle des
  /// enseignements : ses choix sont [RadioQuality], lus par
  /// [MediaPreferences.radio] et non par [MediaPreferences.of].
  radio('radio'),

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

/// **Les deux choix de la radio** (décisions 4 et 10 du plan
/// `server-portal/docs/radio-adaptative-plan.md`).
///
/// Un type à lui et non [MediaQuality], parce que ni l'échelle ni la règle ne
/// sont les mêmes : l'antenne a ses propres paliers (32 / 64 / 128 k, écrits par
/// liquidsoap), aucun choix « 192 k » n'y aurait de sens, et son automatique est
/// adaptatif **partout** — y compris en données mobiles, là où celui des
/// enseignements bride à 64 k. Réutiliser [MediaQuality] aurait offert trois
/// paliers sans rendu derrière, et laissé [effectiveBitrateCap] brider la radio
/// en 4G à l'encontre de la décision 10.
enum RadioQuality {
  /// Le défaut : `master.m3u8`, le lecteur choisit le palier (ABR natif), en
  /// wifi comme en données mobiles.
  auto('auto', 128000),

  /// **Bloquée sur le palier 32 k** — l'URL économie que rend la route
  /// d'antenne (`ecoStreamUrl`).
  economy('economy', 32000);

  const RadioQuality(this.key, this.bitsPerSecond);

  /// Clé de rangement, stable pour la même raison que [MediaUsage.key].
  final String key;

  /// Le débit **le plus haut** que ce choix peut consommer : le palier haut de
  /// l'antenne pour [auto], le seul palier pour [economy].
  final int bitsPerSecond;

  /// Coût d'une heure au pire, arrondi comme [MediaQuality.megabytesPerHour] :
  /// 14 Mo pour [economy], 58 pour [auto].
  int get megabytesPerHour => (bitsPerSecond * 3600 / 8 / 1000000).round();

  /// Tolérante comme [MediaQuality.parse] : l'inconnu rend [auto].
  static RadioQuality parse(String? raw) {
    for (final value in RadioQuality.values) {
      if (value.key == raw) return value;
    }
    return RadioQuality.auto;
  }
}

/// L'état des réglages média, tel qu'un écran le lit.
@immutable
class MediaPreferences {
  const MediaPreferences({
    this.streaming = MediaQuality.auto,
    this.live = MediaQuality.auto,
    this.download = MediaQuality.auto,
    this.downloadOnCellular = false,
    this.radio = RadioQuality.auto,
  });

  final MediaQuality streaming;
  final MediaQuality live;
  final MediaQuality download;

  /// **Télécharger en données mobiles** (F8). Un booléen, distinct des trois
  /// qualités : il ne dit rien du débit, seulement du **réseau autorisé** pour
  /// les téléchargements. Défaut **`false`** — wifi seulement, pour ne pas
  /// consommer le forfait d'un fidèle sans qu'il l'ait choisi. C'est cette
  /// valeur qui alimente `DownloadManager.mobileDataAllowed`.
  final bool downloadOnCellular;

  /// Le choix de la radio — voir [RadioQuality].
  final RadioQuality radio;

  /// Le palier d'un usage **de l'échelle des enseignements**. La radio n'y est
  /// pas : elle se lit par [radio], et la demander ici est une erreur d'appel.
  MediaQuality of(MediaUsage usage) => switch (usage) {
        MediaUsage.streaming => streaming,
        MediaUsage.live => live,
        MediaUsage.download => download,
        MediaUsage.radio => throw ArgumentError.value(
            usage, 'usage', 'la radio se lit par MediaPreferences.radio'),
      };

  @override
  bool operator ==(Object other) =>
      other is MediaPreferences &&
      other.streaming == streaming &&
      other.live == live &&
      other.download == download &&
      other.downloadOnCellular == downloadOnCellular &&
      other.radio == radio;

  @override
  int get hashCode =>
      Object.hash(streaming, live, download, downloadOnCellular, radio);
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
