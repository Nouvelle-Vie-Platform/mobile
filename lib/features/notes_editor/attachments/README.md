# `attachments` — les pièces jointes dans le fil du texte (N4, mobile#192)

Module **autonome** : il ne touche ni l'écran, ni le routeur, ni le schéma.
La donnée vit dans `lib/data/notes_media/`, le dessin ici. Plan :
`server-portal/docs/notes-bible-plan.md` (décisions 10 et 11).

| Fichier | Ce qu'il expose |
|---|---|
| `note_attachment_button.dart` | `NoteAttachmentButton` (le trombone de la pilule, menu façon Apple), `NoteAudioRecordSheet` |
| `note_attachment_embed_builder.dart` | `NoteAttachmentEmbedBuilder` (clé `nvAttachment`, remplace `NvAttachmentPlaceholderBuilder`), `NoteAttachmentBlock`, `noteAttachmentStatusOf` |
| `data/notes_media/note_media_composer.dart` | `NoteMediaComposer` (`attach`, `retry`, `resendPending`, `attachEditor` / `detachEditor`), `insertAttachmentEmbed` |
| `data/notes_media/note_attachment_content.dart` | **pur Dart** : `serverNoteContent`, `hasPendingAttachment`, `contentCites`, `patchAttachmentJson` |
| `data/notes_media/note_media_dao.dart` | `NoteMediaDao` (`pending_note_media`, sans code généré) |
| `data/notes_media/note_media_transport.dart` | `POST /notes/media-uploads` + `PUT` présigné (délégué à `HttpGroupMediaTransport.upload`) |
| `data/notes_media/note_media_urls.dart` | `GET /notes/media/<key>` lu sans suivre le 302, URL gardée 50 min en mémoire |
| `data/notes_media/load_image_for_pdf.dart` | `loadImageForPdf(key, dao:, urls:)` |
| `data/notes_media/note_media_providers.dart` | les providers (`noteMediaComposerProvider`, `noteImageLoaderProvider`…) |

## Le chemin local ne part pas au serveur

L'embed est inséré **tout de suite**, sans clé, avec un champ local
`localId` (= `embedId` de la ligne `pending_note_media`). Le chemin du
fichier n'est **jamais** dans le Delta : le bloc le lit sur la ligne en
attente. Une fois monté, l'embed reçoit `key` / `thumbKey` et perd `localId` —
il a alors la forme exacte du contrat N1. Le serveur refuse tout champ hors
liste et exige `key` : d'où les deux branchements **obligatoires** du §5.

## Brancher (l'écran de N2)

### 1. Le trombone et le rendu

L'écran fournit **son** contrôleur à l'éditeur (le bouton en a besoin au
moment du `build`) :

```dart
final controller = QuillController(
  document: documentFromJson(note.content),
  selection: const TextSelection.collapsed(offset: 0),
);
final focusNode = FocusNode();

RichNoteEditor(
  controller: controller,
  focusNode: focusNode,
  onChanged: …,
  attachmentSlot: NoteAttachmentButton(
    noteId: note.id,
    controller: controller,
    focusNode: focusNode,
  ),
  embedBuilders: const [NoteAttachmentEmbedBuilder()],
)
```

La carte d'attente de N3 (`NvAttachmentPlaceholderBuilder`) a été retirée à
l'intégration : ce builder est le seul rendu de `nvAttachment`.

### 2. L'éditeur ouvert, déclaré au composeur

```dart
// initState
_composer = ref.read(noteMediaComposerProvider)..attachEditor(note.id, controller);
// dispose
_composer.detachEditor(note.id, controller);
```

Écran ouvert, la clé est posée **dans le contrôleur** (l'`onChanged` de
l'écran enregistre) ; écran fermé, dans `local_notes.content` (ligne remise
`dirty`), puis `notesOutboxProvider` est appelé.

### 3. Après chaque cycle de synchronisation réussi (`app.dart`)

**Avant** le renvoi des brouillons :

```dart
await ref.read(noteMediaComposerProvider).resendPending();
await ref.read(notesOutboxProvider)();
```

### 4. Le PDF

```dart
NotePdfExporter().build(
  title: …,
  contentJson: …,
  loadImage: ref.read(noteImageLoaderProvider),
);
```

Fichier local tant qu'il existe, sinon l'URL signée téléchargée juste avant.

### 5. Deux correctifs dans le code de N2 — **faits à l'intégration**

- **Le contenu envoyé** (`noteUpsertPayload`, `notes_repository.dart`) :
  `'content': serverNoteContent(note.content)` — retire les embeds sans clé et
  les champs locaux ; sans cela, toute note qui porte une pièce jointe en
  cours d'envoi reçoit un 422.
- **La purge des brouillons** (`NotesDao.purgeReconciled`) : ne pas effacer un
  brouillon qui attend encore une montée, sinon la version serveur (envoyée
  sans l'embed) le remplace et la pièce jointe disparaît. Fait à l'intégration, par `hasPendingAttachment` sur les candidats (pas
  de `LIKE '%"localId"%'`, qui retiendrait ce mot tapé dans le texte).

  Un bloc en échec définitif garde donc le brouillon local jusqu'à ce que
  l'utilisateur le retire ou le réessaie.

## Comportement

- **Menu** : prendre une photo ou une vidéo (puis « Photo » / « Vidéo » —
  l'appareil du système ne fait qu'un des deux), choisir dans la galerie,
  enregistrer un audio (`VoiceRecorder`, AAC, envoyé en `kind: audio`,
  `audio/mp4`), joindre un fichier (documents et fichiers audio acceptés par
  le serveur). Pas de scan.
- **Préparation** : `DeviceMediaPreparer` (image ≤ 1600 px, JPEG q80, EXIF
  retiré ; vidéo 720p + vignette, durée sondée avant la compression et
  refusée au-delà de `maxDurationSeconds`). Audio et document tels quels.
- **Bornes** : `size ≤ maxBytes` vérifié **avant** le `PUT`. Les causes
  `tooLarge`, `tooLong`, `typeNotAllowed` (`E_NOTE_MEDIA_*`) et `unreadable`
  sont définitives : affichées sur le bloc, jamais rejouées par
  `resendPending` ; « Réessayer » les relance à la main. Une panne réseau
  (`network`) est rejouée.
- **Outbox** : `MediaOutbox` réutilisé avec la racine
  `<support>/note_outbox/` (fichiers dans `note_outbox/message_outbox/`) ;
  `resendPending` y efface ce qu'aucune ligne ne cite.
- **Rendu** : photo pleine largeur (coins arrondis, ratio `width/height`,
  plein écran au toucher) ; vidéo, audio, fichier en carte. Vidéo →
  `ChatVideoScreen` ; audio → `chatAudioControllerProvider` (un son à la
  fois) ; fichier → téléchargé dans le dossier temporaire puis
  `mediaOpenerProvider.openFile`.

## Tests

`flutter test test/features/notes_editor/attachments/`
