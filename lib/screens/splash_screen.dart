import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/season_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_logo.dart';

/// Écran de démarrage (splash) — écran de marque, sur le fond de la saison.
///
/// Aiguillage **automatique** : le `redirect` du routeur, piloté par
/// `authProvider`, garde l'utilisateur ici tant que la session n'est pas
/// résolue (`AuthStatus.unknown`), puis l'envoie vers `/auth` ou `/home`.
/// Cet écran ne navigue donc **jamais** de lui-même — il se contente
/// d'afficher l'emblème et un indicateur de chargement pendant la résolution.
///
/// ## Le fond vient du disque, jamais du réseau
///
/// C'est le même fond que les deux lecteurs, mais lu **autrement** : par
/// `startupBackgroundProvider`, que `main()` a rempli avant le premier frame en
/// regardant le dossier de cache. Cet écran dure le temps de résoudre une
/// session ; y déclencher une lecture de base ou une descente d'image donnerait
/// un fond qui apparaît une fraction de seconde après que l'écran a disparu, ou
/// pire, qui retarde l'ouverture de l'application.
///
/// **Le premier lancement n'a donc pas de fond**, et c'est le contrat : on
/// descend pendant que l'application tourne, on s'en sert à l'ouverture
/// suivante.
///
/// ## Le dégradé reste, il ne se remplace pas
///
/// Il est peint **par-dessus** l'image, à demi opaque. Sans lui, un fond clair
/// rendrait l'emblème blanc, le nom de l'église et le témoin de chargement
/// illisibles — et ça ne se verrait qu'avec ce fond-là, c'est-à-dire un jour,
/// chez quelqu'un d'autre.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = ref.watch(startupBackgroundProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (background != null)
              Image(
                image: background,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: background == null
                    ? AppColors.gradientPrimary
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.70),
                        ],
                      ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    const BrandLogo(size: 200),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      context.l10n.appName,
                      style: AppTypography.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.l10n.splashTagline,
                      style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const Spacer(flex: 3),
                    // Indicateur de résolution de la session (non interactif) :
                    // le `redirect` du routeur aiguille automatiquement dès que
                    // `authProvider` quitte l'état `unknown`.
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
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
