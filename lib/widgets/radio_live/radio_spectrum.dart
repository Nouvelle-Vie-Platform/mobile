/// **Le spectre de l'antenne** — décoratif, pas un vrai spectre.
///
/// Des barres horizontales empilées sur toute la hauteur de la page, collées au
/// bord gauche de l'écran, qui s'allongent vers la droite. Elles ondulent
/// pendant que l'antenne joue et se rétractent en pause.
///
/// ## Pourquoi un spectre « grossier »
///
/// Un vrai spectre demande les échantillons décodés, et `just_audio` ne les
/// donne pas : sur iPhone, le flux HLS est décodé par AVPlayer, qui ne les
/// expose pas. Les longueurs sont donc une somme de sinus déphasés par barre —
/// assez irrégulière pour faire illusion, et rien ne prétend le contraire.
///
/// L'horloge ne tourne **que** pendant la lecture, et jamais quand le système
/// demande de réduire les animations : une animation continue de plus
/// interdirait `pumpAndSettle` à tous les tests qui montent cette page.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/radio_config.dart';
import '../../state/player_providers.dart';

/// Épaisseur d'une barre et écart entre deux barres.
const double _kBarThickness = 3;
const double _kBarGap = 7;

/// La part de la largeur qu'une barre peut atteindre : le spectre reste un
/// fond discret, il ne traverse pas la page.
const double _kMaxSpanFraction = 0.5;

/// La longueur d'une barre au repos (en pause, ou animations réduites).
const double _kRestLength = 4;

class RadioSpectrum extends ConsumerStatefulWidget {
  const RadioSpectrum({super.key});

  static const Key spectrumKey = Key('radio_spectrum');

  @override
  ConsumerState<RadioSpectrum> createState() => _RadioSpectrumState();
}

class _RadioSpectrumState extends ConsumerState<RadioSpectrum>
    with TickerProviderStateMixin {
  /// Le temps de l'ondulation, qui boucle.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  /// L'amplitude : 1 en lecture, 0 au repos — pour que les barres se
  /// rétractent en douceur au lieu de se figer en pleine ondulation.
  late final AnimationController _level = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool _active = false;

  @override
  void dispose() {
    _wave.dispose();
    _level.dispose();
    super.dispose();
  }

  void _sync(bool playing, bool reduceMotion) {
    final active = playing && !reduceMotion;
    if (active == _active) return;
    _active = active;
    if (active) {
      _wave.repeat();
      _level.forward();
    } else {
      // L'ondulation s'arrête une fois les barres rentrées : plus aucune
      // horloge ne tourne au repos.
      _level.reverse().whenComplete(() {
        if (!_active && mounted) _wave.stop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(
      contentPlaybackProvider.select(
        (p) =>
            p.contentId == RadioConfig.contentId &&
            p.isPlaying &&
            !p.isBuffering &&
            !p.hasError,
      ),
    );
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync(playing, reduceMotion);

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          key: RadioSpectrum.spectrumKey,
          painter: _SpectrumPainter(wave: _wave, level: _level),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.wave, required this.level})
      : super(repaint: Listenable.merge([wave, level]));

  final Animation<double> wave;
  final Animation<double> level;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.height / (_kBarThickness + _kBarGap)).floor();
    if (count <= 0 || size.width * _kMaxSpanFraction <= _kRestLength) return;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.02),
        ],
      ).createShader(
          Offset.zero & Size(size.width * _kMaxSpanFraction, size.height));

    final t = wave.value * 2 * math.pi;
    final amplitude = level.value;
    final span = size.width * _kMaxSpanFraction - _kRestLength;

    for (var i = 0; i < count; i++) {
      // Trois sinus déphasés par barre : irrégulier sans hasard, donc sans
      // saut d'une image à l'autre.
      final v = 0.5 +
          0.28 * math.sin(t * 3 + i * 0.62) +
          0.16 * math.sin(t * 7 + i * 1.73) +
          0.06 * math.sin(t * 13 + i * 0.29);
      final length = _kRestLength + span * v.clamp(0.05, 1.0) * amplitude;
      final top = i * (_kBarThickness + _kBarGap);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, top, length, _kBarThickness),
          topRight: const Radius.circular(_kBarThickness / 2),
          bottomRight: const Radius.circular(_kBarThickness / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) =>
      oldDelegate.wave != wave || oldDelegate.level != level;
}
