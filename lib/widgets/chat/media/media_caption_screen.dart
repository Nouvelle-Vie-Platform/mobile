import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

/// **L'aperçu avant envoi d'une photo ou d'une vidéo**, avec sa légende
/// facultative (M4, #143). Rend la légende (éventuellement vide) si l'on
/// envoie, `null` si l'on renonce.
class MediaCaptionScreen extends StatefulWidget {
  const MediaCaptionScreen({super.key, required this.path, this.video = false});

  final String path;
  final bool video;

  static Future<String?> open(
    BuildContext context, {
    required String path,
    bool video = false,
  }) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MediaCaptionScreen(path: path, video: video),
        ),
      );

  @override
  State<MediaCaptionScreen> createState() => _MediaCaptionScreenState();
}

class _MediaCaptionScreenState extends State<MediaCaptionScreen> {
  final TextEditingController _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: l.m4Cancel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: widget.video
                  ? const Icon(Icons.movie_outlined,
                      color: Colors.white70, size: 96)
                  : Image.file(
                      File(widget.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('m4_caption_field'),
                      controller: _caption,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: l.m4CaptionHint,
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    key: const Key('m4_caption_send'),
                    tooltip: l.m4Send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () =>
                        Navigator.of(context).pop(_caption.text.trim()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
