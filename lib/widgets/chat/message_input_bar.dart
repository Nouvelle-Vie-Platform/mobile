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
/// est une promesse que personne ne tient. Le trombone, l'appareil photo et le
/// micro **reviennent avec les médias** (M4, #143), par les emplacements
/// [attachments], [voiceButton] et [replacement] — que `ChatComposer` remplit.
class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.hintText,
    this.controller,
    this.onSend,
    this.focusNode,
    this.attachments,
    this.voiceButton,
    this.replacement,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSend;

  /// Le focus du champ, pour que l'écran l'ouvre (clavier) — M2 : glisser pour
  /// répondre place le curseur dans le champ, comme WhatsApp.
  final FocusNode? focusNode;

  // ── Les médias (M4, #143) — trois emplacements, remplis par `ChatComposer` ──

  /// Le trombone et l'appareil photo, **dans** le champ, après le texte.
  final Widget? attachments;

  /// Le micro : il prend la place du bouton d'envoi **tant que le champ est
  /// vide**, comme WhatsApp.
  final Widget? voiceButton;

  /// Ce qui remplace le champ (la bande d'un vocal en cours d'enregistrement).
  final Widget? replacement;

  void _send() {
    final text = controller?.text.trim() ?? '';
    if (text.isEmpty) return;
    onSend?.call(text);
    controller?.clear();
  }

  /// Le bouton d'envoi — ou, champ vide, le micro (M4).
  Widget _sendSlot() {
    final send = GestureDetector(
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
    );
    final voice = voiceButton, text = controller;
    if (voice == null || text == null) return send;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: text,
      builder: (context, value, _) => value.text.trim().isEmpty ? voice : send,
    );
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
        // Les boutons restent **en bas** quand le champ grandit, comme
        // WhatsApp : le pouce les trouve au même endroit.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: replacement ??
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      // Un rayon fixe, pas une pilule : sur plusieurs lignes, un
                      // rayon « pill » ferait un ovale.
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: palette.border),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          // **Le texte passe à la ligne** au bord du champ, et
                          // la touche Entrée insère une ligne : on envoie avec
                          // le bouton. Le champ grandit jusqu'à six lignes, puis
                          // défile.
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            cursorColor: AppColors.secondary,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: 1,
                            maxLines: 6,
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
                        if (attachments != null) attachments!,
                      ],
                    ),
                  ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _sendSlot(),
          ],
        ),
      ),
    );
  }
}
