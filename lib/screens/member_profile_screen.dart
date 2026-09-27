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
/// groupe (D15). Même inspiration Telegram : en-tête immersif (avatar, nom,
/// statut), action **Message** (démarre/rouvre une conversation directe, D10),
/// puis les **médias partagés**.
///
/// Accessible aussi bien depuis un groupe (membre, auteur d'un message) que
/// depuis l'en-tête d'une discussion privée : un utilisateur simple bénéficie
/// de la même page détail. Domaine fictif — les médias sont dérivés du nom.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.memberName});

  final String memberName;

  /// Médias partagés fictifs, **déterministes** pour un nom donné (pas d'aléa,
  /// pour que la page soit stable d'un affichage à l'autre).
  List<String> get _sharedMedia {
    final seed = memberName.hashCode.abs();
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
          _Header(name: memberName),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppButton(
              label: l.memberMessage,
              icon: Icons.chat_bubble_outline,
              onPressed: () => context.pushNamed(
                AppRoute.groupChat,
                extra: Conversation(
                  id: 'dm-${memberName.hashCode}',
                  kind: ConversationKind.direct,
                  name: memberName,
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
