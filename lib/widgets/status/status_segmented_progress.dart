import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Fenêtre de segments réellement affichée par [StatusSegmentedProgress].
///
/// Fonction pure, extraite pour être testable sans monter de widget : quand
/// `count` dépasse `maxVisible`, la fenêtre glisse pour garder `index` visible
/// et à peu près centré, bornée aux deux extrémités (§3 — sans plafond, trente
/// statuts donneraient des traits de 3 px illisibles).
({int start, int length}) statusSegmentWindow({
  required int count,
  required int index,
  required int maxVisible,
}) {
  if (count <= 0) return (start: 0, length: 0);
  if (maxVisible <= 0 || count <= maxVisible) return (start: 0, length: count);

  final safeIndex = index.clamp(0, count - 1);
  var start = safeIndex - (maxVisible ~/ 2);
  if (start < 0) start = 0;
  if (start > count - maxVisible) start = count - maxVisible;
  return (start: start, length: maxVisible);
}

/// Barre de segments façon « stories » : un segment par statut, celui en cours
/// se remplissant au fil de la lecture.
///
/// Widget de **présentation pur** : il ne connaît ni le modèle `Announcement`
/// ni le lecteur. Aucune animation propre — la progression vient entièrement
/// de [progress], donc un `pumpAndSettle` sur cet écran se termine (§12).
class StatusSegmentedProgress extends StatelessWidget {
  const StatusSegmentedProgress({
    super.key,
    required this.count,
    required this.index,
    required this.progress,
    this.maxVisible = 10,
    this.height = 3,
    this.spacing = 3,
  });

  /// Nombre total de statuts.
  final int count;

  /// Index du statut courant.
  final int index;

  /// Progression `0..1` sur le statut courant (bornée à l'usage).
  final double progress;

  /// Taille de la fenêtre glissante (§3).
  final int maxVisible;

  /// Épaisseur d'un segment.
  final double height;

  /// Écart horizontal entre deux segments.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return SizedBox(height: height);

    final window = statusSegmentWindow(
      count: count,
      index: index,
      maxVisible: maxVisible,
    );
    if (window.length <= 0) return SizedBox(height: height);

    // Posée sur un fond coloré ou une image : on suit la couleur de texte du
    // contexte (choisie selon la luminance du fond), palette en dernier recours.
    final filled =
        DefaultTextStyle.of(context).style.color ?? context.palette.textPrimary;
    final track = filled.withValues(alpha: 0.30);

    final safeIndex = index.clamp(0, count - 1);
    final safeProgress =
        progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0).toDouble();

    final segments = <Widget>[];
    for (var i = window.start; i < window.start + window.length; i++) {
      // Avant l'index courant : plein. Sur l'index : rempli à `progress`.
      // Après : vide.
      final fill = i < safeIndex
          ? 1.0
          : i == safeIndex
              ? safeProgress
              : 0.0;

      if (segments.isNotEmpty) segments.add(SizedBox(width: spacing));
      segments.add(
        Expanded(
          child: _Segment(height: height, fill: fill, track: track, on: filled),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(children: segments),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.height,
    required this.fill,
    required this.track,
    required this.on,
  });

  final double height;
  final double fill;
  final Color track;
  final Color on;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: track),
          if (fill > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: ColoredBox(color: on),
              ),
            ),
        ],
      ),
    );
  }
}
