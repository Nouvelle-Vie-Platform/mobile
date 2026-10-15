import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/theme_provider.dart';
import '../theme/app_spacing.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/segmented_tabs.dart';
import 'notes/notes_tab.dart';

/// Les deux onglets de la page, par leur nom dans `?tab=`.
enum BibleTab { bible, notes }

/// **La page Bible, à deux onglets** (#190) : **Bible** — encore « en
/// construction » — et **Notes**. Pilules maison sous la [BrandAppBar],
/// glissement latéral entre les deux, **dernier onglet mémorisé** dans
/// `app_settings` et rouvert quand la route ne dit rien (`/bible` nu, le
/// bouton de l'accueil).
///
/// Route `/bible?tab=bible|notes`, **ouverte à tous** : la Bible appartient à
/// la surface invitée, et l'onglet Notes montre à un invité une porte de
/// session plutôt qu'une liste — sans qu'aucune lecture privée ne parte.
///
/// Poussée, et non montée en permanence. Elle ne survit donc pas en
/// arrière-plan, et c'est pourquoi l'onglet se garde dans le magasin et non
/// dans son `State`.
class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key, this.initialTab});

  /// L'onglet demandé par la route, ou `null` pour « le dernier ouvert ».
  final BibleTab? initialTab;

  static const tabsKey = Key('bible_tabs');

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  late BibleTab _tab = widget.initialTab ?? BibleTab.bible;
  late final PageController _pages = PageController(initialPage: _tab.index);
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == null) _restoreTab();
  }

  Future<void> _restoreTab() async {
    final saved = await ref.read(settingsDaoProvider).bibleTab();
    final tab = BibleTab.values.asNameMap()[saved];
    // Un geste fait entre-temps l'emporte sur la mémoire.
    if (tab == null || !mounted || _touched || tab == _tab) return;
    setState(() => _tab = tab);
    if (_pages.hasClients) {
      _pages.jumpToPage(tab.index);
      return;
    }
    // Le magasin a répondu avant la première image : le `PageView` n'est pas
    // encore attaché, on saute dès qu'il l'est.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(tab.index);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(BibleTab tab, {bool animate = true}) {
    _touched = true;
    if (tab != _tab) setState(() => _tab = tab);
    if (animate && _pages.hasClients) {
      _pages.animateToPage(
        tab.index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    ref.read(settingsDaoProvider).setBibleTab(tab.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: BrandAppBar(
        title: _tab == BibleTab.bible ? l.navBible : l.notesAppBarTitle,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding.copyWith(
                top: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              child: SegmentedTabs(
                key: BibleScreen.tabsKey,
                tabs: [l.navBible, l.notesTab],
                selected: _tab.index,
                onSelect: (i) => _select(BibleTab.values[i]),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) =>
                    _select(BibleTab.values[i], animate: false),
                children: const [_BibleTab(), NotesTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le contenu provisoire de la Bible, déplacé **tel quel** de l'ancien écran.
/// Le remplir est un autre chantier.
class _BibleTab extends StatelessWidget {
  const _BibleTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.pageUnderConstruction,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
