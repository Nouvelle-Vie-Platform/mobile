import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../models/message_media.dart';
import '../state/echanges_providers.dart';
import '../state/menu_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/chat/media/message_media_view.dart';

/// **« Médias, liens et docs »** d'un groupe, comme WhatsApp : trois onglets
/// lus dans le magasin (`groupSharedFilesProvider`, `groupSharedLinksProvider`).
///
/// - **Médias** : images et vidéos, en grille, les plus récentes d'abord ; le
///   toucher fait ce que fait la bulle (visionneuse, lecteur vidéo).
/// - **Liens** : une ligne par adresse `http(s)` trouvée dans un texte.
/// - **Docs** : documents et fichiers audio — pas les vocaux.
///
/// Un onglet vide le dit, sobrement ; ce n'est jamais une erreur.
class GroupSharedContentScreen extends ConsumerWidget {
  const GroupSharedContentScreen({super.key, required this.groupId});

  final String groupId;

  static const mediaGridKey = Key('shared_media_grid');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(echangesActorProvider);
    final key = (actor: me, id: groupId);
    final title = ref.watch(groupDetailProvider(key)).value?.title;
    final files = ref.watch(groupSharedFilesProvider(key)).value ?? const [];
    final links = ref.watch(groupSharedLinksProvider(key)).value ?? const [];

    // **Médias** : photos, vidéos et fichiers audio (décision utilisateur du
    // 08/10) ; **Docs** : les documents seuls. Les vocaux ne sont nulle part.
    bool isVisual(GroupMessageView m) =>
        m.media!.kind != MessageMediaKind.document;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: BrandAppBar(title: title ?? l.sharedContentTitle),
        body: Column(
          children: [
            DecoratedBox(
              decoration:
                  const BoxDecoration(gradient: AppColors.gradientPrimary),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
                labelStyle: AppTypography.bodyStrong,
                unselectedLabelStyle: AppTypography.body,
                tabs: [
                  Tab(text: l.sharedContentMedia),
                  Tab(text: l.sharedContentLinks),
                  Tab(text: l.sharedContentDocs),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MediaGrid(files.where(isVisual).toList()),
                  _LinkList(links),
                  _DocList(files.where((m) => !isVisual(m)).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
        padding: AppSpacing.screenPadding,
        children: [AppEmptyState(title: title, icon: icon)],
      );
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid(this.messages);

  final List<GroupMessageView> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _Empty(
        context.l10n.sharedContentMediaEmpty,
        Icons.photo_library_outlined,
      );
    }
    // ponytail: pas de regroupement par mois — une grille continue, du plus
    // récent au plus ancien ; à ajouter si les fils deviennent longs.
    return GridView.builder(
      key: GroupSharedContentScreen.mediaGridKey,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final message = messages[i];
        final media = message.media!;
        return LayoutBuilder(
          builder: (context, box) => switch (media.kind) {
            MessageMediaKind.video => VideoMediaTile(
                message: message,
                media: media,
                extent: box.maxWidth,
              ),
            MessageMediaKind.audio => _AudioCell(message: message),
            _ => ImageMediaTile(
                message: message,
                media: media,
                extent: box.maxWidth,
              ),
          },
        );
      },
    );
  }
}

/// **Un fichier audio dans la grille** : une note de musique, le nom et la
/// durée ; au toucher, le lecteur de la bulle dans une feuille.
class _AudioCell extends StatelessWidget {
  const _AudioCell({required this.message});

  final GroupMessageView message;

  static Key keyOf(String id) => Key('shared_audio_$id');

  void _open(BuildContext context) {
    final media = message.media!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding.add(
            const EdgeInsets.only(bottom: AppSpacing.lg),
          ),
          child: AudioMediaTile(
            message: message,
            media: media,
            ink: context.palette.textPrimary,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = message.media!;
    final seconds = media.durationSeconds;
    return Material(
      color: AppColors.secondary,
      child: InkWell(
        key: keyOf(message.id),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 32),
              if (media.name case final name?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
              ],
              if (seconds != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatMediaDuration(Duration(seconds: seconds)),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _date(BuildContext context, DateTime? at) => at == null
    ? ''
    : DateFormat.yMd(context.l10n.intlLocale).format(at.toLocal());

class _LinkList extends ConsumerWidget {
  const _LinkList(this.links);

  final List<SharedLink> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (links.isEmpty) {
      return _Empty(context.l10n.sharedContentLinksEmpty, Icons.link);
    }
    final secondary = context.palette.textSecondary;
    return ListView.separated(
      itemCount: links.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final (:message, :url) = links[i];
        final host = Uri.tryParse(url)?.host ?? url;
        return ListTile(
          key: Key('shared_link_$i'),
          leading: const Icon(Icons.link),
          title: Text(host, style: AppTypography.bodyStrong),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: AppColors.primary),
              ),
              Text(
                message.body!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: secondary),
              ),
            ],
          ),
          trailing: Text(
            _date(context, message.createdAt),
            style: AppTypography.caption.copyWith(color: secondary),
          ),
          onTap: () => ref.read(externalLinkLauncherProvider).open(url),
        );
      },
    );
  }
}

class _DocList extends StatelessWidget {
  const _DocList(this.messages);

  final List<GroupMessageView> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _Empty(
        context.l10n.sharedContentDocsEmpty,
        Icons.insert_drive_file_outlined,
      );
    }
    final ink = context.palette.textPrimary;
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final message = messages[i];
        final media = message.media!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // La tuile de la bulle, et son geste : le document s'ouvre dans
            // l'application du système.
            DocumentMediaTile(
              message: message,
              media: media,
              ink: ink,
              width: double.infinity,
            ),
            Text(
              _date(context, message.createdAt),
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary),
            ),
          ],
        );
      },
    );
  }
}
