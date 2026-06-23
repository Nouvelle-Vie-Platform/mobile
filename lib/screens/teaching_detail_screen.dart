import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/icon_text.dart';
import '../widgets/media_thumbnail.dart';

/// Écran de détail d'un enseignement (vidéo, actions, description).
class TeachingDetailScreen extends StatelessWidget {
  const TeachingDetailScreen({super.key, required this.teaching});

  final Teaching teaching;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.teachingAppBarTitle)),
      body: ListView(
        children: [
          MediaThumbnail(height: 210, borderRadius: 0, seed: teaching.seed),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(teaching.title, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    IconText(
                        icon: Icons.person_outline, label: teaching.author),
                    const SizedBox(width: AppSpacing.lg),
                    IconText(icon: Icons.schedule, label: teaching.duration),
                  ],
                ),
                const SizedBox(height: 4),
                Text('1.2K vues • 26 Mai 2024',
                    style: AppTypography.caption
                        .copyWith(color: context.palette.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Action(
                        icon: Icons.download_outlined,
                        label: context.l10n.actionDownload),
                    _Action(
                        icon: Icons.bookmark_add_outlined,
                        label: context.l10n.actionMyNotes),
                    _Action(
                        icon: Icons.share_outlined,
                        label: context.l10n.actionShare),
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
                  label: context.l10n.actionDownloadAudio,
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
    return Row(
      children: [
        _Tab(label: context.l10n.tabDescription, selected: true),
        const SizedBox(width: AppSpacing.xl),
        _Tab(label: context.l10n.tabNotesCount(12), selected: false),
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
