# Messagerie de groupe — contrat de branchement

Contrat écrit **avant** le branchement, comme `auth-contract.md` et
`statuts-annonces.md` l'ont été avant les leurs. Il fait autorité sur **l'origine
d'un message** : ce qui distingue le message d'un membre, celui du serveur et
celui d'un auteur dont le compte a été supprimé.

> **✅ Branché par #96** (état au 01/10/2026). Ce document décrivait un contrat
> écrit d'avance ; il décrit désormais un code qui l'applique, et les paragraphes
> ci-dessous ont été rectifiés en conséquence. Ce qui a changé :
>
> - `ChatMessage` (`author` en `String`, `time` déjà formatée) **a disparu**. Le
>   modèle de lecture est `GroupMessageView` (`lib/models/echanges_view.dart`), qui
>   porte `authorId`, et l'origine se lit par `messageOriginOf` — **le seul endroit
>   de l'application qui interprète le couple** ;
> - **cinq collections** sont au registre du moteur
>   (`lib/data/sync/synced_collection.dart`) : `profiles`, `groups`,
>   `group_members`, `group_join_requests`, `group_messages` ;
> - `groupsProvider` / `chatProvider` ont disparu de
>   `lib/state/repository_providers.dart`, qui ne porte plus que les prières et les
>   notes — **le dernier reste fictif de l'application** ;
> - le §6, point 1 (« le nom d'un auteur vivant ») **est levé** : la collection
>   `profiles` existe. Voir la rectification sur place.

## 1. L'origine se lit sur le **couple**, jamais sur `authorId` seul

| `authorId` | `isSystem` | Ce que c'est |
| --- | --- | --- |
| uuid | `false` | **Message d'un membre** |
| `null` | `true` | **Message système** — émis par le serveur |
| `null` | `false` | **Auteur retiré** — la personne a supprimé son compte |

C'est **le** discriminant. `isSystem` seul suffit à répondre « est-ce le
serveur qui parle ? » ; `authorId` seul ne répond à **rien**.

### Pourquoi le nul est ambigu

Il ne l'a pas toujours été, et c'est ce qui rend le piège silencieux. La
migration `group_messages`, la vue de lecture et le transformer serveur ont
longtemps déclaré tous les trois la même chose : « `author_id NULL` = **System
Message** ». Un client écrit à cette époque avait raison de tester le nul seul.

La suppression de compte (`miracle-house-server#128`, ADR-0032) a pris le nul
une seconde fois. Neuf tables référencent `users.id` en `ON DELETE RESTRICT` :
supprimer franchement la ligne est une opération que le schéma **refuse** dès
que la personne a écrit quoi que ce soit. La ligne `users` est donc **vidée**
(coquille sans donnée personnelle) et le contenu communautaire **détaché** par
le mécanisme que chaque table porte déjà — pour `group_messages`,
`author_id → NULL` (la colonne est nullable / `SET NULL`).

Les messages **restent dans le fil**, et ce n'est pas une commodité : un fil
amputé devient incompréhensible, et la conversation appartient aussi à ceux qui
y ont répondu. Seul le lien vers la personne est coupé.

### Le défaut à éviter

Un client qui teste `authorId == null` pour dire « c'est un message système »
affiche **les messages d'un membre parti comme des annonces du serveur** —
centrés, en gris, sans bulle, mêlés aux « X a rejoint le groupe ». Rien ne
plante, aucun test ne rougit : la phrase d'un fidèle devient une phrase de
machine, en silence.

Symétriquement, un client qui testerait `isSystem` **et** replierait « pas
d'auteur » sur un rendu vide donnerait une bulle sans ligne d'auteur, que le
lecteur prendrait pour un bug d'affichage plutôt que pour ce que c'est.

## 2. Ce que le serveur sert, et ce qu'il ne sert pas

Un message de groupe, tel que le transformer l'expose (corps REST **et** flux
delta, `camelCase`) :

```jsonc
{
  "id": "0197…",              // UUIDv7 — trie temporellement, et sert de curseur ?since=
  "groupId": "…",
  "authorId": "…" | null,     // uuid du membre, ou null (voir le tableau du §1)
  "isSystem": false,          // true = produit par le serveur, jamais par un client
  "body": "…",
  "clientMessageId": "…" | null,  // clé d'idempotence offline fournie par le client
  "clientCreatedAt": "…" | null,  // horodatage de rédaction (ordre offline-first)
  "createdAt": "…",           // instant serveur
  "deletedAt": null | "…"     // tombstone de modération — voyage dans le flux
}
```

**Aucune identité de membre ne circule.** Il n'existe pas de collection de
synchronisation `users` (ADR-0029), et les transformers ne servent que des uuid
nus. `GET /groups/:id/members` n'existe pas côté mobile — `ReadGroupMembers`
est une action de **supervision admin** (portail), avec son propre périmètre.
La collection `groups` elle-même ne sert que `{ id, name, description,
joinPolicy, ownerId, branchIds, … }` : pas de composition, pas de noms.

⚠️ **Ce paragraphe est périmé, et sa correction est la nouvelle du lot.** Il
disait : « le mobile n'a aujourd'hui aucun moyen d'afficher le nom de l'auteur
d'un message, retiré ou vivant », et il en faisait un **prérequis de
branchement**.

La collection **`profiles`** existe désormais (`app/sync/descriptors/
profiles_descriptor.ts`), et c'est une **réversion assumée d'ADR-0029** côté
serveur. Le compromis qui la justifie est son **périmètre** : jamais un annuaire
ouvert, seulement les personnes que je **côtoie** — un profil `U` entre dans mon
périmètre s'il existe un groupe où `U` et moi sommes tous deux membres actifs. Elle
sert quatre clés et quatre seulement : `{ id, displayName, avatarUrl, updatedAt }`.

Deux choses à savoir, et elles comptent à l'écran :

- **`displayName` est nullable par contrat.** « Prénom Nom » élagué, à défaut le
  titre, à défaut `null` — un compte qui n'a jamais rempli son profil n'a pas de
  nom, et c'est courant. L'absence se rend comme une absence : jamais un
  « Utilisateur inconnu », qui ressemblerait à une donnée ;
- **`avatarUrl` est toujours `null`** aujourd'hui : `users` ne porte aucune colonne
  d'avatar. Le repli est l'initiale, et pour un auteur retiré l'avatar **neutre**.

Deux limites restent, assumées par le descripteur : un co-membre présent de longue
date dont `users.updated_at` précède mon curseur peut ne pas voyager au moment où
je rejoins son groupe ; et `profiles` **n'a pas de tombstone**, donc un profil sorti
de mon périmètre subsiste — un nom périmé, et rien de plus.

## 3. Rendu — trois origines, deux axes orthogonaux

L'origine (§1) décide de la **forme** :

1. **Membre** (`uuid, false`) → bulle, alignée selon l'axe `mine` ci-dessous.
2. **Système** (`null, true`) → `ChatInfoBanner` : centré, sans bulle, sans
   avatar, sans ligne d'auteur.
3. **Auteur retiré** (`null, false`) → **une bulle de membre**, jamais une
   bannière. Ligne d'auteur explicite (« Membre retiré », §5) et avatar
   **neutre** — une initiale viendrait d'un nom qui n'existe plus (§5).

Deux axes s'y ajoutent, et ne se confondent pas avec l'origine :

- **`mine`** = `authorId != null && authorId == session.user.id`
  (`docs/auth-contract.md`, `User.id`). Se **dérive**, ne se sert pas.
  Un message d'auteur retiré n'est **jamais** `mine` : la comparaison à `null`
  doit échouer, pas se replier. (Supprimer son compte ferme la session ; le cas
  ne se pose pas de mon côté du fil.)
- **`deletedAt`** = tombstone de modération. `deletedAt != null` retire le
  message du magasin local — la ligne voyage dans le flux **avec** son drapeau
  pour ça (le serveur ne fait jamais de hard delete, et `readsAsRetraction`
  tranche déjà avant toute désérialisation, règle 3 du moteur).

## 4. Le détachement arrive **en cours de route**, sur une ligne déjà stockée

C'est le point que le tableau seul ne dit pas, et le plus facile à rater.

`EraseAccount` écrit `author_id = NULL` **et `updated_at` à la main**, exprès
pour que la ligne reparte dans le flux delta (le curseur keyset est bâti sur
`updated_at`, ADR-0017). Le mobile ne reçoit donc pas un message neuf : il
reçoit **la mise à jour d'un message qu'il a déjà**, dont `authorId` passe d'un
uuid à `null` pendant que `isSystem` reste `false`.

Deux conséquences pour le magasin local :

1. **L'écriture doit remplacer, pas fusionner.** Un upsert qui ignorerait les
   champs nuls (`Value.absentIfNull`, un `COALESCE`, un « ne pas écraser par du
   vide ») laisserait l'ancien uuid en place et l'effacement serait **faux sur
   tous les téléphones déjà synchronisés** — la seule promesse qui compte, « vos
   messages ne vous sont plus attribués », ne serait tenue que côté serveur.
   Le patron du dépôt le garantit déjà : `sync_rows.dart` écrit
   `Value(_optionalText(item, 'authorId'))` (un nul explicite, jamais une
   absence) et `sync_dao.dart` applique en `InsertMode.insertOrReplace`. **Ne
   pas y déroger pour cette collection.**
2. **Un écran ouvert doit suivre.** Le domaine se lit en `Stream` depuis le
   magasin, comme les autres collections répliquées : une bulle affichée doit
   perdre son auteur sous les yeux du lecteur, pas au prochain démarrage.

## 5. Les libellés

Une clé à créer dans les `.arb` **au branchement** (pas avant : une clé sans
lecteur est du texte que personne ne relit) :

| clé | fr | en | ee |
| --- | --- | --- | --- |
| `chatAuthorRemoved` | Membre retiré | Removed member | *(repli fr)* |

`app_ee.arb` est partiel par construction — le repli français est automatique
(`l10n_setup.dart`). Le libellé se rend **via `context.l10n`**, jamais en dur,
et il n'est **pas** un nom : il ne se glisse pas dans `AppAvatar(name: …)`, qui
en tirerait les initiales « MR » et une couleur dérivée de la longueur du
libellé — deux marqueurs d'identité fabriqués de toutes pièces, et identiques
pour tous les auteurs retirés. Passer une chaîne vide donne « ? », ce qui est au
moins vrai ; l'avatar de repli est à décider au branchement, avec les noms
(§6, point 1).

C'est la même règle que les quatre absences et que `ContentView.authorName` :
**l'absence s'affiche comme une absence**, jamais comme un « Auteur inconnu »
qui ressemble à une donnée. La nuance ici : « Membre retiré » n'est pas un nom
de repli, c'est un **fait** — la personne est partie, et le dire est plus juste
que ne rien dire.

## 6. Prérequis et questions ouvertes, côté serveur

1. ~~**Le nom d'un auteur vivant.**~~ ✅ **Levé** par la collection `profiles`
   (voir la rectification du §2). C'était le prérequis bloquant : sans source
   d'identité, « Membre retiré » aurait été **la seule** ligne d'auteur du fil, et
   l'auteur parti aurait été plus identifié que les présents. Le §3 est resté
   valable mot pour mot, comme annoncé.
2. **Les messages système arrivent en français en dur.** Le serveur les écrit
   comme prose (« Un nouveau membre a rejoint le groupe. »,
   `post_group_system_message.ts` et ses appelants), pas comme des clés à
   traduire. Un membre anglophone ou éwéphone les lira en français, et le mobile
   n'a rien pour y remédier — il ne peut pas traduire une phrase libre.
3. **L'écriture** (`POST /groups/:id/messages`, idempotence par
   `clientMessageId`, ADR-0018) est branchée par #96 : écho optimiste, clé
   d'idempotence **obligatoire** (un UUIDv7 frappé par le client), et rupture
   assumée avec le composeur d'annonces — une conversation ne supporte pas
   d'attendre le réseau. Voir `lib/data/repositories/group_message_composer.dart`.
   Le **temps réel par SSE** est arrivé depuis, par #101 (un signal par groupe,
   ouvert dans le fil affiché), puis a été **refait** par #140 : le canal
   `users/{id}` porte la ligne elle-même, rangée par la même fonction que la
   synchronisation. Il ne change **rien** à la règle du §1 — la ligne est celle
   du flux delta, couple `(authorId, isSystem)` compris. Voir le §10 et
   `lib/data/messaging/`.

## 7. Tests attendus au branchement — **écrits**

> Les six cas ci-dessous existent. Les quatre premiers et le sixième vivent dans
> `test/sync/echanges_collections_test.dart` (de bout en bout, par le moteur) et
> `test/screens/group_chat_origins_test.dart` (le rendu). Le cinquième — la
> transition — est dans le premier fichier, sous « Le détachement arrive sur une
> ligne DÉJÀ STOCKÉE ». Les fixtures portent **un exemplaire de chaque ligne du
> tableau**, l'auteur retiré compris (`test/helpers/sync_fixtures.dart`).
>
> La valeur du cas 4 a été **mesurée** : remplacer `messageOriginOf` par un
> `authorId == null` fait rougir trois tests, et pas un de moins.

Un test **par ligne du tableau du §1**, sur le rendu, plus le cas qui ne
s'obtient qu'en deux temps :

1. `(uuid, false)` d'un autre → bulle reçue, ligne d'auteur du membre.
2. `(uuid, false)` = le mien → bulle envoyée (alignée à droite).
3. `(null, true)` → bannière système, **aucune** bulle.
4. `(null, false)` → **bulle**, ligne d'auteur « Membre retiré », et **pas** de
   bannière système. C'est le test qui échoue si quelqu'un réécrit
   `authorId == null`.
5. **Transition** (§4) : un message stocké avec un `authorId`, puis la même
   ligne re-servie par le flux avec `authorId: null` / `isSystem: false` — le
   magasin doit avoir **perdu** l'uuid, et l'écran ouvert avoir basculé sur le
   libellé.
6. `deletedAt` non nul → la ligne quitte le magasin, quelle que soit son
   origine.

Les données fictives doivent porter **un exemplaire de chaque ligne du
tableau** : sans un message d'auteur retiré dans les fixtures, le cas 4 n'existe
que dans un test unitaire et aucun écran ne le montre jamais à personne.

## 8. Ce que le modèle mobile devient

`ChatMessage` est un modèle de maquette : `author` (nom déjà résolu), `time`
(chaîne déjà formatée), `mine` et `system` posés à la main dans `SampleData`. Au
branchement, il suit le chemin des autres domaines — un **modèle de lecture**
porté par le magasin :

- `authorId` (`String?`) et `isSystem` (`bool`) **arrivent** — ce sont eux la
  donnée ; `system` seul ne peut pas porter trois origines.
- `mine` se **dérive** de la session (§3), il ne se stocke pas.
- `time` redevient un **instant** (`createdAt` / `clientCreatedAt`), formaté à
  la vue — « ce que sert le back est une donnée, jamais du texte pré-formaté ».
- `author` (le `String`) **disparaît** : il n'a pas de source serveur, et un
  modèle qui porte ce que le back ne sert pas fabrique un écran qui marche sur
  les fixtures et se vide en production.

`ChatInfoBanner`, `ChatBubble` et le reste de `widgets/chat/` restent : c'est ce
qui **choisit** entre eux qui change, et c'est exactement le §1.

> ✅ **Fait par #96, et à la lettre.** `GroupMessageView`
> (`lib/models/echanges_view.dart`) porte `authorId` et `origin` ; `mine` se dérive
> de la session ; `createdAt` est un **instant**, formaté à la vue
> (`formatMessageTime`) ; et `author` a disparu — remplacé par `authorName`, qui
> vient de `profiles` et peut légitimement manquer.
>
> Deux ajouts que ce paragraphe n'avait pas prévus, et qui se sont imposés :
>
> - **`MessageOrigin`**, un enum à trois valeurs, parce qu'un booléen `isSystem`
>   stocké à côté d'un `authorId` nullable laisse le lecteur refaire le
>   raisonnement à chaque site d'appel. `messageOriginOf` le fait une fois, et
>   `origin.isBubble` est ce que l'écran lit ;
> - **`MessageDelivery`**, parce que l'écho optimiste fait paraître un message
>   avant qu'il soit parti, et qu'un envoi perdu doit le **dire** au lieu de rester
>   « en cours » pour toujours.
>
> Et une garde structurelle de plus : `AppAvatar.neutral` est un constructeur
> **sans paramètre `name`**. Le §5 avertissait de ne pas passer « Membre retiré » à
> `AppAvatar(name:)` ; un avertissement se rate, une signature qui n'accepte pas de
> nom ne se rate pas.

## 9. Le retour au premier plan après un réveil de fond (#138)

**Une écriture faite par le réveil de fond n'est jamais vue par les flux de
l'isolate principal.** Le réveil push d'une application en arrière-plan
(`lib/data/push/push_background.dart`) ouvre une **seconde** `AppDatabase` sur le
même fichier, tire `profiles`, `groups`, `group_members` et `group_messages`,
écrit les lignes **et avance le curseur**. Drift ne prévient que les écouteurs de
**sa** connexion : `conversationsOf` et `threadOf`, écoutés par l'isolate
principal, gardent leur ancien résultat. Et le cycle du retour au premier plan,
trouvant un curseur déjà avancé, n'a plus rien à écrire — donc rien ne les
relit. La liste des Échanges restait périmée jusqu'au redémarrage, tirer-pour-
rafraîchir compris (surtout sur Android, application en arrière-plan mais vivante).

Le correctif : au passage à `resumed`, `SyncScheduler.onForeground` est appelé
**immédiatement**, puis **de nouveau à la fin du cycle du retour** (un réveil de
fond peut être encore en cours). `syncSchedulerProvider` y branche un
`markTablesUpdated` sur les tables de toutes les collections synchronisées, plus
`pending_group_messages` (et, depuis #140, `pending_group_reads`). Le rappel est
injecté : le planificateur ne dépend pas
de drift.

`shareAcrossIsolates` n'est **pas** la solution : le gestionnaire de fond FCM
tourne dans un moteur Flutter séparé, que `IsolateNameServer` ne relie pas.

Test de non-régression : `test/sync/foreground_foreign_writes_test.dart` — deux
connexions sur un même fichier temporaire, le vrai moteur restreint du réveil sur
l'une, le vrai `syncSchedulerProvider` sur l'autre, et les deux flux qui doivent
émettre la ligne du réveil après le retour.

## 10. Un fil fiable, comme WhatsApp (#140, tranche M1b)

Le plan est `server-portal/docs/messagerie-whatsapp-plan.md` (décisions 11 et 12,
pièges 1, 2, 4 et 5) ; le contrat serveur consommé est
`server-portal/docs/messagerie-temps-reel-contrat.md` (M1a). `CLAUDE.md` détaille
le code ; voici ce que ce contrat-ci en retient.

### Le corps nul (piège 1)

`group_messages.body` est **nullable** depuis le schéma v20. Un message-média
(vocal, image) arrive avec `body: null` au-delà du plancher de compatibilité
(`GROUP_MEDIA_COMPAT_FLOOR_VERSION`) et **toujours** sur le canal ; la colonne
`NOT NULL` faisait lever `groupMessageRowOf`, donc rejeter la page, donc couper le
cycle à chaque tour. Le palier v19 → v20 recrée la table (`alterTable`), recopie
le fil et garde le curseur. À l'écran, un corps nul se **dit**
(`chatMediaUnsupported`), jamais une bulle vide ; la notification de réveil se
tait. **À faire avant toute montée de `X-App-Version` au-delà de 1.14.0.**

### Le canal `users/{monId}`

Un seul canal pour toutes les discussions, ouvert tant que l'application est au
premier plan **et** la session ouverte (`messagingLinkProvider`, écouté par
`app.dart`), fermé en arrière-plan. Le canal par groupe `groups/{id}` n'est plus
ouvert (il reste servi pour le parc installé, contrat M1a §1).

| événement | collection | rangement |
| --- | --- | --- |
| `message.created` / `.updated` / `.deleted` | `group_messages` | remplace la ligne ; un tombstone la retire ; l'écho de même `clientMessageId` cède |
| `membership.changed` | `group_members` | remplace ; **ma** ligne tombstonée retire la conversation |
| `group.updated` | `groups` | remplace — c'est ainsi qu'arrivent l'effectif juste et un groupe rejoint |
| `read.advanced` | `group_reads` | **seulement s'il avance** (identifiant du message lu) |
| `$$transmit/ping` | — | signe de vie ; 60 s de silence → reconnexion |

Chaque ligne passe par `MessagingStoreWriter` → le descripteur du registre →
`SyncDao.applyLiveRows` : **la même fonction que la ligne de synchronisation**,
sans curseur. Une ligne qui cite un groupe inconnu est rangée, **puis** un cycle
est lancé ; chaque (re)connexion lance un cycle de rattrapage. La
synchronisation reste la vérité (piège 4).

### Non-lus, lecture et badge

`group_reads` (collection `private`, rangée par `groupId`, **avant**
`group_messages` dans le registre) porte ma position servie ;
`pending_group_reads` (locale seule) celle que ce téléphone a avancée sans
confirmation. Le compteur — la formule du contrat, écrite une fois dans
`GroupDao` — prend la plus avancée des deux : un message lu hors ligne cesse
aussitôt de compter. La lecture avance (`POST /groups/:id/read`) quand le fil
montre son message le plus récent ; elle est rejouée après chaque cycle réussi
jusqu'à confirmation. Badge de l'onglet = somme des pastilles des conversations.

### Renvoi sans doublon (piège 5)

Après chaque cycle réussi, les échos non réconciliés (`failed` **et** `sending`)
repartent sous **leur** `clientMessageId`, dans l'ordre de rédaction ; le geste
manuel (toucher le message en échec → Réessayer / Supprimer) fait de même. Le
serveur reconnaît la clé : jamais de second message.

### Un déclencheur n'est plus perdu

`SyncScheduler.trigger()` rejoignait le cycle en vol, même quand ce cycle avait
déjà passé la collection concernée : le signal était perdu jusqu'au déclencheur
suivant. Un déclencheur reçu pendant un cycle en programme désormais un second,
coalescé, lancé dès la fin du premier.

### Ce qui reste à vérifier sur appareil

- l'ouverture sur le premier non-lu (alignement d'`ensureVisible` dans une liste
  inversée) et le maintien du dernier message au-dessus du clavier ;
- la reconnexion après une bascule bleu/vert (~120 s sans flux) et après un
  passage en arrière-plan ;
- le retour depuis une notification (flèche et geste système Android).
