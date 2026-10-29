import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/app_update_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// **Le bandeau de mise à jour** — il informe, il renvoie au magasin, il se
/// ferme, et l'application continue.
///
/// **Sur le web, il recharge au lieu de renvoyer au magasin** : il n'y a pas de
/// magasin dans un navigateur, et un bouton qui n'ouvre rien aurait rendu le
/// seuil réglé au portail sans effet là-bas (voir `appReloaderProvider`).
///
/// ## Ce qu'il n'est pas, et ne deviendra pas
///
/// Ni « mise à jour forcée », ni « version minimale », ni « kill switch ». Aucun
/// `PopScope`, aucune barrière modale, rien qui capte les gestes hors de sa
/// propre surface : l'accueil reste utilisable derrière, barre d'onglets et
/// bouton central compris. Un fidèle dont l'application se bloque n'écoute plus
/// rien — et l'invitation à monter de version ne vaut jamais ce prix-là.
///
/// C'est la même famille que `LegalNoticeBanner`, posée dans la même pile de la
/// coquille, et la seule différence qui compte est la **mémoire** : celui-là se
/// retient pour toujours, celui-ci pour la session (voir
/// [AppUpdateBannerDismissal]).
///
/// ## Trois silences, et ils penchent tous du même côté
///
/// 1. **Pas de seuil réglé ⇒ rien.** C'est le cas d'aujourd'hui, et le plus
///    important : l'application n'a jamais été publiée, et un bandeau de mise à
///    jour sur la toute première version serait le plus mauvais premier contact
///    possible. Voir `appUpdateThresholdProvider`.
/// 2. **Version locale ou seuil illisible ⇒ rien.** On n'invite pas à quitter
///    une version qu'on ne sait pas nommer.
/// 3. **Déjà fermé ⇒ rien**, jusqu'au prochain lancement.
class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key});

  /// Le bandeau lui-même. Les tests prouvent surtout son **absence** : sans
  /// seuil, et après fermeture.
  static const Key bannerKey = Key('app_update_banner');
  static const Key actionKey = Key('app_update_action');
  static const Key dismissKey = Key('app_update_dismiss');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appUpdateBannerDismissedProvider)) {
      return const SizedBox.shrink();
    }
    if (!ref.watch(appUpdateAvailableProvider)) return const SizedBox.shrink();

    final l10n = context.l10n;
    final palette = context.palette;
    // Dans un navigateur, l'action est de recharger ; ailleurs, d'aller au
    // magasin. Voir `appReloaderProvider` : `null` est la réponse de tout ce
    // qui n'est pas le web.
    final reloader = ref.watch(appReloaderProvider);

    return Padding(
      key: AppUpdateBanner.bannerKey,
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
                l10n.appUpdateBody,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              // La sortie et l'action sur une seule ligne, et dans cet ordre :
              // le bandeau recouvre l'accueil, il doit rester aussi bas que
              // possible, et le geste le plus probable — « plus tard » — ne doit
              // pas se trouver sous le pouce du geste le plus engageant.
              Row(
                children: [
                  TextButton(
                    key: AppUpdateBanner.dismissKey,
                    onPressed: () => ref
                        .read(appUpdateBannerDismissedProvider.notifier)
                        .dismiss(),
                    child: Text(l10n.appUpdateDismiss),
                  ),
                  const Spacer(),
                  TextButton(
                    key: AppUpdateBanner.actionKey,
                    // **Le bandeau ne se ferme pas en ouvrant le magasin.** On
                    // part vers une autre application et on revient ; retrouver
                    // l'invitation est juste tant que la mise à jour n'est pas
                    // faite, et la refermer soi-même reste à un geste. Sur le
                    // web il n'y a nulle part où partir : la page se recharge et
                    // le bandeau disparaît de lui-même, la version ayant monté.
                    onPressed: () => reloader != null
                        ? reloader.reload()
                        : ref.read(storeLauncherProvider).open(),
                    child: Text(
                      reloader != null
                          ? l10n.appUpdateReload
                          : l10n.appUpdateAction,
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
