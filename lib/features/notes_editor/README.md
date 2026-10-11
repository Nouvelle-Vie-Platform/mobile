# `notes_editor` — l'éditeur riche des notes (N3, mobile#191)

Module **autonome** : ni route, ni table, ni provider. Il reçoit un Delta JSON,
remonte ce que l'utilisateur tape, et c'est l'écran de N2 qui l'écrit dans
`local_notes`. Plan : `server-portal/docs/notes-bible-plan.md`.

## API publique

| Fichier | Ce qu'il expose |
|---|---|
| `rich_note_editor.dart` | `RichNoteEditor` (l'éditeur plein cadre, pilule comprise), `RichNoteEditorState.controller` / `.focusNode`, `documentFromJson`, `noteEditorStyles`, `NvAttachmentPlaceholderBuilder` |
| `format_pill.dart` | `FormatPill` (la pilule sombre), `PillButton` (le dessin d'un bouton, pour N4 et N5) |
| `format_sheet.dart` | `showFormatSheet(context, controller)`, `FormatSheet`, `noteColorOf` |
| `note_formatting.dart` | extension `NoteFormatting` sur `QuillController` : `isActive`, `toggle`, `setHeader`, `toggleList`, `setTextColor`, `toggleHighlight`… |
| `note_content.dart` | **pur Dart** : `parseNoteLines`, `deltaToPlainText`, `plainToDeltaJson`, `NotePreview.firstLines`, `noteAllowedAttributes`, `attachmentLabel` |
| `note_colors.dart` | **pur Dart** : `noteTextColors` (8), `noteHighlight`, `isNoteTextColor`, `isNoteHighlight` |
| `note_pdf_exporter.dart` | `NotePdfExporter.build(...)`, `shareNoteAsPdf(context, title, bytes)`, `noteFileSlug` |

```dart
RichNoteEditor(
  initialContentJson: note.content,            // Delta JSON ou null
  onChanged: (contentJson, plainText) => …,    // débordé à 300 ms
  onLinkTap: (url) => …,                       // N5
  attachmentSlot: PillButton(…),               // N4
  linkSlot: PillButton(…),                     // N5
  embedBuilders: [NvAttachmentBuilder()],      // N4, clé `nvAttachment`
)
```

`RichNoteEditor` **prend toute la hauteur** qu'on lui donne (`expands`) et
place lui-même la pilule au-dessus du clavier (`viewInsets`), visible seulement
quand l'éditeur a le focus. Pour un autre agencement, `FormatPill` se pose à la
main. Le contrôleur et le focus peuvent être fournis (`controller:`,
`focusNode:`) — pour insérer un embed, lire la sélection, ou fermer le clavier
avec la coche (`focusNode.unfocus()`) — ou lus sur l'état via une
`GlobalKey<RichNoteEditorState>`.

## Comment N2, N4 et N5 se branchent

- **N2 (écran)** : titre à part, `RichNoteEditor` dans un `Expanded`,
  `onChanged` → `local_notes` (`content` = Delta, `body` = `plainText`).
  `NotePreview.firstLines(content, 3)` pour les cartes ; `deltaToPlainText`
  remplace la copie minimale `lib/screens/notes/note_content.dart`
  (`plainToDeltaJson` garde la même signature).
- **N4 (pièces jointes)** : un `PillButton` dans `attachmentSlot`, qui insère un
  `BlockEmbed('nvAttachment', jsonEncode({...}))` au curseur ; un
  `EmbedBuilder` de clé `nvAttachment` dans `embedBuilders` (il remplace la
  carte d'attente `NvAttachmentPlaceholderBuilder`) ; et le `loadImage` du
  PDF, branché sur l'URL signée.
- **N5 (liens)** : un `PillButton` dans `linkSlot`, qui pose
  `LinkAttribute(url)` sur la sélection ; `onLinkTap` reçoit l'URL quand
  l'utilisateur choisit « ouvrir » dans le menu d'appui long de flutter_quill
  (en édition, un simple appui pose le curseur).

## La liste fermée des attributs — à garder alignée avec le serveur

`noteAllowedAttributes` (`note_content.dart`) :
`bold, italic, underline, strike, color, background, header, list, indent,
code-block, blockquote, link`. Valeurs : `color` ∈ `noteTextColors` (8 hex),
`background` = `noteHighlight` (`#f8d05e`), `header` 1–3, `list` ∈
`bullet | ordered | checked | unchecked`, `indent` 0–3. Un seul embed,
`nvAttachment`. Tout le reste → 422 côté serveur ; la feuille Format ne pose
rien d'autre, et `setTextColor` ignore une couleur hors palette.

Pas d'alignement, pas de tirets (flutter_quill ne connaît qu'une liste à
puces), pas de barre flutter_quill ni de `flutter_quill_extensions`.

## PDF

`NotePdfExporter().build(title:, contentJson:, loadImage:)` rend les octets
dans un isolate (Atkinson Hyperlegible embarquée ; monostyle en Courier).
Vingt photos au plus, les suivantes et les autres pièces jointes en ligne
« Pièce jointe : nom ». `shareNoteAsPdf` passe par `share_plus`
(`<titre-slug>.pdf`).

## Tests

`flutter test test/features/notes_editor/`
