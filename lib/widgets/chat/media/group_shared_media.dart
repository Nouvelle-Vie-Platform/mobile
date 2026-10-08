import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/echanges_view.dart';
import '../../../models/message_media.dart';
import '../../../router/app_router.dart';
import '../../../state/echanges_providers.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import 'message_media_view.dart';

/// **Les médias partagés d'un groupe**, sur sa fiche (M4, #143 — #98) : la
/// ligne « Médias, liens et docs » avec leur nombre, qui ouvre l'écran à trois
/// onglets, puis l'aperçu des images et vidéos du fil, les plus récentes
/// d'abord. Au toucher d'une vignette, ce que fait la bulle.
///
/// « Pas de contenu, pas de section » : sans média, lien ni document au fil,
/// rien ne se peint.
class GroupSharedMedia extends ConsumerWidget {
  const GroupSharedMedia({super.key, required this.groupId});

  final String groupId;

  static const openKey = Key('shared_content_open');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (actor: ref.watch(echangesActorProvider), id: groupId);
    final files = ref.watch(groupSharedFilesProvider(key)).value ?? const [];
    final links = ref.watch(groupSharedLinksProvider(key)).value ?? const [];
    final total = files.length + links.length;
    if (total == 0) return const SizedBox.shrink();

    final visuals = files
        .where((m) =>
            m.media!.kind == MessageMediaKind.image ||
            m.media!.kind == MessageMediaKind.video)
        .take(30)
        .toList();

    return Column(
      key: const Key('m4_shared_media'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: openKey,
          onTap: () => context.pushNamed(
            AppRoute.groupSharedContent,
            pathParameters: {'id': groupId},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.sharedContentTitle,
                    style: AppTypography.h5,
                  ),
                ),
                Text(
                  '$total',
                  key: const Key('shared_content_count'),
                  style: AppTypography.body
                      .copyWith(color: context.palette.textSecondary),
                ),
                Icon(Icons.chevron_right, color: context.palette.textSecondary),
              ],
            ),
          ),
        ),
        if (visuals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 96,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: visuals.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) => _thumb(visuals[i]),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _thumb(GroupMessageView message) {
    final media = message.media!;
    return media.kind == MessageMediaKind.video
        ? VideoMediaTile(message: message, media: media, extent: 96)
        : ImageMediaTile(message: message, media: media, extent: 96);
  }
}
