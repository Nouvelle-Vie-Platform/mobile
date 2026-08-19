import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import 'media_viewer_screen.dart';

/// Fiche détail d'un **membre** — le pendant, pour une personne, de la fiche de
/// groupe (D15). Même inspiration Telegram : en-tête immersif (avatar, nom),
/// action **Message** (démarre/rouvre une conversation directe, D10).
///
/// **Au réel** (PRD `messagerie-directe.md`) : la fiche porte le **vrai `userId`**
/// du membre ([GroupMemberView]), d'où part le DM. Le bouton « Message » ouvre le
/// fil direct **adressé par `userId`** — création paresseuse : le fil n'existe
/// qu'au premier message. Les médias partagés restent une maquette.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.member});

  final GroupMemberView member;

  /// Médias partagés fictifs, **déterministes** pour un membre donné.
  List<String> get _sharedMedia {
    final seed = member.userId.hashCode.abs();
    return List.generate(
      4,
      (i) => 'https://picsum.photos/seed/m$seed-$i/240',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(name: member.name),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppButton(
              label: l.memberMessage,
              icon: Icons.chat_bubble_outline,
              // DM **adressé par userId**, fil vide au départ (création paresseuse) :
              // l'écran de chat le résout par `directConversationProvider` et se
              // rebranche sur l'id réel après le premier envoi.
              onPressed: () => context.pushNamed(
                AppRoute.groupChat,
                extra: Conversation(
                  id: '',
                  kind: ConversationKind.direct,
                  name: member.name,
                  avatarUrl: member.avatarUrl,
                  peerUserId: member.userId,
                  lastMessagePreview: '',
                  time: '',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SharedMedia(urls: _sharedMedia),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// En-tête immersif au dégradé de marque : retour, grand avatar, nom, statut.
class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
      padding: EdgeInsets.only(top: topInset, bottom: AppSpacing.xl),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: AppAvatar(name: name, size: 96),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: AppTypography.h3.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.memberProfileSubtitle,
            style: AppTypography.body
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _SharedMedia extends StatelessWidget {
  const _SharedMedia({required this.urls});

  final List<String> urls;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child:
              Text(context.l10n.groupInfoSharedMedia, style: AppTypography.h5),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: _size,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => context.pushNamed(
                AppRoute.mediaViewer,
                extra: MediaViewerArgs(urls: urls, index: i),
              ),
              child: _MediaThumb(url: urls[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: AppRadius.card,
      child: SizedBox(
        width: _SharedMedia._size,
        height: _SharedMedia._size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: palette.divider,
            child: Icon(Icons.image_outlined, color: palette.textSecondary),
          ),
        ),
      ),
    );
  }
}
