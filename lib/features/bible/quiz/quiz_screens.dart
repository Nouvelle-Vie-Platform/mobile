/// **Les écrans des quiz** (M6, mobile#204) : la liste par tranche d'âge et
/// la partie, hors ligne.
///
/// Poussés sur le `Navigator` racine du routeur (aucune route nommée : le
/// routeur n'appartient pas à cette tranche). Le lien d'une explication ouvre
/// le lecteur par `BibleReaderScreen.push`, comme partout dans le module.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../reader/bible_reader_screen.dart';
import '../shell/bible_route.dart';
import 'quiz.dart';
import 'quiz_hub_screen.dart';
import 'quiz_providers.dart';

/// Pousse [screen] sur le `Navigator` du routeur, jamais par le contexte.
Future<void> _push(WidgetRef ref, Widget screen) async {
  await ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentState
      ?.push(bibleRoute<void>(screen));
}

String _bandLabel(AppLocalizations l, QuizAgeBand b) => switch (b) {
      QuizAgeBand.kids => l.bibleQuizBandKids,
      QuizAgeBand.teens => l.bibleQuizBandTeens,
      QuizAgeBand.adults => l.bibleQuizBandAdults,
    };

String _bandAges(AppLocalizations l, QuizAgeBand b) => switch (b) {
      QuizAgeBand.kids => l.bibleQuizBandKidsAges,
      QuizAgeBand.teens => l.bibleQuizBandTeensAges,
      QuizAgeBand.adults => l.bibleQuizBandAdultsAges,
    };

String _difficulty(AppLocalizations l, int d) => switch (d) {
      1 => l.bibleQuizDifficulty1,
      2 => l.bibleQuizDifficulty2,
      _ => l.bibleQuizDifficulty3,
    };

PreferredSizeWidget _appBar(String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
      ),
      title: Text(
        title,
        style: AppTypography.h5.copyWith(color: Colors.white),
      ),
      actions: actions,
    );

class _Stars extends StatelessWidget {
  const _Stars(this.count, {this.size = 18});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              i < count ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: AppColors.accent,
            ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// La liste
// ─────────────────────────────────────────────────────────────────────────────

class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key});

  /// Toucher « Quiz » ouvre toujours le choix du joueur ; la tranche choisie
  /// ouvre ensuite cette liste.
  static Future<void> open(WidgetRef ref) => _push(ref, const QuizHubScreen());

  /// Lance [quiz] dans le profil choisi (carte « Quiz de la semaine », M7).
  static Future<void> play(WidgetRef ref, Quiz quiz) => _push(
        ref,
        QuizPlayScreen(
          quiz: quiz,
          kids: ref.read(quizAgeProfileProvider).value == QuizAgeBand.kids,
        ),
      );

  static Key bandKey(QuizAgeBand b) => Key('quiz_band_${b.name}');
  static Key profileKey(QuizAgeBand b) => Key('quiz_profile_${b.name}');
  static Key quizKey(int id) => Key('quiz_item_$id');

  /// Un quiz publié depuis moins de ce délai, jamais joué, est « nouveau ».
  static const newFor = Duration(days: 14);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(quizAgeProfileProvider);
    final band = profile.value;
    return Scaffold(
      appBar: _appBar(l.bibleQuizTitle),
      body: switch (profile) {
        AsyncData(value: null) => _ProfilePicker(
            onPick: (b) => ref.read(quizStoreProvider).setAgeBand(b),
          ),
        AsyncData() => _QuizList(band: band!),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Le choix du profil, la première fois.
class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({required this.onPick});

  final void Function(QuizAgeBand) onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(l.bibleQuizWhoPlays, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l.bibleQuizWhoPlaysHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        for (final b in QuizAgeBand.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: OutlinedButton(
              key: QuizListScreen.profileKey(b),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
              ),
              onPressed: () => onPick(b),
              child: Column(
                children: [
                  Text(_bandLabel(l, b), style: theme.textTheme.titleMedium),
                  Text(_bandAges(l, b), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuizList extends ConsumerWidget {
  const _QuizList({required this.band});

  final QuizAgeBand band;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final quizzes = [
      for (final q in ref.watch(quizzesProvider).value ?? const <Quiz>[])
        if (q.ageBand == band) q,
    ];
    final best = ref.watch(quizBestScoresProvider);
    final now = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final b in QuizAgeBand.values)
                ChoiceChip(
                  key: QuizListScreen.bandKey(b),
                  label: Text(_bandLabel(l, b)),
                  selected: b == band,
                  onSelected: (_) => ref.read(quizStoreProvider).setAgeBand(b),
                ),
            ],
          ),
        ),
        Expanded(
          child: quizzes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(l.bibleQuizEmpty, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  children: [
                    for (final q in quizzes)
                      _QuizTile(
                        quiz: q,
                        best: best[q.id],
                        isNew: best[q.id] == null &&
                            q.publishedAt != null &&
                            now.difference(q.publishedAt!) <
                                QuizListScreen.newFor,
                        onTap: () => QuizListScreen.play(ref, q),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QuizTile extends StatelessWidget {
  const _QuizTile({
    required this.quiz,
    required this.best,
    required this.isNew,
    required this.onTap,
  });

  final Quiz quiz;
  final QuizScore? best;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = best;
    final image = quiz.imageUrl;
    const fallback = Icon(Icons.quiz_outlined, size: 32);
    return ListTile(
      key: QuizListScreen.quizKey(quiz.id),
      leading: SizedBox.square(
        dimension: 48,
        child: image == null
            ? fallback
            : ClipRRect(
                borderRadius: AppRadius.card,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              ),
      ),
      title: Text(quiz.title),
      subtitle: Text(
        '${_difficulty(l, quiz.difficulty)} · '
        '${l.bibleQuizQuestionCount(quiz.questions.length)}',
      ),
      trailing: b != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l.bibleQuizBest(b.score, b.total)),
                _Stars(quizStars(b.score, b.total), size: 14),
              ],
            )
          : isNew
              ? Chip(
                  label: Text(l.bibleQuizNew),
                  backgroundColor: AppColors.chipNewBg,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                )
              : null,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// La partie
// ─────────────────────────────────────────────────────────────────────────────

class QuizPlayScreen extends ConsumerStatefulWidget {
  const QuizPlayScreen({super.key, required this.quiz, this.kids = false});

  final Quiz quiz;

  /// Profil enfant : texte agrandi, boutons larges, questions lues à voix
  /// haute, chronomètre sans pénalité.
  final bool kids;

  /// Le chronomètre doux d'une question.
  static const questionTime = Duration(seconds: 30);

  static Key choiceKey(int i) => Key('quiz_choice_$i');
  static const nextKey = Key('quiz_next');
  static const listenKey = Key('quiz_listen');
  static const referenceKey = Key('quiz_reference');
  static const timerKey = Key('quiz_timer');
  static const scoreKey = Key('quiz_score');
  static const replayKey = Key('quiz_replay');
  static const doneKey = Key('quiz_done');

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  late QuizGame _game;
  final Stopwatch _clock = Stopwatch();
  Timer? _tick;
  int _left = 0;
  bool _finished = false;

  /// Lu une fois : `dispose` ne peut plus lire `ref`.
  late final QuizSpeaker _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(quizSpeakerProvider);
    _start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_speaker.stop());
    super.dispose();
  }

  void _start() {
    _game = QuizGame(widget.quiz);
    _finished = false;
    _clock
      ..reset()
      ..start();
    _askQuestion();
  }

  void _askQuestion() {
    _left = QuizPlayScreen.questionTime.inSeconds;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left > 0) return;
      _tick?.cancel();
      // Pas de pénalité pour un enfant : le temps s'arrête, la question reste.
      if (!widget.kids) _answer(-1);
    });
    if (widget.kids) _speak();
  }

  void _speak() {
    final q = _game.question;
    unawaited(_speaker.speak([q.prompt, ...q.choices].join('. ')));
  }

  void _answer(int choice) {
    if (_game.answered) return;
    _tick?.cancel();
    setState(() => _game.answer(choice));
  }

  void _next() {
    if (_game.next()) {
      setState(_askQuestion);
      return;
    }
    _clock.stop();
    setState(() => _finished = true);
    unawaited(
      ref.read(quizStoreProvider).record(
            quizId: widget.quiz.id,
            score: _game.score,
            total: _game.total,
            durationSeconds: _clock.elapsed.inSeconds,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _finished ? _result(context) : _question(context);
    return Scaffold(
      appBar: _appBar(widget.quiz.title),
      body: SafeArea(
        child: widget.kids
            ? MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.3,
                maxScaleFactor: 3,
                child: body,
              )
            : body,
      ),
    );
  }

  Widget _question(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final q = _game.question;
    final picked = _game.picked;
    final total = QuizPlayScreen.questionTime.inSeconds;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.bibleQuizProgress(_game.index + 1, _game.total),
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (widget.kids)
              IconButton(
                key: QuizPlayScreen.listenKey,
                tooltip: l.bibleQuizListen,
                icon: const Icon(Icons.volume_up_rounded),
                onPressed: _speak,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          key: QuizPlayScreen.timerKey,
          value: _game.answered ? 0 : _left / total,
          minHeight: 4,
          borderRadius: AppRadius.card,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(q.prompt, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xl),
        for (final (i, choice) in q.choices.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ChoiceButton(
              key: QuizPlayScreen.choiceKey(i),
              label: choice,
              large: widget.kids,
              state: picked == null
                  ? _ChoiceState.open
                  : i == q.answer
                      ? _ChoiceState.right
                      : i == picked
                          ? _ChoiceState.wrong
                          : _ChoiceState.idle,
              onPressed: picked == null ? () => _answer(i) : null,
            ),
          ),
        if (picked != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Feedback(question: q, picked: picked),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            key: QuizPlayScreen.nextKey,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(widget.kids ? 64 : 48),
            ),
            onPressed: _next,
            child: Text(_game.isLast ? l.bibleQuizSeeScore : l.bibleQuizNext),
          ),
        ],
      ],
    );
  }

  Widget _result(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.bibleQuizFinished, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.bibleQuizScore(_game.score, _game.total),
              key: QuizPlayScreen.scoreKey,
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _Stars(quizStars(_game.score, _game.total), size: 40),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              key: QuizPlayScreen.replayKey,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(widget.kids ? 64 : 48),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(l.bibleQuizReplay),
              onPressed: () => setState(_start),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: QuizPlayScreen.doneKey,
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(widget.kids ? 64 : 48),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l.bibleQuizDone),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChoiceState { open, idle, right, wrong }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.large,
    required this.state,
    required this.onPressed,
  });

  final String label;
  final bool large;
  final _ChoiceState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _ChoiceState.right => (AppColors.successBg, AppColors.success),
      _ChoiceState.wrong => (AppColors.dangerBg, AppColors.danger),
      _ => (null, null),
    };
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(large ? 72 : 52),
        backgroundColor: bg,
        disabledBackgroundColor: bg,
        foregroundColor: fg,
        disabledForegroundColor: fg,
        side: fg == null ? null : BorderSide(color: fg, width: 2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// Le retour immédiat : juste ou non, la bonne réponse, l'explication et sa
/// référence (toucher → lecteur au verset).
class _Feedback extends ConsumerWidget {
  const _Feedback({required this.question, required this.picked});

  final QuizQuestion question;
  final int picked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final right = picked == question.answer;
    final ref0 = question.reference;
    final explanation = question.explanation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Une animation sobre à la bonne réponse : la coche se pose.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: right ? 0.4 : 1, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Icon(
                right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: right ? AppColors.success : AppColors.danger,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                right
                    ? l.bibleQuizRight
                    : picked < 0
                        ? l.bibleQuizTimeUp
                        : l.bibleQuizWrong,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (!right) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l.bibleQuizAnswerWas(question.choices[question.answer])),
        ],
        if (explanation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(explanation, style: theme.textTheme.bodyMedium),
        ],
        if (ref0 != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ActionChip(
            key: QuizPlayScreen.referenceKey,
            avatar: const Icon(Icons.menu_book_rounded, size: 18),
            label: Text(ref0.labelFr),
            onPressed: () =>
                BibleReaderScreen.push(ref.read(routerProvider), ref0),
          ),
        ],
      ],
    );
  }
}
