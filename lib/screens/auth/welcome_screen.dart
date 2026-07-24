import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Première page de `/auth` : accueil / point d'entrée du parcours unifié.
///
/// Écran immersif : une scène nocturne (image de fond, église + rayon de
/// lumière), une colombe animée (WebP animé, boucle infinie) nimbée d'un halo,
/// le message de bienvenue, puis le bouton « Commencer » menant à la saisie de
/// l'identifiant (flow login/inscription unifié).
///
/// Écran sans état : un simple [ConsumerWidget] suffit.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Le Scaffold reste transparent : l'image de fond ci-dessous couvre l'écran.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond immersif plein écran (repli sur le dégradé de marque).
          Image.asset(
            'assets/images/welcome_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
            ),
          ),
          // Léger voile bas pour la lisibilité du texte et du bouton.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66020A1E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.32),
                    child: SingleChildScrollView(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _DoveAnimation(),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            l.onboardingWelcome,
                            textAlign: TextAlign.center,
                            style: AppTypography.h1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 42,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Fin trait lumineux (centre plus clair), façon maquette.
                          Container(
                            width: 160,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l.onboardingTitleHighlight,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _StartButton(
                  label: l.authStart,
                  onTap: () => context.goNamed(AppRoute.authIdentifier),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Colombe de la paix animée (WebP animé, alpha) nimbée d'un halo lumineux.
///
/// Le WebP boucle nativement (`Loop Count : 0`) : aucun plugin, compatible web.
/// L'animation est détourée (fond transparent) et survole la scène de fond.
class _DoveAnimation extends StatelessWidget {
  const _DoveAnimation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo radial derrière la colombe.
          IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x33FFFFFF), Colors.transparent],
                  stops: [0.15, 1.0],
                ),
              ),
            ),
          ),
          Image.asset(
            'assets/animations/colombe.webp',
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Plaque de marque posée sur le bas de l'animation : la queue de la
          // colombe (tronquée dans la vidéo source) passe derrière.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: _NouvelleViePlaque()),
          ),
        ],
      ),
    );
  }
}

/// Plaque dorée « Nouvelle Vie » posée sur le bas de la colombe.
///
/// Élément de marque (nom de l'église) qui habille l'écran et recouvre la
/// partie basse de l'animation : la queue de la colombe, tronquée dans la
/// vidéo source, disparaît derrière la plaque.
class _NouvelleViePlaque extends StatelessWidget {
  const _NouvelleViePlaque();

  static const _gold = Color(0xFFD8C09C);
  static const _goldBright = Color(0xFFF0D8B4);
  static const _fill = Color(0xF7141B30);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 286,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cadre doré + fond sombre (opaque : c'est lui qui masque la queue).
          Container(
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _gold, width: 1.4),
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: const Text(
                // Nom de marque : non localisé.
                'NOUVELLE VIE',
                style: TextStyle(
                  color: _goldBright,
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          // Rameau d'olivier doré débordant du coin haut-gauche.
          const Positioned(
            left: -16,
            top: -22,
            child: CustomPaint(
              size: Size(76, 46),
              painter: _OliveBranchPainter(_goldBright),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit rameau d'olivier doré : tige courbe + feuilles alternées.
class _OliveBranchPainter extends CustomPainter {
  const _OliveBranchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final leaf = Paint()..color = color;
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.05
      ..strokeCap = StrokeCap.round;

    final p0 = Offset(w * 0.03, h * 0.92);
    final p1 = Offset(w * 0.50, h * 0.86);
    final p2 = Offset(w * 0.99, h * 0.34);

    canvas.drawPath(
      Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
      stem,
    );

    const stops = <double>[0.16, 0.32, 0.48, 0.64, 0.80, 0.94];
    for (var i = 0; i < stops.length; i++) {
      final t = stops[i];
      final pos = _point(p0, p1, p2, t);
      final tangent = _tangent(p0, p1, p2, t);
      final angle =
          math.atan2(tangent.dy, tangent.dx) + (i.isEven ? -0.9 : 0.9);
      final length = h * (0.42 - i * 0.02);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(angle)
        ..drawOval(
          Rect.fromCenter(
            center: Offset(length * 0.5, 0),
            width: length,
            height: length * 0.4,
          ),
          leaf,
        )
        ..restore();
    }
  }

  static Offset _point(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx,
      u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy,
    );
  }

  static Offset _tangent(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      2 * u * (b.dx - a.dx) + 2 * t * (c.dx - b.dx),
      2 * u * (b.dy - a.dy) + 2 * t * (c.dy - b.dy),
    );
  }

  @override
  bool shouldRepaint(_OliveBranchPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bouton principal « Commencer » épinglé en bas : pilule blanche, texte bleu,
/// et pastille circulaire bleue avec flèche à gauche (façon maquette).
///
/// Au tap, la pilule se **remplit de gauche à droite** avec le bleu de la
/// pastille (le texte et la flèche s'inversent au passage du remplissage),
/// puis l'action de navigation est déclenchée.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  static const _height = 60.0;

  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_fill.isAnimating || _fill.value == 1) return;
    await _fill.forward();
    if (!mounted) return;
    widget.onTap();
    // Rétablit la pilule blanche une fois la transition de route passée,
    // au cas où l'écran resterait monté (retour arrière).
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fill.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: _height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: _handleTap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return AnimatedBuilder(
                    animation: _fill,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_fill.value);
                      return Stack(
                        children: [
                          _StartButtonFace(
                            label: widget.label,
                            background: Colors.transparent,
                            foreground: AppColors.primary,
                            badgeBackground: AppColors.primary,
                            badgeForeground: Colors.white,
                            height: _height,
                          ),
                          // Remplissage de gauche à droite.
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: t,
                              child: SizedBox(
                                width: width,
                                child: _StartButtonFace(
                                  label: widget.label,
                                  background: AppColors.primary,
                                  foreground: Colors.white,
                                  badgeBackground: Colors.white,
                                  badgeForeground: AppColors.primary,
                                  height: _height,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un « état » visuel du bouton (fond, texte, pastille) — empilé deux fois pour
/// produire l'effet de remplissage.
class _StartButtonFace extends StatelessWidget {
  const _StartButtonFace({
    required this.label,
    required this.background,
    required this.foreground,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.height,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color badgeBackground;
  final Color badgeForeground;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: background,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              label,
              style: AppTypography.button.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            left: 8,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeBackground,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: badgeForeground,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
