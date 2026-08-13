import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../models/legal_document_view.dart';
import '../state/legal_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/content_absence.dart';
import '../widgets/legal_document_body.dart';

/// **La consultation d'un document légal** — `/legal/:kind`, `kind ∈ {cgu,
/// privacy}`.
///
/// « À propos » a sa propre route (`/about`, #57) : son écran ne se réduit pas
/// au document servi — il porte la version du binaire, que le serveur ne peut
/// pas connaître.
///
/// L'écran ne fait que **trois** choses : une barre de marque, une résolution
/// depuis le provider, et un corps. Il n'applique aucune règle de langue,
/// aucune mise en forme, aucun repli : tout cela a déjà eu lieu dans le modèle
/// de lecture.
///
/// **Le magasin vide n'est pas une erreur.** C'est `ContentAbsence.notSynced`,
/// rendue par `ContentAbsenceView` — la même vue que les trois autres absences,
/// et surtout pas un écran d'absence de plus. C'est aussi ce que
/// `LegalPlaceholderScreen` affichait avant cet écran : le provisoire
/// préfigurait le définitif, c'était son seul mérite.
///
/// Le chargement se rend comme l'absence, à dessein. Une lecture de magasin
/// local se résout en quelques millisecondes : un indicateur de progression y
/// ferait un clignotement, et rien de plus.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  /// Le segment de route. Une valeur inconnue retombe sur les CGU plutôt que
  /// de lever : la route est publique, et un lien mal formé ne doit pas casser
  /// l'application.
  final String kind;

  /// Le genre effectivement demandé au magasin.
  String get resolvedKind => LegalDocumentKind.consultable.contains(kind)
      ? kind
      : LegalDocumentKind.terms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title = resolvedKind == LegalDocumentKind.privacy
        ? l10n.drawerPrivacy
        : l10n.drawerTerms;

    final document = ref.watch(legalDocumentProvider(resolvedKind));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: title),
      body: document.when(
        data: (value) => value == null
            ? const ContentAbsenceView(absence: ContentAbsence.notSynced)
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                children: [LegalDocumentBody(document: value)],
              ),
        // Une base illisible n'est pas un document retiré : c'est une attente
        // qui ne se résoudra pas toute seule, mais l'écran dit la même chose —
        // « ce contenu n'est pas encore arrivé ». Rien à réessayer ici, le
        // provider ne réessaie pas non plus.
        loading: () =>
            const ContentAbsenceView(absence: ContentAbsence.notSynced),
        error: (_, __) =>
            const ContentAbsenceView(absence: ContentAbsence.notSynced),
      ),
    );
  }
}
