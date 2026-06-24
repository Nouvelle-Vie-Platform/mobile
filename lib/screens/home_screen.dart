import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/media_thumbnail.dart';
import '../widgets/section_header.dart';

/// Onglet « Accueil » : en-tête ondulé, cultes à venir et derniers enseignements.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final teachings = ref.watch(teachingsProvider);
    // Dégagement pour la barre de nav givrée (sous laquelle le contenu défile).
    final bottomInset = MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête fixe : ne défile pas avec le contenu.
        const _WavyHeader(name: 'Jean'),
        // Contenu défilant sous l'en-tête.
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: bottomInset,
            ),
            children: [
              Padding(
                padding: AppSpacing.screenPadding,
                child: SectionHeader(
                  title: context.l10n.sectionUpcomingServices,
                  actionLabel: context.l10n.actionSeeAll,
                  onAction: () => context.pushNamed(AppRoute.agenda),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ServicesList(events: events),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: AppSpacing.screenPadding,
                child:
                    SectionHeader(title: context.l10n.sectionLatestTeachings),
              ),
              const SizedBox(height: AppSpacing.md),
              _TeachingsCarousel(teachings: teachings),
            ],
          ),
        ),
      ],
    );
  }
}

/// En-tête « plein écran » au dégradé bleu→teal, découpé en vague à sa base.
class _WavyHeader extends StatelessWidget {
  const _WavyHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderWaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradientHeader),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          // Dégagement pour la vague découpée à la base.
          bottom: AppSpacing.xxxl + AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.menu, color: Colors.white, size: 28),
                _NotificationBell(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              context.l10n.homeGreeting(name),
              style: AppTypography.h1.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.homeBlessing,
              style: AppTypography.bodyLarge
                  .copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _LiveCtaPill(),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none, color: Colors.white, size: 28),
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pastille jaune « Regarder le direct » → écran live.
class _LiveCtaPill extends StatelessWidget {
  const _LiveCtaPill();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.live),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors, size: 18, color: AppColors.neutralDark),
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.l10n.homeWatchLive,
              style: AppTypography.bodyStrong
                  .copyWith(color: AppColors.neutralDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrousel horizontal des cultes à venir (cartes-date compactes).
class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.events});
  final List<ChurchEvent> events;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => _ServiceDateCard(
          event: events[i],
          active: i == 0,
          onTap: () => context.pushNamed(AppRoute.agenda),
        ),
      ),
    );
  }
}

class _ServiceDateCard extends StatelessWidget {
  const _ServiceDateCard({
    required this.event,
    required this.active,
    this.onTap,
  });

  final ChurchEvent event;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = active ? Colors.white : palette.textPrimary;
    final fgMuted = active ? Colors.white70 : palette.textSecondary;
    // « 15:00 - 17:00 » → « 15:00 » pour une carte compacte.
    final startTime = event.time.split('-').first.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: active ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: active ? null : Border.all(color: palette.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(event.month,
                style: AppTypography.caption.copyWith(color: fgMuted)),
            const SizedBox(height: 2),
            Text(event.day, style: AppTypography.h1.copyWith(color: fg)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 13, color: fgMuted),
                const SizedBox(width: 4),
                Text(
                  startTime,
                  style: AppTypography.caption
                      .copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrousel horizontal des derniers enseignements (cartes image + texte).
class _TeachingsCarousel extends StatelessWidget {
  const _TeachingsCarousel({required this.teachings});
  final List<Teaching> teachings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: teachings.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => _TeachingCard(
          teaching: teachings[i],
          onTap: () => context.pushNamed(
            AppRoute.teachingDetail,
            extra: teachings[i],
          ),
        ),
      ),
    );
  }
}

class _TeachingCard extends StatelessWidget {
  const _TeachingCard({required this.teaching, this.onTap});
  final Teaching teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 264,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            MediaThumbnail(
              width: 104,
              height: double.infinity,
              borderRadius: 0,
              seed: teaching.seed,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      teaching.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong
                          .copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 13, color: palette.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          teaching.duration,
                          style: AppTypography.caption
                              .copyWith(color: palette.textSecondary),
                        ),
                      ],
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

/// Découpe la base de l'en-tête en vague (courbe de Bézier).
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 40)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height + 20,
        size.width,
        size.height - 60,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
