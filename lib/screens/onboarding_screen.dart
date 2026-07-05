import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Méthode d'inscription choisie sur l'étape « Nous rejoindre ».
enum _JoinMethod { none, phone, email }

/// Parcours d'accueil / inscription en 3 étapes, sur fond bleu de marque :
/// en-tête logo, contenu (illustration ou formulaire), indicateurs et bouton
/// plein-largeur épinglé en bas.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  // Illustrations de la page d'accueil (remplaçables par de vraies photos).
  static const _welcomeImages = [
    'https://picsum.photos/seed/eglise/500/600',
    'https://picsum.photos/seed/louange/500/600',
    'https://picsum.photos/seed/communaute/500/600',
  ];

  final _pageController = PageController();
  final _joinController = TextEditingController();
  final _codeController = TextEditingController();

  int _page = 0;
  _JoinMethod _method = _JoinMethod.none;

  @override
  void initState() {
    super.initState();
    _joinController.addListener(_onChanged);
    _codeController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _pageController.dispose();
    _joinController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _goTo(int page) => _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  /// Auth réussie (fictive) → accueil.
  void _finish() => context.goNamed(AppRoute.home);

  bool get _joinReady =>
      _method != _JoinMethod.none && _joinController.text.trim().isNotEmpty;
  bool get _codeReady => _codeController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        child: SafeArea(
          child: Column(
            children: [
              // Barre de retour (visible dès la 2ᵉ étape).
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _page > 0
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              size: 20, color: Colors.white),
                          onPressed: () => _goTo(_page - 1),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [_welcomePage(), _joinPage(), _codePage()],
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Indicateurs (blancs) + bouton d'action contextuel épinglé en bas.
  Widget _bottomBar() {
    final l = context.l10n;
    Widget? button;
    if (_page == 0) {
      button =
          _WhiteButton(label: l.onboardingStart, onPressed: () => _goTo(1));
    } else if (_page == 1 && _joinReady) {
      button = _WhiteButton(label: l.actionJoin, onPressed: () => _goTo(2));
    } else if (_page == 2 && _codeReady) {
      button = _WhiteButton(label: l.actionValidate, onPressed: _finish);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dots(count: _pageCount, active: _page),
          const SizedBox(height: AppSpacing.lg),
          // Hauteur réservée pour éviter que les indicateurs ne sautent.
          SizedBox(height: 52, child: button ?? const SizedBox.shrink()),
        ],
      ),
    );
  }

  // ── Étape 1 : Bienvenue + verset ─────────────────────────────────────────
  Widget _welcomePage() {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          const _StackedCards(imageUrls: _welcomeImages),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l.onboardingWelcome,
            textAlign: TextAlign.center,
            style: AppTypography.h1
                .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.onboardingVerse,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Étape 2 : Nous rejoindre ─────────────────────────────────────────────
  Widget _joinPage() {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(l.onboardingJoinTitle,
              style: AppTypography.h2.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.onboardingJoinSubtitle,
            style: AppTypography.bodyLarge
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: AppSpacing.xl),
          // 4 méthodes sur une seule ligne, icônes uniquement.
          Row(
            children: [
              Expanded(
                child: _MethodTile(
                  icon: Icons.phone_outlined,
                  tooltip: l.authPhone,
                  selected: _method == _JoinMethod.phone,
                  onTap: () => setState(() => _method = _JoinMethod.phone),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MethodTile(
                  icon: Icons.mail_outline,
                  tooltip: l.authEmail,
                  selected: _method == _JoinMethod.email,
                  onTap: () => setState(() => _method = _JoinMethod.email),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MethodTile(
                  icon: Icons.g_mobiledata,
                  tooltip: 'Google',
                  selected: false,
                  onTap: _finish,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MethodTile(
                  icon: Icons.apple,
                  tooltip: 'Apple',
                  selected: false,
                  onTap: _finish,
                ),
              ),
            ],
          ),
          if (_method != _JoinMethod.none) ...[
            const SizedBox(height: AppSpacing.xl),
            _OnboardField(
              controller: _joinController,
              hint: _method == _JoinMethod.phone
                  ? '+228 90 12 34 56'
                  : 'jean.kossi@email.com',
              icon: _method == _JoinMethod.phone
                  ? Icons.phone_outlined
                  : Icons.mail_outline,
              keyboardType: _method == _JoinMethod.phone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
            ),
          ],
        ],
      ),
    );
  }

  // ── Étape 3 : Code de vérification ───────────────────────────────────────
  Widget _codePage() {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(l.onboardingCodeTitle,
              style: AppTypography.h2.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.onboardingCodeSubtitle,
            style: AppTypography.bodyLarge
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: AppSpacing.xl),
          _OnboardField(
            controller: _codeController,
            hint: '••••••',
            icon: Icons.password_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

/// Bouton de méthode (icône seule), blanc, contour bleu si choisi.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.tooltip,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primary : AppColors.neutralDark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: AppRadius.button,
        child: InkWell(
          borderRadius: AppRadius.button,
          onTap: onTap,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: AppRadius.button,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Center(child: Icon(icon, size: 24, color: fg)),
          ),
        ),
      ),
    );
  }
}

/// Champ de saisie blanc arrondi (sans label sombre), lisible sur fond bleu.
class _OnboardField extends StatelessWidget {
  const _OnboardField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.button,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTypography.bodyLarge.copyWith(color: AppColors.neutralDark),
        decoration: InputDecoration(
          filled: false,
          hintText: hint,
          hintStyle:
              AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
        ),
      ),
    );
  }
}

/// Bouton plein-largeur blanc (texte bleu) pour l'action principale.
class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: AppTypography.button.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateurs de page, blancs sur fond bleu.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

/// Illustration : trois cartes-photo empilées et pivotées (façon polaroid).
class _StackedCards extends StatelessWidget {
  const _StackedCards({required this.imageUrls});
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    String url(int i) => i < imageUrls.length ? imageUrls[i] : '';
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            bottom: 30,
            child: Transform.rotate(
              angle: -0.22,
              child: _ImageCard(url: url(0)),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 44,
            child: Transform.rotate(
              angle: 0.16,
              child: _ImageCard(url: url(1)),
            ),
          ),
          Transform.rotate(
            angle: 0.03,
            child: _ImageCard(url: url(2), front: true),
          ),
        ],
      ),
    );
  }
}

/// Carte-photo à liseré blanc, avec repli si l'image ne charge pas.
class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.url, this.front = false});
  final String url;
  final bool front;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: const Color(0xFFDDE3EC));
    return Container(
      width: 210,
      height: 160,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: front ? 0.28 : 0.14),
            blurRadius: front ? 22 : 10,
            offset: Offset(0, front ? 10 : 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
