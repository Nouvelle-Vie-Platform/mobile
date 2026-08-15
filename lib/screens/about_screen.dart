import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/legal_document_view.dart';
import '../router/app_router.dart';
import '../state/app_version_providers.dart';
import '../state/legal_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/brand_logo.dart';
import '../widgets/legal_document_body.dart';

/// **« À propos » — `/about`.** Un entête local au-dessus d'un corps servi.
///
/// ## Pourquoi une route distincte de `/legal/:kind`
///
/// Ranger « À propos » sous `/legal/` mentirait sur sa nature : ce n'est ni un
/// contrat ni une politique, on ne l'accepte pas, et il n'entre **jamais** dans
/// la barrière de consentement (#56) — pas de case, pas de version exigée.
/// L'écran ne se réduit d'ailleurs pas au document servi.
///
/// ## Le partage entre le local et le servi
///
/// **Le numéro de version ne peut pas venir du serveur** : il décrit le binaire
/// installé sur *ce* téléphone-ci. C'est toute la raison de l'entête local.
/// Tout ce qui doit rester corrigeable **sans publier une version de
/// l'application** — la présentation, la mission, le contact — vit au portail
/// et arrive par le corps servi, rendu par [LegalDocumentBody] comme les deux
/// autres documents.
///
/// ## Le magasin vide n'efface pas l'écran
///
/// Sans document `about` en magasin, **l'entête s'affiche quand même** : logo,
/// nom, version, et les deux renvois. Seul le corps manque. C'est le seul des
/// trois écrans documentaires qui ait quelque chose à montrer sans le serveur,
/// et la règle du dépôt s'applique telle quelle — « pas de contenu, pas de
/// section », jamais « pas de contenu, pas d'écran ». Il n'y a donc **aucune**
/// `ContentAbsenceView` ici, contrairement à `LegalDocumentScreen`.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  /// L'entête local — présent que le magasin ait servi un document ou non.
  static const Key headerKey = Key('about_header');

  /// La ligne « Version 1.0.0 (1) ». Absente tant que la version n'est pas
  /// connaissable : une absence se dessine comme une absence.
  static const Key versionKey = Key('about_version');

  /// Les deux renvois vers `/legal/:kind`.
  static const Key termsLinkKey = Key('about_link_terms');
  static const Key privacyLinkKey = Key('about_link_privacy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(legalDocumentProvider(LegalDocumentKind.about));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: context.l10n.drawerAbout),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LegalDocumentBody.maxLineWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LocalHeader(key: headerKey),
                  // Le corps est la seule partie qui puisse manquer, et il
                  // manque en silence. Le chargement se rend comme l'absence :
                  // une lecture de magasin local se résout en quelques
                  // millisecondes, un indicateur y ferait un clignotement.
                  if (document.value case final value?)
                    LegalDocumentBody(document: value),
                  const _LegalLinks(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo, nom de l'église, version du binaire, filet.
///
/// Tout y est **local** : aucune de ces quatre lignes ne dépend du réseau, et
/// c'est ce qui permet à l'écran d'exister devant un magasin vide.
class _LocalHeader extends ConsumerWidget {
  const _LocalHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final version = ref.watch(appVersionProvider).value;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        const BrandLogo(size: 132),
        const SizedBox(height: AppSpacing.md),
        // Le bandeau de l'emblème porte « Maison du Miracle », mais illisible à
        // cette taille : le nom complet en dessous n'est pas une répétition,
        // c'est ce qui le rend lisible — et ce qui autorise l'emblème à rester
        // décoratif pour un lecteur d'écran.
        Text(
          l10n.aboutChurchName,
          textAlign: TextAlign.center,
          style: AppTypography.h3.copyWith(color: palette.textPrimary),
        ),
        if (version != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            key: AboutScreen.versionKey,
            l10n.aboutVersion(version.version, version.build),
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Divider(color: palette.divider),
      ],
    );
  }
}

/// « CGU · Confidentialité » — deux renvois vers `/legal/:kind`.
///
/// Ils poussent la route **nommée** avec son paramètre de chemin, comme le menu
/// latéral : le chemin ne s'écrit qu'à un seul endroit.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegalLink(
            key: AboutScreen.termsLinkKey,
            label: l10n.drawerTerms,
            kind: LegalDocumentKind.terms,
          ),
          Text(
            ' · ',
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
          _LegalLink(
            key: AboutScreen.privacyLinkKey,
            label: l10n.drawerPrivacy,
            kind: LegalDocumentKind.privacy,
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({super.key, required this.label, required this.kind});

  final String label;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(
        AppRoute.legalDocument,
        pathParameters: {'kind': kind},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: context.palette.primary,
            decoration: TextDecoration.underline,
            decorationColor: context.palette.primary,
          ),
        ),
      ),
    );
  }
}
