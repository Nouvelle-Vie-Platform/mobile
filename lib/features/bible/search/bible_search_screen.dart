/// **La recherche dans la Bible** (M3, #201, décision 18) — « Recherche
/// simple » et « Recherche croisée » de la maquette, sur un seul écran :
///
/// - une saisie qui est une **référence** (« jn 3 16 ») propose « Aller à
///   Jean 3:16 » et, validée, ouvre directement le lecteur ;
/// - sinon, les **mots** dans la version active, filtres Tout / AT / NT /
///   Livre, le mot surligné, « N résultats », « Voir plus » ;
/// - cocher plusieurs versions installées fait une recherche **croisée** :
///   un résultat par verset, le texte de chaque version dessous ;
/// - l'icône « comparer » d'un résultat ouvre les **résultats comparatifs**
///   (`bible_compare_screen.dart`) ;
/// - saisie vide : les 10 dernières recherches.
///
/// À l'ouverture, l'index de chaque version installée est construit s'il
/// manque (les deux versions factices, la première fois).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_empty_state.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import '../reader/bible_reader_screen.dart';
import 'bible_compare_screen.dart';
import 'bible_reference_parser.dart';
import 'bible_search_history.dart';
import 'bible_search_index.dart';

class BibleSearchScreen extends ConsumerStatefulWidget {
  const BibleSearchScreen({super.key});

  static const Key fieldKey = Key('bible_search_field');
  static const Key gotoKey = Key('bible_search_goto');
  static const Key countKey = Key('bible_search_count');
  static const Key moreKey = Key('bible_search_more');
  static const Key clearHistoryKey = Key('bible_search_clear_history');
  static const Key bookKey = Key('bible_search_scope_book');
  static Key scopeKey(String id) => Key('bible_search_scope_$id');
  static Key versionKey(String code) => Key('bible_search_version_$code');
  static Key hitKey(BibleLink link) => Key('bible_search_hit_${link.toUrl()}');
  static Key compareKey(BibleLink link) =>
      Key('bible_search_compare_${link.toUrl()}');

  static const int pageSize = 20;

  /// **Ouvre la recherche**, par la pile du routeur (jamais un
  /// `BuildContext`). Une route nommée `/bible/search` pourra la remplacer à
  /// l'assemblage sans rien changer aux appelants.
  static Future<void> open(GoRouter router) async {
    await router.routerDelegate.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => const AppBackground(child: BibleSearchScreen()),
      ),
    );
  }

  @override
  ConsumerState<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends ConsumerState<BibleSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<BibleVersion> _installed = const [];
  Set<String> _selected = {};
  bool _indexing = true;
  List<String> _history = const [];

  BibleSearchScope _scope = BibleSearchScope.all;
  String _searched = '';
  BibleSearchPage _page = BibleSearchPage.empty;
  bool _loading = false;
  int _generation = 0;

  BibleSearchIndex get _index => ref.read(bibleSearchIndexProvider);

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final active = ref.read(activeBibleVersionProvider);
    final versions = await ref.read(bibleCatalogProvider).versions();
    final history = await ref.read(bibleSearchHistoryProvider).read();
    if (!mounted) return;
    setState(() {
      _installed = [
        for (final v in versions)
          if (v.installed) v,
      ];
      _selected = {
        _installed.any((v) => v.code == active)
            ? active
            : _installed.firstOrNull?.code ?? active,
      };
      _history = history;
    });
    await Future.wait(
        [for (final v in _installed) _index.ensureIndexed(v.code)]);
    if (!mounted) return;
    setState(() => _indexing = false);
    if (_controller.text.trim().isNotEmpty) _run();
  }

  List<String> get _versions => [
        for (final v in _installed)
          if (_selected.contains(v.code)) v.code,
      ];

  /// Lance la recherche de la saisie ; [more] ajoute la page suivante.
  Future<void> _run({bool more = false}) async {
    _debounce?.cancel();
    final text = _controller.text.trim();
    if (_indexing) return;
    final generation = ++_generation;
    setState(() => _loading = true);
    final page = await _index.search(
      text,
      versions: _versions,
      scope: _scope,
      offset: more ? _page.hits.length : 0,
      limit: BibleSearchScreen.pageSize,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _searched = text;
      _page = more
          ? BibleSearchPage(page.total, [..._page.hits, ...page.hits])
          : page;
    });
  }

  void _onChanged(String _) {
    setState(() {}); // « Aller à … » suit la saisie.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  Future<void> _onSubmitted(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    _remember(query);
    final link = parseBibleReference(query);
    if (link != null) {
      _debounce?.cancel();
      await _openReader(link);
    } else {
      await _run();
    }
  }

  Future<void> _remember(String query) async {
    final history = await ref.read(bibleSearchHistoryProvider).add(query);
    if (mounted) setState(() => _history = history);
  }

  Future<void> _openReader(BibleLink link) =>
      BibleReaderScreen.push(ref.read(routerProvider), link);

  void _setScope(BibleSearchScope scope) {
    setState(() => _scope = scope);
    _run();
  }

  void _toggleVersion(String code) {
    final next = {..._selected};
    if (!next.remove(code)) next.add(code);
    if (next.isEmpty) return; // Au moins une version.
    setState(() => _selected = next);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = _controller.text.trim();
    final reference = parseBibleReference(text);
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleSearchTitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
            child: TextField(
              key: BibleSearchScreen.fieldKey,
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.bibleSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
            ),
          ),
          _filters(context),
          if (_indexing) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body(context, text, reference)),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final l = context.l10n;
    final book = _scope.book;
    Widget chip(String id, String label, BibleSearchScope scope) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(
            key: BibleSearchScreen.scopeKey(id),
            label: Text(label),
            selected: _scope == scope,
            onSelected: (_) => _setScope(scope),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppSpacing.screenPadding.copyWith(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          chip('all', l.bibleSearchScopeAll, BibleSearchScope.all),
          chip('old', l.bibleSearchScopeOld, BibleSearchScope.oldTestament),
          chip('new', l.bibleSearchScopeNew, BibleSearchScope.newTestament),
          PopupMenuButton<String>(
            key: BibleSearchScreen.bookKey,
            onSelected: (osis) => _setScope(BibleSearchScope.book(osis)),
            itemBuilder: (_) => [
              for (final b in bibleCanon)
                PopupMenuItem(value: b.osis, child: Text(b.name)),
            ],
            child: Chip(
              avatar: const Icon(Icons.arrow_drop_down, size: 18),
              label: Text(
                  book == null ? l.bibleSearchScopeBook : osisBooksFr[book]!),
              backgroundColor: book == null
                  ? null
                  : context.palette.primary.withValues(alpha: 0.14),
            ),
          ),
          if (_installed.length > 1) ...[
            const SizedBox(width: AppSpacing.md),
            for (final v in _installed)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  key: BibleSearchScreen.versionKey(v.code),
                  label: Text(v.code),
                  tooltip: v.name,
                  selected: _selected.contains(v.code),
                  onSelected: (_) => _toggleVersion(v.code),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _body(BuildContext context, String text, BibleLink? reference) {
    final l = context.l10n;
    final goto = reference == null
        ? null
        : Padding(
            padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.sm),
            child: AppCard(
              key: BibleSearchScreen.gotoKey,
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () {
                _remember(text);
                _openReader(reference);
              },
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      color: context.palette.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l.bibleSearchGoTo(reference.labelFr),
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );

    if (text.isEmpty) return _historyView(context);

    final page = _page;
    final showResults = _searched == text && !_indexing;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (goto != null) goto,
        if (showResults && (reference == null || page.total > 0))
          Padding(
            padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.sm),
            child: Text(
              l.bibleSearchResults(page.total),
              key: BibleSearchScreen.countKey,
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary),
            ),
          ),
        if (showResults && page.total == 0 && reference == null)
          Padding(
            padding: AppSpacing.screenPadding,
            child: AppEmptyState(
              title: l.bibleSearchNoResults,
              icon: Icons.search_off,
            ),
          ),
        if (showResults)
          for (final hit in page.hits) _hitCard(context, hit),
        if (showResults && page.hits.length < page.total)
          Center(
            child: TextButton(
              key: BibleSearchScreen.moreKey,
              onPressed: _loading ? null : () => _run(more: true),
              child: Text(l.bibleSearchMore),
            ),
          ),
        if (_indexing || (_loading && !showResults))
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                _indexing ? l.bibleSearchIndexing : '',
                style: AppTypography.caption,
              ),
            ),
          ),
      ],
    );
  }

  Widget _historyView(BuildContext context) {
    final l = context.l10n;
    if (_history.isEmpty) {
      return ListView(
        padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.xl),
        children: [
          AppEmptyState(
            title: l.bibleSearchTitle,
            message: l.bibleSearchEmpty,
            icon: Icons.search,
          ),
        ],
      );
    }
    return ListView(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: Row(
            children: [
              Expanded(
                child: Text(l.bibleSearchHistory, style: AppTypography.h5),
              ),
              TextButton(
                key: BibleSearchScreen.clearHistoryKey,
                onPressed: () async {
                  await ref.read(bibleSearchHistoryProvider).clear();
                  if (mounted) setState(() => _history = const []);
                },
                child: Text(l.bibleSearchClearHistory),
              ),
            ],
          ),
        ),
        for (final q in _history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(q),
            onTap: () {
              _controller.text = q;
              _controller.selection = TextSelection.collapsed(offset: q.length);
              _onSubmitted(q);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _hitCard(BuildContext context, BibleSearchHit hit) {
    final palette = context.palette;
    final cross = _versions.length > 1;
    return Padding(
      padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.sm),
      child: AppCard(
        key: BibleSearchScreen.hitKey(hit.link),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => _openReader(hit.link),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(hit.link.labelFr, style: AppTypography.bodyStrong),
                ),
                IconButton(
                  key: BibleSearchScreen.compareKey(hit.link),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.compare_arrows),
                  tooltip: context.l10n.bibleSearchCompare,
                  onPressed: () => BibleCompareScreen.open(
                      ref.read(routerProvider), hit.link),
                ),
              ],
            ),
            for (final t in hit.texts)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text.rich(
                  TextSpan(
                    style:
                        AppTypography.body.copyWith(color: palette.textPrimary),
                    children: [
                      if (cross)
                        TextSpan(
                          text: '${t.version}  ',
                          style: AppTypography.caption
                              .copyWith(color: palette.primary),
                        ),
                      ...highlightSpans(
                        t.text,
                        TextStyle(
                          fontWeight: FontWeight.w700,
                          backgroundColor:
                              palette.primary.withValues(alpha: 0.16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Découpe un texte marqué par [kHitStart] / [kHitEnd] en morceaux, les mots
/// trouvés portant [hit].
List<TextSpan> highlightSpans(String marked, TextStyle hit) {
  final spans = <TextSpan>[];
  var on = false;
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString(), style: on ? hit : null));
    buffer.clear();
  }

  for (final ch in marked.split('')) {
    if (ch == kHitStart || ch == kHitEnd) {
      flush();
      on = ch == kHitStart;
    } else {
      buffer.write(ch);
    }
  }
  flush();
  return spans;
}
