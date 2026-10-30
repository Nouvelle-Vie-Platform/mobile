/// **La lecture audio d'un chapitre** (M4, mobile#202, décision 10) : verset
/// par verset, le verset en cours surligné dans le lecteur (par
/// `chapterDecorators`), lecture/pause, chapitre précédent/suivant, vitesse.
///
/// La voix du **système** (`stts` : AVSpeechSynthesizer, TextToSpeech)
/// derrière [BibleSpeech]. La barre de lecture se pose par-dessus le lecteur
/// (sous son en-tête) et s'efface dès qu'on le quitte.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stts/stts.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import '../shell/bible_slots.dart';
import 'bible_prefs.dart';

/// **Une voix** : dit un texte et ne rend la main qu'à la fin — ou à
/// [stop].
abstract class BibleSpeech {
  Future<void> speak(String text, double rate);
  Future<void> stop();
  Future<void> dispose() async {}
}

/// La synthèse **du système**, en français.
class SystemBibleSpeech extends BibleSpeech {
  SystemBibleSpeech({Tts? tts}) : _tts = tts ?? Tts();

  final Tts _tts;
  bool _ready = false;
  Completer<void>? _current;

  @override
  Future<void> speak(String text, double rate) async {
    final done = _current = Completer<void>();
    var started = false;
    final sub = _tts.onStateChanged.listen((s) {
      if (s == TtsState.start) started = true;
      if (s == TtsState.stop && started && !done.isCompleted) done.complete();
    });
    try {
      if (!_ready) {
        await _tts.setLanguage('fr-FR');
        _ready = true;
      }
      await _tts.setRate(rate);
      await _tts.start(text);
      await done.future;
    } on Object {
      // Moteur absent ou refus : on passe, sans rester suspendu.
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> stop() async {
    final c = _current;
    if (c != null && !c.isCompleted) c.complete();
    try {
      await _tts.stop();
    } on Object {
      // Rien à arrêter.
    }
  }

  @override
  Future<void> dispose() => stop();
}

/// La voix de lecture : celle du système.
final bibleSpeechProvider = Provider<BibleSpeech>((ref) {
  final speech = SystemBibleSpeech();
  ref.onDispose(speech.dispose);
  return speech;
});

/// Ce que la barre et le lecteur lisent.
@immutable
final class BibleAudioState {
  const BibleAudioState({
    required this.version,
    required this.book,
    required this.chapter,
    this.verse,
    this.playing = false,
  });

  final String version;
  final String book;
  final int chapter;

  /// Le verset en cours (`null` : rien, ou fin du chapitre).
  final int? verse;
  final bool playing;

  BibleAudioState copyWith(
          {int? verse, bool? playing, bool clearVerse = false}) =>
      BibleAudioState(
        version: version,
        book: book,
        chapter: chapter,
        verse: clearVerse ? null : (verse ?? this.verse),
        playing: playing ?? this.playing,
      );
}

final bibleAudioProvider =
    NotifierProvider<BibleAudioController, BibleAudioState?>(
  BibleAudioController.new,
);

class BibleAudioController extends Notifier<BibleAudioState?> {
  /// Chaque lecture lancée porte son numéro : une boucle dépassée s'arrête.
  int _run = 0;

  @override
  BibleAudioState? build() {
    ref.onDispose(() => _run++);
    return null;
  }

  BibleSpeech get _speech => ref.read(bibleSpeechProvider);

  /// Lit [book] [chapter] de [version] à partir de [verse].
  Future<void> playFrom(
    String version,
    String book,
    int chapter, {
    int verse = 1,
  }) async {
    final run = ++_run;
    await _speech.stop();
    state = BibleAudioState(
      version: version,
      book: book,
      chapter: chapter,
      verse: verse,
      playing: true,
    );
    final source = ref.read(bibleCatalogProvider).sourceFor(version);
    final verses = source == null
        ? const <BibleVerse>[]
        : await source.chapter(book, chapter);
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      if (v.number < verse) continue;
      if (run != _run || !ref.mounted) return;
      state = state?.copyWith(verse: v.number);
      await _speech.speak(v.text, ref.read(biblePrefsProvider).speechRate);
    }
    if (run == _run && ref.mounted) {
      state = state?.copyWith(playing: false, clearVerse: true);
    }
  }

  /// Pause : le verset en cours reprendra depuis son début.
  Future<void> pause() async {
    _run++;
    state = state?.copyWith(playing: false);
    await _speech.stop();
  }

  Future<void> resume() async {
    final s = state;
    if (s == null) return;
    await playFrom(s.version, s.book, s.chapter, verse: s.verse ?? 1);
  }

  /// Chapitre suivant (`+1`) ou précédent (`-1`), d'un livre à l'autre.
  Future<void> skipChapter(int delta) async {
    final s = state;
    if (s == null) return;
    final i = bibleChapterIndex(s.book, s.chapter) + delta;
    if (i < 0 || i >= bibleChapters.length) return;
    final c = bibleChapters[i];
    await playFrom(s.version, c.book, c.chapter);
  }

  /// La vitesse suivante ; elle vaut dès le verset suivant.
  Future<void> cycleRate() async {
    final rates = kBibleSpeechRates;
    final current = ref.read(biblePrefsProvider).speechRate;
    final next = rates[(rates.indexOf(current) + 1) % rates.length];
    await ref
        .read(biblePrefsProvider.notifier)
        .update((p) => p.copyWith(speechRate: next));
  }

  Future<void> stop() async {
    _run++;
    state = null;
    await _speech.stop();
  }
}

/// Le surlignage du verset en cours, posé dans `chapterDecorators`.
Map<int, BibleVerseDecoration> bibleAudioDecorator(
  WidgetRef ref,
  String book,
  int chapter,
) {
  final verse = ref.watch(
    bibleAudioProvider.select(
      (s) =>
          s != null && s.book == book && s.chapter == chapter ? s.verse : null,
    ),
  );
  if (verse == null) return const {};
  return {
    verse: BibleVerseDecoration(
      background: ref.context.palette.primary.withValues(alpha: 0.16),
    ),
  };
}

/// L'action « Écouter à partir d'ici ».
void listenFromHere(
  BuildContext context,
  WidgetRef ref,
  BibleLink selection,
  String versionCode,
) {
  unawaited(
    ref.read(bibleAudioProvider.notifier).playFrom(
          versionCode,
          selection.book,
          selection.chapter,
          verse: selection.from ?? 1,
        ),
  );
  BibleAudioBar.show(context);
}

/// **La barre de lecture**, posée dans l'`Overlay` racine sous l'en-tête du
/// lecteur. Elle se retire quand la lecture s'arrête ou qu'on quitte le
/// lecteur.
class BibleAudioBar extends ConsumerStatefulWidget {
  const BibleAudioBar({super.key, required this.onGone});

  final VoidCallback onGone;

  static const Key barKey = Key('bible_audio_bar');
  static const Key playKey = Key('bible_audio_play');
  static const Key nextKey = Key('bible_audio_next');
  static const Key previousKey = Key('bible_audio_previous');
  static const Key rateKey = Key('bible_audio_rate');
  static const Key closeKey = Key('bible_audio_close');

  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => BibleAudioBar(
        onGone: () {
          if (_entry == entry) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  ConsumerState<BibleAudioBar> createState() => _BibleAudioBarState();
}

class _BibleAudioBarState extends ConsumerState<BibleAudioBar> {
  late final _router = ref.read(routerProvider);

  @override
  void initState() {
    super.initState();
    _router.routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (!path.startsWith('/bible/read')) {
      unawaited(ref.read(bibleAudioProvider.notifier).stop());
    }
  }

  void _gone() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGone());

  @override
  Widget build(BuildContext context) {
    ref.listen(bibleAudioProvider, (_, next) {
      if (next == null) _gone();
    });
    final s = ref.watch(bibleAudioProvider);
    if (s == null) return const SizedBox.shrink();
    final l = context.l10n;
    final palette = context.palette;
    final controller = ref.read(bibleAudioProvider.notifier);
    final rate = ref.watch(biblePrefsProvider.select((p) => p.speechRate));
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final reference = BibleLink(s.book, s.chapter, from: s.verse)
        .labelIn(ref.watch(bibleBookLanguageProvider));
    return Positioned(
      top: top + AppSpacing.sm,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Material(
        key: BibleAudioBar.barKey,
        color: palette.surface,
        elevation: 6,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  reference,
                  style: AppTypography.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: BibleAudioBar.previousKey,
                tooltip: l.bibleM4AudioPrevious,
                icon: const Icon(Icons.skip_previous),
                onPressed: () => controller.skipChapter(-1),
              ),
              IconButton(
                key: BibleAudioBar.playKey,
                tooltip: s.playing ? l.bibleM4AudioPause : l.bibleM4AudioPlay,
                icon: Icon(s.playing ? Icons.pause : Icons.play_arrow),
                onPressed: s.playing ? controller.pause : controller.resume,
              ),
              IconButton(
                key: BibleAudioBar.nextKey,
                tooltip: l.bibleM4AudioNext,
                icon: const Icon(Icons.skip_next),
                onPressed: () => controller.skipChapter(1),
              ),
              TextButton(
                key: BibleAudioBar.rateKey,
                onPressed: controller.cycleRate,
                child: Text('$rate×'),
              ),
              IconButton(
                key: BibleAudioBar.closeKey,
                tooltip: l.bibleM4AudioClose,
                icon: const Icon(Icons.close),
                onPressed: controller.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
