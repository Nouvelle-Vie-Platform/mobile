/// **L'éditeur d'une note, minimal** (#190) — titre + corps texte, épingle,
/// catégorie, suppression. La tranche N3 remplace [NoteBodyPlain] par
/// l'éditeur riche et ajoute la pilule de format ; rien d'autre ici ne bouge.
///
/// Route `/notes/:id`, membres seulement. L'identifiant est **frappé par
/// l'appelant** (UUIDv7) : une note qui n'existe pas encore est un brouillon
/// vide sous cet identifiant, et le bouton du lecteur passe l'enseignement en
/// `extra` pour le brouillon pré-lié.
///
/// Pas de bouton Enregistrer : chaque frappe écrit `local_notes`, l'envoi part
/// 2 s après la dernière et à la sortie ([NoteDraftSaver]). La coche de la
/// barre **ferme le clavier**, et c'est tout ce qu'elle fait.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/note_draft_saver.dart';
import '../../data/repositories/notes_repository.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/note_view.dart';
import '../../router/app_router.dart';
import '../../state/notes_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand_app_bar.dart';
import 'note_body_plain.dart';
import 'note_category_sheet.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId, this.teachingId});

  final String noteId;

  /// L'enseignement auquel lier un **brouillon neuf**. Ignoré pour une note
  /// qui existe déjà : son lien est celui qu'elle porte.
  final String? teachingId;

  static const titleFieldKey = Key('note_editor_title');
  static const bodyFieldKey = Key('note_editor_body');
  static const pinButtonKey = Key('note_editor_pin');
  static const newNoteButtonKey = Key('note_editor_new');
  static const doneButtonKey = Key('note_editor_done');
  static const menuButtonKey = Key('note_editor_menu');
  static const menuCategoryKey = Key('note_editor_menu_category');
  static const menuShareKey = Key('note_editor_menu_share');
  static const menuDeleteKey = Key('note_editor_menu_delete');

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final NoteDraftSaver _saver;
  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  NoteDraft? _draft;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _saver = NoteDraftSaver(
      dao: ref.read(notesDaoProvider),
      repository: ref.read(notesRepositoryProvider),
    );
    _titleFocus.addListener(_onFocus);
    _bodyFocus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _titleController.dispose();
    if (!_deleted) unawaited(_saver.close());
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
  }

  void _update(NoteDraft next) {
    setState(() => _draft = next);
    unawaited(_saver.update(next));
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
    _deleted = true;
    // La ligne locale part tout de suite ; la tombstone revient par le delta.
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

    return Scaffold(
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
          PopupMenuButton<_MenuAction>(
            key: NoteEditorScreen.menuButtonKey,
            onSelected: (action) => switch (action) {
              _MenuAction.category => _pickCategory(),
              _MenuAction.share => null,
              _MenuAction.delete => _delete(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                key: NoteEditorScreen.menuCategoryKey,
                value: _MenuAction.category,
                child: Text(l.notesCategoryTitle),
              ),
              // **Désactivé** : le partage en PDF est la tranche N3.
              PopupMenuItem(
                key: NoteEditorScreen.menuShareKey,
                value: _MenuAction.share,
                enabled: false,
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
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              TextField(
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
                onChanged: (text) => _update(draft.copyWith(title: text)),
                onSubmitted: (_) => _bodyFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: NoteBodyPlain(
                  key: NoteEditorScreen.bodyFieldKey,
                  initialBody: draft.body,
                  focusNode: _bodyFocus,
                  hint: l.notesBodyHint,
                  onChanged: (body, contentJson) =>
                      _update(draft.copyWith(body: body, content: contentJson)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { category, share, delete }
