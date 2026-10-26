/// **Le lecteur** (M1, #199) : un chapitre par page, glissement gauche/droite
/// d'un chapitre à l'autre **et d'un livre à l'autre** (la version ouverte est
/// une seule suite de pages — 1 189 dans le canon figé).
/// La suite des pages est celle de **sa** versification (C3, #240) : changer
/// de version la refait, et replace le lecteur sur le même chapitre.
///
/// L'allure vient des références de #250 : barre du haut claire, **lettrine**
/// rouge brique ouvrant le chapitre (dont le titre quitte le corps — il
/// doublait la barre), numéros de versets **en ligne** à la taille du texte,
/// un paragraphe par verset, et des surlignages peints au marqueur
/// ([MarkerHighlight]) plutôt que des rectangles arrondis.
///
/// - L'en-tête « Jean 3 ▾ » rouvre le choix du livre et du chapitre.
/// - Le sélecteur de version change la version active.
/// - La position (version, livre, chapitre, verset) s'écrit dans
///   `local_bible_reading_state` à chaque page ; un chapitre défilé jusqu'au
///   bout est **marqué lu**.
/// - Ouvert sur des versets (`?v=16-18`, un lien `nv://bible/John/3/16-18`),
///   il défile jusqu'au premier et les **surligne un instant**.
/// - Les emplacements : l'habillage des versets (`chapterDecorators`) et le
///   menu d'action (`verseActions`) — s'il y a des actions, toucher un verset
///   le sélectionne, toucher un autre étend la plage contiguë (un appui long
///   puis glisser aussi), et le **menu flottant** de M2 paraît sous la
///   sélection, palette de surlignage comprise.
/// - Le **marque-page** du chapitre, dans l'en-tête (M2).
///
/// Route `/bible/read/:book/:chapter?v=…`, ouverte à tous.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import '../marks/bible_marks_store.dart';
import '../marks/bible_verse_menu.dart';
import '../personalize/personalize_routes.dart';
import '../personalize/reader_appearance.dart';
import '../shell/bible_browser.dart';
import '../shell/bible_slots.dart';
import 'marker_highlight.dart';

/// La durée du surlignage d'arrivée. Surchargée en test : sous `runAsync`
/// sa minuterie est réelle, et une machine chargée l'éteignait avant que le
/// test ne la voie.
final bibleFlashDurationProvider =
    Provider<Duration>((_) => const Duration(milliseconds: 2400));

class BibleReaderScreen extends ConsumerStatefulWidget {
  const BibleReaderScreen({
    super.key,
    required this.book,
    required this.chapter,
    this.from,
    this.to,
  });

  final String book;
  final int chapter;

  /// Les versets à montrer en arrivant (surlignés un instant).
  final int? from;
  final int? to;

  static const Key headerKey = Key('bible_reader_header');
  static const Key versionKey = Key('bible_reader_version');
  static const Key pagesKey = Key('bible_reader_pages');
  static const Key actionsKey = BibleVerseMenu.menuKey;
  static const Key bookmarkKey = Key('bible_reader_bookmark');
  static const Key downloadKey = Key('bible_reader_download');
  static const Key extendKey = Key('bible_reader_extend');
  static Key pageKey(String book, int chapter) =>
      Key('bible_reader_page_${book}_$chapter');
  static Key verseKey(int verse) => Key('bible_reader_verse_$verse');

  /// **Ouvre le lecteur sur [link]**, par la `GoRouter` (jamais un
  /// `BuildContext` : le geste peut venir d'une feuille ou d'un lien).
  static Future<void> push(GoRouter router, BibleLink link) {
    final from = link.from;
    return router.pushNamed(
      AppRoute.bibleReader,
      pathParameters: {'book': link.book, 'chapter': '${link.chapter}'},
      queryParameters: {
        if (from != null) 'v': link.to == null ? '$from' : '$from-${link.to}',
      },
    );
  }

  /// Lit `?v=16` ou `?v=16-18` ; tout le reste vaut « pas de verset ».
  static (int?, int?) parseVerses(String? v) {
    final m = RegExp(r'^(\d{1,3})(?:-(\d{1,3}))?$').firstMatch(v ?? '');
    if (m == null) return (null, null);
    final from = int.parse(m.group(1)!);
    final to = m.group(2) == null ? null : int.parse(m.group(2)!);
    return (from, to != null && to >= from ? to : null);
  }

  @override
  ConsumerState<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  /// Les pages de la version ouverte, et le rang de la page courante dedans.
  late List<({String book, int chapter})> _chapters =
      ref.read(bibleVersificationProvider).chapters;
  late int _index = () {
    final i = ref
        .read(bibleVersificationProvider)
        .chapterIndex(widget.book, widget.chapter);
    return i < 0 ? 0 : i;
  }();
  late final PageController _pages = PageController(initialPage: _index);

  /// La plage choisie pour le menu d'action, sur la page courante.
  int? _from;
  int? _to;

  /// Le menu flottant se pose **au-dessus** du premier verset choisi — les
  /// versets suivants restent à portée du doigt pour étendre la plage —, et
  /// **sous** le dernier quand la place manque en haut de l'écran.
  final _aboveLink = LayerLink();
  final _belowLink = LayerLink();
  final _firstKey = GlobalKey();
  final _stackKey = GlobalKey();
  bool _menuBelow = false;

  /// La hauteur à réserver au-dessus du premier verset pour le menu. La
  /// pilule de #250 tient sur une rangée : il lui en faut bien moins.
  static const double _menuRoom = 96;

  void _placeMenu() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final verse = _firstKey.currentContext?.findRenderObject() as RenderBox?;
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (!mounted || verse == null || stack == null) return;
      final top = verse.localToGlobal(Offset.zero, ancestor: stack).dy;
      final below = top < _menuRoom;
      if (below != _menuBelow) setState(() => _menuBelow = below);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _savePosition(verse: widget.from);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ({String book, int chapter}) get _current => _chapters.isEmpty
      ? (book: widget.book, chapter: widget.chapter)
      : _chapters[_index];

  /// La version a changé, et sa versification avec : refaire la suite des
  /// pages et **y retrouver le chapitre ouvert** — sans cela, le rang pointait
  /// une autre page (ou Malachie 4, que la S21 n'a pas).
  void _followVersification(BibleVersification next) {
    final c = _current;
    final i = next.chapterIndex(c.book, c.chapter);
    setState(() {
      _chapters = next.chapters;
      _index = i < 0 ? 0 : i;
      _from = _to = null;
    });
    if (_pages.hasClients) _pages.jumpToPage(_index);
  }

  void _savePosition({int? verse}) {
    final c = _current;
    unawaited(
      ref.read(bibleDaoProvider).savePosition(
            member: ref.read(bibleIsMemberProvider),
            versionCode: ref.read(activeBibleVersionProvider),
            book: c.book,
            chapter: c.chapter,
            verse: verse,
          ),
    );
  }

  void _markRead(String book, int chapter) {
    unawaited(
      ref.read(bibleDaoProvider).markChapterRead(
            member: ref.read(bibleIsMemberProvider),
            book: book,
            chapter: chapter,
          ),
    );
  }

  Future<void> _pickChapter() async {
    final c = _current;
    final versification = ref.read(bibleVersificationProvider);
    final picked = await showModalBottomSheet<BibleLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheet) => SizedBox(
        height: MediaQuery.of(sheet).size.height * 0.8,
        child: BibleBrowser(
          mode: BibleBrowserMode.pickChapter,
          initialBook: c.book,
          onOpen: (link) => Navigator.of(sheet).pop(link),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final i = versification.chapterIndex(picked.book, picked.chapter);
    if (i >= 0) _pages.jumpToPage(i);
  }

  /// Toucher : un verset hors de la plage l'étend jusqu'à lui ; une borne la
  /// raccourcit ; le seul verset choisi la lève ; un verset intérieur repart
  /// de lui seul.
  void _tapVerse(int verse) {
    setState(() {
      final (from, to) = (_from, _to);
      if (from == null || to == null) {
        _from = _to = verse;
      } else if (verse < from || verse > to) {
        _from = verse < from ? verse : from;
        _to = verse > to ? verse : to;
      } else if (from == to) {
        _from = _to = null;
      } else if (verse == from) {
        _from = from + 1;
      } else if (verse == to) {
        _to = to - 1;
      } else {
        _from = _to = verse;
      }
    });
    _placeMenu();
  }

  /// **Le « + » de la sélection** (#250) : la plage gagne le verset suivant.
  /// L'appui long puis glisser faisait déjà cela, mais rien ne l'annonçait —
  /// une fonction que personne ne trouvait. Le bouton la rend visible, et le
  /// glissement continue de marcher.
  void _extendSelection() {
    final to = _to;
    if (to == null) return;
    final c = _current;
    final verses = ref
        .read(
          bibleChapterProvider((
            version: ref.read(activeBibleVersionProvider),
            book: c.book,
            chapter: c.chapter,
          )),
        )
        .value;
    // Au bout du chapitre, le « + » ne fait rien plutôt que de déborder sur
    // le suivant : la sélection ne traverse pas une page.
    if (verses == null || verses.isEmpty || to >= verses.last.number) return;
    setState(() => _to = to + 1);
    _placeMenu();
  }

  /// Appui long puis glisser : la plage d'[anchor] à [verse].
  void _dragVerses(int anchor, int verse) => setState(() {
        _from = anchor < verse ? anchor : verse;
        _to = anchor < verse ? verse : anchor;
        _placeMenu();
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _current;
    final version = ref.watch(activeBibleVersionProvider);
    final versions = ref.watch(bibleVersionsProvider).value ?? const [];
    ref.listen<BibleVersification>(
      bibleVersificationProvider,
      (_, next) => _followVersification(next),
    );
    final actions = ref.watch(bibleSlotsProvider).verseActions;
    final from = _from;
    final member = ref.watch(bibleIsMemberProvider);
    final bookmarked = (ref
                .watch(
                  bibleChapterMarksProvider((
                    book: c.book,
                    chapter: c.chapter,
                  )),
                )
                .value ??
            const <BibleMark>[])
        .where((m) => m.kind == BibleMarkKind.bookmark)
        .toList();
    // L'habillage du lecteur enveloppe maintenant l'écran entier, et non plus
    // les seules pages : la barre du haut des références est **claire**, donc
    // elle doit suivre le thème choisi (sépia, sombre) comme le texte. Le
    // `Builder` n'est là que pour lire la palette du thème ainsi posé.
    return BibleReaderAppearance(
      child: Builder(
        builder: (context) => _scaffold(context, context.palette, l, c,
            version: version,
            versions: versions,
            actions: actions,
            from: from,
            member: member,
            bookmarked: bookmarked),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l,
    ({String book, int chapter}) c, {
    required String version,
    required List<BibleVersion> versions,
    required List<BibleVerseAction> actions,
    required int? from,
    required bool member,
    required List<BibleMark> bookmarked,
  }) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surfaceAlt,
        foregroundColor: palette.textSecondary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Tooltip(
          message: l.bibleChangeChapter,
          child: InkWell(
            key: BibleReaderScreen.headerKey,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: _pickChapter,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    BibleLink(c.book, c.chapter).labelFr,
                    style: AppTypography.h5.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            key: BibleReaderScreen.bookmarkKey,
            tooltip: l.bibleM2Bookmark,
            icon: Icon(
              bookmarked.isEmpty ? Icons.bookmark_border : Icons.bookmark,
              color: palette.textSecondary,
            ),
            onPressed: () => unawaited(
              ref.read(bibleMarksStoreProvider).toggleBookmark(
                    member: member,
                    book: c.book,
                    chapter: c.chapter,
                  ),
            ),
          ),
          PopupMenuButton<String>(
            key: BibleReaderScreen.versionKey,
            tooltip: l.bibleVersionTooltip,
            initialValue: version,
            onSelected: (code) {
              ref.read(activeBibleVersionProvider.notifier).select(code);
              _savePosition();
            },
            itemBuilder: (_) => [
              for (final v in versions)
                if (v.installed)
                  PopupMenuItem(
                    key: Key('bible_version_${v.code}'),
                    value: v.code,
                    child: Text(v.name),
                  ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    version,
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        key: _stackKey,
        children: [
          PageView.builder(
            key: BibleReaderScreen.pagesKey,
            controller: _pages,
            itemCount: _chapters.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _from = _to = null;
              });
              _savePosition();
            },
            itemBuilder: (context, i) {
              final page = _chapters[i];
              final arrival = page.book == widget.book &&
                  page.chapter == widget.chapter &&
                  widget.from != null;
              return _ChapterPage(
                key: BibleReaderScreen.pageKey(page.book, page.chapter),
                chapterKey: (
                  version: version,
                  book: page.book,
                  chapter: page.chapter,
                ),
                flashFrom: arrival ? widget.from : null,
                flashTo: arrival ? (widget.to ?? widget.from) : null,
                selectedFrom: i == _index ? _from : null,
                selectedTo: i == _index ? _to : null,
                onVerseTap: actions.isEmpty ? null : _tapVerse,
                onVerseDrag: actions.isEmpty ? null : _dragVerses,
                menu: i == _index
                    ? (
                        above: _aboveLink,
                        below: _belowLink,
                        firstKey: _firstKey,
                      )
                    : null,
                onReadToEnd: () {
                  if (i == _index) _markRead(page.book, page.chapter);
                },
              );
            },
          ),
          if (from != null && actions.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _menuBelow ? _belowLink : _aboveLink,
                showWhenUnlinked: false,
                targetAnchor:
                    _menuBelow ? Alignment.bottomCenter : Alignment.topCenter,
                followerAnchor:
                    _menuBelow ? Alignment.topCenter : Alignment.bottomCenter,
                offset: Offset(0, _menuBelow ? AppSpacing.xs : -AppSpacing.xs),
                child: Center(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: BibleVerseMenu(
                      selection: BibleLink(
                        c.book,
                        c.chapter,
                        from: from,
                        to: _to == from ? null : _to,
                      ),
                      versionCode: version,
                      actions: actions,
                      onDone: () => setState(() => _from = _to = null),
                    ),
                  ),
                ),
              ),
            ),
          // Le « + » des références : au centre du dernier verset choisi,
          // là où le doigt descend pour en prendre un de plus.
          if (from != null && actions.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _belowLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.center,
                followerAnchor: Alignment.center,
                child: Center(
                  child: _ExtendButton(onTap: _extendSelection),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une page : le texte d'un chapitre.
class _ChapterPage extends ConsumerStatefulWidget {
  const _ChapterPage({
    super.key,
    required this.chapterKey,
    required this.onReadToEnd,
    this.flashFrom,
    this.flashTo,
    this.selectedFrom,
    this.selectedTo,
    this.onVerseTap,
    this.onVerseDrag,
    this.menu,
  });

  final BibleChapterKey chapterKey;
  final int? flashFrom;
  final int? flashTo;
  final int? selectedFrom;
  final int? selectedTo;
  final ValueChanged<int>? onVerseTap;

  /// Appui long sur un verset puis glisser : (verset de départ, verset sous
  /// le doigt).
  final void Function(int anchor, int verse)? onVerseDrag;

  /// Posé sur la page courante : les cibles du menu flottant (au-dessus du
  /// premier verset choisi, sous le dernier) et la clé du premier.
  final ({LayerLink above, LayerLink below, GlobalKey firstKey})? menu;
  final VoidCallback onReadToEnd;

  @override
  ConsumerState<_ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends ConsumerState<_ChapterPage> {
  final _scroll = ScrollController();
  final _target = GlobalKey();
  bool _flashing = false;
  bool _scrolledToTarget = false;
  bool _reported = false;
  Timer? _flashTimer;
  int? _dragAnchor;

  /// Le verset sous [global] : chaque ligne porte son numéro en `MetaData`.
  int? _verseAt(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(global));
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is int) {
        return target.metaData as int;
      }
    }
    return null;
  }

  void _drag(Offset global, {bool start = false}) {
    final drag = widget.onVerseDrag;
    final verse = _verseAt(global);
    if (drag == null || verse == null) return;
    if (start) _dragAnchor = verse;
    final anchor = _dragAnchor;
    if (anchor != null) drag(anchor, verse);
  }

  @override
  void initState() {
    super.initState();
    _flashing = widget.flashFrom != null;
    if (_flashing) {
      _flashTimer = Timer(ref.read(bibleFlashDurationProvider), () {
        if (mounted) setState(() => _flashing = false);
      });
    }
    _scroll.addListener(_checkEnd);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Fin de défilement atteinte — ou chapitre assez court pour tenir à
  /// l'écran : le chapitre est lu.
  void _checkEnd() {
    if (_reported || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 24) {
      _reported = true;
      widget.onReadToEnd();
    }
  }

  void _afterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrolledToTarget && _target.currentContext != null) {
        _scrolledToTarget = true;
        Scrollable.ensureVisible(_target.currentContext!, alignment: 0.1);
      }
      _checkEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final key = widget.chapterKey;
    final verses = ref.watch(bibleChapterProvider(key));
    final decorations = <int, BibleVerseDecoration>{
      for (final decorate in ref.watch(bibleSlotsProvider).chapterDecorators)
        ...decorate(ref, key.book, key.chapter),
    };
    return verses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(l.bibleChapterUnavailable)),
      data: (list) {
        if (list.isEmpty) {
          // **« Rien sur l'appareil » n'est pas « chapitre indisponible »**
          // (#249). Depuis que les exemples s'effacent dès qu'une vraie
          // version est proposée, le lecteur s'ouvre sur une version que rien
          // n'a encore descendue : `sourceFor` rend `null`,
          // `bibleChapterProvider` rend une liste vide, et le fidèle lisait
          // « pas disponible dans cette version » — vrai, inutile, et sans
          // issue. La règle de #249 n'est tenable qu'avec cette contrepartie :
          // ici on dit quoi faire, et on y mène.
          final missing =
              ref.watch(bibleCatalogProvider).sourceFor(key.version) == null;
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    missing
                        ? l.bibleVersionNotInstalled
                        : l.bibleChapterUnavailable,
                    textAlign: TextAlign.center,
                  ),
                  if (missing) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: BibleReaderScreen.downloadKey,
                      onPressed: () => openBiblePersonalize(
                        ref,
                        BiblePersonalizePage.offline,
                      ),
                      icon: const Icon(Icons.download_for_offline_outlined),
                      label: Text(l.bibleM4Download),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        _afterLayout();
        return SingleChildScrollView(
          controller: _scroll,
          // La marge latérale est passée dans chaque verset : la bande de
          // sélection et le trait de marqueur doivent filer **jusqu'aux
          // bords**, comme sur les références.
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            // De quoi loger la pilule flottante sous le dernier verset.
            bottom: 160,
          ),
          child: GestureDetector(
            onLongPressStart: widget.onVerseDrag == null
                ? null
                : (d) => _drag(d.globalPosition, start: true),
            onLongPressMoveUpdate: widget.onVerseDrag == null
                ? null
                : (d) => _drag(d.globalPosition),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final v in list)
                  _wrap(
                    v.number,
                    _VerseLine(
                      key: v.number == widget.flashFrom ? _target : null,
                      verse: v,
                      decoration: decorations[v.number],
                      flashed: _flashing &&
                          v.number >= widget.flashFrom! &&
                          v.number <= widget.flashTo!,
                      selected: widget.selectedFrom != null &&
                          v.number >= widget.selectedFrom! &&
                          v.number <= widget.selectedTo!,
                      palette: palette,
                      // La lettrine ouvre le chapitre sur son premier verset ;
                      // le titre dans le corps, lui, a disparu — la barre du
                      // haut le portait déjà.
                      dropCap: v.number == list.first.number
                          ? '${key.chapter}'
                          : null,
                      onTap: widget.onVerseTap == null
                          ? null
                          : () => widget.onVerseTap!(v.number),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on _ChapterPageState {
  /// Le numéro pour le glisser ; les cibles du menu sur les bornes choisies.
  Widget _wrap(int verse, Widget line) {
    final menu = widget.menu;
    var anchored = line;
    if (menu != null && verse == widget.selectedTo) {
      anchored = CompositedTransformTarget(link: menu.below, child: anchored);
    }
    if (menu != null && verse == widget.selectedFrom) {
      anchored = KeyedSubtree(
        key: menu.firstKey,
        child: CompositedTransformTarget(link: menu.above, child: anchored),
      );
    }
    return MetaData(
      metaData: verse,
      behavior: HitTestBehavior.translucent,
      child: anchored,
    );
  }
}

class _VerseLine extends StatelessWidget {
  const _VerseLine({
    super.key,
    required this.verse,
    required this.decoration,
    required this.flashed,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.dropCap,
  });

  final BibleVerse verse;
  final BibleVerseDecoration? decoration;
  final bool flashed;
  final bool selected;
  final AppPalette palette;
  final VoidCallback? onTap;

  /// Le numéro du chapitre en lettrine, sur le premier verset seulement.
  final String? dropCap;

  @override
  Widget build(BuildContext context) {
    final background = flashed
        ? palette.primary.withValues(alpha: 0.18)
        : decoration?.background;
    final body = BibleReaderAppearance.verseStyle(context);
    final rubric = BibleReaderAppearance.rubric(context);
    final icons = decoration?.marginIcons ?? const <IconData>[];
    final line = (body.fontSize ?? 18) * (body.height ?? 1.6);
    final cap = dropCap;
    return InkWell(
      key: BibleReaderScreen.verseKey(verse.number),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        // La sélection reste une bande pleine et nette, d'un bord à l'autre
        // (références, verset 4) ; le surlignage, lui, est **peint**.
        decoration: BoxDecoration(color: selected ? palette.surfaceAlt : null),
        child: MarkerHighlight(
          color: background,
          lineHeight: line,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cap != null)
                Padding(
                  // Le chiffre descend sous sa ligne de base : on le remonte
                  // pour que sa panse s'aligne sur la première ligne du texte.
                  padding: EdgeInsets.only(
                    right: AppSpacing.sm,
                    top: line * 0.10,
                  ),
                  child: Text(
                    cap,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.w500,
                      fontSize: line * 2.9,
                      height: 0.78,
                      color: rubric,
                    ),
                  ),
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      // Le numéro est **en ligne** et à la taille du texte :
                      // lisible comme sur les références, et l'interligne
                      // reste régulier — ce dont le marqueur a besoin pour
                      // poser ses bandes.
                      TextSpan(
                        text: '${verse.number} ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: rubric,
                        ),
                      ),
                      TextSpan(text: verse.text),
                    ],
                  ),
                  style: body,
                ),
              ),
              for (final icon in icons)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs, top: 6),
                  child: Icon(icon, size: 16, color: palette.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Le « + » posé sur la sélection** : rond, translucide, au centre du
/// dernier verset choisi. Il n'ouvre rien — il étend d'un verset.
class _ExtendButton extends StatelessWidget {
  const _ExtendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Tooltip(
      message: l.bibleM2ExtendSelection,
      child: Semantics(
        button: true,
        label: l.bibleM2ExtendSelection,
        child: Material(
          key: BibleReaderScreen.extendKey,
          // Translucide pour qu'on lise le verset à travers : c'est ce qui le
          // distingue d'un bouton flottant posé par-dessus le texte.
          color: AppColors.neutralDark.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
