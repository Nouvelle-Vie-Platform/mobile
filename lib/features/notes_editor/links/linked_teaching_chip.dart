/// **La puce « enseignement lié »** (N5, #193), sous le titre de la note :
/// le titre de l'enseignement, et le lecteur au toucher.
///
/// Lue dans le magasin local. Aucune FK côté mobile (piège 10) : un
/// enseignement retiré quitte le magasin, et la puce disparaît d'elle-même.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../state/mediatheque_providers.dart';

class LinkedTeachingChip extends ConsumerWidget {
  const LinkedTeachingChip({super.key, required this.teachingId});

  /// `note.teachingId` ; nul → rien.
  final String? teachingId;

  static const Key chipKey = Key('note_linked_teaching');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = teachingId;
    if (id == null) return const SizedBox.shrink();
    final teaching = ref.watch(teachingByIdProvider(id)).value;
    if (teaching == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ActionChip(
        key: chipKey,
        avatar: const Icon(Icons.play_circle_outline, size: 18),
        label: Text(
          teaching.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () => context.pushNamed(
          AppRoute.teachingDetail,
          pathParameters: {'id': id},
        ),
      ),
    );
  }
}
