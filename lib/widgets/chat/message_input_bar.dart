import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Barre de saisie d'un message : champ arrondi (emoji, pièce jointe, photo)
/// et bouton d'envoi circulaire de marque.
class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.hintText,
    this.controller,
    this.onSend,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSend;

  void _send() {
    final text = controller?.text.trim() ?? '';
    if (text.isEmpty) return;
    onSend?.call(text);
    controller?.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      color: palette.textSecondary,
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        cursorColor: AppColors.secondary,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        style: AppTypography.bodyLarge
                            .copyWith(color: palette.textPrimary),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          hintText: hintText,
                          hintStyle: AppTypography.bodyLarge
                              .copyWith(color: palette.textSecondary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: palette.textSecondary,
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_camera_outlined),
                      color: palette.textSecondary,
                      onPressed: () {},
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppColors.gradientSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
