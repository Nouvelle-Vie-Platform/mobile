import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_spacing.dart';

/// Visuel d'un enseignement : image d'habillage (réseau) avec **repli coloré**
/// (la couleur de l'enseignement) si l'image est absente, hors-ligne ou en test.
///
/// Partagé par l'accueil et la médiathèque pour un rendu cohérent.
class TeachingCover extends StatelessWidget {
  const TeachingCover({
    super.key,
    required this.teaching,
    this.radius = AppRadius.lg,
  });

  final Teaching teaching;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Color(teaching.color),
      child: const Center(
        child: Icon(Icons.headphones_rounded, color: Colors.white70, size: 30),
      ),
    );

    final image = teaching.image;
    final Widget content = image == null
        ? fallback
        : Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(child: content),
    );
  }
}
