import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messaging/media/message_media_usage.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/message_media.dart';
import '../state/echanges_providers.dart';
import '../state/message_media_storage_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/chat/media/media_labels.dart';

/// **L'écran « Stockage »** (`/settings/media/storage`, T4 de #226) — ce que
/// chaque conversation occupe, et de quoi vider.
///
/// Poussé depuis le Profil comme ses voisins (confidentialité, téléchargements,
/// suppression) : `BrandAppBar`, flèche de retour, et l'air de la maquette qui
/// commence dessous sur l'`AppBackground` que pose la route.
///
/// ## Ce que l'écran promet, et pourquoi il ne promet rien de plus
///
/// **Aucune éviction automatique** (décision 1 du cadrage) : rien ne disparaît
/// dans le dos du fidèle, et il n'y a donc ni plafond, ni ancienneté, ni
/// réglage à régler. Le bandeau le dit, parce qu'un écran qui montre des
/// mégaoctets sans dire qui décide se lit comme une menace.
///
/// La purge est **réversible par un téléchargement** : le serveur garde les
/// fichiers, seule la copie locale part. C'est vrai mécaniquement — vider
/// efface la ligne de `local_message_media`, la jointure du fil ne trouve plus
/// de chemin, et la bulle repasse par l'URL présignée.
///
/// ## Les chiffres sont ceux du disque
///
/// `GroupMessages.mediaSize` existe pour tout message à média, descendu ou non ;
/// l'additionner afficherait des mégaoctets que rien n'occupe. L'écran pèse
/// donc les fichiers réellement écrits — voir [MessageMediaStorage]. Un média
/// jamais descendu ne pèse rien et n'apparaît pas.
class MediaStorageScreen extends ConsumerWidget {
  const MediaStorageScreen({super.key});

  /// La ligne d'une conversation, pour la cibler sans dépendre de son nom.
  static Key conversationKey(String groupId) => Key('storage_group_$groupId');

  /// Le bouton qui vide une conversation.
  static Key purgeConversationKey(String groupId) =>
      Key('storage_purge_group_$groupId');

  /// La ligne d'une forme de média, et son bouton.
  static Key kindKey(MessageMediaKind kind) => Key('storage_kind_${kind.name}');
  static Key purgeKindKey(MessageMediaKind kind) =>
      Key('storage_purge_kind_${kind.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final usage = ref.watch(messageMediaUsageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.mediaStorageTitle),
      body: usage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Une pesée qui échoue est une **panne**, pas un vide : `AppErrorState`
        // est teinté et porte une action, là où `AppEmptyState` affirmerait
        // qu'il n'y a rien sur l'appareil.
        error: (_, __) => Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: AppErrorState(
              message: l.stateErrorMessage,
              onRetry: () => ref.invalidate(messageMediaUsageProvider),
            ),
          ),
        ),
        data: (data) => _Body(usage: data),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.usage});

  final MessageMediaUsage usage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;

    // Le titre lisible d'un tête-à-tête est le nom de l'autre, et c'est la
    // liste des conversations qui le sait déjà (`StoreEchangesRepository`) : on
    // ne réécrit pas cette règle ici. Un groupe quitté n'y est plus, et ses
    // fichiers occupent pourtant encore la place — d'où le repli.
    final titles = {
      for (final c in ref
              .watch(conversationsProvider(ref.watch(echangesActorProvider)))
              .value ??
          const [])
        c.groupId: c.title,
    };

    final kinds = usage.byKind.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.mediaStorageNotice,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(Icons.sd_storage_outlined,
                size: 18, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l.mediaStorageTotal(
                formatByteSize(usage.totalBytes, l.localeName),
              ),
              style:
                  AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
        if (usage.isEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppEmptyState(
            icon: Icons.photo_library_outlined,
            title: l.mediaStorageEmpty,
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(l.mediaStorageByKind),
          _Rows(
            children: [
              for (final entry in kinds)
                _UsageRow(
                  rowKey: MediaStorageScreen.kindKey(entry.key),
                  buttonKey: MediaStorageScreen.purgeKindKey(entry.key),
                  label: _kindLabel(l, entry.key),
                  bytes: entry.value,
                  onPurge: (ref) => ref
                      .read(messageMediaStorageProvider)
                      .purgeKind(entry.key),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(l.mediaStorageByConversation),
          _Rows(
            children: [
              for (final c in usage.conversations)
                _UsageRow(
                  rowKey: MediaStorageScreen.conversationKey(c.groupId),
                  buttonKey: MediaStorageScreen.purgeConversationKey(c.groupId),
                  label: titles[c.groupId] ??
                      (c.groupName.isEmpty
                          ? l.mediaStorageUnknownConversation
                          : c.groupName),
                  subtitle: l.mediaStorageFiles(c.fileCount),
                  bytes: c.bytes,
                  onPurge: (ref) => ref
                      .read(messageMediaStorageProvider)
                      .purgeConversation(c.groupId),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Le libellé d'une forme : celui de l'aperçu des conversations (« 📷 Photo »,
  /// « 🎤 Message vocal »), qui existe déjà et est déjà traduit. Une forme que
  /// cette version ne connaît pas garde un libellé générique plutôt que de
  /// disparaître d'un total — ses octets sont bien là.
  static String _kindLabel(AppLocalizations l, MessageMediaKind kind) =>
      mediaPreviewLabel(l, kind) ?? l.mediaStorageByKind;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: context.palette.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Les lignes d'une section, dans une carte, séparées par un filet.
class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, color: context.palette.divider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Une ligne pesée : ce qu'elle nomme, ce qu'elle occupe, et de quoi la vider.
class _UsageRow extends ConsumerWidget {
  const _UsageRow({
    required this.rowKey,
    required this.buttonKey,
    required this.label,
    required this.bytes,
    required this.onPurge,
    this.subtitle,
  });

  final Key rowKey;
  final Key buttonKey;
  final String label;
  final String? subtitle;
  final int bytes;
  final Future<void> Function(WidgetRef ref) onPurge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;

    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.body.copyWith(color: palette.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatByteSize(bytes, l.localeName),
            style:
                AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
          ),
          IconButton(
            key: buttonKey,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.danger,
            tooltip: l.mediaStoragePurgeAction,
            onPressed: () => _purge(context, ref),
          ),
        ],
      ),
    );
  }

  /// Confirmation **toujours** : on jette un fichier prêt, exactement le cas
  /// que la page Téléchargements protège déjà (F14). Puis la pesée est relue —
  /// elle est la seule source du chiffre affiché.
  Future<void> _purge(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.mediaStoragePurgeTitle),
        content: Text(l.mediaStoragePurgeMessage(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l.mediaStoragePurgeAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await onPurge(ref);
    ref.invalidate(messageMediaUsageProvider);
  }
}
