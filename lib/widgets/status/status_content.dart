import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/announcement_view.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/relative_time.dart';
import '../app_avatar.dart';

/// Contenu d'un statut, empilé sur son fond.
///
/// Ne fait **aucun `switch` sur le type** : il empile ce qui existe — en-tête,
/// pastille, titre, corps, puis la [waveform] fournie par l'appelant. C'est ce
/// qui rend « vocal + texte » gratuit, sans cas particulier.
///
/// Composant de présentation pur : il ne connaît pas le lecteur. La progression
/// audio lui arrive déjà construite, via le slot [waveform].
class StatusContent extends StatelessWidget {
  const StatusContent({
    super.key,
    required this.announcement,
    required this.foreground,
    this.waveform,
    this.topInset = 0,
    this.bottomInset = 0,
    this.actionsWidth = _Header.defaultActionsWidth,
    this.onBodyScroll,
  });

  final AnnouncementView announcement;

  /// Couleur de texte résolue pour ce fond (garantie de contraste, cf. §8).
  final Color foreground;

  /// Waveform à poser **sous le texte** quand le statut porte de l'audio.
  final Widget? waveform;

  /// Hauteur réservée en haut pour la barre de segments, posée en
  /// surimpression par l'écran : sans elle, le trait de progression mordrait
  /// sur l'avatar de l'en-tête.
  final double topInset;

  /// Hauteur réservée en bas pour la barre de navigation et son encoche.
  final double bottomInset;

  /// Largeur réservée à droite de l'en-tête pour les boutons posés en
  /// surimpression par l'écran.
  ///
  /// Elle **varie** : le son et la liste sont là pour tout le monde, la
  /// composition et la modification seulement pour les membres d'un compte
  /// officiel. Figée à deux boutons, la réserve laissait le nom du compte passer
  /// sous les icônes des rares personnes qui en ont quatre.
  final double actionsWidth;

  /// Notifié quand le corps commence (`true`) ou cesse (`false`) de défiler :
  /// l'auto-avance doit se suspendre tant qu'on lit.
  final ValueChanged<bool>? onBodyScroll;

  /// Taille du corps par paliers de longueur : un statut court s'affiche en
  /// très gros et centré, un long se resserre et s'aligne en haut.
  double get _bodySize {
    final length = (announcement.body ?? '').characters.length;
    if (length <= 60) return 32;
    if (length <= 140) return 26;
    if (length <= 280) return 21;
    return 17;
  }

  bool get _hasText {
    final body = announcement.body;
    return announcement.title != null || (body != null && body.isNotEmpty);
  }

  bool get _isCompact {
    final length = (announcement.body ?? '').characters.length;
    return announcement.title == null && length <= 140;
  }

  @override
  Widget build(BuildContext context) {
    final muted = foreground.withValues(alpha: 0.75);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topInset + AppSpacing.sm,
          AppSpacing.lg,
          bottomInset + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              announcement: announcement,
              foreground: foreground,
              muted: muted,
              actionsWidth: actionsWidth,
            ),
            // Une seule pastille possible désormais : le badge « vidéo ».
            // Celle de catégorie (`tag`) a disparu avec la refonte des annonces
            // — le compte officiel occupe déjà l'en-tête, et « COE » en auteur
            // *et* en pastille disait deux fois la même chose.
            if (announcement.video != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _Badges(foreground: foreground),
            ],
            const SizedBox(height: AppSpacing.md),
            // Sans texte, la waveform occupe le centre : la reléguer en bas
            // d'un écran vide donnerait une page inachevée. Avec du texte, elle
            // se range dessous, comme demandé.
            Expanded(
              child: _hasText
                  ? _body(context)
                  : Center(child: waveform ?? const SizedBox.expand()),
            ),
            if (_hasText && waveform != null) ...[
              const SizedBox(height: AppSpacing.lg),
              waveform!,
            ],
            // Emplacement réservé au bouton d'action (`actionLabel` /
            // `actionRoute`) : les champs existent déjà côté modèle, le bouton
            // n'est pas rendu en phase 1.
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final title = announcement.title;
    final body = announcement.body;
    if (title == null && (body == null || body.isEmpty)) {
      // Statut image seule : rien à poser, le fond porte tout.
      return const SizedBox.expand();
    }

    final align = _isCompact ? TextAlign.center : TextAlign.start;
    final content = Column(
      crossAxisAlignment:
          _isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Text(
            title,
            textAlign: align,
            style: AppTypography.h1.copyWith(color: foreground, height: 1.2),
          ),
        if (title != null && body != null && body.isNotEmpty)
          const SizedBox(height: AppSpacing.md),
        if (body != null && body.isNotEmpty)
          Text(
            body,
            textAlign: align,
            style: AppTypography.bodyLarge.copyWith(
              color: foreground,
              fontSize: _bodySize,
              height: 1.45,
            ),
          ),
      ],
    );

    // Centré tant que ça tient, défilant au-delà : c'est pour ça que l'axe
    // vertical a été laissé libre (le pager est horizontal).
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) onBodyScroll?.call(true);
        if (notification is ScrollEndNotification) onBodyScroll?.call(false);
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: content),
            ),
          );
        },
      ),
    );
  }
}

/// En-tête : le **compte officiel** signataire et l'horodatage relatif localisé.
///
/// Le nom vient d'une jointure, jamais d'une chaîne recopiée dans l'annonce, et
/// il peut manquer : quand le compte n'est pas encore dans le magasin, la ligne
/// et l'avatar **ne se rendent pas**. Aucun « Compte inconnu » de remplacement —
/// ça ressemble à une donnée et serait pris pour une erreur de saisie ; le nom
/// paraîtra au cycle de synchronisation suivant.
class _Header extends StatelessWidget {
  const _Header({
    required this.announcement,
    required this.foreground,
    required this.muted,
    required this.actionsWidth,
  });

  final AnnouncementView announcement;
  final Color foreground;
  final Color muted;

  /// Largeur occupée par les boutons d'action posés en surimpression.
  final double actionsWidth;

  /// Le cas commun : le son et la liste, deux boutons de 48 points.
  static const double defaultActionsWidth = 96;

  @override
  Widget build(BuildContext context) {
    final account = announcement.accountName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (account != null) ...[
          AppAvatar(name: account, size: 36),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (account != null)
                Text(
                  account,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(color: foreground),
                ),
              Text(
                relativeTime(context.l10n, announcement.publishedAt),
                style: AppTypography.caption.copyWith(color: muted),
              ),
            ],
          ),
        ),
        // Place réservée aux actions (son, liste) posées en surimpression par
        // l'écran : sans ça, l'en-tête passerait dessous.
        SizedBox(width: actionsWidth),
      ],
    );
  }
}

/// Pastilles du statut, sur leur propre ligne **sous** l'en-tête — jamais dans
/// la ligne du compte, dont la droite appartient aux boutons d'action.
///
/// Il n'en reste qu'une : le badge « vidéo ». La pastille de catégorie est
/// partie avec `tag` (issue #35).
class _Badges extends StatelessWidget {
  const _Badges({required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _Badge(
          icon: Icons.videocam_rounded,
          label: context.l10n.statusVideoBadge,
          foreground: foreground,
        ),
      ],
    );
  }
}

/// Pastille translucide lisible sur n'importe quel fond : on ne peut pas
/// réutiliser `AppChip`, dont les tons sont pensés pour un fond de carte.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.foreground, this.icon});

  final String label;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
