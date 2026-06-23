import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_text_field.dart';
import '../widgets/cards/teaching_tile.dart';

/// Onglet « Médiathèque » : recherche, filtres et liste d'enseignements.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  static const _filters = ['Tout', 'Prêches', 'Enseignements', 'Musique'];

  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final teachings = ref.watch(teachingsProvider);

    return SafeArea(
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Médiathèque', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.lg),
          const AppSearchField(hint: 'Rechercher un enseignement...'),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) => FilterChipButton(
                label: _filters[i],
                selected: i == _selectedFilter,
                onTap: () => setState(() => _selectedFilter = i),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final t in teachings) ...[
            TeachingTile(
              teaching: t,
              onTap: () => context.pushNamed(AppRoute.teachingDetail, extra: t),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SeriesTile(
            onTap: () => context.pushNamed(
              AppRoute.teachingDetail,
              extra: teachings.first,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Carte « Série » regroupant plusieurs messages.
class _SeriesTile extends StatelessWidget {
  const _SeriesTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: AppRadius.card,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: palette.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.infoBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child:
                    Icon(Icons.playlist_play, color: palette.primary, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppChip('Série', tone: AppChipTone.info),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Vie Victorieuse',
                            style: AppTypography.bodyStrong),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('5 messages',
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
