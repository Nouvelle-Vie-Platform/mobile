/// **Les réactions qui montent** (#135) — les miennes tout de suite, celles de
/// l'audience à chaque agrégat d'une seconde.
///
/// Trois bornes, et chacune protège la fluidité d'un téléphone d'entrée de
/// gamme :
///
/// 1. **un lot est déjà plafonné** par le contrôleur (`kRadioReactionBurstCap`) :
///    trois cents cœurs dans une seconde en font monter une poignée ;
/// 2. **l'écran n'en montre jamais plus de [kRadioMaxParticles] à la fois** —
///    au-delà, les nouvelles sont **jetées**, pas mises en file : une réaction
///    affichée trois secondes en retard ne dit plus rien ;
/// 3. **une seule horloge** (`Ticker`) pour toutes les particules, qui s'arrête
///    dès que la dernière est sortie — aucune animation ne tourne à vide, et
///    aucune minuterie ne survit à la page.
///
/// **Animations réduites** (`MediaQuery.disableAnimations`, réglage du système) :
/// rien ne monte. Le bouton reste, l'envoi aussi ; seule la décoration part.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/radio/radio_live.dart';
import '../../l10n/l10n_extension.dart';
import '../../state/radio_live_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Le plafond de particules à l'écran, toutes réactions confondues.
const int kRadioMaxParticles = 24;

/// Le temps qu'une particule met à monter et s'effacer.
const Duration kRadioParticleLife = Duration(milliseconds: 2400);

/// L'écart entre deux particules d'un même lot : un lot de six ne doit pas
/// monter en bloc.
const Duration kRadioParticleStagger = Duration(milliseconds: 140);

/// La marge minimale entre une réaction en vol et le bord droit de l'écran.
const double _kEdgeMargin = 6;

class RadioReactionParticles extends ConsumerStatefulWidget {
  const RadioReactionParticles({super.key});

  @override
  ConsumerState<RadioReactionParticles> createState() =>
      _RadioReactionParticlesState();
}

class _Particle {
  _Particle(this.reaction, this.born, this.seed);
  final RadioReaction reaction;
  final Duration born;
  final int seed;
}

class _Pending {
  _Pending(this.reaction, this.at);
  final RadioReaction reaction;
  final Duration at;
}

class _RadioReactionParticlesState extends ConsumerState<RadioReactionParticles>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<RadioReactionBurst>? _bursts;
  final List<_Particle> _live = [];
  final List<_Pending> _queue = [];
  Duration _now = Duration.zero;
  int _seed = 0;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _bursts = ref.read(radioLiveProvider.notifier).bursts.listen(_onBurst);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) _clear();
  }

  void _onBurst(RadioReactionBurst burst) {
    if (!mounted || _reduced) return;
    if (!_ticker.isActive) {
      _now = Duration.zero;
      unawaited(_ticker.start());
    }
    for (var i = 0; i < burst.count; i++) {
      _queue.add(_Pending(burst.reaction, _now + kRadioParticleStagger * i));
    }
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    _queue.removeWhere((pending) {
      if (pending.at > _now) return false;
      if (_live.length < kRadioMaxParticles) {
        _live.add(_Particle(pending.reaction, _now, _seed++));
      }
      // Au-delà du plafond, elle est **jetée** : en retard, elle ne dit plus
      // rien.
      return true;
    });
    _live.removeWhere((p) => _now - p.born >= kRadioParticleLife);
    if (_live.isEmpty && _queue.isEmpty) _ticker.stop();
    setState(() {});
  }

  void _clear() {
    _live.clear();
    _queue.clear();
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    unawaited(_bursts?.cancel());
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_live.isEmpty) return const SizedBox.expand();
    final amen = context.l10n.radioReactionAmen;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final lifeMs = kRadioParticleLife.inMilliseconds;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final particle in _live)
                  _place(particle, box,
                      (_now - particle.born).inMilliseconds / lifeMs, amen),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Une trajectoire **déterministe** — tirée de l'ordre d'apparition, jamais
  /// du hasard : deux rendus du même instant sont identiques, ce qu'exige une
  /// image de référence.
  Widget _place(_Particle p, BoxConstraints box, double t, String amen) {
    final lane = box.maxWidth;
    final rise = box.maxHeight * 0.85;
    final phase = (p.seed * 2.399) % (2 * math.pi);
    final sway = 10 + (p.seed % 3) * 4.0;
    // Ancrée par la DROITE : une réaction large (« Amen ») déborde vers le fil,
    // jamais hors de l'écran.
    final right = math.max(
      _kEdgeMargin,
      lane / 2 - 18 - math.sin(t * 2 * math.pi + phase) * sway,
    );
    final y = t * rise;
    final opacity = t < 0.1
        ? t / 0.1
        : t > 0.6
            ? math.max(0.0, 1 - (t - 0.6) / 0.4)
            : 1.0;
    final scale = 0.8 + 0.4 * math.min(1.0, t * 3);
    return Positioned(
      right: right,
      bottom: y,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: _ReactionGlyph(reaction: p.reaction, amen: amen),
        ),
      ),
    );
  }
}

/// Le rendu d'une réaction : l'emoji, ou le mot « Amen » sur une pastille.
class _ReactionGlyph extends StatelessWidget {
  const _ReactionGlyph({required this.reaction, required this.amen});

  final RadioReaction reaction;
  final String amen;

  @override
  Widget build(BuildContext context) {
    final emoji = reaction.emoji;
    if (emoji != null) {
      return Text(emoji, style: const TextStyle(fontSize: 28, height: 1.2));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          amen,
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
