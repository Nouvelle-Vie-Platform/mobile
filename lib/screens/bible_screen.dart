import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../widgets/brand_app_bar.dart';

/// Écran **provisoire** de la Bible, atteint depuis l'icône en haut à droite de
/// l'accueil (route `/bible`).
///
/// ## Poussé, et non plus monté en permanence
///
/// La Bible occupait un onglet de la barre du bas : elle vivait donc dans
/// l'`IndexedStack` de la coquille, construite au démarrage et jamais démontée.
/// Elle est désormais une route **poussée** — elle naît à l'ouverture et meurt à
/// la fermeture, comme la médiathèque ou l'agenda.
///
/// ⚠️ **Elle ne survit donc plus en arrière-plan.** Sans conséquence tant que
/// l'écran est celui-ci : il n'a ni contenu, ni défilement, ni position de
/// lecture à perdre. Le jour où il portera un passage ouvert, cette position
/// devra vivre ailleurs que dans son `State` — dans le magasin local, comme la
/// reprise de lecture du lecteur.
///
/// **Ouvert à tous.** `/bible` n'est pas dans `memberOnlyRoutes`, et c'est la
/// décision écrite du client : la Bible appartient à la surface invitée.
///
/// Le contenu est déplacé **tel quel** depuis l'ancien onglet. Le remplir est un
/// autre chantier ; seule la barre d'application est neuve, et elle n'est pas
/// cosmétique : un écran poussé sans retour serait un cul-de-sac.
class BibleScreen extends StatelessWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(title: context.l10n.navBible),
      body: Center(
        child: Text(
          // La phrase était écrite en dur dans la coquille, alors que
          // `pageUnderConstruction` existait dans les trois fichiers de
          // traduction sans appelant.
          context.l10n.pageUnderConstruction,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
