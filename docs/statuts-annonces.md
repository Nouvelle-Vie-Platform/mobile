# Statuts façon WhatsApp — onglet Annonces

Spécification issue de la session de cadrage. Fait autorité pour l'implémentation.
Tout écart doit être signalé, pas silencieusement corrigé.

## 1. Forme générale

L'onglet **Annonces** *est* la visionneuse plein écran : pas d'écran d'index en
amont, on entre directement dans le statut le plus récent.

- Un bouton **« liste »** en haut à droite ouvre une **feuille modale**
  (le statut courant se met en pause) listant tout l'historique ; taper une
  vignette saute au statut correspondant.
- La `BottomAppBar` à encoche et le FAB central **restent visibles** ; le
  contenu du statut s'arrête au-dessus. Le FAB devient **translucide** quand le
  statut courant est une vidéo.
- Un **bouton muet** est présent en haut ; son état est mémorisé pour la session
  (provider Riverpod), pas au-delà.

## 2. Modèle de données

Statuts **à plat** (pas de groupement par auteur), chacun portant son auteur pour
l'en-tête. Le type n'est **pas** déclaré par une énumération : il est **déduit**
de ce qui est présent (composition). « Vocal + texte » = `body` et `audio` tous
deux non nuls, sans cas particulier.

`Announcement` évolue (on ne crée pas de second modèle parallèle) :

| champ | type | rôle |
|---|---|---|
| `id` | `String` | stable — repli waveform, couleur dérivée, clés de pager, état vu futur |
| `publishedAt` | `DateTime` (UTC) | date de publication ; **formatée côté client**, jamais par le back |
| `title` | `String?` | absent ⇒ bloc de texte centré façon WhatsApp |
| `body` | `String?` | corps du statut |
| `author` | `String?` | affiché en en-tête |
| `tag` | `String?` | pastille en haut, sous l'en-tête auteur |
| `audio` | `StatusAudio?` | présence ⇒ waveform **sous** le texte |
| `video` | `StatusVideo?` | présence ⇒ fond vidéo |
| `backgroundImage` | `String?` | image de fond (`Image.network` + `errorBuilder` obligatoire) |
| `backgroundColor` | `int?` | couleur de fond ; repli = palette de marque dérivée de l'`id` |
| `durationMs` | `int?` | **durée d'affichage** — distincte de `publishedAt` |
| `expiresAt` | `DateTime?` | `null` = n'expire jamais (défaut) |
| `isPinned` | `bool` | épinglé en tête de liste |
| `actionLabel` / `actionRoute` | `String?` | bouton d'action optionnel — **prévu, inerte en phase 1** |

Un getter dérivé `StatusKind get kind` (`text` / `image` / `audio` / `video`)
sert uniquement aux rares cas à valeur unique (icône de vignette, choix de fond).
**Le rendu ne fait pas de `switch`** : il empile ce qui existe.

> ⚠️ `DateTime` n'est pas constructible en `const` : les listes de
> `SampleData` passent de `static const` à `static final`.

## 3. Cycle de vie du feed

- **Aucune expiration côté client par défaut.** `expiresAt` optionnel ; un
  statut périmé **disparaît complètement** (pas de grisé).
- **Aucun plafond dans le pager** : il contient tout ce que le back envoie.
  C'est au back de décider combien il expose. C'est la **barre de segments** qui
  est plafonnée (fenêtre glissante d'une dizaine de segments).
- **Entrée sur le plus récent**, progression vers les plus anciens.
- **Tri** : épinglés d'abord, puis `publishedAt` décroissant.
- **Pas d'état « déjà vu »** en phase 1 (ni pastille non-lu sur l'onglet). Le
  modèle prévoit le champ ; l'UI dessine déjà les segments vus en gris, ce qui
  avec tout à `false` donne naturellement « démarrer au premier ».
- **État vide** à dessiner explicitement (aucune annonce publiée).

## 4. Lecture des médias

Abstraction `StatusPlayer` exposée par `statusPlayerProvider`, sur le modèle
déjà en place de `churchRepositoryProvider` :

- **phase 1** : implémentation factice (`FakeStatusPlayer`) ;
- **phase 2** : `just_audio` / `video_player`, **sans qu'aucun écran ne change**.

Règles non négociables :

1. **L'auto-avance et l'horloge appartiennent au lecteur, jamais au widget.**
   Le widget est passif : il écoute une position et une progression. C'est ce qui
   rend les tests déterministes (un timer dans le `State` survit à l'override du
   provider et fait échouer les tests sur « pending timer »).
2. **Durée effective** = durée réelle du lecteur → sinon `durationMs` du back →
   sinon défaut par type : **5 s** (texte / image), **30 s** (audio / vidéo).
3. Les médias **vont jusqu'à leur fin** ; un tap coupe court.
4. **Fin du dernier statut** : on reste figé dessus, barre pleine. Pas de boucle.

### Vidéo en phase 1

Poster (image d'aperçu) + badge « vidéo » + barre de progression qui avance.
Rien ne bouge à l'écran, c'est assumé : l'objectif est de valider **maintenant**
la mise en page coûteuse (bandes d'une vidéo verticale, voile derrière le texte,
FAB translucide). Un `poster` est **requis** sur tout statut vidéo, phase 2
comprise.

## 5. Waveform

- **28 à 40 barres**, volontairement grossières.
- Hauteurs **précalculées par le back** (`List<int>`, 0–100).
- **Repli déterministe** dérivé d'un hash de l'`id` — **jamais `Random()`**,
  qui changerait les barres à chaque `build`. Même esprit que le `seed` de
  `Teaching`.
- **Remplissage de gauche à droite** au fil de la lecture (barres jouées
  colorées, à venir translucides).
- **Pulsation** : la barre en cours et ses deux voisines grossissent légèrement.
  Elle est **dérivée de la position de lecture**, *pas* d'un `AnimationController`
  autonome — l'animation s'arrête donc avec un lecteur inerte et l'écran reste
  « settleable » en test.
- Pas d'analyse audio temps réel (`just_audio` ne fournit pas l'amplitude ;
  ce serait un plugin d'analyse de plus et une seconde implémentation sur web).
- **Quand il y a texte + audio, la waveform est en bas du texte.**

## 6. Gestes

- `PageView` **horizontal** (l'axe vertical reste libre pour le texte long).
- `GestureDetector` posé **au-dessus** du `PageView`, zones latérales en
  `behavior: opaque` : tap à droite = suivant, tap à gauche = précédent.
  Dans l'autre sens, le `PageView` avale les taps et rien n'avance.
- **Maintien du doigt = pause** (progression figée, son en pause).
- Le **défilement vertical du texte long suspend l'auto-avance**.

## 7. Cycle de vie de l'écran

`HomeShell` monte les 4 onglets dans un `IndexedStack` : `AnnouncementsScreen`
est **vivant en permanence**, même sur l'onglet Accueil.

- La lecture ne démarre **que** si l'onglet est actif **et** l'app au premier
  plan (`WidgetsBindingObserver` / `AppLifecycleState`).
- Quitter l'onglet ⇒ pause immédiate, progression figée. Y revenir ⇒ reprise.

Sans cette garde, les statuts défilent en tâche de fond et le son peut démarrer
au lancement de l'app.

## 8. Fonds

- **Dégradés**, pas d'aplats (l'app est entièrement construite sur des dégradés
  et du verre dépoli).
- Défaut : palette de marque fermée (4–6 teintes issues d'`AppColors`),
  choisie **déterministement par hash de l'`id`**.
- **Contraste garanti** : la luminance de la couleur reçue décide d'un texte
  clair ou sombre. Sans ça, un jaune pâle envoyé par le back rend l'annonce
  illisible sans que personne s'en aperçoive.
- **Image de fond** : `Image.network` + `errorBuilder` **obligatoire** (règle du
  `CLAUDE.md` : sinon échec hors-ligne *et* en test, le réseau renvoyant 400),
  repli sur la couleur du statut, plus un voile dégradé sombre derrière le texte.
- **Vidéo** : le fond est la vidéo ; la couleur ne sert qu'aux bandes et au
  temps de chargement.

## 9. Texte

- **Taille adaptative par paliers** selon la longueur : court ⇒ très gros et
  centré ; long ⇒ plus petit et aligné en haut.
- **Débordement** ⇒ défilement vertical (voir §6).
- Titre optionnel affiché en accroche ; absent ⇒ bloc unique centré.

## 10. Horodatage

`publishedAt` est une **donnée**, pas du texte d'interface.

- Le back envoie de l'ISO 8601 UTC ; le client formate en relatif et **localisé**
  (`context.l10n` + `intl`). Une chaîne pré-formatée casserait l'i18n (`fr`,
  `en`, `ee`) et se périmerait instantanément.
- Clés à ajouter dans `app_fr.arb` et `app_en.arb`. **`app_ee.arb` reste
  partiel** et retombe sur le français — c'est le comportement déjà en place, et
  inventer de l'éwé approximatif serait pire.

## 11. Interactions

- **Phase 1 : consultation pure.** Pas de réaction, pas de réponse — il n'y a ni
  backend ni messagerie personnelle, et le bas de l'écran est occupé par la barre
  et le FAB.
- **Bouton d'action optionnel** (`actionLabel` / `actionRoute`) : champs présents
  dans le modèle dès maintenant, emplacement réservé au-dessus de la barre du
  bas, bouton affiché **uniquement** si les champs sont remplis. Il ne fait que
  pousser une route existante (`agenda`, `donations`, `groupChat`, `media`,
  `live`). Inerte en phase 1, activable sans retoucher l'UI.

### Hors périmètre assumé

Réactions et réponses · publication depuis l'app (micro ⇒ `record` +
`permission_handler`, à faire en back-office) · partage / lien profond ·
état « déjà vu » persistant · vidéo réellement lue.

## 12. Tests

`test/helpers/pump_screen.dart` utilise `pump()` et **jamais `pumpAndSettle`**.
Un `Timer` qui se replanifie fait échouer le test sur « pending timer ».

- Le lecteur est **écrasable par provider** (`statusPlayerProvider`) : les tests
  injectent un lecteur **inerte** (pas de timer, position figée).
- Pas de drapeau `enableAutoAdvance` dans l'API de production — une porte
  dérobée de test finit par être activée par erreur.

Tests attendus :

1. **Smoke** — la visionneuse se monte et affiche le premier statut.
2. **Injection** — un `_FakeRepository` renvoyant un statut vocal + texte affiche
   texte *et* waveform ; un statut texte seul n'affiche **pas** de waveform.
3. **Repli** — statut sans couleur ni image : rendu sans erreur (couleur dérivée
   de l'`id`) ; statut avec image réseau : le chemin `errorBuilder` s'exécute
   (le réseau renvoie 400 en test) et **doit** être couvert.

Les données fictives doivent contenir **un exemplaire de chaque forme** : texte
seul, texte long qui déborde, vocal seul, vocal + texte, vidéo, image seule, un
avec `expiresAt`, un épinglé.

## 13. Découpage en commits

Chaque commit compile, `flutter analyze` à 0 problème, `flutter test` vert.

1. `refactor(announcements)` — évolution du modèle, données fictives couvrant
   toutes les formes, horodatage relatif localisé, **et adaptation de l'écran
   actuel pour qu'il continue de fonctionner tel quel**. Point de retour propre.
2. `feat(status)` — `StatusPlayer` + `statusPlayerProvider` + implémentation
   factice. Aucun rendu.
3. `feat(announcements)` — visionneuse plein écran : pager, gestes, barre de
   segments, fonds, waveform, texte adaptatif.
4. `feat(announcements)` — feuille modale liste + cycle de vie (pause hors
   onglet, `AppLifecycleState`, FAB translucide, bouton muet).
5. `test` — les trois tests.

`AnnouncementCard` est **réutilisé en le compactant** pour les vignettes de la
feuille modale, pas supprimé : il porte déjà tag, date et titre.

## 14. Risques identifiés

- **Cohabitation des trois reconnaisseurs de gestes** (pager horizontal, zones
  de tap, maintien-pause) — ordre de composition critique.
- **Couplage `HomeShell` → onglet actif**, à poser proprement au commit 4 et non
  à bricoler après coup : ajouté trop tard, il oblige à remonter l'état d'onglet
  dans toute la coquille.
