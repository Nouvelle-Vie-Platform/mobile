import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Vignette média (placeholder dégradé) avec bouton lecture optionnel.
///
/// Les maquettes utilisent des photos ; on rend ici un substitut élégant
/// prêt à recevoir une vraie image via [image].
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.showPlay = true,
    this.image,
    this.seed = 0,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final bool showPlay;
  final ImageProvider? image;

  /// Décale la teinte du dégradé pour différencier les vignettes.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final tones = [
      [const Color(0xFF2A3F6E), const Color(0xFF16213E)],
      [const Color(0xFF3A2E5A), const Color(0xFF1E1733)],
      [const Color(0xFF1F4D45), const Color(0xFF0E2A26)],
      [const Color(0xFF5A3A3A), const Color(0xFF2E1717)],
    ];
    final pair = tones[seed % tones.length];

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pair,
          ),
          image: image == null
              ? null
              : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        child: showPlay
            ? Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: AppColors.primary, size: 24),
                ),
              )
            : null,
      ),
    );
  }
}
