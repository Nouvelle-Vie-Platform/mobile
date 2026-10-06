import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/community/my_requests_tab.dart';

/// La route **`/requests`** — le contenu de l'onglet « Requêtes » de la page
/// Échanges, sur une page à part avec sa flèche de retour.
///
/// Depuis #148, plus aucun écran ne l'ouvre : le bouton en haut à droite du
/// bandeau a disparu, et « Requêtes » est le second onglet d'Échanges. La route
/// reste servie pour qu'un lien qui y mènerait (cible web, lien gardé) montre
/// **la même liste**, et non l'ancienne liste vide qui ne lisait rien. Ouvrir
/// directement l'onglet demanderait de choisir l'onglet de départ de la
/// coquille, ce que la page ne sait pas encore faire.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(title: context.l10n.requestsTitle),
      body: const SafeArea(child: MyRequestsTab()),
    );
  }
}
