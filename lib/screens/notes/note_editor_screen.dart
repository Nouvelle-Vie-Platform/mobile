/// **L'éditeur d'une note** (#190, #191) — titre, corps riche
/// ([RichNoteEditor], pilule de format au-dessus du clavier), épingle,
/// catégorie, partage en PDF, suppression.
///
/// Route `/notes/:id`, membres seulement. L'identifiant est **frappé par
/// l'appelant** (UUIDv7) : une note qui n'existe pas encore est un brouillon
/// vide sous cet identifiant, et le bouton du lecteur passe l'enseignement en
/// `extra` pour le brouillon pré-lié.
///
/// Pas de bouton Enregistrer : chaque changement écrit `local_notes` — le
/// Delta dans `content`, son texte aplati dans `body` —, l'envoi part 2 s
/// après le dernier et à la sortie ([NoteDraftSaver]). La coche de la barre
/// **ferme le clavier**, et c'est tout ce qu'elle fait. Le fond prend le pastel
/// de la catégorie, comme la carte de la liste (décision 5).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/notes_media/note_media_composer.dart';
import '../../data/notes_media/note_media_providers.dart';
import '../../data/repositories/note_draft_saver.dart';
import '../../data/repositories/notes_repository.dart';
import '../../features/notes_editor/attachments/note_attachment_button.dart';
import '../../features/notes_editor/attachments/note_attachment_embed_builder.dart';
import '../../features/notes_editor/links/add_link_sheet.dart';
import '../../features/notes_editor/links/linked_teaching_chip.dart';
import '../../features/notes_editor/links/note_link_opener.dart';
import '../../features/notes_editor/note_content.dart';
import '../../features/notes_editor/note_pdf_exporter.dart';
import '../../features/notes_editor/rich_note_editor.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/note_view.dart';
import '../../router/app_router.dart';
import '../../state/notes_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/note_palette.dart';
import '../../widgets/brand_app_bar.dart';
import 'note_category_sheet.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId, this.teachingId});

  final String noteId;

  /// L'enseignement auquel lier un **brouillon neuf**. Ignoré pour une note
  /// qui existe déjà : son lien est celui qu'elle porte.
  final String? teachingId;

  static const titleFieldKey = Key('note_editor_title');

  /// Posée sur le [RichNoteEditor] : les tests y lisent son contrôleur.
  static const bodyFieldKey = Key('note_editor_body');
  static const pinButtonKey = Key('note_editor_pin');
  static const newNoteButtonKey = Key('note_editor_new');
  static const doneButtonKey = Key('note_editor_done');
  static const menuButtonKey = Key('note_editor_menu');
  static const menuCategoryKey = Key('note_editor_menu_category');
  static const menuShareKey = Key('note_editor_menu_share');
  static const menuDeleteKey = Key('note_editor_menu_delete');
  static const shareProgressKey = Key('note_editor_share_progress');

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final NoteDraftSaver _saver;
  late final NoteMediaComposer _composer;

  /// Le contrôleur du corps, **possédé par l'écran** : le trombone y insère
  /// ses embeds et le composeur y pose les clés montées pendant que l'écran
  /// est ouvert. Créé à l'amorçage, quand le contenu est connu.
  QuillController? _quill;
  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  NoteDraft? _draft;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _saver = NoteDraftSaver(
      dao: ref.read(notesDaoProvider),
      repository: ref.read(notesRepositoryProvider),
    );
    _composer = ref.read(noteMediaComposerProvider);
    _titleFocus.addListener(_onFocus);
    _bodyFocus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    // Les enfants (l'éditeur) sont démontés avant : le contrôleur n'a plus
    // d'auditeur quand on le libère.
    final quill = _quill;
    if (quill != null) {
      _composer.detachEditor(widget.noteId, quill);
      quill.dispose();
    }
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _titleController.dispose();
    unawaited(_saver.close());
    super.dispose();
  }

  /// La première valeur du magasin **amorce** le brouillon, et plus rien ne
  /// le réamorce ensuite : les frappes sont la vérité de cet écran, et le
  /// flux ré-émet à chaque écriture locale.
  void _seed(NoteView? note) {
    if (_draft != null) return;
    _draft = note == null
        ? NoteDraft(
            id: widget.noteId,
            teachingId: widget.teachingId,
            clientCreatedAt: DateTime.now(),
          )
        : NoteDraft(
            id: note.id,
            title: note.title,
            body: note.body,
            content: note.content,
            categoryId: note.categoryId,
            pinned: note.pinned,
            teachingId: note.teachingId,
            clientCreatedAt: note.updatedAt ?? DateTime.now(),
          );
    _titleController.text = _draft!.title ?? '';
    final draft = _draft!;
    _quill = QuillController(
      // Une note d'avant le texte riche n'a qu'un `body` : il devient le
      // Delta le plus simple, pour ne pas s'ouvrir vide.
      document: documentFromJson(
        draft.content ??
            (draft.body.isEmpty ? null : plainToDeltaJson(draft.body)),
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _composer.attachEditor(widget.noteId, _quill!);
  }

  void _update(NoteDraft next) {
    setState(() => _draft = next);
    unawaited(_saver.update(next));
  }

  /// Le titre tel que le PDF et la feuille de partage le montrent.
  String get _displayTitle {
    final title = (_draft!.title ?? '').trim();
    return title.isEmpty ? context.l10n.notesUntitled : title;
  }

  Future<void> _pickCategory() async {
    final choice = await showNoteCategorySheet(
      context,
      selectedId: _draft!.categoryId,
    );
    if (choice == null || !mounted) return;
    _update(_draft!.copyWith(
      categoryId: choice.id,
      clearCategory: choice.id == null,
    ));
  }

  /// Le PDF se rend hors de l'isolate principal (`NotePdfExporter`), puis
  /// part à la feuille système. Un échec se dit en `SnackBar`, jamais en rouge.
  Future<void> _share() async {
    final l = context.l10n;
    final title = _displayTitle;
    final contentJson = _draft!.content ?? '';
    setState(() => _sharing = true);
    try {
      final bytes = await const NotePdfExporter().build(
        title: title,
        contentJson: contentJson,
        // Fichier local tant qu'il existe, sinon l'URL signée.
        loadImage: ref.read(noteImageLoaderProvider),
      );
      if (!mounted) return;
      await shareNoteAsPdf(context, title, bytes);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.notesShareFailed)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.notesDeleteConfirmTitle),
        content: Text(l.notesDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l.notesDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Plus rien ne doit partir pour cette note — surtout pas la frappe qui
    // attendait sa minuterie. Puis la ligne locale part tout de suite ; la
    // tombstone revient par le delta.
    _saver.cancel();
    await ref.read(notesDaoProvider).deleteLocal(widget.noteId);
    unawaited(ref.read(notesRepositoryProvider).deleteNote(widget.noteId));
    if (mounted) context.pop();
  }

  void _newNote() {
    context.pushReplacementNamed(
      AppRoute.noteEditor,
      pathParameters: {'id': mintNoteId()},
    );
  }

  void _openLink(String url) =>
      unawaited(NoteLinkOpener.open(context, ref, url));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final note = ref.watch(noteProvider(widget.noteId));
    // Tant que le magasin n'a pas répondu, rien à éditer — et surtout pas un
    // brouillon vide qui écraserait la note au premier `build`.
    if (!note.hasValue && _draft == null) {
      return Scaffold(appBar: BrandAppBar(title: l.notesUntitled));
    }
    _seed(note.value);
    final draft = _draft!;
    final typing = _titleFocus.hasFocus || _bodyFocus.hasFocus;
    final color = ref
        .watch(noteCategoriesProvider)
        .value
        ?.where((c) => c.id == draft.categoryId)
        .firstOrNull
        ?.color;

    return Scaffold(
      backgroundColor: color == null ? null : NotePalette.of(context, color),
      appBar: BrandAppBar(
        centerTitle: false,
        actions: [
          if (typing)
            IconButton(
              key: NoteEditorScreen.doneButtonKey,
              icon: const Icon(Icons.check),
              tooltip: l.notesDone,
              onPressed: () => FocusScope.of(context).unfocus(),
            ),
          IconButton(
            key: NoteEditorScreen.newNoteButtonKey,
            icon: const Icon(Icons.note_add_outlined),
            tooltip: l.notesUntitled,
            onPressed: _newNote,
          ),
          IconButton(
            key: NoteEditorScreen.pinButtonKey,
            icon: Icon(
              draft.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            tooltip: draft.pinned ? l.notesUnpin : l.notesPin,
            onPressed: () => _update(draft.copyWith(pinned: !draft.pinned)),
          ),
          if (_sharing)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox.square(
                key: NoteEditorScreen.shareProgressKey,
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            PopupMenuButton<_MenuAction>(
              key: NoteEditorScreen.menuButtonKey,
              onSelected: (action) => switch (action) {
                _MenuAction.category => _pickCategory(),
                _MenuAction.share => _share(),
                _MenuAction.delete => _delete(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: NoteEditorScreen.menuCategoryKey,
                  value: _MenuAction.category,
                  child: Text(l.notesCategoryTitle),
                ),
                PopupMenuItem(
                  key: NoteEditorScreen.menuShareKey,
                  value: _MenuAction.share,
                  child: Text(l.actionShare),
                ),
                PopupMenuItem(
                  key: NoteEditorScreen.menuDeleteKey,
                  value: _MenuAction.delete,
                  child: Text(
                    l.notesDelete,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
              child: TextField(
                key: NoteEditorScreen.titleFieldKey,
                controller: _titleController,
                focusNode: _titleFocus,
                style: AppTypography.h3,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: l.notesUntitled,
                  hintStyle:
                      AppTypography.h3.copyWith(color: palette.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (text) => _update(_draft!.copyWith(title: text)),
                onSubmitted: (_) => _bodyFocus.requestFocus(),
              ),
            ),
            // L'enseignement lié (décision 12) : rien si la note n'en a pas,
            // ou s'il n'est plus dans le magasin.
            Padding(
              padding: AppSpacing.screenPadding.copyWith(top: 0, bottom: 0),
              child: LinkedTeachingChip(teachingId: draft.teachingId),
            ),
            // L'éditeur prend tout le reste et pose lui-même la pilule
            // au-dessus du clavier ; sa marge horizontale est celle du titre.
            Expanded(
              child: RichNoteEditor(
                key: NoteEditorScreen.bodyFieldKey,
                controller: _quill,
                focusNode: _bodyFocus,
                onChanged: (contentJson, plainText) => _update(
                  _draft!.copyWith(body: plainText, content: contentJson),
                ),
                onLinkTap: _openLink,
                attachmentSlot: NoteAttachmentButton(
                  noteId: widget.noteId,
                  controller: _quill!,
                  focusNode: _bodyFocus,
                ),
                linkSlot: NoteLinkButton(
                  controller: _quill!,
                  currentNoteId: widget.noteId,
                  focusNode: _bodyFocus,
                ),
                embedBuilders: const [NoteAttachmentEmbedBuilder()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MenuAction { category, share, delete }
