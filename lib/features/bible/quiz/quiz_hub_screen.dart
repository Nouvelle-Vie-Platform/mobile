/// **Le choix du joueur** — l'écran sur lequel on arrive en touchant « Quiz ».
///
/// D'après l'infographie fournie par l'utilisateur (arc plein, arc pointillé,
/// trois nœuds reliés à trois pastilles numérotées), aux couleurs de l'appli
/// et sur l'image d'en-tête de l'accueil (jour ou nuit). « QUIZ » et sa
/// description à gauche de l'arc dès 700 pt de large (tablette, paysage) ;
/// au-dessus sur un téléphone en portrait, où l'arc laisse toute la largeur
/// aux pastilles. Toucher une tranche la mémorise (elle sert aussi au « Quiz
/// de la semaine » de l'accueil) et ouvre ses quiz ; la dernière choisie est
/// mise en avant.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_typography.dart';
import '../home/home_view.dart';
import '../shell/bible_route.dart';
import 'quiz.dart';
import 'quiz_providers.dart';
import 'quiz_path_screen.dart';

class QuizHubScreen extends ConsumerWidget {
  const QuizHubScreen({super.key});

  static Key bandKey(QuizAgeBand b) => Key('quiz_hub_${b.name}');
  static const backKey = Key('quiz_hub_back');

  /// Largeur à partir de laquelle « QUIZ » passe à gauche de l'arc.
  static const double sideBySideFrom = 700;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = BibleHomeColors.of(context);
    final l = context.l10n;
    final current = ref.watch(quizAgeProfileProvider).value;

    Future<void> pick(QuizAgeBand b) async {
      await ref.read(quizStoreProvider).setAgeBand(b);
      await ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentState
          ?.push(bibleRoute<void>(QuizPathScreen(band: b)));
    }

    final bands = [
      for (final b in QuizAgeBand.values)
        _Band(
          band: b,
          number: '0${b.index + 1}',
          title: _title(l, b),
          line: '${_ages(l, b)} · ${_hint(l, b)}',
          icon: switch (b) {
            QuizAgeBand.kids => Icons.child_care_outlined,
            QuizAgeBand.teens => Icons.emoji_people_outlined,
            QuizAgeBand.adults => Icons.menu_book_outlined,
          },
          selected: b == current,
          onTap: () => pick(b),
        ),
    ];

    final title = _Title(
      title: l.bibleQuizTitle.toUpperCase(),
      intro: l.bibleQuizHubIntro,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.heroShade,
        // L'arc est peint autour d'un centre **hors de l'écran**, à gauche :
        // rien ne le coupait (le défilement ne coupe que s'il déborde), et au
        // retour, pendant que la page glisse vers la droite, son cercle
        // flottait sur l'écran d'arrivée. La page se coupe à ses bords.
        body: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // L'image de fond de l'accueil, assombrie pour la lecture.
              Image.asset(colors.heroImage, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.heroShade.withValues(alpha: 0.35),
                      colors.heroShade.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= sideBySideFrom;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: wide
                              ? _WideLayout(title: title, bands: bands)
                              : _PhoneLayout(title: title, bands: bands),
                        ),
                        Positioned(
                          left: 4,
                          top: 4,
                          child: IconButton(
                            key: backKey,
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _title(AppLocalizations l, QuizAgeBand b) => switch (b) {
        QuizAgeBand.kids => l.bibleQuizBandKids,
        QuizAgeBand.teens => l.bibleQuizBandTeens,
        QuizAgeBand.adults => l.bibleQuizBandAdults,
      };

  static String _ages(AppLocalizations l, QuizAgeBand b) => switch (b) {
        QuizAgeBand.kids => l.bibleQuizBandKidsAges,
        QuizAgeBand.teens => l.bibleQuizBandTeensAges,
        QuizAgeBand.adults => l.bibleQuizBandAdultsAges,
      };

  static String _hint(AppLocalizations l, QuizAgeBand b) => switch (b) {
        QuizAgeBand.kids => l.bibleQuizBandKidsHint,
        QuizAgeBand.teens => l.bibleQuizBandTeensHint,
        QuizAgeBand.adults => l.bibleQuizBandAdultsHint,
      };
}

final class _Band {
  const _Band({
    required this.band,
    required this.number,
    required this.title,
    required this.line,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final QuizAgeBand band;
  final String number;
  final String title;
  final String line;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.intro});

  final String title;
  final String intro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w500,
            fontSize: 46,
            height: 1.05,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          intro,
          style: AppTypography.body.copyWith(
            fontSize: 16,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Les deux dispositions
// ─────────────────────────────────────────────────────────────────────────────

const double _pillHeight = 92;
const double _pillGap = 30;
const double _numberSize = 56;

/// Téléphone en portrait : le titre en haut à gauche, l'arc et les pastilles
/// dessous, sur toute la largeur.
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({required this.title, required this.bands});

  final Widget title;
  final List<_Band> bands;

  @override
  Widget build(BuildContext context) {
    // Le titre en haut ; l'arc et les pastilles centrés dans la place qui
    // reste (et l'écran défile si elle manque, en paysage serré).
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 64, 16, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 96),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 28),
                const Spacer(),
                _ArcSystem(bands: bands, arcRight: 58),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tablette, paysage : le titre à gauche, à l'intérieur de l'arc, comme
/// l'infographie.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.title, required this.bands});

  final Widget title;
  final List<_Band> bands;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: LayoutBuilder(
            builder: (context, box) {
              final arcRight = (box.maxWidth * 0.42).clamp(260.0, 400.0);
              return Stack(
                children: [
                  _ArcSystem(bands: bands, arcRight: arcRight),
                  Positioned(
                    left: 0,
                    width: arcRight - 70,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: title,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// L'arc et les pastilles
// ─────────────────────────────────────────────────────────────────────────────

/// L'arc plein, l'arc pointillé et ses trois nœuds, et les trois pastilles,
/// dont la gauche suit la courbe (la deuxième plus à droite, comme
/// l'infographie). [arcRight] : l'abscisse du point le plus à droite de l'arc
/// pointillé.
class _ArcSystem extends StatelessWidget {
  const _ArcSystem({required this.bands, required this.arcRight});

  final List<_Band> bands;
  final double arcRight;

  static const double height = 3 * _pillHeight + 2 * _pillGap + 40;

  @override
  Widget build(BuildContext context) {
    final colors = BibleHomeColors.of(context);
    // Les centres des pastilles, et le nœud de l'arc qui porte chacune.
    const cy = height / 2;
    final radius = height * 0.55;
    final cx = arcRight - radius;
    final rows = <({Offset node, Offset number})>[];
    for (var i = 0; i < bands.length; i++) {
      final y = cy + (i - 1) * (_pillHeight + _pillGap);
      // Les nœuds haut et bas sont décalés vers le centre : le trait qui les
      // relie au numéro monte (ou descend) en biais, comme l'infographie.
      final nodeY = y + (i - 1) * -34;
      final sin = ((nodeY - cy) / radius).clamp(-1.0, 1.0);
      final nodeX = cx + radius * math.cos(math.asin(sin));
      final node = Offset(nodeX, nodeY);
      final number = Offset(nodeX + (i == 1 ? 46 : 38), y);
      rows.add((node: node, number: number));
    }

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ArcPainter(
                center: Offset(cx, cy),
                radius: radius,
                rows: rows,
                solidTop: colors.button,
                solidBottom: Color.lerp(colors.button, Colors.white, 0.35)!,
              ),
            ),
          ),
          for (final (i, b) in bands.indexed)
            Positioned(
              left: rows[i].number.dx - _numberSize / 2,
              right: 0,
              top: rows[i].number.dy - _pillHeight / 2,
              height: _pillHeight,
              child: _Pill(band: b),
            ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.center,
    required this.radius,
    required this.rows,
    required this.solidTop,
    required this.solidBottom,
  });

  final Offset center;
  final double radius;
  final List<({Offset node, Offset number})> rows;
  final Color solidTop;
  final Color solidBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // L'arc plein, intérieur : moitié haute foncée, moitié basse claire.
    final inner = Rect.fromCircle(center: center, radius: radius - 44);
    final solid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        inner, -math.pi / 2.6, math.pi / 2.6, false, solid..color = solidTop);
    canvas.drawArc(inner, 0, math.pi / 2.6, false, solid..color = solidBottom);

    // L'arc pointillé, extérieur.
    const sweep = math.pi * 0.62;
    const dash = 0.045;
    const gap = 0.03;
    for (var a = -sweep; a < sweep; a += dash + gap) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a,
        math.min(dash, sweep - a),
        false,
        line,
      );
    }
    // Les deux bouts : un point plein.
    final dot = Paint()..color = Colors.white;
    for (final a in const [-sweep, sweep]) {
      canvas.drawCircle(
        center + Offset(radius * math.cos(a), radius * math.sin(a)),
        5,
        dot,
      );
    }

    // Les nœuds et leur trait vers le numéro.
    for (final r in rows) {
      canvas.drawLine(r.node, r.number, line);
      canvas.drawCircle(r.node, 9, Paint()..color = Colors.white);
      canvas.drawCircle(r.node, 5, Paint()..color = solidTop);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.solidTop != solidTop ||
      old.rows.length != rows.length;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.band});

  final _Band band;

  @override
  Widget build(BuildContext context) {
    final colors = BibleHomeColors.of(context);
    final fill = band.selected
        ? Color.lerp(colors.button, Colors.white, 0.18)!
        : colors.button;
    const radius = BorderRadius.all(Radius.circular(_pillHeight / 2));
    return Semantics(
      button: true,
      selected: band.selected,
      label: '${band.title}, ${band.line}',
      child: Stack(
        children: [
          Positioned.fill(
            left: _numberSize / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: band.selected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: fill,
                borderRadius: radius,
                child: InkWell(
                  key: QuizHubScreen.bandKey(band.band),
                  borderRadius: radius,
                  onTap: band.onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _numberSize / 2 + 14,
                      10,
                      14,
                      10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                band.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                band.line,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                  fontSize: 14,
                                  height: 1.3,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(band.icon, size: 30, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Le numéro, à cheval sur le bout gauche de la pastille.
          Positioned(
            left: 0,
            top: (_pillHeight - _numberSize) / 2,
            width: _numberSize,
            height: _numberSize,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1F2B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: Text(
                    band.number,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.w500,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
