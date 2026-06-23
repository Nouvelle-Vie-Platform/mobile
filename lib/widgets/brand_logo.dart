import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Emblème circulaire de l'église (colombe + bandeau).
///
/// Reproduit le logo de la maquette de façon vectorielle simple.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 160,
    this.onLight = false,
  });

  final double size;

  /// `true` pour un rendu sombre sur fond clair ; sinon blanc sur fond bleu.
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final color = onLight ? AppColors.primary : Colors.white;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(Icons.flutter_dash, size: size * 0.42, color: color),
          ),
          SizedBox(height: size * 0.06),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: size * 0.08, vertical: size * 0.02),
            color: color == Colors.white ? Colors.white : AppColors.primary,
            child: Text(
              'MAISON DU MIRACLE',
              style: AppTypography.caption.copyWith(
                color: color == Colors.white
                    ? AppColors.primary
                    : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.055,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
