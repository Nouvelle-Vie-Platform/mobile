/// **Le rendu d'une pièce jointe dans le fil du texte** (N4, mobile#192) — il
/// remplace la carte d'attente `NvAttachmentPlaceholderBuilder` de N3.
///
/// - **photo** : pleine largeur, coins arrondis, ratio d'après `width/height` ;
///   plein écran au toucher ;
/// - **vidéo, audio, fichier** : un bloc-carte (vignette ou icône, nom, taille
///   ou durée). Vidéo → lecteur plein écran ; audio → lecture sur place ;
///   fichier → téléchargé dans le dossier temporaire puis ouvert par le
///   système.
///
/// L'état (en préparation, en envoi, en échec avec « Réessayer ») se lit sur
/// la ligne `pending_note_media`. La source : le fichier local tant qu'il
/// existe, sinon l'URL signée (`NoteMediaUrls`, gardée 50 min en mémoire).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../data/messaging/media/media_mime.dart';
import '../../../data/notes_media/note_attachment_content.dart';
import '../../../data/notes_media/note_media_providers.dart';
import '../../../data/notes_media/note_media_urls.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/message_media.dart';
import '../../../state/chat_media_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/chat/media/chat_video_screen.dart';
import '../../../widgets/chat/media/media_labels.dart';
import '../note_content.dart';

class NoteAttachmentEmbedBuilder extends EmbedBuilder {
  const NoteAttachmentEmbedBuilder();

  @override
  String get key => noteAttachmentEmbed;

  @override
  bool get expanded => true;

  static Map<String, dynamic> _dataOf(Embed node) => switch (node.value.data) {
        final Map<dynamic, dynamic> m => Map<String, dynamic>.from(m),
        _ => const {},
      };

  @override
  String toPlainText(Embed node) =>
      attachmentLabel((_dataOf(node)['name'] as String?) ?? '');

  @override
  Widget build(BuildContext context, EmbedContext embedContext) =>
      NoteAttachmentBlock(data: _dataOf(embedContext.node));
}

/// Où en est une pièce jointe.
enum NoteAttachmentStatus { ready, preparing, uploading, failed }

NoteAttachmentStatus noteAttachmentStatusOf(
  PendingNoteMediaRow? row, {
  String? key,
}) {
  if (row == null) {
    return key != null
        ? NoteAttachmentStatus.ready
        : NoteAttachmentStatus.preparing;
  }
  if (row.error != null) return NoteAttachmentStatus.failed;
  if (row.key != null) return NoteAttachmentStatus.ready;
  return row.mime == null
      ? NoteAttachmentStatus.preparing
      : NoteAttachmentStatus.uploading;
}

/// Un bloc du fil, d'après les données de l'embed.
class NoteAttachmentBlock extends ConsumerWidget {
  const NoteAttachmentBlock({super.key, required this.data});

  static const Key imageKey = Key('note_attachment_image');
  static const Key cardKey = Key('note_attachment_card');
  static const Key retryKey = Key('note_attachment_retry');

  final Map<String, dynamic> data;

  String? get _embedId => data[kNoteAttachmentLocalId] as String?;
  String? get _key => data['key'] as String?;
  String get _kind => (data['kind'] as String?) ?? 'document';
  String get _name => (data['name'] as String?) ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final embedId = _embedId;
    final row = ref
        .watch(
          pendingNoteMediaProvider((
            embedId: embedId,
            key: embedId == null ? _key : null,
          )),
        )
        .value;
    final status = noteAttachmentStatusOf(row, key: _key);
    final localPath = row?.localPath;
    final local =
        localPath != null && File(localPath).existsSync() ? localPath : null;
    final thumbPath = row?.thumbPath;
    final localThumb =
        thumbPath != null && File(thumbPath).existsSync() ? thumbPath : null;

    final retry = embedId == null
        ? null
        : () => unawaited(ref.read(noteMediaComposerProvider).retry(embedId));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: _kind == 'image'
          ? _ImageBlock(
              data: data,
              local: local,
              status: status,
              error: row?.error,
              onRetry: retry,
            )
          : _CardBlock(
              data: data,
              kind: _kind,
              name: _name,
              local: local,
              localThumb: localThumb,
              status: status,
              error: row?.error,
              onRetry: retry,
            ),
    );
  }
}

/// La phrase de l'état d'un bloc pas encore prêt.
String _statusLabel(
  BuildContext context,
  NoteAttachmentStatus status,
  String? error,
) {
  final l = context.l10n;
  return switch (status) {
    NoteAttachmentStatus.preparing => l.noteAttachmentPreparing,
    NoteAttachmentStatus.uploading => l.noteAttachmentUploading,
    NoteAttachmentStatus.failed => switch (MediaSendError.parse(error)) {
        final MediaSendError cause => mediaErrorLabel(l, cause),
        null => l.noteAttachmentFailed,
      },
    NoteAttachmentStatus.ready => '',
  };
}

class _ImageBlock extends ConsumerWidget {
  const _ImageBlock({
    required this.data,
    required this.local,
    required this.status,
    required this.error,
    required this.onRetry,
  });

  final Map<String, dynamic> data;
  final String? local;
  final NoteAttachmentStatus status;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = data['width'], height = data['height'];
    final ratio = width is num && height is num && width > 0 && height > 0
        ? width / height
        : 4 / 3;
    final key = data['key'] as String?;
    final urls = ref.watch(noteMediaUrlsProvider);

    return GestureDetector(
      key: NoteAttachmentBlock.imageKey,
      onTap: local == null && key == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PhotoViewer(local: local, mediaKey: key),
                ),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Picture(local: local, mediaKey: key, urls: urls),
              if (status != NoteAttachmentStatus.ready)
                ColoredBox(
                  color: Colors.black38,
                  child: Center(
                    child: _StatusLine(
                      label: _statusLabel(context, status, error),
                      status: status,
                      onRetry: onRetry,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBlock extends ConsumerWidget {
  const _CardBlock({
    required this.data,
    required this.kind,
    required this.name,
    required this.local,
    required this.localThumb,
    required this.status,
    required this.error,
    required this.onRetry,
  });

  final Map<String, dynamic> data;
  final String kind;
  final String name;
  final String? local;
  final String? localThumb;
  final NoteAttachmentStatus status;
  final String? error;
  final VoidCallback? onRetry;

  String? get _key => data['key'] as String?;

  /// L'identité d'un son pour le lecteur partagé (un seul à la fois).
  String get _audioId =>
      _key ?? (data[kNoteAttachmentLocalId] as String?) ?? name;

  Future<String?> _source(NoteMediaUrls urls) async =>
      local ?? (_key == null ? null : await urls.resolve(_key!));

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final urls = ref.read(noteMediaUrlsProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final unavailable = context.l10n.noteAttachmentUnavailable;
    switch (kind) {
      case 'audio':
        await ref.read(chatAudioControllerProvider).toggle(
              _audioId,
              resolveUrl: () => _source(urls),
              knownDuration: _duration,
            );
      case 'video':
        final url = await _source(urls);
        if (url == null) {
          messenger?.showSnackBar(SnackBar(content: Text(unavailable)));
          return;
        }
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => ChatVideoScreen(url: url)),
        );
      default:
        final path =
            local ?? (_key == null ? null : await urls.download(_key!, name));
        final opened = path != null &&
            await ref
                .read(mediaOpenerProvider)
                .openFile(path, mime: data['mime'] as String?);
        if (!opened) {
          messenger?.showSnackBar(SnackBar(content: Text(unavailable)));
        }
    }
  }

  Duration? get _duration => switch (data['duration']) {
        final num s => Duration(milliseconds: (s * 1000).round()),
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toString();
    final size = data['size'];
    final duration = _duration;
    final details = status != NoteAttachmentStatus.ready
        ? _statusLabel(context, status, error)
        : [
            if (duration != null) formatMediaDuration(duration),
            if (size is int) formatByteSize(size, locale),
          ].join(' · ');

    final Widget trailing = switch (status) {
      NoteAttachmentStatus.failed => const SizedBox.shrink(),
      NoteAttachmentStatus.preparing ||
      NoteAttachmentStatus.uploading =>
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      NoteAttachmentStatus.ready when kind == 'audio' => ValueListenableBuilder(
          valueListenable: ref.watch(chatAudioControllerProvider),
          builder: (context, audio, _) => Icon(
            audio.activeId == _audioId && audio.playing
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
            color: palette.primary,
            size: 32,
          ),
        ),
      NoteAttachmentStatus.ready => Icon(
          kind == 'video' ? Icons.play_circle_fill : Icons.open_in_new,
          color: palette.primary,
        ),
    };

    final canOpen = local != null || _key != null;
    return Material(
      key: NoteAttachmentBlock.cardKey,
      color: palette.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: canOpen ? () => unawaited(_open(context, ref)) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _CardLeading(
                kind: kind,
                mime: data['mime'] as String?,
                name: name,
                localThumb: localThumb,
                thumbKey: data['thumbKey'] as String?,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: status == NoteAttachmentStatus.failed
                              ? AppColors.danger
                              : palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (status == NoteAttachmentStatus.failed && onRetry != null)
                TextButton(
                  key: NoteAttachmentBlock.retryKey,
                  onPressed: onRetry,
                  child: Text(context.l10n.noteAttachmentRetry),
                )
              else
                trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _CardLeading extends ConsumerWidget {
  const _CardLeading({
    required this.kind,
    required this.mime,
    required this.name,
    required this.localThumb,
    required this.thumbKey,
  });

  final String kind;
  final String? mime;
  final String name;
  final String? localThumb;
  final String? thumbKey;

  IconData get _icon => switch (kind) {
        'video' => Icons.movie_outlined,
        'audio' => Icons.graphic_eq,
        _ => switch (documentFamilyOf(mime: mime, name: name)) {
            DocumentFamily.pdf => Icons.picture_as_pdf_outlined,
            DocumentFamily.sheet => Icons.table_chart_outlined,
            DocumentFamily.slides => Icons.slideshow_outlined,
            DocumentFamily.text => Icons.description_outlined,
            DocumentFamily.other => Icons.insert_drive_file_outlined,
          },
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final icon = Icon(_icon, color: palette.primary, size: 26);
    final hasThumb =
        kind == 'video' && (localThumb != null || thumbKey != null);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 48,
        height: 48,
        color: palette.surface,
        alignment: Alignment.center,
        child: hasThumb
            ? _Picture(
                local: localThumb,
                mediaKey: thumbKey,
                urls: ref.watch(noteMediaUrlsProvider),
                fallback: icon,
              )
            : icon,
      ),
    );
  }
}

/// Une image : le fichier local, sinon l'URL signée, sinon [fallback].
class _Picture extends StatefulWidget {
  const _Picture({
    required this.local,
    required this.mediaKey,
    required this.urls,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? local;
  final String? mediaKey;
  final NoteMediaUrls urls;
  final Widget? fallback;
  final BoxFit fit;

  @override
  State<_Picture> createState() => _PictureState();
}

class _PictureState extends State<_Picture> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_Picture old) {
    super.didUpdateWidget(old);
    if (old.mediaKey != widget.mediaKey) _resolve();
  }

  void _resolve() {
    final key = widget.mediaKey;
    _url =
        widget.local == null && key != null ? widget.urls.resolve(key) : null;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ??
        const ColoredBox(
          color: Colors.black12,
          child: Center(
            child: Icon(Icons.image_outlined, color: Colors.black38, size: 40),
          ),
        );
    final local = widget.local;
    if (local != null) {
      return Image.file(
        File(local),
        fit: widget.fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return fallback;
        return Image.network(
          url,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.status,
    required this.onRetry,
    required this.color,
  });

  final String label;
  final NoteAttachmentStatus status;
  final VoidCallback? onRetry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final failed = status == NoteAttachmentStatus.failed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!failed)
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: AppTypography.body.copyWith(color: color)),
        if (failed && onRetry != null)
          TextButton(
            key: NoteAttachmentBlock.retryKey,
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: color),
            child: Text(context.l10n.noteAttachmentRetry),
          ),
      ],
    );
  }
}

/// La photo plein écran : fond noir, zoom par pincement.
class _PhotoViewer extends ConsumerWidget {
  const _PhotoViewer({required this.local, required this.mediaKey});

  final String? local;
  final String? mediaKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: _Picture(
            local: local,
            mediaKey: mediaKey,
            urls: ref.watch(noteMediaUrlsProvider),
            fit: BoxFit.contain,
            fallback: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
