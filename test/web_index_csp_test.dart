import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Aucun script en ligne dans `web/index.html`** — la CSP de l'origine le
/// refuse, et son refus ne se voit qu'en production.
///
/// L'app web est servie sous `script-src 'self' 'wasm-unsafe-eval'` (bloc Caddy
/// du dépôt `context`). Un `<script>` sans `src` y est **bloqué** : « Executing
/// inline script violates the following Content Security Policy directive ».
/// Rien ne le signale avant — ça compile, ça s'empaquette, ça se sert, et seule
/// la console d'un fidèle le dit.
///
/// Constaté le 29/10/2026 : le script qui capte `beforeinstallprompt` était en
/// ligne, donc **jamais exécuté**, donc le bandeau d'installation ne pouvait
/// pas paraître — or l'installation porte le téléchargement hors ligne et la
/// durabilité du stockage. Deux tranches se contredisaient : T0 avait posé la
/// CSP, T1 avait écrit le script en ligne.
///
/// Le remède est toujours le même : un fichier servi depuis notre origine, qui
/// satisfait `'self'` sans relâcher la politique. Surtout pas un hash
/// `sha256-…` dans la CSP — il lierait un en-tête du dépôt `context` à un octet
/// de celui-ci, à refaire à chaque virgule changée.
void main() {
  test('index.html ne porte aucun script en ligne', () {
    final html = File('web/index.html').readAsStringSync();

    // Un `<script>` est en ligne quand il n'a pas de `src` : on regarde ce que
    // porte chaque balise ouvrante.
    final tags = RegExp(r'<script([^>]*)>').allMatches(html);
    expect(tags, isNotEmpty, reason: 'index.html charge au moins Flutter');

    final inlines = tags.where((m) => !m.group(1)!.contains('src=')).toList();
    expect(
      inlines,
      isEmpty,
      reason: 'Script en ligne trouvé : la CSP de l\'origine le bloquera, et '
          'ça ne se verra que dans la console d\'un fidèle. Posez-le dans un '
          'fichier de `web/`, chargé par `src`.',
    );
  });

  test('le capteur d\'installation est bien chargé, et sans defer', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('<script src="install_hook.js"></script>'),
        reason: 'Sans lui, `beforeinstallprompt` — qui ne se rejoue jamais — '
            'est raté, et le bandeau d\'installation ne paraît pas. `defer` '
            'retarderait l\'écouteur, ce qui est exactement ce qu\'il ne faut '
            'pas.');
    expect(File('web/install_hook.js').existsSync(), isTrue);
  });
}
