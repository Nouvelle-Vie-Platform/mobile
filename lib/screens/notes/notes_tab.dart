/// **L'onglet Notes de la page Bible** (#190) : recherche, puces de filtre,
/// grille de cartes colorées, bouton +. Et pour un invité, **la porte de
/// session** — un état vide et un bouton de connexion, sans qu'aucune lecture
/// privée ne parte (piège 9 : ni synchro privée ni `GET /notes` sans session).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notes_repository.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/note_view.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../state/notes_providers.dart';
import '../../state/session_gate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/note_palette.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_error_state.dart';
import 'note_category_sheet.dart';

class NotesTab extends ConsumerStatefulWidget {
  const NotesTab({super.key});

  static const signInButtonKey = Key('notes_sign_in');
  static const addButtonKey = Key('notes_add');
  static const allChipKey = Key('notes_chip_all');
  static Key chipKey(String categoryId) => Key('notes_chip_$categoryId');
  static Key cardKey(String noteId) => Key('notes_card_$noteId');

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  String _query = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    // `isGuest`, jamais `!isAuthenticated` : le second est aussi vrai pendant
    // `unknown`, c'est-à-dire pendant le démarrage.
    if (ref.watch(authProvider.select((s) => s.isGuest))) {
      return const _NotesGate();
    }
    return _NotesList(
      query: _query,
      categoryId: _categoryId,
      onQuery: (q) => setState(() => _query = q),
      onCategory: (id) => setState(() => _categoryId = id),
    );
  }
}

class _NotesGate extends ConsumerWidget {
  const _NotesGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ListView(
      padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.xl),
      children: [
        AppEmptyState(
          title: l.notesGuestTitle,
          message: l.notesGuestMessage,
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: NotesTab.signInButtonKey,
          label: l.actionLogin,
          // Rien à rejouer : la connexion aboutie, la page revient sur cet
          // onglet (mémorisé), et c'est la liste qui se peint à la place.
          onPressed: () => ref.requireSession(action: () {}),
        ),
      ],
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({
    required this.query,
    required this.categoryId,
    required this.onQuery,
    required this.onCategory,
  });

  final String query;
  final String? categoryId;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final categories = ref.watch(noteCategoriesProvider).value ?? const [];
    final notes =
        ref.watch(notesListProvider((categoryId: categoryId, query: query)));
    final byId = {for (final c in categories) c.id: c};

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        key: NotesTab.addButtonKey,
        backgroundColor: AppColors.primary,
        tooltip: l.notesUntitled,
        onPressed: () => _open(ref, mintNoteId()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: AppSearchField(hint: l.notesSearchHint, onChanged: onQuery),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.screenPadding,
              children: [
                _FilterChip(
                  key: NotesTab.allChipKey,
                  label: l.notesFilterAll,
                  color: null,
                  selected: categoryId == null,
                  onTap: () => onCategory(null),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    key: NotesTab.chipKey(c.id),
                    label: c.name,
                    color: c.color,
                    selected: categoryId == c.id,
                    onTap: () => onCategory(c.id),
                    onLongPress: () =>
                        showNoteCategoryEditSheet(context, category: c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorState(
                message: l.stateErrorMessage,
                onRetry: () => ref.invalidate(notesListProvider),
              ),
              data: (items) => items.isEmpty
                  ? ListView(
                      padding: AppSpacing.screenPadding,
                      children: [
                        AppEmptyState(
                          title: l.notesEmptyTitle,
                          message: l.notesEmptyMessage,
                          icon: Icons.edit_note,
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: AppSpacing.screenPadding.copyWith(
                        bottom: AppSpacing.xxxl * 2,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _NoteCard(
                        note: items[i],
                        color: byId[items[i].categoryId]?.color,
                        onTap: () => _open(ref, items[i].id),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// **La route est lue par `ref`, jamais par le `BuildContext`** : la règle
/// des gestes vers une route réservée (`guest_affordances_test`). Ici la liste
/// n'est montée que pour un membre, mais la forme reste celle du dépôt.
void _open(WidgetRef ref, String noteId) {
  ref.read(routerProvider).pushNamed(
    AppRoute.noteEditor,
    pathParameters: {'id': noteId},
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final NoteColor? color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color == null ? null : NotePalette.of(context, color!);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.textPrimary : (tint ?? palette.surface),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
              color: selected ? palette.textPrimary : palette.border),
        ),
        child: Text(
          label,
          style: AppTypography.bodyStrong.copyWith(
            color: selected ? palette.surface : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.color,
    required this.onTap,
  });

  final NoteView note;
  final NoteColor? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final title = (note.title ?? '').trim();
    return Material(
      key: NotesTab.cardKey(note.id),
      color:
          color == null ? palette.surfaceAlt : NotePalette.of(context, color!),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? l.notesUntitled : title,
                      style: AppTypography.h5.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.pinned)
                    Icon(Icons.push_pin, size: 16, color: palette.textPrimary),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Text(
                  note.body,
                  style:
                      AppTypography.body.copyWith(color: palette.textPrimary),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
