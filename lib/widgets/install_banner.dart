import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/install/install_prompt.dart';
import '../l10n/l10n_extension.dart';
import '../state/install_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// **Le bandeau d'installation de l'app web.**
///
/// Il existe parce que Chrome a rangé « Installer l'application » dans son menu
/// ⋮, que personne n'ouvre — et parce que l'installation n'est pas cosmétique
/// ici : elle porte le téléchargement hors ligne et la durabilité du stockage
/// (voir [InstallOffer]). Le laisser au hasard du menu, c'était le laisser
/// mourir.
///
/// Il ne bloque rien, comme ses deux voisins de la même pile : il informe, il
/// propose, il se ferme, et l'application continue derrière.
///
/// ## Deux textes, un seul bouton
///
/// Sur Chrome, le bandeau **déclenche** la vraie boîte d'installation. Sur
/// iPhone, Safari n'en offre aucune : le bandeau **explique le geste** et ne
/// porte alors **pas de bouton d'action** — un bouton qui n'ouvrirait rien
/// serait une promesse que personne ne tient, et c'est la règle du dépôt
/// (absence, jamais grisage).
///
/// ## La permission de notification part dans la foulée (#283)
///
/// Et **seulement** quand l'installation a été acceptée. C'est la décision du
/// cadrage : sur le web un refus de notification est quasi définitif, et il
/// emporte tout (sans permission, pas de jeton, donc pas même la
/// synchronisation réveillée). L'installation est l'instant de plus forte
/// intention ; un refus d'installation ne l'est pas, et on n'y brûle pas
/// l'unique chance d'un fidèle.
///
/// Sur iPhone il n'y a pas de bouton, donc pas de ce moment-là : l'ajout à
/// l'écran d'accueil se fait hors de l'application, et Safari ne nous dit pas
/// qu'il a eu lieu. Les annonces poussées n'arriveront donc pas sur un iPhone
/// par ce chemin — c'est une limite connue, pas un oubli.
class InstallBanner extends ConsumerWidget {
  const InstallBanner({super.key});

  static const Key bannerKey = Key('install_banner');
  static const Key actionKey = Key('install_action');
  static const Key dismissKey = Key('install_dismiss');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(installBannerDismissedProvider)) {
      return const SizedBox.shrink();
    }
    // Chargement ou erreur valent « rien à proposer » : on n'invite jamais sur
    // une incertitude, et il n'y a pas d'état d'attente à peindre pour ça.
    final offer = ref.watch(installOfferProvider).value;
    if (offer == null || offer == InstallOffer.none) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final palette = context.palette;
    final canPrompt = offer == InstallOffer.prompt;

    return Padding(
      key: InstallBanner.bannerKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: palette.surface,
        borderRadius: AppRadius.card,
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canPrompt ? l10n.installBannerBody : l10n.installBannerIosBody,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Même disposition que le bandeau de mise à jour : la sortie à
              // gauche, l'action à droite, pour que le geste le plus probable
              // ne soit pas sous le pouce du plus engageant.
              Row(
                children: [
                  TextButton(
                    key: InstallBanner.dismissKey,
                    onPressed: () => ref
                        .read(installBannerDismissedProvider.notifier)
                        .dismiss(),
                    child: Text(l10n.installBannerDismiss),
                  ),
                  const Spacer(),
                  if (canPrompt)
                    TextButton(
                      key: InstallBanner.actionKey,
                      // Le bandeau ne se ferme pas tout seul : l'offre
                      // retombera à `none` quand l'installation sera faite, et
                      // c'est elle qui le retire. Un refus le laisse en place,
                      // ce qui est juste — rien n'a changé.
                      onPressed: () => installThenAskForNotifications(ref),
                      child: Text(
                        l10n.installBannerAction,
                        style: AppTypography.caption.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
