/// **Parcourir la Bible** (M1, #199) : testament → livre → chapitre → verset,
/// sur des grilles **neutres** (piège 9 : pas les pastels de la maquette).
///
/// Un seul widget, trois usages :
///
/// - [BibleBrowserMode.browse] — l'onglet Bible : un chapitre ouvre
///   directement le lecteur, sans grille de versets ;
/// - [BibleBrowserMode.select] — le mode sélection des notes : on touche des
///   versets (plage contiguë), [BibleBrowser.onSelection] remonte la
///   référence, la coquille porte le bouton « Insérer » ;
/// - [BibleBrowserMode.pickChapter] — la feuille de l'en-tête du lecteur :
///   un chapitre touché est rendu tel quel.
///
/// **Les grilles suivent la version ouverte** (C3, #240) : chapitres et
/// versets viennent de sa versification, et un chapitre qu'elle n'a pas — la
/// S21 n'a pas de Malachie 4 — n'est **pas proposé**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/segmented_tabs.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import '../home/home_view.dart';

enum BibleBrowserMode { browse, select, pickChapter }

class BibleBrowser extends ConsumerStatefulWidget {
  const BibleBrowser({
    super.key,
    this.mode = BibleBrowserMode.browse,
    this.initialBook,
    this.onOpen,
    this.onSelection,
  });

  final BibleBrowserMode mode;

  /// Ouvre directement la grille des chapitres de ce livre.
  final String? initialBook;

  /// [BibleBrowserMode.browse] : ouvrir le lecteur (verset facultatif).
  /// [BibleBrowserMode.pickChapter] : le chapitre choisi.
  final void Function(BibleLink ref)? onOpen;

  /// [BibleBrowserMode.select] : la référence courante — chapitre seul, ou
  /// plage de versets —, `null` tant qu'aucun chapitre n'est choisi.
  final ValueChanged<BibleLink?>? onSelection;

  static const Key searchFieldKey = Key('bible_book_search');
  static const Key testamentTabsKey = Key('bible_testament_tabs');
  static const Key backKey = Key('bible_browser_back');
  static Key bookKey(String osis) => Key('bible_book_$osis');
  static Key chapterKey(int chapter) => Key('bible_chapter_$chapter');
  static Key verseKey(int verse) => Key('bible_verse_cell_$verse');

  @override
  ConsumerState<BibleBrowser> createState() => _BibleBrowserState();
}

class _BibleBrowserState extends ConsumerState<BibleBrowser> {
  Testament _testament = Testament.old;
  String _query = '';
  late String? _book = widget.initialBook;
  int? _chapter;
  int? _from;
  int? _to;

  @override
  void initState() {
    super.initState();
    final b = _book == null ? null : bibleBook(_book!);
    if (b != null) _testament = b.testament;
  }

  void _openBook(String osis) => setState(() {
        _book = osis;
        _chapter = null;
      });

  void _openChapter(int chapter) {
    // Hors sélection, un chapitre ouvre **le texte** : la grille des versets
    // n'était qu'une étape de plus (28/10/2026). Elle reste pour le mode
    // sélection, dont le but est justement de choisir des versets.
    if (widget.mode != BibleBrowserMode.select) {
      widget.onOpen?.call(BibleLink(_book!, chapter));
      return;
    }
    setState(() {
      _chapter = chapter;
      _from = _to = null;
    });
    widget.onSelection?.call(BibleLink(_book!, chapter));
  }

  void _back() {
    setState(() {
      if (_chapter != null) {
        _chapter = null;
        _from = _to = null;
      } else {
        _book = null;
      }
    });
    widget.onSelection?.call(null);
  }

  void _tapVerse(int verse) {
    setState(() {
      final (from, to) = (_from, _to);
      if (from == null || to == null) {
        _from = _to = verse;
      } else if (verse == to + 1) {
        _to = verse;
      } else if (verse == from - 1) {
        _from = verse;
      } else if (from == to && verse == from) {
        _from = _to = null;
      } else if (verse == from) {
        _from = from + 1;
      } else if (verse == to) {
        _to = to - 1;
      } else {
        _from = _to = verse;
      }
    });
    widget.onSelection?.call(
      BibleLink(
        _book!,
        _chapter!,
        from: _from,
        to: _from == null || _to == _from ? null : _to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _book == null ? null : bibleBook(_book!);
    final versification = ref.watch(bibleVersificationProvider);
    return PopScope(
      // Le retour système remonte d'un niveau avant de quitter la page.
      canPop: book == null || widget.initialBook == _book && _chapter == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: book == null
          ? _books(context, versification)
          : _chapter == null
              ? _chapters(context, book, versification)
              : _verses(context, book, _chapter!, versification),
    );
  }

  Widget _books(BuildContext context, BibleVersification versification) {
    final l = context.l10n;
    final palette = context.palette;
    final needle = _fold(_query.trim());
    // Un livre absent de la version ne mène qu'à une grille vide : l'éwé 2014
    // n'a ni Esther ni Daniel (décision 3 du PRD, comblés en C5).
    final books = [
      for (final b in bibleCanon)
        if (versification.chapterCount(b.osis) > 0 &&
            (needle.isEmpty
                ? b.testament == _testament
                : _fold(b.name).contains(needle) ||
                    _fold(b.nameIn('en')).contains(needle) ||
                    _fold(b.nameIn('ee')).contains(needle) ||
                    b.abbreviations.any((a) => _fold(a).startsWith(needle))))
          b,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
          // Une carte blanche à l'ombre douce, sans bordure (maquette).
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.elevation1,
            ),
            child: TextField(
              key: BibleBrowser.searchFieldKey,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.bibleBookSearchHint,
                isDense: true,
                filled: true,
                fillColor: palette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (needle.isEmpty)
          Padding(
            padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
            child: SegmentedTabs(
              key: BibleBrowser.testamentTabsKey,
              tabs: [l.bibleOldTestament, l.bibleNewTestament],
              selected: _testament.index,
              onSelect: (i) => setState(() => _testament = Testament.values[i]),
              selectedColor: AppColors.primary,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: books.isEmpty
              ? Center(
                  child: Text(
                    l.bibleNoBookFound,
                    style: TextStyle(color: palette.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  itemCount: books.length,
                  // Le filet part sous le nom, pas sous la case (maquette).
                  separatorBuilder: (context, _) => Divider(
                    height: 1,
                    indent: 72,
                    color: palette.divider,
                  ),
                  itemBuilder: (context, i) {
                    final b = books[i];
                    final tiles = BibleHomeColors.of(context);
                    return ListTile(
                      key: BibleBrowser.bookKey(b.osis),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tiles.bookTile,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          b.abbreviations.first,
                          style: AppTypography.bodyStrong
                              .copyWith(color: tiles.bookTileInk),
                        ),
                      ),
                      title: Text(b.nameIn(l.localeName)),
                      subtitle: Text(
                        l.bibleChapterCount(versification.chapterCount(b.osis)),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openBook(b.osis),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            key: BibleBrowser.backKey,
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _back,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h5),
                Text(
                  subtitle,
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chapters(
    BuildContext context,
    BibleBook book,
    BibleVersification versification,
  ) {
    final state = ref.watch(bibleReadingStateProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, book.nameIn(context.l10n.localeName),
            context.l10n.bibleChooseChapter),
        Expanded(
          child: _Grid(
            numbers: versification.chaptersOf(book.osis),
            keyOf: BibleBrowser.chapterKey,
            caption: context.l10n.bibleChapterShort,
            tone: (c) => state != null && state.hasRead(book.osis, c)
                ? _Tone.read
                : _Tone.neutral,
            onTap: _openChapter,
          ),
        ),
      ],
    );
  }

  Widget _verses(
    BuildContext context,
    BibleBook book,
    int chapter,
    BibleVersification versification,
  ) {
    final l = context.l10n;
    final reference = BibleLink(book.osis, chapter).labelFr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, reference, l.bibleSelectHint),
        Expanded(
          child: _Grid(
            numbers: [
              for (var v = 1;
                  v <= versification.versesIn(book.osis, chapter);
                  v++)
                v,
            ],
            keyOf: BibleBrowser.verseKey,
            tone: (v) => _from != null && v >= _from! && v <= _to!
                ? _Tone.strong
                : _Tone.neutral,
            onTap: _tapVerse,
          ),
        ),
      ],
    );
  }
}

enum _Tone { neutral, read, strong }

/// La grille des numéros (maquette « chpt », 28/10/2026) : des **carrés
/// arrondis** en léger relief, cinq par ligne sur un téléphone. Un chapitre
/// lu ([_Tone.read]) porte une coche, sans autre teinte — le beige de la
/// maquette jaunissait la grille (retiré le 28/10/2026) ; [_Tone.strong] pour
/// les versets choisis.
///
/// Une **liste** de numéros, et non un compte : la versification d'une version
/// peut sauter un chapitre (C3, #240), et la grille ne doit pas le proposer.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.numbers,
    required this.keyOf,
    required this.tone,
    required this.onTap,
    this.caption,
  });

  final List<int> numbers;
  final Key Function(int n) keyOf;
  final _Tone Function(int n) tone;
  final ValueChanged<int> onTap;

  /// Le petit mot sous chaque numéro (« ch. »), sur toutes les cases.
  final String? caption;

  // Relevées sur la maquette ; la nuit garde les teintes de la palette. Les
  // cases, elles, sont blanches : le gris chaud de la maquette, posé sur le
  // fond bleuté de l'appli, tirait sur le jaune (retiré le 28/10/2026).
  static const _ink = Color(0xFF2B3849);
  static const _check = Color(0xFF8A8496);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(14));
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        96,
      ),
      // 72 : cinq cases d'environ 59 pt sur un téléphone, comme la maquette
      // (80 n'en laissait que quatre).
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 72,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      itemCount: numbers.length,
      itemBuilder: (context, i) {
        final n = numbers[i];
        final t = tone(n);
        final ink = dark ? palette.textPrimary : _ink;
        final (bg, fg) = switch (t) {
          _Tone.neutral || _Tone.read => (
              dark ? palette.surfaceAlt : palette.surface,
              ink
            ),
          _Tone.strong => (palette.primary, Colors.white),
        };
        final label = caption;
        return DecoratedBox(
          // Le relief : une ombre chaude dessous, un reflet clair dessus.
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: dark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-2, -2),
                    ),
                  ],
          ),
          child: Material(
            color: bg,
            borderRadius: radius,
            child: InkWell(
              key: keyOf(n),
              borderRadius: radius,
              onTap: () => onTap(n),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$n',
                          style: AppTypography.h3.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        if (label != null)
                          Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              color: t == _Tone.strong
                                  ? Colors.white70
                                  : palette.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (t == _Tone.read)
                    Positioned(
                      top: 6,
                      right: 8,
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: dark ? palette.textSecondary : _check,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Minuscules sans accents : « esaie » trouve « Ésaïe ».
String _fold(String s) {
  const from = 'àâäéèêëîïôöùûüçœ';
  const to = 'aaaeeeeiioouuuco';
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}
