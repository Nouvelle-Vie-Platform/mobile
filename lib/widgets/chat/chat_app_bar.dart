import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// Barre d'application d'une discussion : dégradé de marque, retour, avatar,
/// titre + sous-titre et actions.
///
/// Composant autonome (implémente [PreferredSizeWidget]) réutilisable par tout
/// écran de messagerie.
///
/// **Aucune pastille de présence** (#140). Elle était là, verte, pour tout le
/// monde et tout le temps : un « en ligne » qui ne mesure rien est un mensonge
/// visuel. La présence reviendra avec sa tranche (M3, « en ligne / vu à »),
/// mesurée par le serveur et soumise à la réciprocité — pas avant.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onTitleTap,
    this.actions,
  });

  final String title;
  final String? subtitle;

  /// Le retour. `null` = dépiler (`context.pop()`) — ce qui suppose une pile :
  /// un écran ouvert par `goNamed` (une notification) doit passer le sien.
  final VoidCallback? onBack;

  /// Tap sur le titre (nom + sous-titre) — ouvre p.ex. la liste des membres d'un
  /// groupe. `null` = titre non interactif (message direct).
  final VoidCallback? onTitleTap;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      // Fond bleu solide garanti (le dégradé en flexibleSpace le sublime).
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
      ),
      leadingWidth: 96,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: onBack ?? () => context.pop(),
          ),
          AppAvatar(name: title, size: 36),
        ],
      ),
      title: InkWell(
        onTap: onTitleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h5.copyWith(color: Colors.white),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
          ],
        ),
      ),
      actions: actions,
    );
  }
}
