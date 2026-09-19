import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/local/app_database.dart';
import '../data/local/tables/download_tables.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/mediatheque_view.dart';
import '../router/app_router.dart';
import '../state/downloads_providers.dart';
import '../state/mediatheque_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/brand_app_bar.dart';

/// **La page « Téléchargements »** (`/downloads`, #193, F13/F14).
///
/// Elle **observe le magasin** ([downloadsListProvider],
/// [downloadsStorageUsageProvider]) et ne touche jamais au moteur autrement que
/// par ses primitives ([DownloadManager.cancel], `download`) : le magasin peint,
/// le réseau jamais (ADR-0026).
///
/// Trois choses vivent ici :
///
/// - **la liste** des téléchargements — image, titre et état (barre + % en
///   cours, « téléchargé » + taille complété, « en pause / en attente de wifi »,
///   « échec ») ;
/// - **l'en-tête** — l'espace disque total occupé ;
/// - **la suppression** — par glissement ou par le menu d'un item, avec
///   confirmation **seulement** pour un complété (F14 : on jette un contenu
///   prêt), directe pour un partiel / en cours / échec.
///
/// Le titre et l'image de chaque item se **joignent à la lecture** depuis le
/// read-model de la médiathèque ([teachingByIdProvider]) à partir du
/// `contentId` : la table `downloads` ne porte aucune métadonnée de contenu
/// (`DownloadsDao` ne joint rien). Un enseignement absent du magasin (rétracté,
/// pas encore synchronisé) laisse un titre de repli — le fichier reste réel.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  /// Clé d'un item, pour le cibler depuis les tests sans dépendre du titre.
  static Key itemKey(String contentId) => Key('download_item_$contentId');

  /// Clé du menu par item (glissement / suppression).
  static Key menuKey(String contentId) => Key('download_menu_$contentId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final downloads = ref.watch(downloadsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.downloadsTitle),
      body: downloads.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        // Une lecture de magasin qui échoue est une **panne**, pas un vide :
        // `AppErrorState` est teinté et porte une action, `AppEmptyState` ne
        // doit jamais se lire « je n'ai pas pu charger ».
        error: (_, __) => Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: AppErrorState(
              message: l.stateErrorMessage,
              onRetry: () => ref.invalidate(downloadsListProvider),
            ),
          ),
        ),
        data: (rows) => _Body(rows: rows),
      ),
    );
  }
}

/// Le corps de la page une fois la liste connue : le bandeau de purge, l'état
/// vide **ou** l'en-tête d'espace suivi des items.
class _Body extends StatelessWidget {
  const _Body({required this.rows});

  final List<DownloadRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const _PurgeBanner(),
          const SizedBox(height: AppSpacing.xxl),
          AppEmptyState(
            icon: Icons.download_done_outlined,
            title: l.downloadsEmptyTitle,
            message: l.downloadsEmptyMessage,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        const _PurgeBanner(),
        const _StorageHeader(),
        const SizedBox(height: AppSpacing.md),
        for (final row in rows) _DownloadItem(row: row),
      ],
    );
  }
}

/// **Le bandeau de notification de purge** (#194, F16).
///
/// À réception d'une **rétractation** (ADR-0025), le cycle de vie
/// (`DownloadLifecycle`) purge la copie locale et dépose une notification. Ce
/// bandeau les **observe** ([downloadNotificationsProvider]) et en rend une par
/// entrée, chacune rejetable (le fidèle l'a vue). Le titre vient de la ligne
/// purgée, dénormalisé au téléchargement — la source ayant disparu du magasin,
/// c'est la seule façon de **nommer** ce qui a été supprimé.
class _PurgeBanner extends ConsumerWidget {
  const _PurgeBanner();

  /// Clé d'une notification, pour la cibler depuis les tests.
  static Key noticeKey(int id) => Key('purge_notice_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(downloadNotificationsProvider).value ?? const [];
    if (notices.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final notice in notices) _PurgeNotice(notice: notice),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Une entrée du bandeau de purge : le message nommé (ou générique) et un bouton
/// pour la rejeter.
class _PurgeNotice extends ConsumerWidget {
  const _PurgeNotice({required this.notice});

  final DownloadNotificationRow notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final title = notice.title;
    final message = title == null
        ? l.downloadPurgeNoticeUnnamed
        : l.downloadPurgeNotice(title);

    return Container(
      key: _PurgeBanner.noticeKey(notice.id),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: palette.textPrimary),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
            tooltip: l.downloadPurgeDismiss,
            onPressed: () =>
                ref.read(downloadNotificationsDaoProvider).dismiss(notice.id),
          ),
        ],
      ),
    );
  }
}

/// L'en-tête : l'espace disque total occupé par les téléchargements.
class _StorageHeader extends ConsumerWidget {
  const _StorageHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    // Somme des octets **reçus** (partiels compris) : c'est ce qui occupe
    // réellement le disque. Un flux qui n'a pas encore émis vaut 0.
    final bytes = ref.watch(downloadsStorageUsageProvider).value ?? 0;

    return Row(
      children: [
        Icon(Icons.sd_storage_outlined, size: 18, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          l.downloadsStorageUsed(_formatMegabytes(context, bytes)),
          style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }
}

/// Un téléchargement : miniature + titre (joints depuis le read-model), état, et
/// suppression par glissement ou par menu.
class _DownloadItem extends ConsumerWidget {
  const _DownloadItem({required this.row});

  final DownloadRow row;

  bool get _isComplete =>
      row.state == DownloadState.complete ||
      row.state == DownloadState.outdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    // Titre et image **joints à la lecture** depuis le read-model : la table
    // `downloads` ne les porte pas.
    final view = ref.watch(teachingByIdProvider(row.contentId)).value;
    final title = view?.title ?? l.downloadsUnknownTitle;

    return Dismissible(
      key: DownloadsScreen.itemKey(row.contentId),
      direction: DismissDirection.endToStart,
      background: _swipeBackground(palette),
      // Confirmation **seulement** pour un complété (F14) ; suppression directe
      // pour un partiel / en cours / échec. Renvoyer `false` laisserait l'item,
      // mais le flux du magasin le retire aussitôt après `cancel` — c'est lui
      // qui fait foi.
      confirmDismiss: (_) => _requestDelete(context),
      onDismissed: (_) => _delete(ref),
      child: InkWell(
        // Tap sur un complété → la fiche de l'enseignement (la lecture locale
        // marche déjà via le résolveur #191). Les autres états n'ouvrent rien :
        // il n'y a pas encore de fichier prêt à écouter.
        onTap: _isComplete
            ? () => context.pushNamed(
                  AppRoute.teachingDetail,
                  pathParameters: {'id': row.contentId},
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(view: view),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong
                          .copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    _StateLine(row: row),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _trailing(context, ref, l),
            ],
          ),
        ),
      ),
    );
  }

  /// L'action par item : un menu « Supprimer », et un raccourci « Réessayer »
  /// quand le téléchargement a échoué.
  Widget _trailing(BuildContext context, WidgetRef ref, AppLocalizations l) {
    return PopupMenuButton<String>(
      key: DownloadsScreen.menuKey(row.contentId),
      icon: Icon(Icons.more_vert, color: context.palette.textSecondary),
      itemBuilder: (_) => [
        if (row.state == DownloadState.failed)
          PopupMenuItem<String>(
            value: 'retry',
            child: Text(l.downloadActionRetry),
          ),
        // Périmé → « Mettre à jour » relance le téléchargement sur la nouvelle
        // version (F15) : `download()` réécrit `versionId`/`title` et repasse
        // complété une fois la nouvelle copie reçue.
        if (row.state == DownloadState.outdated)
          PopupMenuItem<String>(
            value: 'update',
            child: Text(l.downloadActionUpdate),
          ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l.downloadActionDelete),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'retry':
          case 'update':
            _retry(ref);
          case 'delete':
            if (await _requestDelete(context)) _delete(ref);
        }
      },
    );
  }

  /// Demande confirmation **seulement** pour un complété (F14). Réutilise le
  /// même dialogue que le menu du bouton de la fiche (#192).
  Future<bool> _requestDelete(BuildContext context) async {
    if (!_isComplete) return true;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.downloadDeleteConfirmTitle),
        content: Text(l.downloadDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l.downloadDeleteConfirmAction),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Efface fichier + tâche + ligne (F14) — la primitive mécanique du moteur.
  void _delete(WidgetRef ref) {
    ref.read(downloadManagerProvider).cancel(row.contentId);
  }

  /// Relance un téléchargement échoué (le moteur écrase l'échec).
  void _retry(WidgetRef ref) {
    ref.read(downloadManagerProvider).download(
          contentId: row.contentId,
          contentType: row.contentType,
          quality: ref.read(downloadQualityProvider),
        );
  }

  Widget _swipeBackground(AppPalette palette) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: AppColors.danger.withValues(alpha: 0.12),
      child: const Icon(Icons.delete_outline, color: AppColors.danger),
    );
  }
}

/// La ligne d'état d'un item : une barre + un pourcentage en cours, une phrase
/// simple sinon.
class _StateLine extends StatelessWidget {
  const _StateLine({required this.row});

  final DownloadRow row;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    switch (row.state) {
      case DownloadState.queued:
      case DownloadState.running:
        final total = row.bytesTotal;
        // Total encore inconnu ⇒ barre **indéterminée** plutôt qu'un 0 % qui se
        // lirait comme un blocage.
        final fraction =
            total > 0 ? (row.bytesReceived / total).clamp(0.0, 1.0) : null;
        final percent = fraction == null ? null : (fraction * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: palette.surfaceAlt,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              percent == null
                  ? l.downloadStateDownloading
                  : l.downloadProgressPercent(percent),
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ],
        );
      case DownloadState.paused:
        return _text(l.downloadStatePaused, palette);
      case DownloadState.waitingWifi:
        return _text(l.downloadStateWaitingWifi, palette);
      case DownloadState.complete:
      case DownloadState.outdated:
        // « Téléchargé » + la taille sur le disque. Le total attendu fait foi ;
        // à défaut, les octets reçus.
        final bytes = row.bytesTotal > 0 ? row.bytesTotal : row.bytesReceived;
        final line = _text(
          '${l.downloadStateComplete} · '
          '${l.downloadSize(_formatMegabytes(context, bytes))}',
          palette,
        );
        // Périmé (révision serveur, ADR-0039) : la copie reste écoutable, mais on
        // signale la mise à jour disponible (F15). Le fichier n'est jamais purgé.
        if (row.state != DownloadState.outdated) return line;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line,
            const SizedBox(height: 4),
            _UpdateBadge(),
          ],
        );
      case DownloadState.failed:
        return _text(l.downloadStateFailed, palette, danger: true);
    }
  }

  Widget _text(String value, AppPalette palette, {bool danger = false}) {
    return Text(
      value,
      style: AppTypography.caption.copyWith(
        color: danger ? AppColors.danger : palette.textSecondary,
      ),
    );
  }
}

/// Le badge « mise à jour disponible » d'un téléchargement périmé (#194, F15).
class _UpdateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.system_update_alt,
              size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            l.downloadUpdateAvailable,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// La miniature d'un item : l'image d'habillage, sinon un aplat coloré à la
/// couleur résolue du contenu (dernier maillon : le bleu de marque).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.view});

  final TeachingView? view;

  @override
  Widget build(BuildContext context) {
    final color = Color(view?.color ?? kBrandFallbackColor);
    // Miniature carrée (64×64) : c'est le cadrage carré qu'il lui faut, avec
    // repli sur le paysage puis le portrait s'il manque.
    final source = view?.squareOrLandscape;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: source == null
            ? _placeholder(color)
            : Image(
                image: source.startsWith('http')
                    ? NetworkImage(source)
                    : AssetImage(source) as ImageProvider,
                fit: BoxFit.cover,
                // Repli obligatoire : un visuel injoignable — hors ligne, ou
                // `flutter test` qui répond 400 à tout réseau — retombe sur
                // l'aplat au lieu de faire lever le widget.
                errorBuilder: (_, __, ___) => _placeholder(color),
              ),
      ),
    );
  }

  Widget _placeholder(Color color) => Container(
        color: color.withValues(alpha: 0.15),
        child: Icon(Icons.auto_stories_rounded, color: color, size: 28),
      );
}

/// Formate un nombre d'octets en mégaoctets, dans la langue courante — la même
/// unité que « Mo par heure » des réglages média. Une décimale sous 10 Mo, un
/// entier au-delà : la précision utile là où elle se voit.
String _formatMegabytes(BuildContext context, int bytes) {
  if (bytes <= 0) return '0';
  final mb = bytes / (1024 * 1024);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final nf = NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = mb < 10 ? 1 : 0
    ..minimumFractionDigits = mb < 10 ? 1 : 0;
  return nf.format(mb);
}
