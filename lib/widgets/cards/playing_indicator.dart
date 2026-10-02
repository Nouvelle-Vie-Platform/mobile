import 'package:flutter/material.dart';

/// Trois barres animées indiquant qu'une lecture est en cours.
///
/// Simple, léger, et immédiatement reconnaissable — le même pictogramme que
/// les grandes applications de musique utilisent dans leurs listes.
/// Utilisé par [TeachingTile], [HomeCarouselCard] et [HomeListRow] pour
/// signaler visuellement qu'un contenu est en cours d'écoute.
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({super.key, required this.color});

  final Color color;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const _barCount = 3;
  static const _delays = [0, 160, 80]; // ms
  static const _size = 22.0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _barCount,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _animations = List.generate(
      _barCount,
      (i) => Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      ),
    );
    for (var i = 0; i < _barCount; i++) {
      Future.delayed(Duration(milliseconds: _delays[i]), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_barCount, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedBuilder(
              animation: _animations[i],
              builder: (_, __) => Container(
                width: 3,
                height: _size * _animations[i].value,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
