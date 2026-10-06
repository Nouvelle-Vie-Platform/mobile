import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// **La lecture d'une vidéo du fil**, plein écran (M4, #143).
///
/// L'un des deux fichiers de `lib/` qui importent `video_player` (garde-fou de
/// source : `test/data/content_player_test.dart`) : un
/// `VideoPlayerController` construit dans un écran lèverait
/// `MissingPluginException` sous `flutter test`. L'écran ne connaît que
/// [ChatVideoSurfaceFactory] ; les tests posent [InertChatVideoSurfaceFactory].
///
/// La vidéo est un **MP4 unique**, lu en progressif : pas de HLS, un fichier
/// de quelques mégaoctets n'achèterait rien à être découpé.
abstract interface class ChatVideoSurfaceFactory {
  /// La surface qui lit [url] (présignée, ou `file://` d'un écho).
  Widget build(BuildContext context, String url);
}

class VideoPlayerChatSurfaceFactory implements ChatVideoSurfaceFactory {
  const VideoPlayerChatSurfaceFactory();

  @override
  Widget build(BuildContext context, String url) =>
      _ChatVideoSurface(url: url);
}

class InertChatVideoSurfaceFactory implements ChatVideoSurfaceFactory {
  const InertChatVideoSurfaceFactory();

  @override
  Widget build(BuildContext context, String url) =>
      const Center(child: Icon(Icons.movie_outlined, color: Colors.white54));
}

class _ChatVideoSurface extends StatefulWidget {
  const _ChatVideoSurface({required this.url});

  final String url;

  @override
  State<_ChatVideoSurface> createState() => _ChatVideoSurfaceState();
}

class _ChatVideoSurfaceState extends State<_ChatVideoSurface> {
  // Créé dans `initState`, jamais paresseusement : `dispose` le touche.
  late final VideoPlayerController _controller;

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.url.startsWith('/')
        ? VideoPlayerController.file(File(widget.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.white70, size: 48),
      );
    }
    final value = _controller.value;
    if (!value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => value.isPlaying ? _controller.pause() : _controller.play(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!value.isPlaying)
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: VideoProgressIndicator(_controller, allowScrubbing: true),
          ),
        ],
      ),
    );
  }
}
