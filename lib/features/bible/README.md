# `bible` — le module Bible (M1 à M7, mobile#199–#205)

Plan qui fait foi : `server-portal/docs/module-bible-plan.md` (contrats §3,
arbitrages §6). M1 pose le socle ; M2 à M7 s'y branchent par les
emplacements, **sans changer le schéma**. L'assemblage a fait les
branchements entre tranches (voir « Branchements » en fin de page).

## Arborescence

| Dossier | Tranche | Contenu |
|---|---|---|
| `data/` | M1, C3, C4 | `canon.dart` (66 livres, versets par chapitre), `bible_source.dart` (`BibleSource`, `BibleCatalog`), `versification.dart` (la versification **d'une version**, C3), `placeholder_bible.dart` (Bible factice, versions EXA / EXB — le repli), `bible_archive.dart` (l'archive téléchargée : empreinte, dézippage, `InstalledBibleSource`, C4), `bible_providers.dart` |
| `shell/` | M1 | `bible_shell.dart` (cinq onglets, mode sélection), `bible_browser.dart` (livres → chapitres → versets), `bible_slots.dart` (les emplacements) |
| `reader/` | M1 | `bible_reader_screen.dart` (le lecteur) |
| `marks/` | M2 | sélection, menu d'action, Favori, marges, file d'envoi, fusion à la connexion |
| `search/` | M3 | recherche simple, croisée, comparative ; index `bible_fts` |
| `personalize/` | M4 | thèmes, audio, partage, versions et hors ligne, Mon espace, rappels, Paramètres |
| `plans/` | M5 | plans, défis, badges |
| `quiz/` | M6 | quiz |
| `home/` | M7 | l'accueil du module |

## Routes

| Route | Écran |
|---|---|
| `/bible?tab=home\|bible\|favorites\|notes\|more` | `BibleShell` ; sans `tab`, le dernier onglet (`SettingsDao.bibleTab`) |
| `/bible/read/:book/:chapter?v=16-18` | `BibleReaderScreen` — `BibleReaderScreen.push(router, BibleLink(...))` |
| `/bible/select` | `BibleShell(selectMode: true)` — dépile avec un `BibleLink` |
| `/bible/personalize/:page` | M4 : `appearance`, `offline`, `my-space`, `settings`, `studio?ref=John/3/16&v=EXA` — `openBiblePersonalize(ref, …)` |

Un lien de note `nv://bible/John/3/16-18` ouvre le lecteur au verset 16, 16–18
surlignés un instant (`NoteLinkOpener`). Toujours naviguer par
`ref.read(routerProvider)`, jamais par le `BuildContext`.

## Données

- **Références** : `BibleLink` (`notes_editor/links/note_link.dart`, réexporté
  par `data/canon.dart`) — `book` OSIS, `chapter`, `from?`, `to?`, `labelFr`,
  `toUrl()`. Indépendante de toute version. `isValidBibleRef` la borne au canon.
- **Canon** : `bibleCanon`, `bibleBook(osis)`, `BibleBook.versesIn(c)`,
  `bibleChapters` (les 1 189 chapitres dans l'ordre), `bibleChapterIndex`.
- **Texte** : `bibleChapterProvider((version:, book:, chapter:))`. Version
  active : `activeBibleVersionProvider` (`.notifier.select(code)`). Catalogue :
  `bibleCatalogProvider` (factice : EXA « Version d'exemple A », EXB « … B »,
  installées d'office), `bibleVersionsProvider`. M4 remplace le catalogue en
  surchargeant `bibleCatalogProvider`, et s'appuie sur `bible_installed_versions`.
- **Position** : `bibleReadingStateProvider` (`BibleReadingSnapshot` : version,
  livre, chapitre, verset, `hasRead`) ; `BibleDao.savePosition` /
  `markChapterRead` écrivent `local_bible_reading_state` (`dirty`). L'envoi
  (`PUT /bible/reading-state`) et la purge au retour du delta sont à M2.
- **Schéma v29** (`data/local/tables/bible_tables.dart`, `bible_fts.drift`) :
  dix miroirs `SyncedRow` (l'appli n'y écrit **jamais** — garde-fou dans
  `bible_dao_test`), quatre `local_bible_*` (brouillons de l'invité + file du
  membre : `dirty`, `clientUpdatedAt`, `lastError`, et `deletedAt` pour les
  marques et les plans), `bible_installed_versions`, `bible_fts(version_code,
  book, chapter, verse, verse_text)` en FTS5 `unicode61 remove_diacritics 2`.
  **Aucune autre tranche ne change le schéma.**
- `isMember` : `bibleIsMemberProvider`. Un invité ne lit jamais un miroir privé.

## Les emplacements — `shell/bible_slots.dart`

Chaque tranche **n'édite que son fichier** `<dossier>/<dossier>_slots.dart`
(créé vide par M1 : `marksSlots`, `searchSlots`, `personalizeSlots`,
`plansSlots`, `quizSlots`, `homeSlots`). `bibleSlotsProvider` les fusionne,
chaque liste triée par `order` (à égalité : l'ordre des tranches). Passer la
déclaration de `const` à `final` dès qu'une fermeture s'y glisse.

```dart
// lib/features/bible/plans/plans_slots.dart
final BibleSlots plansSlots = BibleSlots(
  moreEntries: [
    BibleMoreEntry(
      id: 'plans', order: 10, icon: Icons.event_note,
      label: (context) => context.l10n.biblePlansTitle,
      onTap: (context, ref) => ref.read(routerProvider).pushNamed(...),
    ),
  ],
  homeShortcuts: [BibleHomeShortcut(id: 'plans', order: 10, ...)],
);
```

| Champ de `BibleSlots` | Type | Où ça paraît | Qui |
|---|---|---|---|
| `homeSections` | `BibleHomeSection(id, order, builder)` | onglet **Accueil**, pleine largeur, dans l'ordre ; vide ⇒ écran d'attente | M7 (et M5/M6 s'ils veulent une carte) |
| `homeShortcuts` | `BibleHomeShortcut(id, order, icon, label, onTap)` | **données** pour la rangée de raccourcis que **M7 dispose** (Plans, Défis, Quiz, Hors ligne) | M4, M5, M6 |
| `moreEntries` | `BibleMoreEntry(id, order, icon, label, onTap)` | onglet **Plus**, une ligne chacune (clé `bible_more_<id>`) ; vide ⇒ attente | M4, M5, M6 |
| `verseActions` | `BibleVerseAction(id, order, icon, label, run(context, ref, BibleLink selection, String versionCode, {int? charFrom, int? charTo}))` | **lecteur** : dès qu'il y en a une, toucher un verset le sélectionne (plage contiguë) et une barre d'actions paraît (clé `bible_action_<id>`) ; `charFrom`/`charTo` sont **les mots choisis** dans `selection.from` (#257), `charTo` exclue — les actions qui emportent du texte les mettent en exergue, les autres les déclarent et les ignorent | M2 (copier, favori, surligner, note, partager), M4 (écouter) |
| `favoriteFilters` | `BibleFavoriteFilter(id, order, label, builder)` | onglet **Favori** : une puce par filtre, la liste du filtre choisi dessous ; vide ⇒ attente | M2 |
| `chapterDecorators` | `Map<int, BibleVerseDecoration> Function(WidgetRef ref, String book, int chapter)` | **lecteur** : fond (`background`) et icônes de marge (`marginIcons`) par verset ; appelé dans le `build`, peut `ref.watch` | M2 |

Libellés : `BibleLabel = String Function(BuildContext)` ; gestes :
`BibleTap = void Function(BuildContext, WidgetRef)`. Tests : surcharger
`bibleSlotsProvider` (voir `test/features/bible/bible_module_test.dart`).

M2 peut remplacer la barre d'actions minimale du lecteur par son propre menu
flottant : c'est la seule retouche du lecteur prévue hors emplacements.

## Tests

`flutter test test/features/bible/ test/data/local/bible_dao_test.dart
test/data/local/migration_bible_test.dart test/sync/bible_collections_test.dart`
(un sous-dossier de tests par tranche, et `bible_module_test.dart` pour le
module entier)
— plus le mode sélection de bout en bout dans `test/screens/bible_notes_test.dart`.

## Branchements entre tranches (assemblage)

| Quoi | Où | Comment |
|---|---|---|
| Loupe des en-têtes | `shell/bible_shell.dart` | onglets Accueil et Bible → `BibleSearchScreen.open` (M3), clé `BibleShell.searchKey` |
| Quiz de la semaine | `home/home_view.dart` | **un seul** `featuredQuizProvider` (M6, `quiz/quiz_providers.dart`, filtré par le profil d'âge) ; la carte ouvre le jeu (`QuizEntry.play`) |
| Favori du verset du jour | `home/home_view.dart` | `BibleMarksStore.toggleFavorite` (M2) ; l'état « favori » se lit dans les marques de M2 |
| Partage du verset du jour | `home/home_view.dart` | `bibleVerseSharerProvider` → studio de partage (M4, `openBibleStudio`) |
| Badges de Mon espace | `personalize/my_space_screen.dart` | **un seul** `bibleBadgesProvider` (M5) peint par `BibleBadgeGrid`, puis les badges de quiz (`quizBadgesProvider`, M6) en `BibleMedal` |
| Indexation après installation | `personalize/bible_catalog.dart` | `bibleEnsureIndexedProvider` relit le catalogue dans le magasin puis `BibleSearchIndex.ensureIndexed` (M3) ; une installation remet `indexed` à `false` |
| Voix du quiz enfant | `quiz/quiz_providers.dart` | `quizSpeakerProvider` → `BibleQuizSpeaker` sur `bibleSpeechProvider` (M4, voix du système `stts`) |
| Rappel « Lecture du plan » | `personalize/bible_reminders.dart` | rien sans plan en cours (`bibleCurrentPlanProvider`), pas aujourd'hui si `biblePlanReadingDoneTodayProvider` (M5) ; `app.dart` reprogramme quand la lecture du jour change |
| Après chaque cycle réussi | `lib/app.dart` | **un bloc ordonné** : file des marques (fusion d'invité d'abord, M2), puis plans (M5) et scores (M6) — sautés au cycle d'une fusion —, puis rappels (M4) |
| Purge des files | M2, M5, M6 | une ligne envoyée est purgée au passage suivant, **même si son `id` ne revient pas** (fusion ou refus côté serveur) |

**Pas de voix naturelle.** Piper (`sherpa_onnx`) est retiré : sherpa-onnx
embarque espeak-ng, sous GPL 3.0, incompatible avec les magasins. Seule la
voix du système (`stts`) lit les chapitres et les questions des quiz.

**Durées réglables en test** : `bibleFlashDurationProvider` (surlignage
d'arrivée du lecteur) et `noteDraftDebounceProvider` (`state/notes_providers.dart`,
délai du brouillon de note) — sous `runAsync` leurs minuteries sont réelles.

