import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/icon_text.dart';
import '../widgets/media_thumbnail.dart';

/// Écran de détail d'un enseignement (vidéo, actions, description).
class TeachingDetailScreen extends StatelessWidget {
  const TeachingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enseignement')),
      body: ListView(
        children: [
          const MediaThumbnail(height: 210, borderRadius: 0, seed: 1),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text('La foi qui déplace les montagnes',
                    style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                const Row(
                  children: [
                    IconText(
                        icon: Icons.person_outline, label: 'Pasteur Samuel'),
                    SizedBox(width: AppSpacing.lg),
                    IconText(icon: Icons.schedule, label: '36:10'),
                  ],
                ),
                const SizedBox(height: 4),
                Text('1.2K vues • 26 Mai 2024',
                    style: AppTypography.caption
                        .copyWith(color: context.palette.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Action(
                        icon: Icons.download_outlined, label: 'Télécharger'),
                    _Action(
                        icon: Icons.bookmark_add_outlined, label: 'Mes notes'),
                    _Action(icon: Icons.share_outlined, label: 'Partager'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const _Tabs(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'La véritable foi nous connecte aux promesses de Dieu et '
                  'permet de voir des résultats extraordinaires.',
                  style: AppTypography.bodyLarge
                      .copyWith(color: context.palette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Matthieu 17:20',
                    style: AppTypography.bodyStrong
                        .copyWith(color: context.palette.primary)),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Télécharger l\'audio',
                  icon: Icons.headphones,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Icon(icon, color: palette.primary),
        const SizedBox(height: 4),
        Text(label,
            style:
                AppTypography.caption.copyWith(color: palette.textSecondary)),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _Tab(label: 'Description', selected: true),
        SizedBox(width: AppSpacing.xl),
        _Tab(label: 'Notes (12)', selected: false),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Text(label,
            style: AppTypography.bodyStrong.copyWith(
                color: selected ? palette.primary : palette.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 2,
          width: 40,
          color: selected ? palette.primary : Colors.transparent,
        ),
      ],
    );
  }
}
