import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../screens/media_viewer_screen.dart';
import '../../../state/chat_media_providers.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

/// **Les médias partagés d'un groupe** (M4, #143 — #98) : les images du fil,
/// les plus récentes d'abord, sur la fiche du groupe. Au toucher, la
/// visionneuse existante.
///
/// « Pas de contenu, pas de section » : sans image au fil, rien ne se peint —
/// ni titre suivi du vide, ni images inventées (la tranche 1 avait retiré les
/// `picsum.photos` pour cette raison).
class GroupSharedMedia extends ConsumerWidget {
  const GroupSharedMedia({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(groupSharedImagesProvider(groupId)).value ?? const [];
    if (ids.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('m4_shared_media'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(context.l10n.m4SharedMedia, style: AppTypography.h5),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) =>
                _SharedThumb(groupId: groupId, messageId: ids[i]),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _SharedThumb extends ConsumerStatefulWidget {
  const _SharedThumb({required this.groupId, required this.messageId});

  final String groupId;
  final String messageId;

  @override
  ConsumerState<_SharedThumb> createState() => _SharedThumbState();
}

class _SharedThumbState extends ConsumerState<_SharedThumb> {
  late final Future<String?> _url = ref
      .read(groupMediaUrlsProvider)
      .resolve(groupId: widget.groupId, messageId: widget.messageId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        return GestureDetector(
          onTap: url == null
              ? null
              : () => context.pushNamed(
                    AppRoute.mediaViewer,
                    extra: MediaViewerArgs(urls: [url], index: 0),
                  ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 96,
              height: 96,
              color: Colors.black12,
              child: url == null
                  ? const Icon(Icons.image_outlined, color: Colors.black26)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      cacheWidth: 192,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.black26,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
