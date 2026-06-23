import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/cards/event_card.dart';
import '../widgets/cards/teaching_tile.dart';
import '../widgets/section_header.dart';

/// Onglet « Accueil » : salutation, live, prochains événements et enseignements.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final teachings = ref.watch(teachingsProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const _GreetingHeader(name: 'Jean'),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                _LiveBanner(
                  onTap: () => context.pushNamed(AppRoute.live),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'À venir',
                  actionLabel: 'Voir tout',
                  onAction: () => context.pushNamed(AppRoute.agenda),
                ),
                const SizedBox(height: AppSpacing.md),
                EventCard(event: events.first),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Derniers enseignements'),
                const SizedBox(height: AppSpacing.md),
                for (final t in teachings.take(3)) ...[
                  TeachingTile(
                    teaching: t,
                    onTap: () => context.pushNamed(
                      AppRoute.teachingDetail,
                      extra: t,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonjour $name ! 👋',
                    style: AppTypography.h2.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text('Que Dieu vous bénisse aujourd\'hui.',
                    style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14)),
              ],
            ),
          ),
          _NotificationButton(),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.notifications_none, color: Colors.white),
          Positioned(
            top: 10,
            right: 12,
            child: CircleAvatar(radius: 4, backgroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Culte en direct', style: AppTypography.h5),
                    const SizedBox(height: 2),
                    Text('Rejoindre maintenant',
                        style: AppTypography.body
                            .copyWith(color: AppColors.neutralDark)),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.neutralDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
