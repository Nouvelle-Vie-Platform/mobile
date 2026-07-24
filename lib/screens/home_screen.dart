import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../state/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/cards/teaching_cover.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/section_header.dart';

/// Onglet « Accueil » : en-tête ondulé, cultes à venir et derniers enseignements.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final teachings = ref.watch(teachingsProvider);
    // Affiche la bannière « compléter le profil » seulement si pertinente
    // (utilisateur présent, profil incomplet, bannière non fermée).
    final user = ref.watch(authProvider).user;
    final bannerDismissed = ref.watch(profileBannerDismissedProvider);
    final showBanner =
        user != null && !user.profileComplete && !bannerDismissed;
    // Dégagement pour la barre de nav givrée (sous laquelle le contenu défile) :
    // hauteur de la barre + encoche, pour que la dernière carte puisse être
    // remontée entièrement au-dessus d'elle.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + AppSpacing.xl;
    // Hauteur de l'en-tête : il est posé PAR-DESSUS la liste (Stack) pour que
    // le contenu glisse dessous au défilement au lieu d'être coupé avant lui.
    final headerHeight = MediaQuery.paddingOf(context).top + _headerBodyHeight;

    return Stack(
      // `expand` : sans cela le Stack se dimensionnerait sur l'en-tête et la
      // liste serait réduite à sa hauteur.
      fit: StackFit.expand,
      children: [
        // Contenu défilant : démarre sous l'en-tête et passe derrière lui.
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight + AppSpacing.md,
            bottom: bottomInset,
          ),
          children: [
            // Bannière douce d'invitation à compléter le profil (masquée si
            // profil complet, absent ou fermée).
            if (showBanner) ...[
              Padding(
                padding: AppSpacing.screenPadding,
                child: const ProfileCompletionBanner(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Padding(
              padding: AppSpacing.screenPadding,
              child: SectionHeader(
                title: context.l10n.sectionUpcoming,
                icon: Icons.calendar_month_outlined,
                actionLabel: context.l10n.actionSeeAll,
                onAction: () => context.pushNamed(AppRoute.agenda),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ServicesList(events: events),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: AppSpacing.screenPadding,
              child: SectionHeader(
                title: context.l10n.sectionLatestTeachings,
                icon: Icons.menu_book_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _TeachingsCarousel(teachings: teachings),
          ],
        ),
        // En-tête opaque posé par-dessus : le contenu disparaît derrière lui.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _WavyHeader(name: _firstName(user), height: headerHeight),
        ),
      ],
    );
  }
}

/// Hauteur du corps de l'en-tête (sous l'encoche). Fixe, car l'en-tête est
/// superposé à la liste : le décalage haut du contenu doit être connu.
const double _headerBodyHeight = 274;

/// En-tête « plein écran » au dégradé bleu→teal, découpé en vague à sa base.
/// Prénom d'usage pour la salutation : premier mot du nom saisi au profil.
/// `null` si l'utilisateur n'a pas (encore) renseigné son nom — le profil
/// étant facultatif, ce cas est normal.
String? _firstName(User? user) {
  final full = user?.fullName?.trim();
  if (full == null || full.isEmpty) return null;
  return full.split(RegExp(r'\s+')).first;
}

class _WavyHeader extends StatelessWidget {
  const _WavyHeader({required this.name, required this.height});
  final String? name;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: _HeaderWaveClipper(),
        child: DecoratedBox(
          decoration:
              const BoxDecoration(gradient: AppColors.gradientHomeHeader),
          child: Stack(
            children: [
              // Église + rayons, calés à droite. L'image est déjà fondue à
              // gauche (alpha) : elle se marie au dégradé sans raccord visible.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Image.asset(
                    'assets/images/home_header_church.webp',
                    // Hauteur de l'en-tête, ratio conservé : l'église occupe la
                    // moitié droite comme sur la maquette (pas de zoom).
                    fit: BoxFit.fitHeight,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // Voile bleu : tamise la photo (trop lumineuse brute) et adoucit
              // son bord droit pour éviter la coupe nette.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xCC022163),
                        Color(0x73022163),
                        Color(0x8C012A72),
                      ],
                      stops: [0.30, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
              // Fondu vaporeux à la base : l'église se dissout dans le fond
              // du contenu au lieu d'être tranchée par la vague.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00ECF1FB),
                        Color(0x2EECF1FB),
                        Color(0x8CECF1FB),
                      ],
                      stops: [0.62, 0.86, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + AppSpacing.md,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  // Dégagement pour la vague découpée à la base.
                  bottom: AppSpacing.xxxl + AppSpacing.lg,
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
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      name == null
                          ? context.l10n.homeGreetingNoName
                          : context.l10n.homeGreeting(name!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Barre jaune sous la salutation (accent de la maquette).
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.homeBlessing,
                      style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.88)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _LiveCtaPill(),
                  ],
                ),
              ),
            ],
          ),
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

/// Carrousel horizontal des évènements à venir.
class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.events});
  final List<ChurchEvent> events;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => _UpcomingCard(
          event: events[i],
          current: i == 0,
          onTap: () => context.pushNamed(AppRoute.agenda),
        ),
      ),
    );
  }
}

/// Étiquette « à venir » : bloc date/heure (bleu) + détails (jour, intitulé,
/// temple). Largeur fixe pour laisser dépasser les étiquettes suivantes.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.event,
    this.current = false,
    this.onTap,
  });

  final ChurchEvent event;

  /// Évènement courant (du jour) : bloc date mis en avant en bleu.
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // « 15:00 - 17:00 » → « 15:00 ».
    final startTime = event.time.split('-').first.trim();

    final boxColor = current ? palette.primary : palette.surfaceAlt;
    final fg = current ? Colors.white : palette.textPrimary;
    final fgMuted =
        current ? Colors.white.withValues(alpha: 0.8) : palette.textSecondary;

    return SizedBox(
      width: 270,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bloc date/heure.
            Container(
              width: 78,
              color: boxColor,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(event.month,
                      style: AppTypography.caption.copyWith(color: fgMuted)),
                  Text(event.day, style: AppTypography.h2.copyWith(color: fg)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 12, color: fgMuted),
                      const SizedBox(width: 3),
                      Text(startTime,
                          style: AppTypography.caption.copyWith(
                              color: fg, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            // Détails : jour, intitulé, temple.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Puce du jour (fond bleu très clair), façon maquette.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(event.weekday,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong
                            .copyWith(color: palette.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 13, color: palette.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(event.place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption
                                  .copyWith(color: palette.textSecondary)),
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

/// Carrousel horizontal des derniers enseignements (cartes image + texte).
class _TeachingsCarousel extends StatelessWidget {
  const _TeachingsCarousel({required this.teachings});
  final List<Teaching> teachings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
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
            SizedBox(
              width: 104,
              child: TeachingCover(teaching: teaching, radius: 0),
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
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.md),
                    // Bouton « Écouter » en pilule contournée (façon maquette).
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              size: 16, color: palette.primary),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.actionListen,
                            style: AppTypography.caption.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
