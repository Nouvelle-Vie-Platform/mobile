import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/content_absence.dart';

/// Enveloppe **provisoire** des trois destinations documentaires du menu
/// latéral : CGU, politique de confidentialité et « À propos ».
///
/// Les écrans réels arrivent avec #55 (`/legal/:kind`, `LegalDocumentView`) et
/// #57 (`/about`). En attendant, ces trois entrées **ne doivent être ni grisées
/// ni inertes** : un bouton qui ne fait rien passe pour une panne. Elles
/// ouvrent donc ce que l'écran réel dira lui-même devant un magasin vide —
/// [ContentAbsence.notSynced], rendue par [ContentAbsenceView].
///
/// Ce fichier n'est **pas un écran d'absence de plus** : il n'a ni
/// pictogramme, ni libellé, ni disposition en propre. C'est une barre de
/// marque, un corps délégué, et rien d'autre ; #55 et #57 remplaceront le corps
/// sans toucher au menu ni aux routes.
class LegalPlaceholderScreen extends StatelessWidget {
  const LegalPlaceholderScreen({super.key, required this.kind});

  /// `cgu`, `privacy` ou `about` — le segment de route. Une valeur inconnue
  /// retombe sur les CGU plutôt que de lever : la route est publique, et un
  /// lien mal formé ne doit pas casser l'application.
  final String kind;

  /// Segments reconnus par la route `/legal/:kind`.
  static const String terms = 'cgu';
  static const String privacy = 'privacy';
  static const String about = 'about';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (kind) {
      privacy => l10n.drawerPrivacy,
      about => l10n.drawerAbout,
      _ => l10n.drawerTerms,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: title),
      body: const ContentAbsenceView(absence: ContentAbsence.notSynced),
    );
  }
}
