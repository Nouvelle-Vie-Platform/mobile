# Statuts façon WhatsApp — onglet Annonces

Spécification issue de la session de cadrage. Fait autorité sur le **rendu** :
la forme de la visionneuse, les gestes, les fonds, le texte, l'horodatage.
Tout écart doit être signalé, pas silencieusement corrigé.

> **Amendé par #130** (tranche 4/4 du chantier « Sparks », plan
> `server-portal/docs/sparks-annonces-audio-video-plan.md`) : la « phase 2 »
> est **livrée** — l'audio et la vidéo des statuts sont servis, stockés et
> joués. Les **deux écarts** que le plan demandait de signaler sont écrits en
> toutes lettres là où ils s'appliquent : la vidéo horizontale garde le fond du
> statut autour d'elle (§4 « Vidéo », §8), et la durée réelle du lecteur prime
> sur les défauts (§4, règle 2).

> **Ce document ne fait plus autorité sur la donnée** (issue #35). Le contrat de
> donnée est celui du serveur — PRD `annonces-comptes-officiels.md`, ADR-0029 à
> ADR-0031 — et il a retiré au mobile trois valeurs que ce document décrivait :
> `author`, `tag` et `backgroundColor`. Les §2, §8 et §11 ont été récrits en
> conséquence, et le pourquoi y est écrit plutôt que résumé : là où le serveur
> sert désormais un **identifiant à joindre** au lieu d'une valeur résolue,
> c'est qu'une valeur résolue est une valeur **figée**, qu'aucun renommage ni
> aucun changement de palette ne viendrait rafraîchir sur les téléphones.

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

Statuts **à plat** (pas de groupement par compte), chacun portant de quoi
composer son en-tête. Le type n'est **pas** déclaré par une énumération : il est
**déduit** de ce qui est présent (composition).

Le modèle mobile est un **modèle de lecture** (`lib/models/announcement_view.dart`,
`AnnouncementView`) : il porte ce qu'un écran affiche, déjà résolu, et rien de
plus. Ce que le magasin stocke, lui, est ce que le serveur envoie — deux
identifiants nus qui se **joignent** à la lecture.

| champ du modèle de lecture | type | rôle |
|---|---|---|
| `id` | `String` | stable — repli waveform, teinte de repli, clés de pager |
| `publishedAt` | `DateTime` (UTC) | date de publication ; **formatée côté client**, jamais par le back |
| `title` | `String?` | absent ⇒ bloc de texte centré façon WhatsApp |
| `body` | `String?` | corps du statut |
| `accountId` | `int?` | **seul champ non destiné à l'affichage** (#36) : il répond à « ce statut est-il de l'un de mes comptes ? », donc à l'existence des actions modifier/supprimer. Comparer `accountName` serait un faux ami — deux comptes de branches différentes peuvent porter le même nom court |
| `accountName` | `String?` | en-tête — `shortName ?? name` du **compte officiel joint** |
| `accountAvatarUrl` | `String?` | avatar du compte, URL déjà résolue |
| `backdrop` | `StatusBackdrop?` | trois arrêts de dégradé + encre, **servis** ; `null` ⇒ repli |
| `backgroundImageUrl` | `String?` | image de fond (`Image.network` + `errorBuilder` obligatoire) |
| `expiresAt` | `DateTime?` | `null` = n'expire jamais (défaut) |
| `isPinned` | `bool` | épinglé en tête de liste |
| `audio` / `video` | `StatusAudio?` / `StatusVideo?` | **livré (#130)** — au plus un des deux, lu des cinq champs `media*` (voir ci-dessous) |

### Le média — cinq champs à plat, un seul lecteur de contrat

Le serveur sert, sur chaque annonce, `mediaKind` (`'audio'`, `'video'` ou
`null`), `mediaUrl` (playlist HLS maître : deux rendus, segments de 5 s, son
normalisé à −16 LUFS), `mediaPosterUrl` (affiche d'une vidéo : l'image déposée,
sinon la vignette extraite), `mediaDurationMs` (mesurée par le transcodeur) et
`mediaWaveform` (36 hauteurs de 0 à 100, audio). Une annonce dont le média n'est
pas prêt **ne transite pas**.

Le magasin les stocke **bruts**, en colonnes (schéma v19). Ils deviennent
`StatusAudio` / `StatusVideo` à la lecture, par **une seule fonction**,
`readStatusMedia` (`lib/models/announcement_view.dart`) :

- un genre inconnu, ou un genre **sans URL**, se lit « pas de média » — le
  statut s'affiche avec ce qu'il a d'autre ;
- les URL passent par `resolveMediaUrl` ;
- l'affiche d'une vidéo se replie sur `backgroundImageUrl` (« une image, deux
  rôles », décision 5 du plan) ; `StatusVideo.poster` est donc nullable, mais
  le serveur la sert sur **tout** statut vidéo ;
- une durée nulle vaut inconnue.

Le palier v18 → v19 **efface le curseur** d'`announcements` : un téléphone resté
en v18 a pu recevoir une annonce à média et en jeter le média faute de colonne,
et rien ne la lui aurait renvoyée.

### Trois champs sont partis, et ne reviendront pas par l'affichage

- **`author`** — remplacé par `accountId` côté ligne, **joint** sur
  `official_accounts`. Une chaîne d'auteur recopiée dans chaque annonce est une
  valeur figée : renommer le compte ne bouscule l'`updatedAt` d'aucune annonce,
  donc aucune ligne ne repasserait par le flux delta pour corriger la copie, et
  les téléphones garderaient l'ancien nom indéfiniment et en silence.
- **`backgroundColor`** — remplacé par `backgroundId`, **joint** sur
  `status_backgrounds`. Même raisonnement, et un second : la palette de cinq
  teintes codées en dur (`statusPalette`) était une décision figée à la
  livraison, alors qu'un fond s'ajoute désormais depuis le portail.
- **`tag`** — abandonné. Le compte officiel occupe déjà l'en-tête ; « COE » en
  auteur *et* en pastille disait deux fois la même chose. Le serveur ne le sert
  pas.

Et trois autres avec eux, faute de source serveur : **`durationMs`**,
**`actionLabel`** et **`actionRoute`** (voir §4 et §11).

Un getter dérivé `StatusKind get kind` (`text` / `image` / `audio` / `video`)
sert uniquement aux rares cas à valeur unique (icône de vignette).
**Le rendu ne fait pas de `switch`** : il empile ce qui existe.

> ⚠️ `DateTime` n'est pas constructible en `const` : les listes de
> `SampleData` sont `static final`.

## 3. Cycle de vie du feed

**Trois responsabilités appartiennent au client, et le serveur ne les prendra
pas.** C'est le cœur du contrat, et chacune a une raison précise.

1. **Filtrer l'expiration.** Le serveur sert `expiresAt` brut et ne retire
   **jamais** une annonce expirée du flux delta. Un statut « valable jusqu'à ce
   soir » doit disparaître **à la seconde**, y compris hors-ligne : un filtrage
   serveur le laisserait affiché jusqu'à la prochaine synchronisation, et un
   filtrage SQL aussi — une requête est évaluée quand la table change, pas quand
   l'heure passe. Le filtre vit donc dans `announcementsProvider`, au plus près
   du rendu. Un statut périmé **disparaît complètement** (pas de grisé).
2. **Trier** : épinglés d'abord, puis `publishedAt` décroissant, puis `id` en
   départage. `List.sort` n'est pas stable en Dart : sans ce dernier maillon,
   deux statuts publiés à la même seconde changeraient d'ordre d'un `build` à
   l'autre, et le pager sauterait sous le doigt.
3. **Joindre** : `accountId` → le nom du compte, `backgroundId` → les trois
   arrêts de dégradé et l'encre. Jointures **tolérantes** : une annonce dont le
   compte n'est pas encore arrivé s'affiche quand même, sans en-tête inventé.

Ce que le client ne fait **pas** : re-tester `publishedAt`. Le serveur ne sert
au mobile ni brouillon ni annonce programmée — tout ce qui arrive est publiable,
et re-tester la visibilité reviendrait à réimplémenter une règle serveur avec
l'horloge de l'appareil pour arbitre.

- **Aucun plafond dans le pager** : il contient tout ce que le magasin porte.
  C'est au back de décider combien il expose. C'est la **barre de segments** qui
  est plafonnée (fenêtre glissante d'une dizaine de segments).
- **Entrée sur le plus récent**, progression vers les plus anciens.
- **Pas d'état « déjà vu »** en phase 1 (ni pastille non-lu sur l'onglet). L'UI
  dessine déjà les segments vus en gris, ce qui avec tout à `false` donne
  naturellement « démarrer au premier ».
- **Trois états à dessiner, distincts** : chargement, vide et erreur. La source
  est le magasin local, donc un `AsyncValue`. Un magasin vide au premier
  lancement est la réponse **normale** — la synchronisation ne l'a pas encore
  rempli — et ne doit jamais ressembler à une base illisible (`AppErrorState`,
  teinté, avec « Réessayer »).

## 4. Lecture des médias

Abstraction `StatusPlayer` exposée par `statusPlayerProvider`, sur le modèle
déjà en place de `churchRepositoryProvider` :

- **phase 1** : implémentation factice (`FakeStatusPlayer`) — toujours le
  défaut du provider, donc celle des tests, et celle du **web** ;
- **phase 2 — livrée (#130)** : `MediaStatusPlayer`
  (`lib/data/players/media_status_player.dart`), `just_audio` pour l'audio,
  `video_player` pour la vidéo HLS, une horloge pour le reste. Branchée par
  `main.dart` sur mobile. **Aucun écran n'a changé de structure** : le contrat
  s'est élargi de ce que la vidéo exige — le genre du média à `load`, les
  dimensions et la première image dans la valeur observée, et
  `videoSurface()`, le widget qui peint l'image décodée.

Le web garde le lecteur factice : ni `just_audio` ni le `<video>` de Chrome ne
lisent le HLS hors Safari (#46). Un statut média y défile avec son affiche, sans
son — un défaut assumé, pas un oubli.

Règles non négociables :

1. **L'auto-avance et l'horloge appartiennent au lecteur, jamais au widget.**
   Le widget est passif : il écoute une position et une progression. C'est ce qui
   rend les tests déterministes (un timer dans le `State` survit à l'override du
   provider et fait échouer les tests sur « pending timer »).
2. **Durée effective** = durée réelle du lecteur → sinon la durée du média
   mesurée par le transcodeur (`mediaDurationMs`) → sinon défaut par type :
   **5 s** (texte / image), **30 s** (audio / vidéo). La **durée d'affichage**
   par statut (`durationMs`) a disparu du modèle : le serveur n'en sert aucune.

   ⚠️ **Écart signalé (plan « Sparks », §4) — confirmé à la livraison** : les
   défauts restent, mais **la durée réelle du lecteur prime** dès qu'il la lit
   dans le média, sur la durée annoncée comme sur le défaut. La chaîne est
   écrite une fois, `effectiveStatusDuration` (`status_player.dart`) : l'écran
   l'appelle sans durée réelle pour la durée de repli qu'il passe à `load`, le
   lecteur réel l'appelle quand le média dit la sienne. Une durée nulle ne
   compte pour aucun maillon.
3. Les médias **vont jusqu'à leur fin** ; un tap coupe court.
4. **Fin du dernier statut** : on reste figé dessus, barre pleine. Pas de boucle.

5. **Un média qui ne s'ouvre pas ne bloque pas le mur** (#130) : hors ligne ou
   sur une playlist refusée, le statut retombe sur l'horloge avec sa durée de
   repli, et défile comme un statut sans média.

### Vidéo — livrée (#130)

`StatusVideoLayer` (`widgets/status/status_video_layer.dart`) prend la place de
l'image de fond dans `StatusBackground` :

1. **l'affiche** couvre le chargement, jusqu'à la **première image** de la
   vidéo — jamais un carré noir ; les pages voisines du pager n'affichent que
   leur affiche ;
2. puis **la vidéo**, et l'affiche s'efface ;
3. **le cadrage** (décision 11 du plan, règle `statusVideoFraming`) : une vidéo
   **verticale occupe le fond** ; une vidéo **horizontale** — ou carrée — est
   **gardée entière, centrée sur le fond du statut, jamais recadrée**. La même
   règle cadre l'affiche, d'après ses propres dimensions.

⚠️ **Écart signalé (plan « Sparks », §4)** : pour une vidéo horizontale, « le
fond *est* la vidéo » (§8) devient faux — **le dégradé du statut subsiste
autour d'elle**. On ne coupe jamais ce que quelqu'un a cadré.

Le texte reste clair sur une vidéo, rendu lisible par le voile ; le bouton
central reste translucide sur un statut vidéo.

### Le son, et le lecteur principal (#130)

- **Les gestes s'appliquent au son** sans rien de neuf : doigt maintenu = pause
  du son, quitter l'onglet = pause, tap = statut suivant (le son du statut
  quitté s'arrête avec son chargement).
- **Cohabitation avec la radio et les enseignements** (décision utilisateur du
  05/10/2026) : si le lecteur principal joue quand un statut **à son** (audio
  ou vidéo) démarre, il se met **en pause** — avant que le statut ne parle —,
  puis **reprend tout seul quand on quitte la visionneuse** (changement
  d'onglet, démontage) : **la radio au direct** (la source est rouverte et le
  cookie renégocié, `RadioListening.rejoinLive`), **un enseignement à sa
  position**. Un statut **texte ou image n'interrompt rien**. Revenir d'un
  statut à son vers un statut muet ne fait rien reprendre : on est toujours
  dans la visionneuse. Un doigt maintenu, la liste ou l'arrière-plan non plus.
- C'est le **contrôleur global** qui tient la parenthèse
  (`PlaybackController.interruptForStatus` / `resumeAfterStatus`), pas un
  second contrôleur. Le lecteur reste juge : un contenu arrêté, remplacé ou
  déjà relancé pendant le statut ne revient pas.
- Le statut joue son son **muet ou non** selon le bouton muet ; le bouton muet
  ne change pas la règle de cohabitation — un statut audio ou vidéo
  interrompt, qu'il soit muet ou non.

## 5. Waveform

- **28 à 40 barres**, volontairement grossières.
- Hauteurs **précalculées par le back** (`List<int>`, 0–100) — **livré
  (#130)** : trente-six, tirées de la passe de normalisation du transcodeur,
  stockées telles quelles et bornées à 0..100 à la lecture. L'écran les
  ré-échantillonne au nombre de barres qu'il dessine.
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

- **Dégradés, pas d'aplats** (l'app est entièrement construite sur des dégradés
  et du verre dépoli).
- **Le fond est servi, pas déduit.** Le référentiel `status_backgrounds` porte
  pour chaque fond une teinte de base, **les deux autres arrêts du dégradé** et
  **l'encre** — tous dérivés par le serveur à l'écriture (ADR-0030). Le rendu ne
  fait que peindre.
- **Interdit : recalculer un dégradé ou un contraste à partir de
  `backgroundId`.** Deux raisons, et la seconde est la plus dure à rattraper :
  un client qui dérive ses propres arrêts rend deux fonds différents pour la
  même annonce selon la version installée ; et un client qui déduit l'encre de
  la luminance refait un calcul déjà fait — donc le refera différemment un jour,
  sur un or pâle, sans que personne le voie avant les utilisateurs.
- **Repli, et repli seulement** : quand `backgroundId` est nul (aucun fond
  choisi) ou que le référentiel n'a pas encore livré la ligne, la teinte est
  choisie **déterministement par hash de l'`id`** (`statusBaseColor`), le
  dégradé s'en déduit (`statusGradient`) et la luminance tranche l'encre
  (`statusForegroundOn`). Jamais `Random()` : la même annonce doit garder la
  même apparence d'un `build`, d'une session et d'une plateforme à l'autre.
  C'est le **seul** endroit de l'application où une variation de couleur se
  calcule encore.
- `statusPalette`, la liste publique des cinq teintes, **a disparu** : ce qui
  reste est privé à `status_palette.dart` et ne se lit plus de l'extérieur — un
  écran qui y puiserait recommencerait à choisir des couleurs dans le binaire.
- **Image de fond** : `Image.network` + `errorBuilder` **obligatoire** (règle du
  `CLAUDE.md` : sinon échec hors-ligne *et* en test, le réseau renvoyant 400),
  repli sur le dégradé déjà peint dessous, plus un voile dégradé derrière le
  texte. En présence d'une image, le texte est **toujours clair** : c'est le
  voile qui garantit alors la lisibilité.
- **Vidéo** : une vidéo **verticale** est le fond ; une vidéo **horizontale**
  est gardée entière, centrée, et **le dégradé du statut subsiste autour
  d'elle** (écart signalé, #130 — voir §4 « Vidéo »). La couleur couvre aussi
  le temps de chargement quand il n'y a pas d'affiche.

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

- **Consultation pure pour la quasi-totalité des fidèles.** Pas de réaction, pas
  de réponse — il n'y a pas de messagerie personnelle, et le bas de l'écran est
  occupé par la barre et le FAB.
- **Le bouton d'action optionnel a été retiré du modèle.** `actionLabel` et
  `actionRoute` étaient « prévus, inertes en phase 1 » ; le serveur ne les sert
  pas et ne les servira pas dans ce lot. Un champ que le back ne sert pas
  fabrique de la donnée en mode maquette — donc un écran qui marche sur les
  fixtures et se vide en production (#33). L'emplacement au-dessus de la barre
  du bas reste libre : il se rouvrira le jour où une colonne existera.

### Écriture — la composition depuis l'app

**Livrée par #36.** Elle **existe**, contrairement à ce que disait le cadrage
initial, mais pour une poignée de personnes seulement, et sous trois règles.

1. **Elle exige le réseau** (ADR-0031). Pas de file d'envoi, pas de brouillon
   local, pas d'`id` fabriqué hors-ligne. « Publier maintenant » choisi lundi et
   synchronisé jeudi n'a aucune bonne interprétation : publié lundi, l'annonce
   arrive enterrée sous trois jours de statuts et peut être expirée à sa
   naissance ; publié jeudi, le serveur écrase le choix de l'auteur.
2. **Le bouton n'existe que si `official_account_memberships` est non vide.**
   Pour tous les autres, l'onglet reste une **visionneuse**, sans affordance
   d'écriture ni menu caché.
3. **La collection d'appartenances est un confort d'affichage, jamais une
   autorisation.** Le serveur revérifie à chaque écriture : un membre retiré du
   bureau dont le téléphone n'a pas synchronisé verra encore le bouton et
   recevra un **403**. L'UI traite ce cas proprement, elle ne s'y appuie pas
   comme sur un droit acquis.

Endpoints : `POST /announcements`, `PUT /announcements/:id`,
`DELETE /announcements/:id`, corps en **`camelCase`**, guard `api`, image en
`multipart`. Le client envoie `accountId`, `title`, `body`, `backgroundId`,
`publishedAt`, `expiresAt`. Il **n'envoie jamais** `branchId` (dérivé du
compte côté serveur), ni `audienceId`, ni `isPinned`, ni `notify` — ces
trois-là sont refusés en **422** pour un membre de compte.

> **`camelCase`, et non `snake_case`.** Le cadrage disait l'inverse ; il avait
> tort. Chez ce serveur, le `snake_case` ne concerne que les **query strings**
> (`?branch_id=`, `?from=`) et l'enveloppe `/sync`. Les **corps** de son API REST
> sont en `camelCase` de bout en bout : `create_announcement_controller` valide
> `branchId` et `clientCreatedAt`, `update_profile_controller` valide
> `firstName`, et `HttpAuthRepository` poste déjà `firstName` / `branchId`. Un
> corps en `snake_case` serait refusé par le validateur VineJS sur chaque clé.

#### Ce que le composeur dessine

L'écran est `screens/announcement_composer_screen.dart`, **un seul pour la
création et la modification** : mêmes champs, mêmes règles de validité, même
traitement des refus. Deux écrans jumeaux auraient divergé au premier correctif.

- **Le sélecteur de compte, et pas de sélecteur de branche.** Choisir le compte
  *est* choisir la portée : le serveur la dérive. Avec un seul compte — le cas
  dominant — la ligne s'affiche sans radio, parce que ce n'est plus un choix.
- **Le sélecteur de fond** propose les lignes `isActive` de `status_backgrounds`
  triées par `position`, et **peint les trois arrêts servis**. Un fond désactivé
  au portail n'y figure plus mais **reste peint** sur les annonces qui le
  portent. Un fond dont les couleurs ne se lisent pas n'est pas proposé : la
  pastille *est* le dégradé, et il n'y a pas de repli honnête (celui du mur est
  dérivé de l'identifiant de l'annonce, qui n'existe pas encore).
- **L'image** se choisit dans la photothèque, derrière l'abstraction
  `StatusImagePicker` (`data/pickers/`) — les tests injectent un sélecteur
  inerte. Pas d'appareil photo : une annonce d'église est une affiche préparée,
  pas une photo prise dans l'instant. Une **affiche** (image seule, sans texte)
  est le cas le plus courant, pas une exception tolérée.
- **Trois modes de publication, un seul champ.** Maintenant ⇒ `publishedAt`
  **omis** (l'horloge est celle du serveur, pas celle d'un téléphone qui dérive).
  Programmer ⇒ l'instant choisi, en UTC. Brouillon ⇒ `publishedAt` **nul
  explicite**. La nuance « clé absente / clé nulle » décide si l'annonce paraît.
- **Validité, vérifiée avant tout appel réseau** : au moins un titre, un corps ou
  une image ; `expiresAt > publishedAt`. Titre et corps vides après `trim`
  valent `null`, jamais `''`.

#### Modifier et supprimer

Un compte officiel est un espace éditorial **collectif** : un membre peut
corriger et retirer **toute** annonce de ses comptes, pas seulement les siennes.
Le lecteur tient le comité pour responsable de ce qui est signé de son nom, et un
comité doit pouvoir se corriger. L'affordance apparaît donc sur `accountId`, pas
sur `ownerId`.

Le composeur repart de la **ligne brute** (`AnnouncementDao.announcementById`),
jamais d'`AnnouncementView` : celui-ci a remplacé les identifiants par un nom de
compte et trois arrêts de dégradé, et retrouver un identifiant depuis un libellé
n'a pas de solution quand deux comptes ont le même nom court. La route porte
l'identifiant (`/announcement/:id/edit`) et l'écran résout à chaque `build` — une
annonce retirée pendant qu'on la modifie s'affiche comme une **absence**.

#### Les refus, dits en langage humain

| Cause | Ce que lit l'auteur |
|---|---|
| pas de réponse (hors ligne) | « Publier demande une connexion internet. Votre saisie est conservée. » |
| **403** — retiré du bureau | « Vous ne publiez plus pour ce compte » |
| **422** | le message du serveur, seul cas où il parle du contenu saisi |
| **404 / 410** | « Elle a été supprimée entre-temps, peut-être par un autre membre » |
| **5xx** | « Le serveur ne répond pas correctement » |
| **401** | « Session expirée » — la purge et le retour à `/auth` sont déjà faits |

Jamais un code HTTP, jamais un `toString()` d'exception. Et dans tous les cas
**la saisie reste à l'écran** : l'échec vit dans l'état du formulaire, il ne
ferme rien.

#### Ce que le composeur ne fait pas

Il **n'écrit pas dans le magasin local**. Après un envoi réussi il déclenche un
cycle de synchronisation (`pullToRefreshProvider`) et rend la main : c'est le flux
delta qui ramène l'annonce. Écrire la ligne nous-mêmes demanderait d'inventer un
identifiant, une branche dérivée et un horodatage — trois valeurs que seul le
serveur connaît.

#### Le dépôt d'image, et la chaîne vide

Deux points que le cadrage laissait ouverts, tranchés depuis :

1. **Le champ de fichier s'appelle `backgroundImage`** — `camelCase` comme le
   reste du corps et comme les dépôts d'image existants du serveur
   (`save_teaching_controller` reçoit `imageLandscape` / `imagePortrait`). Sans
   le suffixe `Url` de la colonne `background_image_url` : ce qui monte est un
   fichier, ce que la colonne garde est le chemin que le serveur en dérive.
2. **La chaîne vide vaut `null`, et c'est une règle du contrat**, pas un
   contournement du multipart. Le PRD §18 la pose déjà pour `title` / `body` ;
   elle s'étend à `publishedAt` — donc une chaîne vide **fait un brouillon** —,
   `expiresAt` et `backgroundId`.

   C'est elle qui permet aux trois modes de publication de rester repliés sur le
   **seul** `publishedAt`, en JSON comme en multipart. L'alternative — un booléen
   `draft` de plus, uniquement quand un fichier est joint — ferait diverger le
   mobile du portail, qui exprime déjà les trois modes sur ce seul champ, et
   introduirait deux façons de dire « brouillon » dont une seule serait jamais
   testée.

Et une limite assumée : **le composeur ne sait pas retirer une image déjà
publiée**, faute de champ pour l'exprimer dans le contrat. Une affiche ne peut
donc pas redevenir un statut texte depuis le mobile.

### Hors périmètre assumé

Réactions et réponses · partage / lien profond · état « déjà vu » persistant ·
**le dépôt d'un média depuis l'application** : le serveur le refuse par
décision éditoriale (décision 8 du plan « Sparks » — de la vidéo non relue
partirait à toute l'église). Les médias de statut, eux, sont **livrés** (#130).

Le libellé de l'onglet (« Sparks » côté portail, décision 1 du plan) n'est
**pas** écrit dans le dépôt : il doit venir du vocabulaire réglable. ⚠️ À la
livraison de #130, l'onglet lit encore `context.l10n.navAnnouncements` et le
catalogue serveur (`vocabulary_catalog.ts`) n'a pas de clé `mobile` pour lui :
le mot réglé au portail n'y arrive donc pas encore. Il faut une entrée de
catalogue côté serveur, puis `context.words` côté mobile.

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
3. **Repli** — statut sans fond servi : rendu sans erreur (teinte dérivée de
   l'`id`) ; statut avec image réseau : le chemin `errorBuilder` s'exécute (le
   réseau renvoie 400 en test) et **doit** être couvert.
4. **Jointures** — un statut dont le compte n'est pas dans le magasin s'affiche
   **sans en-tête** et sans « Compte inconnu » ; un fond servi est peint avec ses
   trois arrêts, sans qu'aucune teinte de repli ne s'y glisse.
5. **Cycle de vie** — une annonce expirée ne sort pas du provider, une expiration
   à venir reste affichée, et l'ordre est : épinglés, date, `id`.
6. **États** — une lecture de magasin en échec se lit comme une **panne**
   (`AppErrorState`), jamais comme un mur vide.

Les données fictives doivent contenir **un exemplaire de chaque forme** : texte
seul, texte long qui déborde, image seule, fond servi, **fond absent**,
**compte absent du magasin**, un avec `expiresAt` à venir, un expiré, un
épinglé. `SampleData` ne contient **ni audio ni vidéo**, même depuis #130 : un
média de statut est une playlist **transcodée**, et une URL inventée ne
jouerait rien. Les fixtures de synchronisation, elles, en portent
(`audioAnnouncementPayload`, `videoAnnouncementPayload`), relevées sur le
transformer du serveur.

Tests de #130 : `test/models/status_media_test.dart` (lecture des champs
`media*`), `test/sync/announcement_media_collection_test.dart` (du flux au
modèle de lecture), `test/data/local/migration_test.dart` (palier v19),
`test/data/status_player_test.dart` (durée effective, contrat),
`test/widgets/status_video_layer_test.dart` (cadrage, affiche puis vidéo),
`test/screens/announcements_screen_test.dart` (chargement des médias,
waveform servie et repli, gestes, cohabitation) et
`test/state/status_interruption_test.dart` (pause et reprise du lecteur
principal). **Aucun ne monte de vrai lecteur** : les états se peignent par
`InertStatusPlayer.emit` et une surface témoin.

## 13. Découpage en commits

Chaque commit compile, `flutter analyze` à 0 problème, `flutter test` vert.

1. `refactor(announcements)` — évolution du modèle, données fictives couvrant
   toutes les formes, horodatage relatif localisé, **et adaptation de l'écran
   actuel pour qu'il continue de fonctionner tel quel**. Point de retour propre.
2. `feat(status)` — `StatusPlayer` + `statusPlayerProvider` + implémentation
   factice. Aucun rendu.
3. `feat(announcements)` — visionneuse plein écran : pager, gestes, barre de
   segments, fonds, waveform, texte adaptatif.
4. `feat(announcements)` — feuille modale liste + FAB translucide + bouton muet.

Deux écarts assumés à l'exécution :

- le **cycle de vie** (pause hors onglet, `AppLifecycleState`) est passé du
  commit 4 au commit 3 : livrer une visionneuse qui joue du son en tâche de
  fond n'est pas un état intermédiaire acceptable ;
- les **tests accompagnent chaque commit** au lieu d'être regroupés dans un
  cinquième. Un commit qui livre un pager piloté par une minuterie sans test
  qui le monte est exactement ce qui casse en CI trois jours plus tard.

`AnnouncementCard` est **réutilisé en le compactant** pour les vignettes de la
feuille modale, pas supprimé : il porte déjà le compte, la date et le titre.

### Le lot de bascule (#35)

La visionneuse livrée par les quatre commits ci-dessus était peinte par
`SampleData`. Le passage au magasin local s'est fait en trois commits de plus,
dans l'ordre où le socle de la médiathèque l'avait fait avant elle :

1. `feat(magasin)` — les quatre tables (`status_backgrounds`,
   `official_accounts`, `official_account_memberships`, `announcements`), leur
   DAO de lecture et le palier de migration v3 ;
2. `feat(sync)` — les quatre collections au registre du moteur, référentiels
   avant contenu, et les fixtures qui écrivent le contrat serveur ;
3. `feat(annonces)` — le modèle de lecture, le repository dédié, les providers,
   les widgets et l'écran passé à l'`AsyncValue`.

## 14. Risques identifiés

- **Cohabitation des trois reconnaisseurs de gestes** (pager horizontal, zones
  de tap, maintien-pause) — ordre de composition critique.
- **Couplage `HomeShell` → onglet actif**, à poser proprement au commit 4 et non
  à bricoler après coup : ajouté trop tard, il oblige à remonter l'état d'onglet
  dans toute la coquille.
