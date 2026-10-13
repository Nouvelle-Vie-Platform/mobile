/// **Les résultats comparatifs** (M3, #201, décision 18) : un verset (ou une
/// plage) dans **chaque version installée**, l'une sous l'autre — la liste
/// verticale du téléphone. Toucher une version ouvre le lecteur au verset
/// dans cette version.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import '../reader/bible_reader_screen.dart';
import '../shell/bible_route.dart';

class BibleCompareScreen extends ConsumerWidget {
  const BibleCompareScreen({super.key, required this.link});

  final BibleLink link;

  static Key versionKey(String code) => Key('bible_compare_$code');

  /// Ouvre la comparaison de [link], par la pile du routeur.
  static Future<void> open(GoRouter router, BibleLink link) async {
    await router.routerDelegate.navigatorKey.currentState?.push(
      bibleRoute<void>(BibleCompareScreen(link: link)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = [
      for (final v in ref.watch(bibleVersionsProvider).value ?? const [])
        if (v.installed) v,
    ];
    return Scaffold(
      appBar: BrandAppBar(title: context.l10n.bibleSearchCompareTitle),
      body: ListView(
        padding: AppSpacing.screenPadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl,
        ),
        children: [
          Text(link.labelFr, style: AppTypography.h4),
          const SizedBox(height: AppSpacing.md),
          for (final v in versions) _VersionCard(link: link, version: v),
        ],
      ),
    );
  }
}

class _VersionCard extends ConsumerWidget {
  const _VersionCard({required this.link, required this.version});

  final BibleLink link;
  final BibleVersion version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final verses = ref
            .watch(bibleChapterProvider((
              version: version.code,
              book: link.book,
              chapter: link.chapter,
            )))
            .value ??
        const <BibleVerse>[];
    final from = link.from ?? 1;
    final to = link.to ?? link.from ?? 1 << 30;
    final shown = [
      for (final v in verses)
        if (v.number >= from && v.number <= to) v,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        key: BibleCompareScreen.versionKey(version.code),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () {
          ref.read(activeBibleVersionProvider.notifier).select(version.code);
          BibleReaderScreen.push(ref.read(routerProvider), link);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${version.code} · ${version.name}',
              style: AppTypography.caption.copyWith(color: palette.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(
              TextSpan(
                style: AppTypography.body.copyWith(color: palette.textPrimary),
                children: [
                  for (final v in shown) ...[
                    if (shown.length > 1)
                      TextSpan(
                        text: '${v.number} ',
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary),
                      ),
                    TextSpan(text: '${v.text} '),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
