import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../models/legal_document_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/event_time.dart';
import '../utils/inline_markdown.dart';

/// **Le rendu d'un document légal, et rien d'autre** : ni app bar, ni bouton,
/// ni garde. C'est le motif de `ContentPlayerView` — un corps que deux
/// enveloppes se partagent, la consultation (`/legal/:kind`) et la barrière
/// d'acceptation (`/legal/accept`, #56).
///
/// ## Pourquoi ce n'est pas `LegalDocumentView`
///
/// Ce nom-là est déjà celui du **modèle de lecture**
/// (`models/legal_document_view.dart`), que ce widget reçoit. Deux classes de
/// même nom ne peuvent pas cohabiter dans le fichier qui les importe toutes
/// les deux — c'est-à-dire chaque écran. La spécification les nomme pourtant
/// pareil (`docs/documents-legaux.md` §2 et §6) : l'écart est ici, assumé, et
/// c'est le widget qui a cédé — le modèle est le nom qui voyage le plus loin.
///
/// ## Ce qu'il n'a plus à décider
///
/// **La langue.** Elle a été tranchée une fois, pour le document entier, par
/// `resolveLegalLocale` (ADR-0035). Les sections qui arrivent ici sont déjà
/// repliées : il n'y a plus aucune règle à appliquer, donc plus aucune occasion
/// d'en appliquer une variante.
///
/// ## Les couleurs viennent toutes de `context.palette`
///
/// Sans exception, et ce n'est pas une politesse de style : c'est l'écran le
/// plus dense en texte de l'application, et une couleur en dur y donnerait du
/// texte noir sur fond sombre sur trente articles. La seule teinte fixe est
/// celle des liens — [AppColors.accent] —, parce qu'un lien doit se distinguer
/// du corps dans les deux thèmes.
class LegalDocumentBody extends StatelessWidget {
  const LegalDocumentBody({super.key, required this.document});

  final LegalDocumentView document;

  /// Largeur de ligne maximale. Au-delà, l'œil perd sa ligne en revenant à la
  /// gauche du paragraphe — sur une tablette, un texte pleine largeur devient
  /// illisible bien avant d'être long.
  static const double maxLineWidth = 620;

  /// La colonne de texte elle-même, pour que les tests mesurent la **largeur
  /// de ligne** et non celle de l'écran.
  static const Key contentKey = Key('legal_document_content');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: ConstrainedBox(
        key: contentKey,
        constraints: const BoxConstraints(maxWidth: maxLineWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in document.sections) _Section(section: section),
            const SizedBox(height: AppSpacing.lg),
            Divider(color: palette.divider),
            const SizedBox(height: AppSpacing.sm),
            Text(_footer(context), style: _footerStyle(palette)),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// « Version 3 — mise à jour le 9 mars 2026 ».
  ///
  /// Sans date connue, la version seule : **jamais une date inventée**. Sur un
  /// texte qu'on demande d'accepter, une date fabriquée ferait foi.
  String _footer(BuildContext context) {
    final l10n = context.l10n;
    final date = document.footerDate;
    if (date == null) return l10n.legalFooterVersion(document.version);
    return l10n.legalFooterUpdated(
      document.version,
      formatLegalDate(date, Localizations.localeOf(context).toLanguageTag()),
    );
  }

  TextStyle _footerStyle(AppPalette palette) =>
      AppTypography.caption.copyWith(color: palette.textSecondary);
}

/// Un titre de section, puis ses blocs de corps.
class _Section extends StatelessWidget {
  const _Section({required this.section});

  final LegalSectionView section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Un `heading` vide ne laisse **pas** un blanc de titre : l'absence
          // se dessine comme une absence, elle ne se réserve pas de place.
          if (section.heading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                section.heading,
                style: AppTypography.h3.copyWith(color: palette.textPrimary),
              ),
            ),
          for (final block in parseMarkdownBlocks(section.body))
            _Block(block: block),
        ],
      ),
    );
  }
}

/// Un paragraphe, ou une puce.
class _Block extends StatelessWidget {
  const _Block({required this.block});

  final MarkdownBlock block;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Interlignage aéré : trente articles se lisent au pouce, et un texte
    // serré se saute plutôt qu'il ne se lit.
    final style = AppTypography.bodyLarge.copyWith(
      color: palette.textPrimary,
      height: 1.6,
    );
    const linkStyle = TextStyle(
      color: AppColors.accent,
      decoration: TextDecoration.underline,
    );

    final text = Text.rich(
      inlineMarkdownSpan(
        block.text,
        style: style,
        // Le lien hérite du corps, sa couleur et son soulignement en plus : le
        // parseur n'écrit aucune couleur, c'est ici que la palette entre.
        linkStyle: style.merge(linkStyle),
      ),
    );

    if (!block.isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: text,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: style),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: text),
        ],
      ),
    );
  }
}
