import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Les **quatre façons dont un contenu ouvert peut ne rien avoir à montrer**.
///
/// Elles se ressemblent à l'écran — un contenu manque — et n'ont rien à voir
/// pour le fidèle : l'une est définitive, deux sont des attentes, la dernière
/// se résout en retrouvant du réseau. Les confondre, c'est répondre à côté de
/// la question qu'il se pose (« est-ce que je peux revenir plus tard ? »).
///
/// Le type existe pour que ces quatre réponses soient **écrites au même
/// endroit** et rendues par le même widget ([ContentAbsenceView]) : chaque
/// variante n'apporte qu'un pictogramme et deux libellés. Seule [retracted]
/// est câblée aujourd'hui (écran de détail d'un enseignement) ; les trois
/// autres arrivent avec le magasin local et le lecteur média, et n'auront rien
/// de nouveau à dessiner.
///
/// Ce n'est **pas** un état d'erreur : `AppErrorState` (teinté, avec bouton
/// « Réessayer ») dit « je n'ai pas pu charger ». Ici, le chargement a réussi
/// et la réponse est qu'il n'y a rien. Ce n'est pas non plus `AppEmptyState`,
/// qui est une carte posée dans une liste : une absence de contenu occupe tout
/// l'écran que le fidèle avait ouvert, et lui rend la main.
enum ContentAbsence {
  /// **Contenu retiré.** L'identifiant a été valide, il ne l'est plus : le
  /// serveur a dépublié ou reprogrammé le contenu dans le futur, et sa
  /// rétractation (`{ id, deletedAt }`, ADR-0025) l'a sorti du magasin —
  /// éventuellement pendant qu'on le regardait. Définitif du point de vue de
  /// l'app : rien à réessayer, rien à attendre.
  retracted,

  /// **Pas encore synchronisé.** Le magasin local n'a pas encore reçu ce
  /// contenu (première ouverture, synchronisation en cours). L'identifiant est
  /// peut-être parfaitement valide côté serveur : c'est une attente, pas une
  /// disparition.
  notSynced,

  /// **Pas encore de média.** Le contenu existe et est publié, mais son fichier
  /// audio/vidéo n'est pas encore attaché (enregistrement en cours de montage).
  /// Les métadonnées s'affichent, la lecture non.
  noMedia,

  /// **Média indisponible hors ligne.** Le média existe et n'a pas été
  /// téléchargé ; l'appareil est hors ligne. La seule des quatre qui se résout
  /// toute seule en retrouvant du réseau.
  offlineMedia;

  IconData get icon => switch (this) {
        ContentAbsence.retracted => Icons.remove_circle_outline,
        ContentAbsence.notSynced => Icons.cloud_sync_outlined,
        ContentAbsence.noMedia => Icons.hourglass_empty_rounded,
        ContentAbsence.offlineMedia => Icons.cloud_off_outlined,
      };

  String title(AppLocalizations l10n) => switch (this) {
        ContentAbsence.retracted => l10n.absenceRetractedTitle,
        ContentAbsence.notSynced => l10n.absenceNotSyncedTitle,
        ContentAbsence.noMedia => l10n.absenceNoMediaTitle,
        ContentAbsence.offlineMedia => l10n.absenceOfflineMediaTitle,
      };

  String message(AppLocalizations l10n) => switch (this) {
        ContentAbsence.retracted => l10n.absenceRetractedMessage,
        ContentAbsence.notSynced => l10n.absenceNotSyncedMessage,
        ContentAbsence.noMedia => l10n.absenceNoMediaMessage,
        ContentAbsence.offlineMedia => l10n.absenceOfflineMediaMessage,
      };
}

/// Présentation partagée des quatre [ContentAbsence], en plein écran.
///
/// Trois partis pris, valables pour les quatre variantes :
/// - **on ne ferme pas l'écran d'autorité.** Éjecter quelqu'un vers la liste
///   pendant qu'il lit ou écoute lui fait perdre son contexte sans rien lui
///   expliquer ; il croit à un bug. On lui dit ce qui s'est passé et on lui
///   laisse le bouton de retour.
/// - **on ne gèle pas la dernière copie connue.** Continuer d'afficher un
///   contenu que le serveur a retiré, c'est mentir — et le fidèle le découvre
///   en revenant à une liste où il a disparu.
/// - **la lecture s'arrête.** C'est à l'écran appelant de couper son lecteur ;
///   ce widget ne le remplace pas, il le remplace *à l'écran*.
///
/// Le rendu est volontairement neutre (sur le fond de l'écran hôte, sans teinte
/// d'alerte) : une absence n'est pas une panne.
class ContentAbsenceView extends StatelessWidget {
  const ContentAbsenceView({
    super.key,
    required this.absence,
    this.onBack,
    this.title,
    this.message,
    this.onDark = false,
  });

  final ContentAbsence absence;

  /// Retour en arrière. À défaut, `Navigator.maybePop` — un écran d'absence
  /// sans porte de sortie est un cul-de-sac.
  final VoidCallback? onBack;

  /// Titre plus précis que celui de la variante (ex. « Cet enseignement n'est
  /// plus disponible »). Déjà localisé par l'appelant.
  final String? title;

  /// Explication plus précise que celle de la variante.
  final String? message;

  /// Écran hôte à fond sombre (lecteur plein écran) : bascule les textes en
  /// blanc. Les couleurs restent portées ici, pas dans l'appelant.
  final bool onDark;

  /// Clé du bouton de retour, pour le cibler depuis les tests.
  static const Key backKey = Key('content_absence_back');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final primary = onDark ? Colors.white : palette.textPrimary;
    final secondary =
        onDark ? Colors.white.withValues(alpha: 0.75) : palette.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(absence.icon, size: 32, color: primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title ?? absence.title(l10n),
              textAlign: TextAlign.center,
              style: AppTypography.h4.copyWith(color: primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? absence.message(l10n),
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: backKey,
              label: l10n.absenceBack,
              icon: Icons.arrow_back,
              variant: AppButtonVariant.outline,
              expand: false,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
