/// **Où est l'antenne, et émet-elle ?** — les deux seules choses que
/// l'application a besoin de savoir de New Life Radio avant d'appuyer.
///
/// Rien n'est stocké localement, et ce n'est pas un oubli : **connaître l'URL
/// hors ligne ne sert à rien**, puisqu'on ne peut pas écouter hors ligne. Pas de
/// table Drift, pas de curseur, pas de descripteur de synchronisation — la
/// décision écrite en tête d'`app/radio/routes.ts` côté serveur (« l'écoute d'une
/// antenne est un flux continu, pas un catalogue à ranger dans un magasin
/// local ») est respectée, pas révisée.
library;

import 'package:flutter/foundation.dart';

import '../../models/media_preferences.dart';
import 'radio_live.dart';

/// L'état d'antenne, tel qu'une route publique le rend.
@immutable
class RadioAntenna {
  const RadioAntenna({
    this.streamUrl,
    this.ecoStreamUrl,
    this.onAir,
    this.listeners,
    this.live,
  });

  /// **Ce qu'on sait avant la première réponse** : rien.
  ///
  /// ⚠️ [onAir] y est **nul, jamais `false`** — et la nuance porte tout le §3 du
  /// cadrage. « Je ne sais pas » n'est pas « hors antenne » : afficher un bouton
  /// éteint parce que la route n'a pas encore répondu dirait à l'auditeur que
  /// l'église ne diffuse pas, ce dont l'application n'a aucune idée. Le bouton
  /// reste donc au repos, et il invite.
  static const RadioAntenna unknown = RadioAntenna();

  /// L'URL de la liste de lecture HLS à ouvrir, ou `null` quand la route n'a rien
  /// dit (ou n'a pas encore répondu).
  final String? streamUrl;

  /// **L'URL économie** — la playlist de la variante 32 k —, ou `null` quand le
  /// serveur n'en a pas (champ nul, ou absent d'une réponse d'avant la
  /// tranche A2). Lue seulement par [streamUrlFor].
  final String? ecoStreamUrl;

  /// **L'URL à ouvrir pour ce choix de qualité** — le seul endroit où le choix
  /// se fait (#184).
  ///
  /// Le serveur publie, à côté de `master.m3u8`, une liste de lecture par
  /// palier : `a16`, `a32`, `a64`, `a128` (`.m3u8`). Automatique → [streamUrl]
  /// (adaptative) ; Économie → [ecoStreamUrl] s'il est servi, sinon `a32`
  /// dérivé ; Minimum → `a16` ; Haute → `a128`.
  ///
  /// La dérivation **échoue du bon côté**, comme `variantPlaylistUrl` des
  /// enseignements : une adresse qui ne finit pas par `/master.m3u8` est rendue
  /// intacte. Le pire cas est « pas de palier forcé », jamais le silence.
  String? streamUrlFor(RadioQuality quality) => switch (quality) {
        RadioQuality.auto => streamUrl,
        RadioQuality.economy => ecoStreamUrl ?? _variant('a32'),
        RadioQuality.minimum => _variant('a16'),
        RadioQuality.high => _variant('a128'),
      };

  String? _variant(String name) {
    const master = '/master.m3u8';
    final url = streamUrl;
    if (url == null || !url.endsWith(master)) return url;
    return '${url.substring(0, url.length - master.length)}/$name.m3u8';
  }

  /// Vrai quand l'antenne émet, faux quand elle se tait, **`null` quand on ne
  /// sait pas** — voir [unknown].
  final bool? onAir;

  /// Vrai **seulement** quand la route a dit « elle se tait ».
  ///
  /// C'est le seul cas qui éteint le bouton et affiche « Hors antenne ». Dérivée
  /// ici et non à l'écran pour qu'il n'y ait qu'un endroit où `null` ne se
  /// confonde pas avec `false`.
  bool get isSilent => onAir == false;

  /// **Le compteur d'auditeurs, ou `null` : ne rien afficher** (#135, décision
  /// 8 du plan radio live).
  ///
  /// Le serveur rend `null` quand le relevé manque, date de plus de 30 s, ou
  /// passe sous le seuil d'affichage (défaut 10). Le téléphone ne cherche pas à
  /// savoir lequel : « 2 à l'écoute » fait vide, et « non mesuré » ne
  /// s'affiche pas davantage. ⚠️ **Jamais `0` à la place de `null`** — zéro
  /// serait une affirmation.
  final int? listeners;

  /// **Le direct en cours**, ou `null` (#135, décision 2) : badge « EN DIRECT »
  /// et fil de commentaires. Déduit des sessions de la régie côté serveur,
  /// **jamais** de [onAir] — « l'antenne sort » n'est pas « un humain est à
  /// l'antenne ».
  final RadioLive? live;

  /// **Lit la charge utile de la route publique.**
  ///
  /// ⚠️ **La forme exacte n'est pas tranchée** : la route est écrite par
  /// `server-portal#493`, lancée en parallèle de cette tranche. Ce lecteur
  /// s'est réglé sur la convention REST du serveur — corps en **`camelCase`**,
  /// comme `HttpAuthRepository` poste déjà `firstName` / `branchId` — et accepte
  /// une poignée de synonymes plausibles **nommés ici** plutôt que de parier sur
  /// un seul mot :
  ///
  /// | ce qu'on cherche | clés acceptées |
  /// | --- | --- |
  /// | l'adresse | `streamUrl`, `url`, `hlsUrl` |
  /// | l'adresse économie | `ecoStreamUrl` |
  /// | l'état | `onAir`, `isOnAir` |
  /// | le compteur (#135) | `listeners` |
  /// | le direct (#135) | `live` |
  ///
  /// ⚠️ **`live` n'est plus un synonyme d'`onAir`** depuis que la route est
  /// fusionnée (#135) : c'est le direct de la régie, `{ startedAt }` ou `null`.
  /// Le lire comme un booléen d'antenne aurait éteint le bouton à chaque fin de
  /// direct.
  ///
  /// Ce n'est pas de la tolérance de confort : un seul mot deviné de travers
  /// rendrait la radio muette **sans qu'aucun test rougisse**, et la panne se
  /// lirait comme une antenne éteinte. Le jour où la route est fusionnée, la
  /// table ci-dessus se réduit à une ligne, et c'est le seul endroit à toucher.
  ///
  /// Une charge utile illisible rend [unknown], jamais « hors antenne » : voir
  /// [unknown].
  factory RadioAntenna.fromJson(Map<String, dynamic>? body) {
    if (body == null) return unknown;
    return RadioAntenna(
      streamUrl: _url(body),
      ecoStreamUrl: _ecoUrl(body['ecoStreamUrl']),
      onAir: _onAir(body),
      listeners: _listeners(body['listeners']),
      live: RadioLive.fromJson(body['live']),
    );
  }

  /// Un entier positif ou nul, sinon `null` — un compteur illisible ne
  /// s'affiche pas.
  static int? _listeners(Object? raw) {
    if (raw is int && raw >= 0) return raw;
    if (raw is double && raw.isFinite && raw >= 0) return raw.round();
    return null;
  }

  /// La même antenne, avec un autre compteur ou un autre direct — ce que le
  /// canal temps réel pousse entre deux lectures de la route.
  RadioAntenna withAudience({
    required int? listeners,
    required RadioLive? live,
  }) =>
      RadioAntenna(
        streamUrl: streamUrl,
        ecoStreamUrl: ecoStreamUrl,
        onAir: onAir,
        listeners: listeners,
        live: live,
      );

  static String? _url(Map<String, dynamic> body) {
    for (final key in const ['streamUrl', 'url', 'hlsUrl']) {
      final raw = body[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return null;
  }

  static String? _ecoUrl(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  static bool? _onAir(Map<String, dynamic> body) {
    for (final key in const ['onAir', 'isOnAir']) {
      final raw = body[key];
      if (raw is bool) return raw;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RadioAntenna &&
      other.streamUrl == streamUrl &&
      other.ecoStreamUrl == ecoStreamUrl &&
      other.onAir == onAir &&
      other.listeners == listeners &&
      other.live == live;

  @override
  int get hashCode =>
      Object.hash(streamUrl, ecoStreamUrl, onAir, listeners, live);

  @override
  String toString() =>
      'RadioAntenna(streamUrl: $streamUrl, ecoStreamUrl: $ecoStreamUrl, onAir: $onAir, '
      'listeners: $listeners, live: $live)';
}
