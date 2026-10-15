import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/messaging/media/media_mime.dart';
import '../../../data/players/chat_audio_player.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/echanges_view.dart';
import '../../../models/message_media.dart';
import '../../../router/app_router.dart';
import '../../../screens/media_viewer_screen.dart';
import '../../../state/chat_media_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../app_avatar.dart';
import '../../status/status_waveform.dart';
import 'chat_video_screen.dart';
import 'media_labels.dart';

/// **Le média d'une bulle** (M4, #143 — reprend #98) : ce que `ChatBubble`
/// peint **au-dessus** de la légende quand le message porte un média.
///
/// Une bulle par forme, et deux états de plus, communs à toutes :
///
/// - **en cours d'envoi** — l'anneau de la montée par-dessus le média (sa
///   progression vient de `MediaUploadProgress`, en mémoire) ;
/// - **en échec** — la cause, quand on la connaît (« Fichier trop
///   volumineux »), sous le média ; le geste « Réessayer / Supprimer » reste
///   celui de la bulle (#140).
///
/// Un message **confirmé** n'a qu'une clé : l'URL de lecture s'obtient au
/// moment d'afficher (`GroupMediaUrls`). Un **écho** a son fichier local : la
/// photo qu'on vient de prendre s'affiche sans aller-retour.
class MessageMediaView extends ConsumerWidget {
  const MessageMediaView({super.key, required this.message});

  final GroupMessageView message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = message.media!;
    final l = context.l10n;
    final mine = message.mine;
    final ink = mine ? Colors.white : context.palette.textPrimary;

    final Widget body = switch (media.kind) {
      MessageMediaKind.voice ||
      MessageMediaKind.audio =>
        AudioMediaTile(message: message, media: media, ink: ink),
      MessageMediaKind.image => ImageMediaTile(message: message, media: media),
      MessageMediaKind.video => VideoMediaTile(message: message, media: media),
      MessageMediaKind.document =>
        DocumentMediaTile(message: message, media: media, ink: ink),
      MessageMediaKind.location => LocationMediaTile(media: media, ink: ink),
      MessageMediaKind.contact => ContactMediaTile(media: media, ink: ink),
      MessageMediaKind.unknown => Text(
          l.m4MediaUnsupportedKind,
          style: AppTypography.body.copyWith(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: ink,
          ),
        ),
    };

    final sending = message.delivery == MessageDelivery.sending;
    final failed = message.delivery == MessageDelivery.failed;
    final error = message.mediaError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sending && media.kind.hasFile)
          _UploadOverlay(clientMessageId: message.id, child: body)
        else
          body,
        if (failed && error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              mediaErrorLabel(l, error),
              key: const Key('m4_media_error'),
              style: AppTypography.caption.copyWith(
                color: mine ? AppColors.accent : AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// **L'anneau de la montée**, par-dessus le média d'un écho.
class _UploadOverlay extends ConsumerWidget {
  const _UploadOverlay({required this.clientMessageId, required this.child});

  final String clientMessageId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(mediaUploadProgressProvider);
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        ValueListenableBuilder<Map<String, double>>(
          valueListenable: progress,
          builder: (context, value, _) {
            final p = value[clientMessageId];
            return Container(
              key: const Key('m4_upload_progress'),
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(
                // Pas encore de chiffre (dégradation, ticket) : l'anneau tourne.
                value: p,
                strokeWidth: 3,
                color: Colors.white,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// **Le disque avant le réseau** (T1, #223) — la règle, en un seul endroit.
///
/// Rend le **fichier local** quand il est là, et [GroupMediaUrls.resolve]
/// n'est alors **pas appelé** : un média déjà sur l'appareil se peint hors
/// ligne, et le revoir en remontant le fil ne coûte plus une requête d'URL
/// présignée. L'existence est **vérifiée** : un fichier que le système ou la
/// purge de #226 a emporté retombe sur le réseau au lieu d'un cadre cassé.
///
/// Un écho (pas encore confirmé) n'a pas d'identité serveur : rien à résoudre.
Future<String?> _mediaSourceOf(
  WidgetRef ref,
  GroupMessageView message, {
  String? local,
  bool thumbnail = false,
}) async {
  // `existsSync` et non `exists` : un `stat` sur un chemin local coûte
  // quelques microsecondes — bien moins qu'une requête réseau, et bien moins
  // qu'une image qui clignote le temps d'une passe d'événements. Et c'est la
  // seule forme qui aboutisse sous `flutter test`, dont la zone d'`async`
  // feint ne fait jamais avancer une entrée-sortie réelle.
  if (local != null && File(local).existsSync()) return local;
  if (!message.isConfirmed) return null;
  return ref.read(groupMediaUrlsProvider).resolve(
        groupId: message.groupId,
        messageId: message.id,
        thumbnail: thumbnail,
      );
}

/// `Image.file` ou `Image.network` selon la source — même convention que le
/// moteur audio et la surface vidéo : un chemin absolu est un fichier de
/// l'appareil, tout le reste est une URL.
Widget _mediaImage(
  String source, {
  BoxFit fit = BoxFit.cover,
  int? cacheWidth,
  required Widget Function() onError,
}) {
  Widget fallback(BuildContext _, Object __, StackTrace? ___) => onError();
  return source.startsWith('/')
      ? Image.file(File(source),
          fit: fit, cacheWidth: cacheWidth, errorBuilder: fallback)
      : Image.network(source,
          fit: fit, cacheWidth: cacheWidth, errorBuilder: fallback);
}

/// **Résout la source une fois** — une `Future` gardée par l'état, pour qu'une
/// reconstruction de la bulle ne relance ni le test du disque ni la requête.
class _MediaSource extends ConsumerStatefulWidget {
  const _MediaSource({
    required this.message,
    required this.builder,
    this.local,
    this.thumbnail = false,
  });

  final GroupMessageView message;

  /// Le chemin noté pour ce message — l'outbox d'un écho, ou le magasin
  /// durable d'un reçu (`local_message_media`).
  final String? local;
  final bool thumbnail;
  final Widget Function(BuildContext context, String? source, bool done)
      builder;

  @override
  ConsumerState<_MediaSource> createState() => _MediaSourceState();
}

class _MediaSourceState extends ConsumerState<_MediaSource> {
  late final Future<String?> _source = _mediaSourceOf(
    ref,
    widget.message,
    local: widget.local,
    thumbnail: widget.thumbnail,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _source,
      builder: (context, snapshot) => widget.builder(
        context,
        snapshot.data,
        snapshot.connectionState == ConnectionState.done,
      ),
    );
  }
}

/// La largeur d'un média visuel dans la bulle.
const double _kVisualWidth = 220;

double _visualHeight(MessageMedia media) {
  final ratio = (media.aspectRatio ?? 4 / 3).clamp(0.6, 1.8);
  return _kVisualWidth / ratio;
}

/// **Une image** : la vignette du fil est **la même image**, redimensionnée à
/// l'affichage (#98 : un seul fichier par image). Au toucher, la visionneuse
/// existante.
class ImageMediaTile extends ConsumerWidget {
  const ImageMediaTile({
    super.key,
    required this.message,
    required this.media,
    this.extent,
  });

  final GroupMessageView message;
  final MessageMedia media;

  /// Un carré de ce côté (grille de « Médias, liens et docs », rangée de la
  /// fiche) ; `null` = le cadre de la bulle.
  final double? extent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = extent ?? _kVisualWidth;
    final height = extent ?? _visualHeight(media);

    Widget frame(Widget child, {VoidCallback? onTap}) => GestureDetector(
          key: const Key('m4_image_tile'),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(width: width, height: height, child: child),
          ),
        );

    return _MediaSource(
      message: message,
      local: media.localPath,
      builder: (context, source, done) {
        if (source == null) {
          return frame(
            _VisualPlaceholder(
              unavailable: done,
              label: done ? context.l10n.m4MediaUnavailable : null,
            ),
          );
        }
        return frame(
          _mediaImage(
            source,
            // Le fil peint des vignettes : décoder 1600 px pour 220 serait
            // gaspiller la mémoire de petits téléphones.
            cacheWidth: (width * 2).round(),
            onError: () => const _VisualPlaceholder(),
          ),
          // Un écho n'a pas d'identité serveur, donc pas de plein écran.
          onTap: message.isConfirmed
              ? () => _openViewer(context, ref, source)
              : null,
        );
      },
    );
  }

  /// La visionneuse plein écran lit par le **réseau** (`Image.network`) : le
  /// fichier local sert la vignette du fil, et l'URL n'est demandée qu'au
  /// toucher — une requête de moins par image **affichée**. L'étendre au
  /// fichier local toucherait aussi l'enregistrement en galerie
  /// (`MediaSaver.saveImageFromUrl`) : hors de cette tranche.
  Future<void> _openViewer(
    BuildContext context,
    WidgetRef ref,
    String source,
  ) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final unavailable = context.l10n.m4MediaUnavailable;
    final url = source.startsWith('/')
        ? await ref.read(groupMediaUrlsProvider).resolve(
              groupId: message.groupId,
              messageId: message.id,
            )
        : source;
    if (url == null) {
      messenger.showSnackBar(SnackBar(content: Text(unavailable)));
      return;
    }
    router.pushNamed(
      AppRoute.mediaViewer,
      extra: MediaViewerArgs(urls: [url], index: 0),
    );
  }
}

class _VisualPlaceholder extends StatelessWidget {
  const _VisualPlaceholder({this.unavailable = false, this.label, this.icon});

  final bool unavailable;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: unavailable
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon ?? Icons.broken_image_outlined,
                    color: Colors.black38),
                if (label != null) Text(label!, style: AppTypography.caption),
              ],
            )
          : Icon(icon ?? Icons.image_outlined, color: Colors.black26, size: 40),
    );
  }
}

/// **Une vidéo** : sa vignette, sa durée, et le lecteur plein écran au
/// toucher. Le fichier est un MP4 unique, lu en progressif.
class VideoMediaTile extends ConsumerWidget {
  const VideoMediaTile({
    super.key,
    required this.message,
    required this.media,
    this.extent,
  });

  final GroupMessageView message;
  final MessageMedia media;

  /// Voir [ImageMediaTile.extent].
  final double? extent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = extent ?? _kVisualWidth;
    final height = extent ?? _visualHeight(media);
    final duration = media.durationSeconds;

    Widget frame(Widget thumb, {VoidCallback? onTap}) => GestureDetector(
          key: const Key('m4_video_tile'),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumb,
                  Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: extent == null ? 52 : 32,
                    ),
                  ),
                  if (duration != null)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Row(
                        children: [
                          const Icon(Icons.videocam,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            formatMediaDuration(Duration(seconds: duration)),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

    void play(String url) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ChatVideoScreen(url: url)),
        );

    // La vignette : le fichier local d'abord. Sans vignette locale **et** sans
    // clé servie, rien à résoudre — le gabarit, et pas une requête perdue.
    final Widget thumbnail = media.localThumbPath == null &&
            media.thumbnailKey == null
        ? const _VisualPlaceholder(icon: Icons.movie_outlined)
        : _MediaSource(
            message: message,
            local: media.localThumbPath,
            thumbnail: true,
            builder: (context, source, _) => source == null
                ? const _VisualPlaceholder(icon: Icons.movie_outlined)
                : _mediaImage(
                    source,
                    onError: () =>
                        const _VisualPlaceholder(icon: Icons.movie_outlined),
                  ),
          );

    return frame(
      thumbnail,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final unavailable = context.l10n.m4MediaUnavailable;
        // Le fichier local joue sans réseau — `VideoPlayerController.file`
        // pour un chemin absolu, `networkUrl` sinon (voir la surface).
        final source = await _mediaSourceOf(
          ref,
          message,
          local: media.localPath,
        );
        if (source == null) {
          messenger.showSnackBar(SnackBar(content: Text(unavailable)));
          return;
        }
        if (context.mounted) play(source);
      },
    );
  }
}

/// **Un vocal** (forme d'onde, durée, position, vitesse) ou **un fichier
/// audio** (son nom). Un seul son à la fois, pour toute l'application
/// (`ChatAudioController`).
class AudioMediaTile extends ConsumerWidget {
  const AudioMediaTile({
    super.key,
    required this.message,
    required this.media,
    required this.ink,
    this.width = 240,
  });

  final GroupMessageView message;
  final MessageMedia media;
  final Color ink;

  /// La largeur de la tuile — celle de la bulle par défaut.
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(chatAudioControllerProvider);
    final l = context.l10n;
    final voice = media.kind == MessageMediaKind.voice;

    // Le fichier local d'abord — le moteur lit un chemin absolu par
    // `Uri.file` (voir `JustAudioChatEngine.load`).
    Future<String?> resolve() =>
        _mediaSourceOf(ref, message, local: media.localPath);

    return ValueListenableBuilder<ChatAudioState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final active = state.activeId == message.id;
        final known = media.durationSeconds == null
            ? null
            : Duration(seconds: media.durationSeconds!);
        final total = (active ? state.duration : null) ?? known;
        final position = active ? state.position : Duration.zero;
        final progress = total == null || total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble();
        final playing = active && state.playing;
        final loading = active && state.loading;
        final failed = active && state.failed;

        final button = SizedBox(
          width: 40,
          height: 40,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                )
              : IconButton(
                  key: Key('m4_audio_play_${message.id}'),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: ink,
                    size: 32,
                  ),
                  onPressed: () => controller.toggle(
                    message.id,
                    resolveUrl: resolve,
                    knownDuration: known,
                  ),
                ),
        );

        final timeText = formatMediaDuration(
          active && position > Duration.zero
              ? position
              : (total ?? Duration.zero),
        );

        return SizedBox(
          width: width,
          child: Row(
            children: [
              if (voice)
                Icon(Icons.mic, color: ink.withValues(alpha: 0.8), size: 18)
              else
                Icon(Icons.music_note,
                    color: ink.withValues(alpha: 0.8), size: 18),
              button,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!voice && media.name != null)
                      Text(
                        media.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(color: ink),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Toucher la forme d'onde saute à cet endroit — du son en
                        // cours seulement.
                        onTapDown: (details) => controller.seekTo(
                          message.id,
                          details.localPosition.dx / constraints.maxWidth,
                        ),
                        child: voice
                            ? StatusWaveform(
                                key: Key('m4_voice_waveform_${message.id}'),
                                bars: media.waveform,
                                progress: progress,
                                seed: message.id,
                                playedColor: ink,
                                height: 28,
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  color: ink,
                                  backgroundColor: ink.withValues(alpha: 0.25),
                                ),
                              ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          failed ? l.m4MediaUnavailable : timeText,
                          key: Key('m4_audio_time_${message.id}'),
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: ink.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        if (active && !failed)
                          GestureDetector(
                            key: const Key('m4_audio_speed'),
                            onTap: controller.cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: ink.withValues(alpha: 0.18),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                speedLabel(state.speed, l.localeName),
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// **Un document** : son icône, son nom, sa taille ; au toucher, il s'ouvre
/// dans l'application du système.
class DocumentMediaTile extends ConsumerWidget {
  const DocumentMediaTile({
    super.key,
    required this.message,
    required this.media,
    required this.ink,
    this.width = 240,
  });

  final GroupMessageView message;
  final MessageMedia media;
  final Color ink;

  /// Voir [AudioMediaTile.width].
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = media.name ?? l.m4PreviewDocument;
    final family = documentFamilyOf(mime: media.mime, name: media.name);
    final (icon, tint) = switch (family) {
      DocumentFamily.pdf => (Icons.picture_as_pdf, const Color(0xFFD93025)),
      DocumentFamily.sheet => (Icons.table_chart, const Color(0xFF188038)),
      DocumentFamily.slides => (Icons.slideshow, const Color(0xFFE37400)),
      DocumentFamily.text => (Icons.description, const Color(0xFF1A73E8)),
      DocumentFamily.other => (Icons.insert_drive_file, Colors.blueGrey),
    };
    final ext = fileExtension(name).toUpperCase();
    final size = media.sizeBytes;
    final details = [
      if (size != null) formatByteSize(size, l.localeName),
      if (ext.isNotEmpty) ext,
    ].join(' · ');

    Future<void> open() async {
      final messenger = ScaffoldMessenger.of(context);
      final failure = l.m4DocumentOpenFailed;
      final opener = ref.read(mediaOpenerProvider);
      // Le fichier noté, s'il est encore là ; sinon [GroupMediaUrls.download],
      // qui teste lui aussi le disque **avant** le réseau (#223) — un document
      // déjà descendu s'ouvre hors ligne.
      var path = media.localPath;
      if (path != null && !File(path).existsSync()) path = null;
      if (path == null && message.isConfirmed) {
        path = await ref.read(groupMediaUrlsProvider).download(
              groupId: message.groupId,
              messageId: message.id,
              fileName: name,
            );
      }
      final opened =
          path != null && await opener.openFile(path, mime: media.mime);
      if (!opened) {
        messenger.showSnackBar(SnackBar(content: Text(failure)));
      }
    }

    return InkWell(
      key: const Key('m4_document_tile'),
      onTap: open,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: tint, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(color: ink),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: AppTypography.caption.copyWith(
                        color: ink.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Une position** : un pavé de carte dessiné (aucune tuile, aucune clé
/// d'API), le libellé et les coordonnées ; au toucher, l'application de cartes
/// du téléphone.
class LocationMediaTile extends ConsumerWidget {
  const LocationMediaTile({super.key, required this.media, required this.ink});

  final MessageMedia media;
  final Color ink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lat = media.latitude, lng = media.longitude;
    if (lat == null || lng == null) {
      return Text(l.m4MediaUnavailable, style: TextStyle(color: ink));
    }
    final coords = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

    return Semantics(
      button: true,
      label: l.m4LocationOpen,
      child: GestureDetector(
        key: const Key('m4_location_tile'),
        onTap: () => ref
            .read(mediaOpenerProvider)
            .openMap(latitude: lat, longitude: lng, label: media.label),
        child: SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 110,
                  width: 240,
                  child: CustomPaint(
                    painter: _MapPainter(),
                    child: const Center(
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.danger,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                media.label ?? l.m4LocationDefaultLabel,
                style: AppTypography.bodyStrong.copyWith(color: ink),
              ),
              Text(
                coords,
                style: AppTypography.caption.copyWith(
                  color: ink.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un fond de carte **dessiné**, pas téléchargé : des îlots et des rues
/// stylisés. Il dit « une carte » sans rien coûter ni rien révéler à un tiers.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFE8F0E3));
    final block = Paint()..color = const Color(0xFFD6E4CF);
    for (var x = 0.0; x < size.width; x += 46) {
      for (var y = 0.0; y < size.height; y += 34) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 6, y + 6, 34, 22),
            const Radius.circular(3),
          ),
          block,
        );
      }
    }
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.38),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.5, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// **Un contact** : son nom, ses numéros, et « Appeler ». Rien d'autre n'a été
/// lu du carnet.
class ContactMediaTile extends ConsumerWidget {
  const ContactMediaTile({super.key, required this.media, required this.ink});

  final MessageMedia media;
  final Color ink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = media.contactName ?? l.m4PreviewContact;
    final phones = media.phones;

    return SizedBox(
      key: const Key('m4_contact_tile'),
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: name, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.bodyStrong.copyWith(color: ink),
                    ),
                    for (final phone in phones)
                      Text(
                        phone.label == null
                            ? phone.number
                            : '${phone.number} · ${phone.label}',
                        style: AppTypography.caption.copyWith(
                          color: ink.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (phones.isNotEmpty) ...[
            Divider(color: ink.withValues(alpha: 0.2), height: 12),
            Center(
              child: TextButton.icon(
                key: const Key('m4_contact_call'),
                onPressed: () =>
                    ref.read(mediaOpenerProvider).dial(phones.first.number),
                icon: Icon(Icons.call, color: ink, size: 18),
                label: Text(l.m4ContactCall, style: TextStyle(color: ink)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
