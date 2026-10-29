/// **La sonde du magasin local, dans un vrai navigateur.**
///
/// Ce que rien d'autre ne peut dire : que `AppDatabase.defaults()` s'ouvre sur
/// le web et répond à une requête. `flutter test` tourne sur la VM, où c'est
/// l'implémentation **native** qui répond ; `flutter build web` compile sans
/// rien exécuter. Entre les deux, il n'y avait que la console d'un fidèle — et
/// le 29/10/2026 ça a coûté une journée.
///
/// Elle renvoie son verdict au serveur du harnais, qui l'imprime.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:maison_du_miracle/data/local/app_database.dart';
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
    final db = AppDatabase.defaults();
    dire('base construite');

    // Une requête qui touche vraiment le moteur : l'ouverture est paresseuse,
    // et sans elle la sonde dirait « tout va bien » sans avoir rien ouvert.
    final ligne =
        await db.customSelect('select sqlite_version() as v').getSingle();
    dire('sqlite répond : ${ligne.data['v']}');

    final curseurs = await db.syncDao.allCursors();
    dire('curseurs lus : ${curseurs.length}');

    await db.close();
    dire('VERDICT : le magasin s\'ouvre et répond');
  } catch (erreur, pile) {
    dire('VERDICT : ÉCHEC');
    dire('$erreur');
    dire('${pile.toString().split('\n').take(6).join('\n')}');
  }

  final requete = web.XMLHttpRequest()
    ..open('POST', '/resultat')
    ..send(lignes.join('\n').toJS);
  requete.onLoad.listen((_) {});
}
