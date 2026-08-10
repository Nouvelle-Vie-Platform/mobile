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
          // Nom de marque posé sur le bas de l'animation. La colombe est
          // entière : plus rien à masquer, seul le mot-symbole doré subsiste.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(child: _NouvelleVieWordmark()),
          ),
        ],
      ),
    );
  }
}

/// Typo du mot-symbole : serif classique, majuscules très espacées.
const TextStyle _wordmarkTextStyle = TextStyle(
  color: Colors.white, // remplacé par le dégradé doré (ShaderMask)
  fontFamily: 'Georgia',
  fontFamilyFallback: ['Times New Roman', 'serif'],
  fontSize: 18,
  fontWeight: FontWeight.w400,
  letterSpacing: 3.4,
);

/// Même typo, en sombre : sert d'ombre portée sous le texte doré. Sans plaque,
/// c'est elle qui détache l'or de la scène nocturne en arrière-plan.
const TextStyle _wordmarkShadowStyle = TextStyle(
  color: Color(0xB003091F),
  fontFamily: 'Georgia',
  fontFamilyFallback: ['Times New Roman', 'serif'],
  fontSize: 18,
  fontWeight: FontWeight.w400,
  letterSpacing: 3.4,
);

/// Mot-symbole doré « Nouvelle Vie » posé sous la colombe.
///
/// Élément de marque (nom de l'église) qui habille l'écran. La colombe étant
/// désormais entière, il n'y a plus rien à masquer : la plaque (liseré, fond
/// navy) et le rameau doré ont disparu, seul reste le texte serif à dégradé
/// métallique, détaché de la scène nocturne par une ombre portée.
class _NouvelleVieWordmark extends StatelessWidget {
  const _NouvelleVieWordmark();

  /// Dégradé métallique du texte (clair en haut, ambre en bas).
  static const _textGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8E8), Color(0xFFF2DFB8), Color(0xFFD2AE74)],
    stops: [0.0, 0.55, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ombre portée : détache l'or du fond immersif.
        const Padding(
          padding: EdgeInsets.only(top: 1.6),
          child: Text('NOUVELLE VIE', style: _wordmarkShadowStyle),
        ),
        ShaderMask(
          shaderCallback: (bounds) => _textGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            // Nom de marque : non localisé.
            'NOUVELLE VIE',
            style: _wordmarkTextStyle,
          ),
        ),
      ],
    );
  }
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
