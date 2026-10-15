/// **L'éditeur de texte riche des notes** (N3, #191) — flutter_quill habillé
/// à la charte, **sans sa barre d'outils** : la pilule et la feuille Format
/// sont à nous (`format_pill.dart`, `format_sheet.dart`).
///
/// Module **autonome** : ni routage, ni persistance. Il reçoit un Delta JSON,
/// remonte chaque changement (débordé à 300 ms) en Delta **et** en texte
/// aplati, et c'est la tranche d'intégration qui l'écrit dans `local_notes`.
///
/// Trois prises pour les tranches suivantes :
///
/// - [RichNoteEditor.attachmentSlot] et [RichNoteEditor.linkSlot] : les deux
///   derniers boutons de la pilule (trombone de N4, lien de N5) ;
/// - [RichNoteEditor.embedBuilders] : le rendu de `nvAttachment` (N4,
///   `NoteAttachmentEmbedBuilder` : photo pleine largeur, carte
///   vidéo/audio/fichier) ;
/// - [RichNoteEditor.onLinkTap] : N5 y branche l'ouverture des `nv://` et
///   des `https://`. Dans l'éditeur, un lien s'ouvre par **appui long** (menu
///   ouvrir / copier / retirer de flutter_quill) — un simple appui y pose le
///   curseur.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'format_pill.dart';
import 'note_content.dart';

/// Signature de [RichNoteEditor.onChanged] : le Delta JSON (`{"ops": […]}`)
/// et le texte aplati (`deltaToPlainText`) du même instant.
typedef NoteContentChanged = void Function(
  String contentJson,
  String plainText,
);

class RichNoteEditor extends StatefulWidget {
  const RichNoteEditor({
    super.key,
    required this.onChanged,
    this.initialContentJson,
    this.controller,
    this.focusNode,
    this.scrollController,
    this.onLinkTap,
    this.attachmentSlot,
    this.linkSlot,
    this.embedBuilders = const [],
    this.autoFocus = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      FormatPill.height + AppSpacing.xl * 2,
    ),
  });

  /// Délai entre la dernière frappe et l'appel de [onChanged].
  static const Duration debounce = Duration(milliseconds: 300);

  /// Le contenu de départ, Delta JSON `{"ops": […]}` ; `null` ou illisible =
  /// note vide.
  final String? initialContentJson;

  final NoteContentChanged onChanged;

  /// Pour piloter l'éditeur de l'extérieur (insérer un embed, lire la
  /// sélection). Créé — et détruit — ici s'il n'est pas fourni ; lisible dans
  /// les deux cas par [RichNoteEditorState.controller].
  final QuillController? controller;

  /// Même règle que [controller] : fourni ou interne, lisible par
  /// [RichNoteEditorState.focusNode]. La coche de l'écran fait `unfocus()`.
  final FocusNode? focusNode;

  final ScrollController? scrollController;

  /// Reçoit l'URL d'un lien que l'utilisateur ouvre. Sans lui, flutter_quill
  /// tente `url_launcher`.
  final ValueChanged<String>? onLinkTap;

  /// Le trombone (N4) et le lien (N5), en fin de pilule.
  final Widget? attachmentSlot;
  final Widget? linkSlot;

  /// Rendus d'embeds. Un contenu qui porte un `nvAttachment` exige le builder
  /// de cette clé (`NoteAttachmentEmbedBuilder`) : flutter_quill n'en a pas
  /// d'autre.
  final List<EmbedBuilder> embedBuilders;

  final bool autoFocus;

  /// Marge intérieure du texte. Le bas laisse la place à la pilule.
  final EdgeInsets padding;

  @override
  State<RichNoteEditor> createState() => RichNoteEditorState();
}

class RichNoteEditorState extends State<RichNoteEditor> {
  late final QuillController controller;
  late final FocusNode focusNode;
  late final ScrollController _scroll;
  late final StreamSubscription<DocChange> _changes;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ??
        QuillController(
          document: documentFromJson(widget.initialContentJson),
          selection: const TextSelection.collapsed(offset: 0),
        );
    focusNode = widget.focusNode ?? FocusNode();
    _scroll = widget.scrollController ?? ScrollController();
    _changes = controller.changes.listen(_scheduleChanged);
    focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _changes.cancel();
    focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) controller.dispose();
    if (widget.focusNode == null) focusNode.dispose();
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _scheduleChanged(DocChange _) {
    _debounce?.cancel();
    _debounce = Timer(RichNoteEditor.debounce, _emitChanged);
  }

  void _emitChanged() {
    if (!mounted) return;
    final json = jsonEncode({'ops': controller.document.toDelta().toJson()});
    widget.onChanged(json, deltaToPlainText(json));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editor = QuillEditor(
      controller: controller,
      focusNode: focusNode,
      scrollController: _scroll,
      config: QuillEditorConfig(
        placeholder: l.noteEditorPlaceholder,
        padding: widget.padding,
        autoFocus: widget.autoFocus,
        expands: true,
        customStyles: noteEditorStyles(context),
        embedBuilders: widget.embedBuilders,
        onLaunchUrl: widget.onLinkTap,
        keyboardAppearance: Theme.of(context).brightness,
      ),
    );

    return Stack(
      children: [
        // flutter_quill lit ses propres traductions (menu d'un lien) et ne
        // connaît pas l'éwé : on lui donne son délégué ici, sur une locale
        // qu'il connaît, sans toucher au `MaterialApp`.
        Positioned.fill(child: _QuillLocalizations(child: editor)),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: focusNode.hasFocus
                ? FormatPill(
                    controller: controller,
                    focusNode: focusNode,
                    attachmentSlot: widget.attachmentSlot,
                    linkSlot: widget.linkSlot,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// Le [Document] d'un Delta JSON. Vide si le JSON est absent ou illisible ;
/// complété d'un `\n` final si le Delta n'en a pas (Quill l'exige).
Document documentFromJson(String? contentJson) {
  if (contentJson == null || contentJson.trim().isEmpty) return Document();
  try {
    final decoded = jsonDecode(contentJson);
    final ops = switch (decoded) {
      {'ops': final List<dynamic> list} => List<dynamic>.of(list),
      final List<dynamic> list => List<dynamic>.of(list),
      _ => null,
    };
    if (ops == null || ops.isEmpty) return Document();
    final last = ops.last;
    if (last is! Map || last['insert'] is! String) {
      ops.add({'insert': '\n'});
    } else if (!(last['insert'] as String).endsWith('\n')) {
      ops[ops.length - 1] = {...last, 'insert': '${last['insert']}\n'};
    }
    return Document.fromJson(ops);
  } on Exception {
    return Document();
  }
}

/// Les styles de l'éditeur, à la charte : Atkinson Hyperlegible, corps 16,
/// titre 28 / sous-titre 22 / titre secondaire 18 en gras, citation à barre
/// `primary`, monostyle sur `surfaceAlt`.
DefaultStyles noteEditorStyles(BuildContext context) {
  final palette = context.palette;
  final base = AppTypography.bodyLarge.copyWith(color: palette.textPrimary);
  TextStyle heading(double size) => TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: palette.textPrimary,
      );
  const horizontal = HorizontalSpacing(0, 0);

  return DefaultStyles(
    color: palette.textPrimary,
    paragraph: DefaultTextBlockStyle(
      base,
      horizontal,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    h1: DefaultTextBlockStyle(
      heading(28),
      horizontal,
      const VerticalSpacing(16, 4),
      VerticalSpacing.zero,
      null,
    ),
    h2: DefaultTextBlockStyle(
      heading(22),
      horizontal,
      const VerticalSpacing(12, 4),
      VerticalSpacing.zero,
      null,
    ),
    h3: DefaultTextBlockStyle(
      heading(18),
      horizontal,
      const VerticalSpacing(8, 2),
      VerticalSpacing.zero,
      null,
    ),
    bold: const TextStyle(fontWeight: FontWeight.w700),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
    link: TextStyle(
      color: palette.primary,
      decoration: TextDecoration.underline,
      decorationColor: palette.primary,
    ),
    placeHolder: DefaultTextBlockStyle(
      base.copyWith(color: palette.textSecondary),
      horizontal,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    lists: DefaultListBlockStyle(
      base,
      horizontal,
      const VerticalSpacing(4, 0),
      const VerticalSpacing(0, 4),
      null,
      null,
    ),
    indent: DefaultTextBlockStyle(
      base,
      horizontal,
      const VerticalSpacing(4, 0),
      const VerticalSpacing(0, 4),
      null,
    ),
    quote: DefaultTextBlockStyle(
      base.copyWith(color: palette.textSecondary),
      horizontal,
      const VerticalSpacing(8, 4),
      const VerticalSpacing(2, 2),
      BoxDecoration(
        border: Border(left: BorderSide(width: 3, color: palette.primary)),
      ),
    ),
    code: DefaultTextBlockStyle(
      TextStyle(
        fontFamily: 'Menlo',
        fontFamilyFallback: const ['monospace', 'Courier New'],
        fontSize: 14,
        height: 1.4,
        color: palette.textPrimary,
      ),
      horizontal,
      const VerticalSpacing(8, 4),
      VerticalSpacing.zero,
      BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  );
}

class _QuillLocalizations extends StatelessWidget {
  const _QuillLocalizations({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context);
    final supported = FlutterQuillLocalizations.supportedLocales
        .any((l) => l.languageCode == current.languageCode);
    return Localizations.override(
      context: context,
      locale: supported ? current : const Locale('fr'),
      delegates: const [FlutterQuillLocalizations.delegate],
      child: child,
    );
  }
}
