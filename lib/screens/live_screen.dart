import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_chip.dart';
import '../widgets/icon_text.dart';
import '../widgets/media_thumbnail.dart';

/// Écran de diffusion en direct (live streaming).
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Culte en direct')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                _Player(),
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Text('Culte de Gloire', style: AppTypography.h3),
                      const SizedBox(height: AppSpacing.sm),
                      const IconText(
                          icon: Icons.person_outline, label: 'Pasteur Samuel'),
                      const SizedBox(height: 4),
                      const IconText(
                          icon: Icons.place_outlined, label: 'Temple Central'),
                      const SizedBox(height: AppSpacing.lg),
                      const Row(
                        children: [
                          Expanded(
                            child: _Toggle(
                                icon: Icons.headphones,
                                label: 'Audio seul',
                                selected: false),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _Toggle(
                                icon: Icons.hd_outlined,
                                label: 'Qualité',
                                selected: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('À propos de ce live', style: AppTypography.h5),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Soyez bénis par la Parole de Dieu et restez connectés.',
                        style: AppTypography.bodyLarge
                            .copyWith(color: context.palette.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const IconText(
                        icon: Icons.people_outline,
                        label: '1.2K personnes connectées',
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _CommentBar(),
        ],
      ),
    );
  }
}

class _Player extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MediaThumbnail(
            height: 220, borderRadius: 0, showPlay: false, seed: 0),
        const Positioned(top: AppSpacing.md, left: AppSpacing.md, child: LiveBadge()),
        Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('1.2K',
                    style: AppTypography.caption.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(
      {required this.icon, required this.label, required this.selected});
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? palette.infoBg : palette.surface,
        borderRadius: AppRadius.field,
        border: Border.all(
            color: selected ? palette.primary : palette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 18,
              color: selected ? palette.primary : palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(label,
              style: AppTypography.bodyStrong.copyWith(
                  color: selected ? palette.primary : palette.textSecondary)),
        ],
      ),
    );
  }
}

class _CommentBar extends StatelessWidget {
  const _CommentBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.palette.dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}
