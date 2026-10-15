import 'package:flutter/foundation.dart';

/// **Les usages réglables** de la médiathèque, et la radio.
///
/// Le téléchargement ne pilote pas de débit aujourd'hui, et c'est assumé —
/// `docs/mediatheque-en-ligne.md` §2. Sa préférence est néanmoins enregistrée.
///
/// **Le direct (`live`) a été retiré** (#184) : aucun lecteur ne le lisait —
/// l'antenne suit [RadioQuality]. Sa clé `live` peut rester orpheline dans
/// `app_settings` sur les appareils déjà installés : la table est clé/valeur,
/// une ligne que personne ne lit ne coûte rien, et la retirer n'exige donc
/// aucune migration.
enum MediaUsage {
  /// L'écoute d'un enseignement ou d'un rassemblement. **Le seul branché.**
  streaming('streaming'),

  /// **New Life Radio.** Le seul usage qui ne se règle pas sur l'échelle des
  /// enseignements : ses choix sont [RadioQuality], lus par
  /// [MediaPreferences.radio] et non par [MediaPreferences.of].
  radio('radio'),

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

/// **Les quatre choix de la radio** (décisions 4 et 10 du plan
/// `server-portal/docs/radio-adaptative-plan.md`, étendues par #184).
///
/// Un type à lui et non [MediaQuality], parce que ni l'échelle ni la règle ne
/// sont les mêmes : l'antenne a ses propres paliers (16 / 32 / 64 / 128 k,
/// écrits par liquidsoap), aucun choix « 192 k » n'y aurait de sens, et son
/// automatique est adaptatif **partout** — y compris en données mobiles, là où
/// celui des enseignements bride à 64 k. Réutiliser [MediaQuality] aurait
/// offert des paliers sans rendu derrière, et laissé [effectiveBitrateCap]
/// brider la radio en 4G à l'encontre de la décision 10.
///
/// **L'ordre des valeurs est celui de l'arc** du panneau Qualité, du plus
/// économe au plus riche. Les clés, elles, ne bougent pas : `auto` et
/// `economy` existent déjà en base.
enum RadioQuality {
  /// **Bloquée sur le palier 16 k** (HE-AAC v2) — `a16.m3u8`, dérivé.
  minimum('minimum', 16000),

  /// **Bloquée sur le palier 32 k** — l'URL économie que rend la route
  /// d'antenne (`ecoStreamUrl`), sinon `a32.m3u8` dérivé.
  economy('economy', 32000),

  /// Le défaut : `master.m3u8`, le lecteur choisit le palier (ABR natif), en
  /// wifi comme en données mobiles.
  auto('auto', 128000),

  /// **Bloquée sur le palier 128 k** — `a128.m3u8`, dérivé.
  high('high', 128000);

  const RadioQuality(this.key, this.bitsPerSecond);

  /// Clé de rangement, stable pour la même raison que [MediaUsage.key].
  final String key;

  /// Le débit **le plus haut** que ce choix peut consommer : le palier haut de
  /// l'antenne pour [auto], le seul palier pour les trois autres.
  final int bitsPerSecond;

  /// Coût d'une heure au pire, arrondi comme [MediaQuality.megabytesPerHour] :
  /// 7 Mo pour [minimum], 14 pour [economy], 58 pour [auto] et [high].
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
    this.download = MediaQuality.auto,
    this.downloadOnCellular = false,
    this.radio = RadioQuality.auto,
    this.chatMedia = ChatMediaDescent.wifi,
  });

  final MediaQuality streaming;
  final MediaQuality download;

  /// **Télécharger en données mobiles** (F8). Un booléen, distinct des trois
  /// qualités : il ne dit rien du débit, seulement du **réseau autorisé** pour
  /// les téléchargements. Défaut **`false`** — wifi seulement, pour ne pas
  /// consommer le forfait d'un fidèle sans qu'il l'ait choisi. C'est cette
  /// valeur qui alimente `DownloadManager.mobileDataAllowed`.
  final bool downloadOnCellular;

  /// Le choix de la radio — voir [RadioQuality].
  final RadioQuality radio;

  /// **Quand les médias des conversations descendent** (T3, #225) — voir
  /// [ChatMediaDescent]. Rangé ici et non dans un réglage à part parce que
  /// l'écran observe déjà ce flux-là : une seconde source pour un seul
  /// booléen de plus aurait doublé le câblage sans rien ajouter.
  final ChatMediaDescent chatMedia;

  /// Le palier d'un usage **de l'échelle des enseignements**. La radio n'y est
  /// pas : elle se lit par [radio], et la demander ici est une erreur d'appel.
  MediaQuality of(MediaUsage usage) => switch (usage) {
        MediaUsage.streaming => streaming,
        MediaUsage.download => download,
        MediaUsage.radio => throw ArgumentError.value(
            usage, 'usage', 'la radio se lit par MediaPreferences.radio'),
      };

  @override
  bool operator ==(Object other) =>
      other is MediaPreferences &&
      other.streaming == streaming &&
      other.download == download &&
      other.downloadOnCellular == downloadOnCellular &&
      other.radio == radio &&
      other.chatMedia == chatMedia;

  @override
  int get hashCode =>
      Object.hash(streaming, download, downloadOnCellular, radio, chatMedia);
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

/// **Quand les médias d'une conversation descendent sur l'appareil** (T3, #225).
///
/// Un type à part, et **surtout pas le booléen « données mobiles » du
/// téléchargement** : autoriser le forfait pour un enseignement d'une heure
/// qu'on a demandé n'est pas autoriser toutes les vidéos qu'un groupe de
/// quarante personnes publiera demain. Les deux gestes n'ont ni la même taille
/// ni le même consentement — d'où un onglet et une clé à eux.
///
/// L'ordre des valeurs est celui de l'arc, du plus économe au plus dépensier.
enum ChatMediaDescent {
  /// **Rien ne descend tout seul.** Un média reste consultable en ligne, et
  /// n'est gardé que si on l'ouvre.
  never('never'),

  /// **Le défaut** (décision 2 du cadrage) : à la réception, **en wifi
  /// seulement**. Le fil se consulte hors ligne sans un geste, et les données
  /// mobiles ne partent jamais sans accord — au Togo c'est un vrai coût.
  wifi('wifi'),

  /// En wifi **et** en données mobiles, pour qui le choisit en connaissance.
  always('always');

  const ChatMediaDescent(this.key);

  /// Clé de rangement dans `app_settings`. Stable, pour la raison de
  /// [MediaUsage.key] : la renommer basculerait tous les appareils installés
  /// sur le défaut, sans rien dire.
  final String key;

  /// Les données mobiles sont-elles autorisées pour cette descente ?
  bool get allowsCellular => this == ChatMediaDescent.always;

  /// Relit une valeur stockée. **Tolérante**, comme [MediaQuality.parse] : une
  /// clé inconnue retombe sur le défaut plutôt que de faire échouer la lecture
  /// de tout l'écran.
  static ChatMediaDescent parse(String? raw) {
    for (final value in ChatMediaDescent.values) {
      if (value.key == raw) return value;
    }
    return ChatMediaDescent.wifi;
  }
}
