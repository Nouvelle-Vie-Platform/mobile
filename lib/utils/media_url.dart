/// Résolution des URL de médias servies **relatives** par le back.
library;

import '../core/network/api_client.dart';

/// Rend une URL de média affichable par `Image.network`.
///
/// Le serveur sert ses visuels en chemins **relatifs** (`/uploads/teachings/…`)
/// et non en URL absolues, parce que l'hôte de l'API change d'un environnement
/// à l'autre — dev, préproduction, production — et qu'une URL absolue figée en
/// base y renverrait vers le mauvais serveur. C'est donc au client de résoudre,
/// contre **sa** base ([kBaseUrl], injectée par `--dart-define=API_BASE_URL`).
///
/// **Unique endroit** où cette règle est écrite : sans lui, chaque widget
/// tenterait `Image.network('/uploads/…')`, qui échoue faute de schéma.
///
/// Trois cas, dans cet ordre :
/// - `null` ou chaîne blanche → `null` (l'appelant affiche son repli coloré) ;
/// - déjà absolue (`http://`, `https://`, `data:`) → rendue telle quelle, ce
///   qui laisse passer les fixtures de démonstration et les assets distants ;
/// - relative → préfixée par [kBaseUrl], sans jamais doubler la barre oblique.
String? resolveMediaUrl(String? source) {
  final raw = source?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') ||
      raw.startsWith('https://') ||
      raw.startsWith('data:')) {
    return raw;
  }
  final base = kBaseUrl.endsWith('/')
      ? kBaseUrl.substring(0, kBaseUrl.length - 1)
      : kBaseUrl;
  return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
}
