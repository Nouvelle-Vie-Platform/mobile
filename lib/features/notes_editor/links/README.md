# `notes_editor/links` — les liens des notes (N5, mobile#193)

Module autonome : ni route, ni table. Plan : `server-portal/docs/notes-bible-plan.md`
(décisions 12 et 13).

| Fichier | Ce qu'il expose |
|---|---|
| `note_link.dart` | **pur Dart** : `NoteLink.parse(url)` / `toUrl()` (`WebLink`, `NoteRefLink`, `TeachingLink`, `BibleLink`), `WebLink.fromInput`, `BibleLink.labelFr` (« Jean 3:16-18 »), `osisBooksFr` (66 livres) |
| `add_link_sheet.dart` | `NoteLinkButton` (le bouton de la pilule), `showAddLinkSheet`, `AddLinkSheet`, `insertNoteLink` |
| `note_link_opener.dart` | `NoteLinkOpener.open(context, ref, url)` |
| `linked_teaching_chip.dart` | `LinkedTeachingChip(teachingId:)` |

## Brancher dans l'écran d'édition

L'écran (un `ConsumerStatefulWidget`) possède le `QuillController` et le
`FocusNode` et les passe à `RichNoteEditor` :

```dart
// Sous le champ titre :
LinkedTeachingChip(teachingId: draft.teachingId),

Expanded(
  child: RichNoteEditor(
    controller: _quill,          // le même que ci-dessous
    focusNode: _bodyFocus,
    initialContentJson: draft.content,
    onChanged: …,
    linkSlot: NoteLinkButton(
      controller: _quill,
      currentNoteId: widget.noteId,
      focusNode: _bodyFocus,     // rendu à l'éditeur à la fermeture
    ),
    onLinkTap: (url) => NoteLinkOpener.open(context, ref, url),
  ),
),
```

`NoteLinkOpener` a remplacé l'opener minimal de l'intégration N2 + N3. Il
pousse par la `GoRouter` du conteneur (`routerProvider`), pas par le
`BuildContext` : règle de `guest_affordances_test`, où il est justifié.

## Comportement

- **Feuille « Ajouter un lien »** : Une note (`notesListProvider`, recherche,
  note courante exclue ; sans titre → « Nouvelle note »), Un enseignement
  (`allTeachingsProvider`, recherche sur le titre en mémoire), Une adresse web
  (`https://` ajouté s'il manque, refus sinon), La Bible **grisée « bientôt »**.
- **Insertion** : le texte sélectionné devient le lien ; sans sélection, le
  titre (ou l'URL) est inséré au curseur, lié. La sélection est relevée au
  toucher du bouton, avant que le focus ne parte avec la feuille.
- **Ouverture** (`onLinkTap`, appui long → « ouvrir » dans flutter_quill) :
  note → `/notes/:id` (absente → `SnackBar`) ; enseignement → `/teaching/:id` ;
  web → `externalLinkLauncherProvider` (navigateur externe) ; Bible →
  `/bible?tab=bible` ; tout autre lien → `SnackBar`.
- **Puce** : titre lu par `teachingByIdProvider` ; rien si l'enseignement n'est
  pas (ou plus) dans le magasin — aucune FK côté mobile.

Le schéma est **fermé** et recopié du serveur (`note_delta.ts`,
`osis_books.ts`) : un changement là-bas se reporte ici.

## Tests

`flutter test test/features/notes_editor/links/`
