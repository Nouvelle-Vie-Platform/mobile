/// **La sonde du magasin de la Bible, dans un vrai navigateur.**
///
/// Ce que rien d'autre ne peut dire : que `bible_store_web.dart` range
/// vraiment des livres dans un `Cache` et les relit. `flutter test` tourne sur
/// la VM, où c'est le magasin **à dossiers** qui répond — il est couvert, et
/// son vert ne dit rien de celui-ci ; `flutter build web` compile sans rien
/// exécuter. Entre les deux il n'y avait que la console d'un fidèle, et c'est
/// précisément là que la panne s'est vue : le 30/10/2026, « Téléchargement
/// impossible. Réessayez plus tard. » devant une archive qu'aucun réessai ne
/// pouvait installer.
///
/// Elle renvoie son verdict au serveur du harnais, qui l'imprime.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:maison_du_miracle/features/bible/data/bible_store.dart';
import 'package:web/web.dart' as web;

void main() {
  unawaited(_sonder());
}

Future<void> _sonder() async {
  final lignes = <String>[];

  void dire(String texte) {
    lignes.add(texte);
    web.console.log(texte.toJS);
  }

  try {
    final store = bibleStore();
    dire('magasin construit : ${store.runtimeType}');

    const manifeste = '{"code":"SND","versification":{"Gen":[2]}}';
    const jean = '{"book":43,"chapters":[["au commencement était la Parole"]]}';

    final chemin = await store.install('S!N/D', {
      'manifest.json': utf8.encode(manifeste),
      'books/43.json': utf8.encode(jean),
    });
    dire('installé sous : $chemin');

    // **Le code est assaini** : il vient du serveur, et `S!N/D` écrirait hors
    // du magasin si personne ne le réduisait.
    if (chemin.contains('!') || chemin.endsWith('/D')) {
      throw StateError('le code n\'a pas été assaini : $chemin');
    }

    final relu = await store.read(chemin, 'books/43.json');
    if (relu != jean) {
      throw StateError('relecture différente : $relu');
    }
    dire('livre relu à l\'identique (${relu!.length} octets)');

    final absent = await store.read(chemin, 'books/19.json');
    dire(
        'livre absent : ${absent == null ? "null, comme attendu" : "INATTENDU"}');

    // Réinstaller **efface d'abord** : sans cela, les livres de deux éditions
    // cohabiteraient et le lecteur lirait un mélange.
    await store.install('S!N/D', {'manifest.json': utf8.encode(manifeste)});
    final apres = await store.read(chemin, 'books/43.json');
    if (apres != null) {
      throw StateError('la réinstallation a laissé l\'ancien livre');
    }
    dire('réinstallation : l\'ancien livre a bien disparu');

    await store.remove(chemin);
    final efface = await store.read(chemin, 'manifest.json');
    if (efface != null) {
      throw StateError('la suppression n\'a rien rendu');
    }
    dire('suppression : le magasin est vide');

    dire('VERDICT : le magasin web range, relit, remplace et efface');
  } catch (erreur, pile) {
    dire('VERDICT : ÉCHEC');
    dire(erreur.toString());
    dire(pile.toString().split('\n').take(6).join('\n'));
  }

  final requete = web.XMLHttpRequest()
    ..open('POST', '/resultat')
    ..send(lignes.join('\n').toJS);
  requete.onLoad.listen((_) {});
}
