/// **Les deux feuilles des catégories** (#190).
///
/// - [showNoteCategorySheet] — la feuille « Category » de la maquette, depuis
///   le menu de l'éditeur : la liste avec coche, « Ajouter une catégorie »
///   (nom + couleur), le bouton Valider.
/// - [showNoteCategoryEditSheet] — l'appui long sur une puce de la liste :
///   nom, couleur, supprimer avec confirmation.
///
/// Une catégorie créée part par `POST /notes/categories` et **revient par le
/// delta** (ADR-0026) ; la feuille la montre tout de suite, depuis sa propre
/// mémoire, pour qu'on puisse la choisir sans attendre le cycle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/note_view.dart';
import '../../state/notes_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/note_palette.dart';
import '../../widgets/app_button.dart';
import '../../data/repositories/notes_repository.dart';

/// Le choix fait dans la feuille : `null` quand on l'a fermée sans valider,
/// sinon l'identifiant choisi — `null` dans [NoteCategoryChoice.id] pour « sans
/// catégorie ».
class NoteCategoryChoice {
  const NoteCategoryChoice(this.id);
  final String? id;
}

Future<NoteCategoryChoice?> showNoteCategorySheet(
  BuildContext context, {
  required String? selectedId,
}) {
  return showModalBottomSheet<NoteCategoryChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategorySheet(selectedId: selectedId),
  );
}

Future<void> showNoteCategoryEditSheet(
  BuildContext context, {
  required NoteCategoryView category,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategoryEditSheet(category: category),
  );
}

/// Les clés des tests.
abstract final class NoteCategorySheetKeys {
  static const addRow = Key('note_category_add');
  static const nameField = Key('note_category_name');
  static const createButton = Key('note_category_create');
  static const validateButton = Key('note_category_validate');
  static const deleteButton = Key('note_category_delete');
  static const none = Key('note_category_none');
  static Key color(NoteColor color) => Key('note_category_color_${color.name}');
  static Key option(String id) => Key('note_category_option_$id');
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late String? _selected = widget.selectedId;
  bool _adding = false;
  final _created = <NoteCategoryView>[];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final synced = ref.watch(noteCategoriesProvider).value ?? const [];
    final categories = [
      ...synced,
      for (final c in _created)
        if (!synced.any((s) => s.id == c.id)) c,
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title: l.notesCategoryTitle),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: AppSpacing.screenPadding,
              children: [
                if (_adding)
                  _CategoryForm(
                    submitLabel: l.notesCategoryCreate,
                    submitKey: NoteCategorySheetKeys.createButton,
                    onSubmit: _create,
                  )
                else
                  ListTile(
                    key: NoteCategorySheetKeys.addRow,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_circle_outline,
                        color: palette.textSecondary),
                    title: Text(l.notesCategoryAdd,
                        style: AppTypography.body
                            .copyWith(color: palette.textSecondary)),
                    onTap: () => setState(() => _adding = true),
                  ),
                _CategoryOption(
                  key: NoteCategorySheetKeys.none,
                  label: l.notesCategoryNone,
                  color: null,
                  checked: _selected == null,
                  onTap: () => setState(() => _selected = null),
                ),
                for (final c in categories)
                  _CategoryOption(
                    key: NoteCategorySheetKeys.option(c.id),
                    label: c.name,
                    color: c.color,
                    checked: _selected == c.id,
                    onTap: () => setState(() => _selected = c.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.screenPadding.copyWith(
              top: AppSpacing.md,
              bottom: AppSpacing.lg,
            ),
            child: AppButton(
              key: NoteCategorySheetKeys.validateButton,
              label: l.actionValidate,
              onPressed: () =>
                  Navigator.of(context).pop(NoteCategoryChoice(_selected)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(String name, NoteColor color) async {
    final id = mintNoteId();
    // La feuille la montre tout de suite ; le serveur la confirme par le delta.
    setState(() {
      _created.add(NoteCategoryView(id: id, name: name, color: color));
      _selected = id;
      _adding = false;
    });
    await ref.read(notesRepositoryProvider).upsertCategory(
          id: id,
          name: name,
          color: color,
          clientCreatedAt: DateTime.now(),
        );
  }
}

class _CategoryEditSheet extends ConsumerWidget {
  const _CategoryEditSheet({required this.category});

  final NoteCategoryView category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title: l.notesCategoryEditTitle),
          Padding(
            padding: AppSpacing.screenPadding,
            child: _CategoryForm(
              initialName: category.name,
              initialColor: category.color,
              submitLabel: l.actionValidate,
              submitKey: NoteCategorySheetKeys.validateButton,
              onSubmit: (name, color) async {
                Navigator.of(context).pop();
                await ref.read(notesRepositoryProvider).upsertCategory(
                      id: category.id,
                      name: name,
                      color: color,
                      clientCreatedAt: DateTime.now(),
                    );
              },
            ),
          ),
          Padding(
            padding: AppSpacing.screenPadding.copyWith(
              top: AppSpacing.sm,
              bottom: AppSpacing.lg,
            ),
            child: AppButton(
              key: NoteCategorySheetKeys.deleteButton,
              label: l.notesCategoryDelete,
              variant: AppButtonVariant.danger,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.notesCategoryDelete),
        content: Text(l.notesCategoryDeleteConfirm(category.name)),
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
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(notesRepositoryProvider).deleteCategory(category.id);
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h4,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    super.key,
    required this.label,
    required this.color,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final NoteColor? color;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: color == null
          ? null
          : CircleAvatar(
              radius: 8,
              backgroundColor: NotePalette.of(context, color!),
            ),
      title: Text(label, style: AppTypography.body),
      trailing: Icon(
        checked ? Icons.check_circle : Icons.check_circle_outline,
        color: checked ? palette.textPrimary : palette.border,
      ),
      onTap: onTap,
    );
  }
}

/// Nom + six pastilles de couleur + bouton. Sert à créer et à modifier.
class _CategoryForm extends StatefulWidget {
  const _CategoryForm({
    this.initialName = '',
    this.initialColor,
    required this.submitLabel,
    required this.submitKey,
    required this.onSubmit,
  });

  final String initialName;
  final NoteColor? initialColor;
  final String submitLabel;
  final Key submitKey;
  final Future<void> Function(String name, NoteColor color) onSubmit;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late NoteColor _color = widget.initialColor ?? NoteColor.blue;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: NoteCategorySheetKeys.nameField,
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l.notesCategoryNameHint,
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final color in NoteColor.values)
              Semantics(
                label: color.name,
                button: true,
                selected: color == _color,
                child: GestureDetector(
                  key: NoteCategorySheetKeys.color(color),
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: NotePalette.of(context, color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color == _color
                            ? context.palette.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: widget.submitKey,
          label: widget.submitLabel,
          variant: AppButtonVariant.secondary,
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => widget.onSubmit(_name.text.trim(), _color),
        ),
      ],
    );
  }
}
