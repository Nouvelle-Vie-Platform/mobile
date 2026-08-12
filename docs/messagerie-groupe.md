# Messagerie de groupe — contrat de branchement

Contrat écrit **avant** le branchement, comme `auth-contract.md` et
`statuts-annonces.md` l'ont été avant les leurs. Il fait autorité sur **l'origine
d'un message** : ce qui distingue le message d'un membre, celui du serveur et
celui d'un auteur dont le compte a été supprimé.

> **Rien de ce document n'est branché aujourd'hui** (état au 12/08/2026). Le
> modèle mobile de la messagerie est `ChatMessage` (`lib/models/models.dart`) :
> un `author` en `String` — un nom d'affichage —, un `text`, une `time` déjà
> formatée, un `mine` et un `system`. Il ne porte **ni `authorId` ni
> `isSystem`**, `groups` et `group_messages` ne sont **pas** au registre du
> moteur de synchronisation (`lib/data/sync/synced_collection.dart`), et
> `groupsProvider` / `chatProvider` lisent encore `InMemoryChurchRepository`.
> Ce document existe pour que le jour du branchement, la règle soit déjà écrite
> — pas pour décrire un code qui l'applique.

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

Conséquence à regarder en face : **le mobile n'a aujourd'hui aucun moyen
d'afficher le nom de l'auteur d'un message, retiré ou vivant.** ADR-0032 en tire
la conclusion inverse de celle qu'on attend (« le mobile n'a donc aucun nom à
remplacer ») — ce qui est vrai, et laisse entière la question de ce qu'affiche
la ligne d'auteur d'un message de membre. Voir §6, point 1 : c'est un
**prérequis de branchement**, pas un détail d'habillage.

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

Aucune de ces trois n'est un détail d'habillage, et aucune n'est tranchée :

1. **Le nom d'un auteur vivant.** Sans source d'identité de membre, la ligne
   d'auteur d'un message de membre est vide, et « Membre retiré » serait alors
   **la seule** ligne d'auteur du fil — l'auteur parti serait plus identifié que
   les présents. Il faut une source (collection de synchronisation dédiée aux
   membres des groupes dont je fais partie, ou endpoint `GET
   /groups/:id/members` côté mobile) **avant** de peindre le fil. Le §3 reste
   valable tel quel une fois cette source branchée.
2. **Les messages système arrivent en français en dur.** Le serveur les écrit
   comme prose (« Un nouveau membre a rejoint le groupe. »,
   `post_group_system_message.ts` et ses appelants), pas comme des clés à
   traduire. Un membre anglophone ou éwéphone les lira en français, et le mobile
   n'a rien pour y remédier — il ne peut pas traduire une phrase libre.
3. **L'écriture** (`POST /groups/:id/messages`, idempotence par
   `clientMessageId`, ADR-0018) et le **temps réel** (SSE/push) sont hors du
   périmètre de ce document. Ils ne changent pas la règle du §1.

## 7. Tests attendus au branchement

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
