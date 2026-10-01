import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/season_providers.dart';
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
/// **Le premier lancement n'est plus nu pour autant** : rien sur le disque, et
/// c'est l'image du dépôt qui paraît — exactement celle que le démarrage
/// **natif** vient de peindre, si bien qu'il n'y a pas de rupture entre les
/// deux. Le décor du portail, lui, prend la place à l'ouverture suivante.
///
/// ## Le voile reste, il ne se remplace pas
///
/// Il est peint **par-dessus** l'image, à demi opaque. Sans lui, un fond clair
/// rendrait l'emblème blanc, le nom de l'église et le témoin de chargement
/// illisibles — et ça ne se verrait qu'avec ce fond-là, c'est-à-dire un jour,
/// chez quelqu'un d'autre. Il n'y a plus de cas « sans image », donc plus de
/// dégradé de marque ici : l'écran porte toujours une photographie.
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
            Image(
              image: background,
              fit: BoxFit.cover,
              // Une image illisible ne laisse pas un écran noir : la route pose
              // déjà `AppBackground` sous cet écran, et le voile se peint
              // par-dessus lui.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
