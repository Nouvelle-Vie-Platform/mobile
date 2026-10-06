import 'package:flutter/foundation.dart';

/// **Où en est la montée de chaque média** (M4, #143), par clé d'écho.
///
/// En mémoire, et seulement en mémoire : une progression écrite au magasin à
/// chaque paquet réveillerait la requête du fil des dizaines de fois par
/// seconde. Ce qui doit survivre à un redémarrage — le fichier, la clé montée,
/// l'échec — est dans `pending_group_messages` ; la progression, elle, repart de
/// zéro avec la montée.
///
/// La bulle d'un écho l'écoute (`ValueListenableBuilder`) : un anneau qui se
/// remplit, puis le message part.
class MediaUploadProgress extends ValueNotifier<Map<String, double>> {
  MediaUploadProgress() : super(const {});

  /// La progression de [clientMessageId], `0..1`, ou `null` si rien ne monte.
  double? of(String clientMessageId) => value[clientMessageId];

  void report(String clientMessageId, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    if (value[clientMessageId] == clamped) return;
    value = {...value, clientMessageId: clamped};
  }

  void clear(String clientMessageId) {
    if (!value.containsKey(clientMessageId)) return;
    value = {...value}..remove(clientMessageId);
  }
}
