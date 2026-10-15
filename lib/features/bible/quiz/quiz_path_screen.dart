/// **Le parcours d'une tranche** — l'écran sur lequel on arrive après avoir
/// choisi Enfants, Jeunes ou Adultes.
///
/// D'après l'infographie fournie par l'utilisateur : une route blanche à
/// ligne pointillée qui serpente, un cercle par étape, et à côté le grand
/// numéro, le titre et la description. Chez nous la route **part d'en bas**
/// (étape 1) et monte ; le bleu nuit du fond est **translucide** sur l'image
/// de l'accueil (jour ou nuit). Le cercle dit l'état : coche (réussie),
/// « jouer » (en cours), cadenas (verrouillée). Règle de progression :
/// `quiz_path.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../home/home_view.dart';
import '../shell/bible_route.dart';
import 'quiz.dart';
import 'quiz_path.dart';
import 'quiz_providers.dart';
import 'quiz_screens.dart';

class QuizPathScreen extends ConsumerStatefulWidget {
  const QuizPathScreen({super.key, required this.band});

  final QuizAgeBand band;

  static Key stepKey(int number) => Key('quiz_step_$number');
  static const backKey = Key('quiz_path_back');

  @override
  ConsumerState<QuizPathScreen> createState() => _QuizPathScreenState();
}

// La géométrie de la route (points).
const double _pitch = 210;
const double _roadWidth = 30;
const double _circle = 84;
const double _top = 150;
const double _bottom = 120;
const double _maxWidth = 560;

class _QuizPathScreenState extends ConsumerState<QuizPathScreen> {
  final _scroll = ScrollController();
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// La route s'ouvre sur l'étape en cours (le défilement part d'en bas).
  void _placeOn(List<QuizStep> steps, double viewport) {
    if (_placed || steps.isEmpty) return;
    _placed = true;
    final i = steps.indexWhere((s) => s.state == QuizStepState.current);
    if (i <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _bottom + i * _pitch - viewport / 2 + _pitch / 2;
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  void _open(QuizStep step) {
    final l = context.l10n;
    if (!step.playable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l.bibleQuizStepLocked(step.number - 1))),
        );
      return;
    }
    ref.read(routerProvider).routerDelegate.navigatorKey.currentState?.push(
          bibleRoute<void>(
            QuizPlayScreen(
              quiz: step.quiz,
              kids: widget.band == QuizAgeBand.kids,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BibleHomeColors.of(context);
    final l = context.l10n;
    final quizzes = [
      for (final q in ref.watch(quizzesProvider).value ?? const <Quiz>[])
        if (q.ageBand == widget.band) q,
    ];
    final steps = quizPath(quizzes, ref.watch(quizBestScoresProvider));
    final done = steps.where((s) => s.state == QuizStepState.done).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.heroShade,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(colors.heroImage, fit: BoxFit.cover),
            // Le bleu nuit de l'infographie, translucide sur l'image.
            ColoredBox(color: colors.heroShade.withValues(alpha: 0.78)),
            LayoutBuilder(
              builder: (context, box) {
                _placeOn(steps, box.maxHeight);
                if (steps.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l.bibleQuizEmpty,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  );
                }
                final width = math.min(box.maxWidth, _maxWidth);
                final height = math.max(
                  box.maxHeight,
                  _top + _bottom + steps.length * _pitch,
                );
                return SingleChildScrollView(
                  controller: _scroll,
                  reverse: true,
                  child: Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _Road(
                        steps: steps,
                        onOpen: _open,
                        width: width,
                        height: height,
                      ),
                    ),
                  ),
                );
              },
            ),
            // L'en-tête, fixe : retour, tranche, avancement.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Opaque sous le titre, fondu en bas : la route qui
                    // défile ne passe jamais sous le texte.
                    stops: const [0, 0.72, 1],
                    colors: [
                      colors.heroShade,
                      colors.heroShade.withValues(alpha: 0.96),
                      colors.heroShade.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 20, 28),
                    child: Row(
                      children: [
                        IconButton(
                          key: QuizPathScreen.backKey,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _bandTitle(l, widget.band),
                                style: const TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                              if (steps.isNotEmpty)
                                Text(
                                  l.bibleQuizPathProgress(done, steps.length),
                                  style: AppTypography.body.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _bandTitle(AppLocalizations l, QuizAgeBand b) => switch (b) {
        QuizAgeBand.kids => l.bibleQuizBandKids,
        QuizAgeBand.teens => l.bibleQuizBandTeens,
        QuizAgeBand.adults => l.bibleQuizBandAdults,
      };
}

/// La route et ses étapes, l'étape 1 en bas.
class _Road extends StatelessWidget {
  const _Road({
    required this.steps,
    required this.onOpen,
    required this.width,
    required this.height,
  });

  final List<QuizStep> steps;
  final void Function(QuizStep) onOpen;
  final double width;
  final double height;

  /// Le centre du cercle de l'étape [i] (0 = la première, en bas) : en
  /// alternance à gauche et à droite.
  Offset _node(int i) {
    final x = width * (i.isEven ? 0.26 : 0.74);
    final y = height - _bottom - i * _pitch - _pitch / 2;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = [for (var i = 0; i < steps.length; i++) _node(i)];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RoadPainter(
              nodes: nodes,
              lineColor: BibleHomeColors.of(context).heroShade,
            ),
          ),
        ),
        for (final (i, step) in steps.indexed) ...[
          // Le texte, du côté opposé au cercle.
          Positioned(
            left: i.isEven ? nodes[i].dx + _circle / 2 + 18 : 20,
            right: i.isEven ? 16 : width - nodes[i].dx + _circle / 2 + 18,
            top: nodes[i].dy - 52,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onOpen(step),
              child: _StepText(step: step),
            ),
          ),
          Positioned(
            left: nodes[i].dx - _circle / 2,
            top: nodes[i].dy - _circle / 2,
            width: _circle,
            height: _circle,
            child: _StepCircle(step: step, onTap: () => onOpen(step)),
          ),
        ],
      ],
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.nodes, required this.lineColor});

  final List<Offset> nodes;
  final Color lineColor;

  Path _path(Size size) {
    final first = nodes.first;
    final path = Path()..moveTo(first.dx, size.height);
    path.lineTo(first.dx, first.dy);
    for (var i = 1; i < nodes.length; i++) {
      final a = nodes[i - 1], b = nodes[i];
      // Un virage en S : on monte, on traverse, on remonte.
      path.cubicTo(
          a.dx, a.dy - _pitch * 0.55, b.dx, b.dy + _pitch * 0.55, b.dx, b.dy);
    }
    final last = nodes.last;
    path.lineTo(last.dx, 0);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _roadWidth
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.round,
    );
    // La ligne pointillée au milieu de la route.
    final dash = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 22) {
        canvas.drawPath(metric.extractPath(d, d + 11), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.lineColor != lineColor || old.nodes.length != nodes.length;
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.step, required this.onTap});

  final QuizStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BibleHomeColors.of(context);
    final current = step.state == QuizStepState.current;
    final fill = switch (step.state) {
      QuizStepState.current => Color.lerp(colors.button, Colors.white, 0.2)!,
      QuizStepState.done => colors.button,
      QuizStepState.locked => colors.heroShade,
    };
    return Semantics(
      button: true,
      label: '${step.number}. ${step.quiz.title}',
      child: Material(
        key: QuizPathScreen.stepKey(step.number),
        color: fill,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 7),
        ),
        elevation: current ? 10 : 2,
        shadowColor: current ? AppColors.accent : Colors.black,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(
            switch (step.state) {
              QuizStepState.done => Icons.check_rounded,
              QuizStepState.current => Icons.play_arrow_rounded,
              QuizStepState.locked => Icons.lock_outline_rounded,
            },
            size: current ? 42 : 34,
            color: step.state == QuizStepState.locked
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText({required this.step});

  final QuizStep step;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dim = step.state == QuizStepState.locked;
    final ink = Colors.white.withValues(alpha: dim ? 0.55 : 1);
    final difficulty = switch (step.quiz.difficulty) {
      1 => l.bibleQuizDifficulty1,
      2 => l.bibleQuizDifficulty2,
      _ => l.bibleQuizDifficulty3,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${step.number}',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w500,
            fontSize: 56,
            height: 1,
            color: ink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.quiz.title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${l.bibleQuizQuestionCount(step.quiz.questions.length)} · '
                '$difficulty',
                style: AppTypography.body.copyWith(
                  fontSize: 14,
                  height: 1.35,
                  color: ink.withValues(alpha: dim ? 0.55 : 0.85),
                ),
              ),
              if (step.stars > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < 3; s++)
                      Icon(
                        s < step.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
