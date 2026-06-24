import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// Barre d'application d'une discussion : dégradé de marque, retour, avatar
/// avec pastille de présence, titre + sous-titre et actions.
///
/// Composant autonome (implémente [PreferredSizeWidget]) réutilisable par tout
/// écran de messagerie.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.online = true,
    this.onBack,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final bool online;
  final VoidCallback? onBack;
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
          _AvatarWithStatus(name: title, online: online),
        ],
      ),
      title: Column(
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
      actions: actions,
    );
  }
}

/// Avatar du correspondant avec pastille de présence en surimpression.
class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppAvatar(name: name, size: 36),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
