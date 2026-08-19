import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/media/media_saver.dart';
import '../l10n/l10n_extension.dart';
import '../state/media_saver_providers.dart';

/// Arguments de la visionneuse : la liste complète des médias et l'index ouvert
/// (pour pouvoir défiler d'un média à l'autre).
class MediaViewerArgs {
  const MediaViewerArgs({required this.urls, required this.index});

  final List<String> urls;
  final int index;
}

/// Visionneuse **plein écran** des médias partagés.
///
/// Fond noir, défilement horizontal entre les médias, zoom par pincement
/// ([InteractiveViewer]). Barre du haut : fermer + **télécharger** (enregistre
/// dans la galerie Photos via [MediaSaver] ; bouton masqué sur le web, que
/// `gal` ne supporte pas).
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.args});

  final MediaViewerArgs args;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.args.index);
  late int _current = widget.args.index;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download(String url) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await ref.read(mediaSaverProvider).saveImageFromUrl(url);
      message = l.mediaSaved;
    } on MediaSaveException catch (e) {
      message = switch (e.error) {
        MediaSaveError.permissionDenied => l.mediaSaveErrorPermission,
        MediaSaveError.network => l.mediaSaveErrorNetwork,
        MediaSaveError.unsupported => l.mediaSaveErrorUnsupported,
        MediaSaveError.unknown => l.mediaSaveError,
      };
    }
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.args.urls;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  urls[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          // Barre du haut : dégradé sombre pour asseoir les icônes.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    // `gal` ne supporte pas le web : pas de bouton là-bas.
                    if (!kIsWeb && urls.isNotEmpty)
                      IconButton(
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_outlined,
                                color: Colors.white),
                        onPressed:
                            _saving ? null : () => _download(urls[_current]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
