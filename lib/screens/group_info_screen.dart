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
import '../widgets/app_card.dart';
import 'media_viewer_screen.dart';

/// Fiche d'un groupe, ouverte en tapant le nom du groupe dans la discussion —
/// **inspiration Telegram** : en-tête immersif (logo + nom + effectif), puis
/// description, médias partagés, et enfin la liste des membres.
///
/// Taper un membre ouvre son **profil**, d'où l'on démarre une conversation
/// privée (décision D10). Domaine fictif : tout vient de [Conversation].
class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.group});

  final Conversation group;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final description = group.description;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(group: group),
          const SizedBox(height: AppSpacing.lg),
          if (description != null && description.isNotEmpty) ...[
            _DescriptionCard(text: description),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (group.sharedMedia.isNotEmpty) ...[
            _SharedMedia(urls: group.sharedMedia),
            const SizedBox(height: AppSpacing.xl),
          ],
          _SectionTitle(l.groupMembers(group.members.length)),
          const SizedBox(height: AppSpacing.md),
          for (final name in group.members) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _MemberTile(name: name),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// En-tête immersif au dégradé de marque : retour, grand logo, nom, effectif.
class _Header extends StatelessWidget {
  const _Header({required this.group});

  final Conversation group;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
            child: AppAvatar(name: group.name, size: 96),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              group.name,
              textAlign: TextAlign.center,
              style: AppTypography.h3.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.groupMembers(group.members.length),
            style: AppTypography.body
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.groupInfoAbout,
              style: AppTypography.caption.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(text, style: AppTypography.body),
          ],
        ),
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
        _SectionTitle(context.l10n.groupInfoSharedMedia),
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
          // Repli coloré : jamais d'échec réseau visible (hors ligne / test).
          errorBuilder: (_, __, ___) => ColoredBox(
            color: palette.divider,
            child: Icon(Icons.image_outlined, color: palette.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: () => context.pushNamed(AppRoute.memberProfile, extra: name),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(name: name, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(name, style: AppTypography.bodyStrong)),
          Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(label, style: AppTypography.h5),
    );
  }
}
