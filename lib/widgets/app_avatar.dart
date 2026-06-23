import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Avatar circulaire affichant les initiales sur un fond coloré.
///
/// Faute de photo dans la maquette, on génère une couleur stable à partir
/// du nom et on affiche les initiales.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFFE0709A),
    Color(0xFFE6A100),
    Color(0xFF7A5AF8),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? _palette[name.length % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: AppTypography.bodyStrong.copyWith(
          color: Colors.white,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
