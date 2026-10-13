/// **« Ajouter un lien »** (N5, #193) — le bouton de la pilule, sa feuille à
/// quatre choix, et l'insertion dans le texte.
///
/// - **Une note** : ses notes (recherche locale, la note courante exclue) ;
/// - **Un enseignement** : la médiathèque locale (recherche sur le titre) ;
/// - **Une adresse web** : un champ, `https://` ajouté s'il manque ;
/// - **La Bible** : pousse le module Bible en **mode sélection**
///   (`/bible/select`, #199) ; on y choisit livre, chapitre et versets, et le
///   `BibleLink` revient ici (libellé « Jean 3:16-18 »).
///
/// Le texte sélectionné devient le lien ; sans sélection, le titre choisi (ou
/// l'URL) est inséré au curseur, déjà lié.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../state/mediatheque_providers.dart';
import '../../../state/notes_providers.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../format_pill.dart';
import 'note_link.dart';

/// Ce que la feuille rend : le lien, et le texte à insérer s'il n'y a pas de
/// sélection.
typedef NoteLinkChoice = ({NoteLink link, String label});

/// **Pose [link] dans [controller]** : sur [selection] si elle couvre du
/// texte, sinon en insérant [label] au curseur. [selection] vaut la sélection
/// courante par défaut — le bouton la relève **avant** d'ouvrir la feuille,
/// le focus de l'éditeur partant avec elle.
void insertNoteLink(
  QuillController controller,
  NoteLink link,
  String label, {
  TextSelection? selection,
}) {
  final sel = selection ?? controller.selection;
  final docEnd = controller.document.length - 1;
  final start = sel.start.clamp(0, docEnd);
  final end = sel.end.clamp(start, docEnd);
  final attribute = LinkAttribute(link.toUrl());
  if (end > start) {
    controller.formatText(start, end - start, attribute);
    return;
  }
  if (label.isEmpty) return;
  controller.replaceText(
    start,
    0,
    label,
    TextSelection.collapsed(offset: start + label.length),
  );
  controller.formatText(start, label.length, attribute);
}

/// Le bouton « lien » de la pilule, à passer dans `linkSlot`.
class NoteLinkButton extends StatelessWidget {
  const NoteLinkButton({
    super.key,
    required this.controller,
    required this.currentNoteId,
    this.focusNode,
  });

  static const Key buttonKey = Key('note_pill_link');

  final QuillController controller;

  /// La note en cours d'édition, retirée de la liste « Une note ».
  final String currentNoteId;

  /// Rendu à l'éditeur quand la feuille se ferme, comme le fait « T ».
  final FocusNode? focusNode;

  Future<void> _onTap(BuildContext context) async {
    // Relevée maintenant : la pilule disparaît avec le focus, et ce bouton
    // avec elle, pendant que la feuille est ouverte.
    final selection = controller.selection;
    final choice = await showAddLinkSheet(
      context,
      currentNoteId: currentNoteId,
    );
    if (choice != null) {
      insertNoteLink(
        controller,
        choice.link,
        choice.label,
        selection: selection,
      );
    }
    focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PillButton(
      key: buttonKey,
      label: context.l10n.noteLinkAdd,
      active: controller.getSelectionStyle().attributes.containsKey(
            Attribute.link.key,
          ),
      onTap: () => _onTap(context),
      child: const Icon(Icons.link),
    );
  }
}

Future<NoteLinkChoice?> showAddLinkSheet(
  BuildContext context, {
  required String currentNoteId,
}) {
  return showModalBottomSheet<NoteLinkChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => AddLinkSheet(currentNoteId: currentNoteId),
  );
}

enum _Page { menu, note, teaching, web }

class AddLinkSheet extends ConsumerStatefulWidget {
  const AddLinkSheet({super.key, required this.currentNoteId});

  final String currentNoteId;

  static const Key noteOptionKey = Key('note_link_option_note');
  static const Key teachingOptionKey = Key('note_link_option_teaching');
  static const Key webOptionKey = Key('note_link_option_web');
  static const Key bibleOptionKey = Key('note_link_option_bible');
  static const Key searchFieldKey = Key('note_link_search');
  static const Key urlFieldKey = Key('note_link_url');
  static const Key urlSubmitKey = Key('note_link_url_submit');
  static const Key backKey = Key('note_link_back');
  static Key noteItemKey(String id) => Key('note_link_note_$id');
  static Key teachingItemKey(String id) => Key('note_link_teaching_$id');

  @override
  ConsumerState<AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends ConsumerState<AddLinkSheet> {
  _Page _page = _Page.menu;
  String _query = '';
  final _url = TextEditingController();
  bool _urlInvalid = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _go(_Page page) => setState(() {
        _page = page;
        _query = '';
      });

  void _pick(NoteLink link, String label) =>
      Navigator.of(context).pop<NoteLinkChoice>((link: link, label: label));

  /// La Bible : le mode sélection du module, poussé **par-dessus** la feuille
  /// (par la `GoRouter`, jamais le `BuildContext`) ; la feuille rend ce qu'il
  /// rapporte.
  Future<void> _pickBible() async {
    final link = await ref
        .read(routerProvider)
        .pushNamed<BibleLink>(AppRoute.bibleSelect);
    if (link != null && mounted) _pick(link, link.labelFr);
  }

  void _submitUrl() {
    final link = WebLink.fromInput(_url.text);
    if (link == null) {
      setState(() => _urlInvalid = true);
      return;
    }
    _pick(link, link.url);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final media = MediaQuery.of(context);
    final body = switch (_page) {
      _Page.menu => _menu(context),
      _Page.note => _list(
          context,
          _NoteResults(
            query: _query,
            excludeId: widget.currentNoteId,
            onPick: (id, title) => _pick(NoteRefLink(id), title),
          ),
        ),
      _Page.teaching => _list(
          context,
          _TeachingResults(
            query: _query,
            onPick: (id, title) => _pick(TeachingLink(id), title),
          ),
        ),
      _Page.web => _web(context),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (_page != _Page.menu)
                      IconButton(
                        key: AddLinkSheet.backKey,
                        icon: const Icon(Icons.arrow_back),
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => _go(_Page.menu),
                      ),
                    Expanded(
                      child: Text(
                        l.noteLinkSheetTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final l = context.l10n;
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          key: AddLinkSheet.noteOptionKey,
          leading: const Icon(Icons.sticky_note_2_outlined),
          title: Text(l.noteLinkToNote),
          onTap: () => _go(_Page.note),
        ),
        ListTile(
          key: AddLinkSheet.teachingOptionKey,
          leading: const Icon(Icons.play_circle_outline),
          title: Text(l.noteLinkToTeaching),
          onTap: () => _go(_Page.teaching),
        ),
        ListTile(
          key: AddLinkSheet.webOptionKey,
          leading: const Icon(Icons.public),
          title: Text(l.noteLinkToWeb),
          onTap: () => _go(_Page.web),
        ),
        ListTile(
          key: AddLinkSheet.bibleOptionKey,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(l.noteLinkToBible),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickBible,
        ),
      ],
    );
  }

  Widget _list(BuildContext context, Widget results) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: AddLinkSheet.searchFieldKey,
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: context.l10n.noteLinkSearch,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(child: results),
      ],
    );
  }

  Widget _web(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: AddLinkSheet.urlFieldKey,
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'https://',
            errorText: _urlInvalid ? l.noteLinkInvalidUrl : null,
          ),
          onChanged: (_) {
            if (_urlInvalid) setState(() => _urlInvalid = false);
          },
          onSubmitted: (_) => _submitUrl(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          key: AddLinkSheet.urlSubmitKey,
          onPressed: _submitUrl,
          child: Text(l.noteLinkInsert),
        ),
      ],
    );
  }
}

typedef _OnPick = void Function(String id, String title);

class _NoteResults extends ConsumerWidget {
  const _NoteResults({
    required this.query,
    required this.excludeId,
    required this.onPick,
  });

  final String query;
  final String excludeId;
  final _OnPick onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final notes = ref.watch(
      notesListProvider((categoryId: null, query: query)),
    );
    final items = [
      for (final note in notes.value ?? const [])
        if (note.id != excludeId) note,
    ];
    if (items.isEmpty) return _Empty(loading: notes.isLoading);
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final note = items[i];
        final title = (note.title?.trim().isNotEmpty ?? false)
            ? note.title!.trim()
            : l.notesUntitled;
        return ListTile(
          key: AddLinkSheet.noteItemKey(note.id),
          leading: const Icon(Icons.sticky_note_2_outlined),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: note.body.trim().isEmpty
              ? null
              : Text(
                  note.body.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => onPick(note.id, title),
        );
      },
    );
  }
}

class _TeachingResults extends ConsumerWidget {
  const _TeachingResults({required this.query, required this.onPick});

  final String query;
  final _OnPick onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachings = ref.watch(allTeachingsProvider);
    final needle = query.trim().toLowerCase();
    // ponytail: filtre en mémoire sur tout le catalogue local ; passer par
    // `MediathequeDao.teachingsMatching` si la médiathèque grossit beaucoup.
    final items = [
      for (final t in teachings.value ?? const [])
        if (needle.isEmpty || t.title.toLowerCase().contains(needle)) t,
    ];
    if (items.isEmpty) return _Empty(loading: teachings.isLoading);
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final t = items[i];
        return ListTile(
          key: AddLinkSheet.teachingItemKey(t.id),
          leading: const Icon(Icons.play_circle_outline),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              t.authorName == null ? null : Text(t.authorName!, maxLines: 1),
          onTap: () => onPick(t.id, t.title),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Text(
                context.l10n.noteLinkNoResult,
                style: TextStyle(color: context.palette.textSecondary),
              ),
      ),
    );
  }
}
