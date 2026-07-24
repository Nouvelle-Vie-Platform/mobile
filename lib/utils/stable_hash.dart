/// Hash FNV-1a 32 bits d'une chaîne.
///
/// Stable dans le temps, entre sessions et entre plateformes — contrairement à
/// `String.hashCode`, dont Dart ne garantit la valeur qu'à l'intérieur d'une
/// même exécution (et qui diffère sur web).
///
/// Sert à dériver déterministement l'habillage d'un statut à partir de son
/// `id` : couleur de fond de repli et hauteurs de waveform de repli. C'est ce
/// qui garantit qu'un statut garde exactement la même apparence d'un `build` et
/// d'une session à l'autre — là où `Random()` la changerait à chaque image.
int stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
