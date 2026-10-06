import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

/// Ce qu'on peut joindre (M4, #143).
enum AttachmentChoice {
  gallery,
  video,
  recordVideo,
  document,
  audio,
  location,
  contact,
}

/// **La feuille du trombone** (M4) : sept sources, comme WhatsApp — moins
/// les sondages et les paiements. Rend le choix, ou `null` si l'on referme.
///
/// Elle réapparaît avec cette tranche : M1b l'avait retirée parce qu'elle ne
/// faisait rien (« l'absence, pas le grisage »). Chaque entrée mène désormais
/// quelque part.
Future<AttachmentChoice?> showAttachmentSheet(BuildContext context) {
  return showModalBottomSheet<AttachmentChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => const AttachmentSheet(),
  );
}

class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = <(AttachmentChoice, IconData, Color, String)>[
      (
        AttachmentChoice.gallery,
        Icons.photo_library,
        const Color(0xFFAC44CF),
        l.m4AttachGallery,
      ),
      (
        AttachmentChoice.video,
        Icons.video_library,
        const Color(0xFFD3396D),
        l.m4AttachVideo,
      ),
      (
        AttachmentChoice.recordVideo,
        Icons.videocam,
        const Color(0xFFE5452F),
        l.m4AttachRecordVideo,
      ),
      (
        AttachmentChoice.document,
        Icons.insert_drive_file,
        const Color(0xFF5F66CD),
        l.m4AttachDocument,
      ),
      (
        AttachmentChoice.audio,
        Icons.headphones,
        const Color(0xFFF96533),
        l.m4AttachAudio,
      ),
      (
        AttachmentChoice.location,
        Icons.location_on,
        const Color(0xFF1FA855),
        l.m4AttachLocation,
      ),
      (
        AttachmentChoice.contact,
        Icons.person,
        const Color(0xFF009DE2),
        l.m4AttachContact,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            for (final (choice, icon, color, label) in entries)
              SizedBox(
                width: 76,
                child: InkWell(
                  key: Key('m4_attach_${choice.name}'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Navigator.of(context).pop(choice),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: color,
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: context.palette.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
