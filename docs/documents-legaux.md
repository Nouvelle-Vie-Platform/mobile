# Documents légaux, menu latéral & barrière de consentement

Spécification issue de la session de cadrage. Fait autorité sur le **rendu** : le menu de l'accueil,
la mise en page d'un document, la barrière d'acceptation, l'écran « À propos », et le parseur de
Markdown restreint. Tout écart doit être signalé, pas silencieusement corrigé.

> **Ce document ne fait pas autorité sur la donnée.** Le contrat vient du serveur — PRD
> `documents-legaux-et-consentement.md`, ADR-0035 à ADR-0037. En cas de divergence, c'est le serveur
> qui a raison et ce fichier qui est périmé.

---

## 1. Le menu latéral

L'icône en haut à gauche de l'accueil (`home_screen.dart`) est aujourd'hui un `Icon` **nu, sans
`onTap`** — décoratif depuis l'origine. Elle devient l'unique ouverture d'un `flutter_zoom_drawer`.

### 1.1 Où il se construit, et pourquoi là

**Dans `HomeShell.build()`**, pas dans la route `/home`.

```dart
// _HomeShellState.build()
return ZoomDrawer(
  controller: _drawerController,
  menuScreen: AppDrawerMenu(
    currentIndex: _index,
    onHome: () { _drawerController.close?.call(); setState(() => _index = 0); },
  ),
  mainScreen: Scaffold(       // ← c'est LUI qui rétrécit et pivote
    extendBody: true,
    body: IndexedStack(index: _index, children: tabs),
    floatingActionButton: …,  // le FAB médiathèque
    bottomNavigationBar: AppBottomNav(…),
  ),
  disableDragGesture: true,
  …
);
```

Trois points, chacun pour une raison distincte :

1. **Le `mainScreen` est le `Scaffold` entier.** Les quatre onglets, la barre à encoche et le FAB
   rétrécissent ensemble — c'est le rendu attendu du composant. N'envelopper que `HomeScreen`
   laisserait la barre du bas et le FAB **fixes** pendant que le contenu s'écarte au-dessus : le
   composant aurait l'air cassé, pas animé. Le `mainScreen` **repeint `AppBackground`** : celui de
   la route est peint *avant* le tiroir, qui recouvre l'écran de son `menuBackgroundColor`. Et
   `angle: 0` — la coquille glisse et rétrécit, elle ne s'incline pas.
2. **Construit dans `build()` et non dans la route**, pour que `_index` reste un `State` local. Le
   menu le change par un simple rappel. `CLAUDE.md` interdit de remonter l'onglet courant dans un
   provider global — « Riverpod = état **partagé** » — et l'onglet est de l'état de coquille.
3. **`disableDragGesture: true`**, sans négociation. Voir §1.2.

### 1.2 Le geste de glissement est coupé

Le comportement par défaut capte le glissement horizontal sur **tout** l'écran principal. Or
l'écran principal contient :

| | fichier | ce qui se disputerait l'arène |
|---|---|---|
| carrousel d'accueil | `home_screen.dart:496` | `scrollDirection: Axis.horizontal` |
| carrousel d'accueil | `home_screen.dart:799` | idem |
| sections de contenu | `widgets/home/home_content_section.dart:178` | idem |
| visionneuse de statuts | `announcements_screen.dart:339` | `PageView` — **passage d'un statut à l'autre** |

Le dernier est rédhibitoire : son propre en-tête prévient déjà que l'imbrication des gestes y est
« critique », et le `GestureDetector` y enveloppe le `PageView` délibérément. Ajouter un capteur
horizontal **au-dessus** de tout ça rendrait non déterministe, à l'œil, le geste le plus courant de
l'onglet Annonces.

Conséquence acceptée : le menu ne s'ouvre que par l'icône. L'utilisateur ne perd rien — cette
affordance n'a jamais existé.

### 1.3 Contenu et habillage

```
┌──────────────────────┐
│  [emblème]           │   fond : AppColors.gradientPrimary
│  120 px, opacité .68 │   (le même que BrandAppBar)
│  BrandLogo.inverse   │
│                      │
│  🏠  Accueil         │ ← entrée courante : blanc franc, gras
│  📄  CGU             │   les autres : blanc à .55, demi-gras
│  🔒  Politique de    │
│      confidentialité │
│  ℹ️   À propos        │
└──────────────────────┘
```

**L'entête ne porte que l'emblème**, à demi effacé — ni le nom de l'église, qui y figurait, ni rien
d'autre. Un bloc de marque qui concurrence quatre entrées leur vole la première seconde. Et c'est la
variante **inversée** de l'emblème (structure blanche, disque évidé, textes bleus) : la pièce
d'origine poserait un disque blanc plein qui ferait tache sur le dégradé.

**L'entrée courante se signale par sa seule clarté.** La barre d'accent jaune de 4 px qui tenait ce
rôle a été retirée : dans un panneau de quatre lignes, c'est un signal faible qu'il faut aller
chercher, et c'était la seule touche de jaune d'un écran qui n'en a nulle part ailleurs. L'écart de
clarté, lui, se voit sans être cherché. L'alignement n'a pas bougé : la barre occupait 4 px suivis
d'un `AppSpacing.md`, soit exactement le `AppSpacing.lg` de marge que porte désormais la ligne — et
que porte déjà l'emblème au-dessus.

**Quatre entrées, rien d'autre.** Pas de mode sombre, pas d'aide, pas de déconnexion : l'onglet
Profil les porte déjà (`profile_screen.dart`), et les dupliquer laisserait le fidèle chercher lequel
des deux ouvrir pour se déconnecter.

Pas d'entête utilisateur non plus — `_ProfileHeader` fait exactement cela dans l'onglet Profil.
L'emblème porte la **marque**, pas la personne.

Tous les libellés via `context.l10n`. L'icône reste `Icons.menu`, désormais dans un `IconButton`
avec `tooltip`.

### 1.4 Mécanique

- **Le menu se ferme avant toute navigation.** Sans cela, `context.pop()` depuis l'écran CGU
  ramènerait sur une coquille encore rétrécie et pivotée.
- **Le bouton retour Android ferme le menu** au lieu de dépiler la route (`PopScope`) — c'est ce
  qu'attend un utilisateur Android d'un panneau ouvert.
- **Le menu n'existe que sur `/home`.** `/media`, `/teaching/:id` et le lecteur plein écran ne le
  connaissent pas ; les trois autres onglets ne portent pas l'icône. Le geste étant coupé, il n'y a
  aucun moyen de l'ouvrir ailleurs, donc aucune incohérence visible.

---

## 2. Rendu d'un document

`widgets/legal_document_view.dart` rend un document et **rien d'autre** : ni app bar, ni bouton, ni
garde. Deux enveloppes l'utilisent (§3, §4). C'est le motif de `ContentPlayerView`, partagé par les
deux écrans de détail.

### 2.1 Le repli de langue se fait sur le document entier

**La règle `pick` ne s'applique pas ici.** C'est la seule dérogation du dépôt, et elle est décidée
par ADR-0035.

```dart
/// La locale n'est retenue que si TOUTES les sections la portent — `heading`
/// ET `body`. Une seule absence bascule le document ENTIER sur le français.
///
/// Ne pas remplacer par `pick` section par section : voir ADR-0035. Un document
/// en éwé dont trois articles sortent en français est impossible à accepter, et
/// il s'affiche parfaitement — aucun test existant ne rougirait.
String resolveLegalLocale(List<LegalSection> sections, String wanted) { … }
```

Le résultat est binaire : **intégralement** dans la langue demandée, ou **intégralement** en
français. Aucun état intermédiaire.

La locale demandée vient de `contentLocaleProvider` (`lib/state/locale_providers.dart`), comme pour
tout le contenu servi par le back.

Un test vérifie qu'une **seule** section manquante bascule tout le document — pas « la majorité ».

### 2.2 Markdown restreint — quatre constructions, et un parseur du dépôt

Le `heading` d'une section étant un champ à part, le `body` n'a plus besoin de titres. Il ne lui
reste que du formatage en ligne :

| construction | syntaxe | rendu |
|---|---|---|
| gras | `**texte**` | `FontWeight.w700` |
| italique | `*texte*` | `FontStyle.italic` |
| lien | `[libellé](url)` | couleur d'accent + soulignement, `TapGestureRecognizer` |
| liste à puces | ligne commençant par `- ` | puce + retrait |

**Rien d'autre.** Pas de titres, pas de tableaux, pas d'images, pas de code, pas de citations.

`utils/inline_markdown.dart` — environ 120 lignes vers des `TextSpan`, sans dépendance. Deux règles
de conception :

- **Ce qui n'est pas reconnu se rend littéralement.** Un `#` en début de ligne s'affiche comme un
  `#`, il n'est pas avalé. Un texte légal qui perdrait silencieusement un caractère serait pire
  qu'un texte légal un peu laid.
- **Aucun HTML n'est interprété**, quelle que soit l'origine du texte.

Pourquoi pas un paquet : `flutter_markdown` a été **abandonné par l'équipe Flutter**, les reprises
sont communautaires, et il faudrait de toute façon recabler entièrement leur thème sur
`context.palette` sous peine de texte noir sur fond sombre. Adosser un écran juridique à ça pour
économiser cent lignes est un mauvais échange.

Les liens ouvrent… **rien, pour l'instant** — voir §7.

### 2.3 Mise en page

- Un titre de section en `AppTypography` (poids fort), puis ses paragraphes.
- Couleurs par `context.palette` **exclusivement** : le document doit être lisible en thème sombre,
  et c'est l'écran le plus dense en texte de l'application.
- Largeur de ligne bornée et interlignage aéré — trente articles se lisent au pouce.
- Un pied discret : « Version {n} — mise à jour le {date} », date formatée côté client
  (`utils/event_time.dart`), jamais par le serveur.

---

## 3. Consultation — `/legal/:kind`

`BrandAppBar` (dégradé de marque, texte blanc — comme tous les écrans à app bar du dépôt), bouton
retour, `LegalDocumentView` dans un `ListView`.

`kind ∈ {cgu, privacy}`. « À propos » a sa propre route (§5).

**Les quatre absences s'appliquent.** Un document que le magasin n'a pas encore reçu n'est pas une
erreur : c'est `ContentAbsence.notSynced`, rendu par `ContentAbsenceView`
(`widgets/content_absence.dart`). **Ne pas écrire un écran d'absence de plus.**

---

## 4. La barrière — `/legal/accept`

L'écran le plus contraignant de l'application. Atteint par le `redirect` du routeur, jamais par une
navigation explicite.

### 4.1 Ce que le `redirect` évalue

```dart
case AuthStatus.authenticated:
  if (loc == '/' || _authLocations.contains(loc)) return '/home';
  // Barrière : les versions acceptées couvrent-elles les versions exigées ?
  if (_legalGateRequired(auth.user, ref)) {
    return loc == '/legal/accept' ? null : '/legal/accept';
  }
  // Barrière levée — ou jamais dressée : l'écran se retire de lui-même (§4.4).
  return loc == '/legal/accept' ? '/home' : null;
```

**La dernière ligne est ce qui fait tenir le §4.4.** Un `return null` y laisserait l'écran en place
après l'accord : personne ne navigue depuis la barrière, c'est la garde qui l'enlève. Elle empêche
accessoirement `/legal/accept` d'être un cul-de-sac pour qui l'atteindrait sans rien avoir à
accepter — `PopScope(canPop: false)` n'en laisse sortir personne.

`_legalGateRequired` compare, pour `cgu` et `privacy` :

```
user.acceptedLegal[kind] < document.lastMandatoryVersion
```

Trois précisions qui décident du comportement réel :

- **Une absence de document ne bloque pas.** Magasin vide, première synchro pas encore passée,
  serveur qui ne sert pas encore de documents : pas de `lastMandatoryVersion`, pas de barrière. Une
  garde qui bloquerait sur une absence transformerait le premier lancement en écran mort.
- **Une absence d'acceptation bloque** dès qu'un `lastMandatoryVersion` existe. `acceptedLegal` ne
  porte pas de `0` : un genre jamais accepté est **absent** de la carte.
- **`about` n'entre jamais dans le calcul.**

Le `redirect` est **synchrone**. Il lit `AuthState.user` et la ligne courante du magasin, jamais un
`Future` ni un `AsyncValue` en cours de chargement.

### 4.2 L'écran

```
┌──────────────────────────┐
│ Nos conditions ont       │  ← pas d'app bar, pas de retour
│ changé                   │
│                          │
│ [CGU — sections]         │  LegalDocumentView
│ [Politique — sections]   │  LegalDocumentView
│                          │
│ ☑ J'ai lu et j'accepte   │  une case par document exigé
│   les conditions         │
│ ☑ J'ai lu la politique   │
│   de confidentialité     │
│                          │
│      [ Continuer ]       │  actif seulement si tout est coché
└──────────────────────────┘
```

- `PopScope(canPop: false)` — **aucune sortie**. Pas de « Plus tard », pas de croix, pas de retour
  Android.
- Une case **par document exigé**. Si seule la politique a changé, une seule case et un seul
  document.
- Le bouton reste inactif tant que tout n'est pas coché. Les cases ne sont **jamais** précochées.
- Le titre distingue la première acceptation (« Avant de commencer ») de la re-acceptation
  (« Nos conditions ont changé »), déduit de la présence d'une acceptation antérieure.

### 4.3 Hors ligne : lisible, mais bloquant

**Le document s'affiche.** Il vient du magasin — c'est précisément ce que la collection synchronisée
achète, et la raison de ne pas avoir pris un `GET /legal/:kind`.

**L'accord ne s'enregistre pas.** `POST /legal/accept` exige le réseau, comme la composition d'une
annonce (ADR-0031) : pas de file d'envoi, pas d'état « accepté, non confirmé ».

L'échec se rend en clair, jamais en brut :

| cas | message | issue |
|---|---|---|
| réseau absent | « Connexion requise pour enregistrer votre accord. » | Réessayer |
| 401 | session expirée | renvoi vers `/auth` |
| 422 version périmée | « Ces conditions ont été mises à jour. » | recharge le document |
| 5xx | « Le serveur n'a pas pu enregistrer votre accord. » | Réessayer |

Les cases **restent cochées** dans tous les cas — la saisie reste à l'écran, comme au composeur
d'annonces.

L'application reste inaccessible tant que le `POST` n'a pas abouti. C'est sévère et c'est le prix de
la preuve (ADR-0036, décision 2).

### 4.4 Après le succès

La réponse porte le résumé à jour ; `authProvider` l'applique, le `redirect` se réévalue, l'écran se
retire de lui-même. **Pas de navigation manuelle** — c'est le motif déjà suivi par la déconnexion.

---

## 5. « À propos » — `/about`

Une route **distincte** de `/legal/:kind` : ranger « À propos » sous `/legal/` mentirait sur sa
nature, et l'écran ne se réduit pas au document.

```
┌──────────────────────────┐
│        [logo]            │  ← local
│  Église Évangélique      │     (assets, l10n)
│     Nouvelle Vie         │
│   Maison du Miracle      │
│                          │
│  Version 1.0.0 (1)       │  ← package_info_plus
│  ──────────────────      │
│                          │
│  [sections servies]      │  ← LegalDocumentView, kind: 'about'
│                          │
│  CGU · Confidentialité   │  ← renvois vers /legal/:kind
└──────────────────────────┘
```

**Le numéro de version ne peut pas venir du serveur** : il décrit le binaire installé. C'est toute la
raison de l'entête local. Ce qui doit rester corrigeable sans publier une version de l'application —
la présentation, le contact — vit au portail et arrive par le corps servi.

Aucune case, aucune acceptation : `about` n'entre jamais dans la barrière.

---

## 6. Couche de données

Le patron du dépôt, sans écart :

- `models/legal_document_view.dart` — le **modèle de lecture**. `LegalDocumentView` porte les
  sections **déjà repliées dans une seule langue** (§2.1) ; un widget qui le reçoit n'a plus aucune
  règle à appliquer, donc plus aucune occasion d'en appliquer une variante.
- `data/repositories/legal_repository.dart` — abstrait, **`Stream`**. Un domaine adossé au magasin ne
  se lit jamais en `Future` : la synchronisation réécrit sous les pieds des écrans.
- `store_legal_repository.dart` (magasin) + implémentation **en mémoire** servie quand
  `AppEnv.useBackend` est faux. Le double applique **les mêmes règles de lecture**, repli en bloc
  compris — sans quoi la dérogation §2.1 resterait invisible pendant tout le développement.
- `data/local/tables/legal_tables.dart` + `legal_dao.dart`. On stocke **ce que le serveur envoie** :
  la carte `{fr,en,ee}` entière, les sections brutes. La présentation se calcule à la lecture.
- `data/sync/synced_collection.dart` — `legal_documents` **parmi les référentiels**, avant les
  contenus.
- `state/legal_providers.dart` — `legalRepositoryProvider`, `legalDocumentProvider.family` (par
  genre). `StreamProvider`, donc `AsyncValue` côté écran, et **pas de réessai automatique**
  (`retry: _noAutomaticRetry`), comme la médiathèque et l'agenda.

`make gen` après la table, `make migrations` après le `schemaVersion`.

Le **résumé d'acceptation** (`acceptedLegal`) n'est pas dans le magasin : il voyage avec la session,
dans `AuthState.user`, parce que le `redirect` est synchrone (§4.1).

---

## 7. Limites assumées

- **Les liens Markdown n'ouvrent rien.** `url_launcher` n'est pas une dépendance du dépôt, et
  l'ajouter pour un lien `mailto:` dans une CGU ne se justifie pas encore. Les liens se rendent
  comme des liens — couleur, soulignement — mais restent inertes. À reprendre le jour où un besoin
  réel de sortie vers le navigateur apparaît.
- **Aucun partage, aucune impression, aucun téléchargement** d'un document.
- **Pas de recherche** dans le texte, pas de sommaire cliquable. Trente articles se parcourent au
  défilement.
- **Pas de notification** à la publication d'une révision : la barrière suffit, et un push
  arriverait avant que la collection ait synchronisé.

---

## 8. Dépendances ajoutées

- **`flutter_zoom_drawer`** — le menu. Pur Dart, aucune configuration native ; la cible web reste
  tenue.
- **`package_info_plus`** — version et build dans « À propos ». Plugin natif, après
  `flutter_secure_storage`, `drift`, `image_picker` et les trois du lecteur. **Aucune permission**
  requise sur aucune plateforme, contrairement à `image_picker` (iOS) et au lecteur (Android).

**Aucune dépendance de rendu Markdown** — c'est le §2.2.
