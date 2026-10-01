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

/// L'état d'antenne, tel qu'une route publique le rend.
@immutable
class RadioAntenna {
  const RadioAntenna({this.streamUrl, this.onAir});

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

  /// Vrai quand l'antenne émet, faux quand elle se tait, **`null` quand on ne
  /// sait pas** — voir [unknown].
  final bool? onAir;

  /// Vrai **seulement** quand la route a dit « elle se tait ».
  ///
  /// C'est le seul cas qui éteint le bouton et affiche « Hors antenne ». Dérivée
  /// ici et non à l'écran pour qu'il n'y ait qu'un endroit où `null` ne se
  /// confonde pas avec `false`.
  bool get isSilent => onAir == false;

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
  /// | l'état | `onAir`, `isOnAir`, `live` |
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
      onAir: _onAir(body),
    );
  }

  static String? _url(Map<String, dynamic> body) {
    for (final key in const ['streamUrl', 'url', 'hlsUrl']) {
      final raw = body[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return null;
  }

  static bool? _onAir(Map<String, dynamic> body) {
    for (final key in const ['onAir', 'isOnAir', 'live']) {
      final raw = body[key];
      if (raw is bool) return raw;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RadioAntenna &&
      other.streamUrl == streamUrl &&
      other.onAir == onAir;

  @override
  int get hashCode => Object.hash(streamUrl, onAir);

  @override
  String toString() => 'RadioAntenna(streamUrl: $streamUrl, onAir: $onAir)';
}
