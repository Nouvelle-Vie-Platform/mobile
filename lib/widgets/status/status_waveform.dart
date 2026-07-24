import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../utils/stable_hash.dart';

/// Nombre de barres par défaut de la waveform (§5 : 28 à 40, grossières).
const int kStatusWaveformBarCount = 32;

/// Hauteurs pseudo-aléatoires **déterministes** dérivées d'un hash de [seed].
///
/// Deux appels avec le même [seed] renvoient exactement la même liste : c'est
/// la condition pour que les barres ne changent pas à chaque `build` (§5 —
/// « jamais `Random()` »). Même esprit que le champ `seed` de `Teaching`.
///
/// Les valeurs sont dans `0..100`, comme celles envoyées par le back.
List<int> waveformFromSeed(String seed, {int count = kStatusWaveformBarCount}) {
  if (count <= 0) return const <int>[];

  var hash = stableHash(seed);
  // Un seed vide ne doit pas dégénérer en état nul du générateur.
  if (hash == 0) hash = 0x9e3779b9;

  final bars = <int>[];
  var state = hash;
  for (var i = 0; i < count; i++) {
    // xorshift32 : suite déterministe, sans `dart:math` ni état global.
    state ^= (state << 13) & 0xffffffff;
    state ^= state >> 17;
    state = (state ^ ((state << 5) & 0xffffffff)) & 0xffffffff;

    // 18..100 : jamais de barre invisible, jamais de forme plate.
    bars.add(18 + (state % 83));
  }
  return bars;
}

/// Ré-échantillonne [bars] pour obtenir exactement [count] valeurs.
///
/// Moyenne par intervalle : volontairement grossier (§5 : « pas très
/// détaillée »). Une liste vide renvoie une liste vide — l'appelant décide du
/// repli.
List<int> resampleWaveform(List<int> bars, int count) {
  if (count <= 0 || bars.isEmpty) return const <int>[];
  if (bars.length == count) return List<int>.of(bars);

  final out = <int>[];
  for (var i = 0; i < count; i++) {
    final start = (i * bars.length) ~/ count;
    var end = ((i + 1) * bars.length) ~/ count;
    if (end <= start) end = start + 1;
    if (end > bars.length) end = bars.length;

    var sum = 0;
    for (var j = start; j < end; j++) {
      sum += bars[j];
    }
    out.add((sum / (end - start)).round());
  }
  return out;
}

/// Forme d'onde d'un statut vocal.
///
/// Widget de **présentation pur** : il ne connaît ni le modèle `Announcement`
/// ni le lecteur, il reçoit des primitives. Les barres déjà jouées sont
/// pleines, celles à venir translucides ; la barre en cours de lecture et ses
/// deux voisines sont légèrement agrandies.
///
/// La pulsation est **dérivée de [progress]**, jamais d'un
/// `AnimationController` : le widget reste donc « settleable » (un
/// `pumpAndSettle` se termine), ce qui est indispensable pour tester l'écran
/// qui l'héberge (§5 et §12 de `docs/statuts-annonces.md`).
class StatusWaveform extends StatelessWidget {
  const StatusWaveform({
    super.key,
    required this.bars,
    required this.progress,
    required this.seed,
    this.playedColor,
    this.pendingColor,
    this.height = 40,
    this.barCount = kStatusWaveformBarCount,
  });

  /// Hauteurs `0..100` fournies par le back. Peut être vide ⇒ repli sur [seed].
  final List<int> bars;

  /// Position de lecture, `0..1` (bornée à l'usage).
  final double progress;

  /// Identifiant du statut : sert au repli déterministe si [bars] est vide.
  final String seed;

  /// Couleur des barres déjà jouées. Défaut : couleur de texte héritée du
  /// contexte (blanc sur un fond de statut), sinon la palette.
  final Color? playedColor;

  /// Couleur des barres à venir. Défaut : [playedColor] translucide.
  final Color? pendingColor;

  /// Hauteur totale allouée à la forme d'onde.
  final double height;

  /// Nombre de barres effectivement dessinées.
  final int barCount;

  /// Hauteurs effectivement dessinées : données du back ré-échantillonnées à
  /// [barCount], ou repli déterministe dérivé de [seed].
  List<int> resolveBars() {
    if (barCount <= 0) return const <int>[];
    if (bars.isEmpty) return waveformFromSeed(seed, count: barCount);
    return resampleWaveform(bars, barCount);
  }

  @override
  Widget build(BuildContext context) {
    // La waveform est posée sur un fond coloré ou une image : on suit la
    // couleur de texte du contexte (le fond du statut choisit clair ou sombre
    // selon sa luminance), avec la palette pour dernier recours.
    final played = playedColor ??
        DefaultTextStyle.of(context).style.color ??
        context.palette.textPrimary;
    final pending = pendingColor ?? played.withValues(alpha: 0.35);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _StatusWaveformPainter(
          bars: resolveBars(),
          progress: progress.isNaN ? 0 : progress.clamp(0.0, 1.0),
          playedColor: played,
          pendingColor: pending,
        ),
      ),
    );
  }
}

class _StatusWaveformPainter extends CustomPainter {
  const _StatusWaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.pendingColor,
  });

  final List<int> bars;
  final double progress;
  final Color playedColor;
  final Color pendingColor;

  /// Part de la demi-hauteur occupée au repos : laisse de la marge à la
  /// pulsation sans déborder de la boîte.
  static const double _restScale = 0.86;

  /// Agrandissement de la barre en cours de lecture et de ses deux voisines,
  /// décroissant avec la distance.
  static const List<double> _pulse = <double>[1.18, 1.10, 1.04];

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final slot = size.width / bars.length;
    // Barre fine avec de l'air autour, dessinée en capsule.
    final barWidth = math.max(0.5, slot * 0.55);
    final radius = Radius.circular(barWidth / 2);
    final centerY = size.height / 2;
    final maxHalf = size.height / 2 * _restScale;
    // Hauteur minimale visible : une barre à 0 reste un point, pas un trou.
    // Bornée par `maxHalf` : sur une boîte très plate, tout se tasse sans
    // planter plutôt que de déborder.
    final minHalf = math.min(math.max(0.5, barWidth / 2), maxHalf);

    // Barre en cours de lecture : la pulsation est dérivée de `progress`.
    final playedCount = progress * bars.length;
    final activeIndex = progress >= 1.0
        ? bars.length - 1
        : playedCount.floor().clamp(0, bars.length - 1).toInt();

    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < bars.length; i++) {
      final value = bars[i].clamp(0, 100) / 100;
      var half = minHalf + (maxHalf - minHalf) * value;

      final distance = (i - activeIndex).abs();
      if (distance < _pulse.length) {
        half = (half * _pulse[distance]).clamp(minHalf, size.height / 2);
      }

      paint.color =
          (progress > 0 && i <= activeIndex) ? playedColor : pendingColor;

      final left = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, centerY - half, barWidth, half * 2),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StatusWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.pendingColor != pendingColor ||
        !_sameBars(oldDelegate.bars, bars);
  }

  static bool _sameBars(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
