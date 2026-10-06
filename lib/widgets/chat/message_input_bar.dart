import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Barre de saisie d'un message : champ arrondi et bouton d'envoi circulaire
/// de marque.
///
/// **Ni emoji, ni pièce jointe, ni photo** (#140) : trois boutons étaient là, et
/// aucun ne faisait rien. La règle est celle du sélecteur de canaux de
/// connexion (#83) — **l'absence, pas le grisage** : un bouton qui ne répond pas
/// est une promesse que personne ne tient. Ils reviendront avec les médias (M4).
class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.hintText,
    this.controller,
    this.onSend,
    this.focusNode,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSend;

  /// Le focus du champ, pour que l'écran l'ouvre (clavier) — M2 : glisser pour
  /// répondre place le curseur dans le champ, comme WhatsApp.
  final FocusNode? focusNode;

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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
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
