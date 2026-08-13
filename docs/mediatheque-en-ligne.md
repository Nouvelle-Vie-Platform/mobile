# La médiathèque mobile est en **lecture en ligne seulement**

> **La règle, en une phrase.** Le **catalogue** est hors ligne, le **son** ne
> l'est pas. On peut parcourir la médiathèque en avion ; on ne peut rien y
> écouter.

Ce document existe parce que la règle s'est déjà perdue une fois. Elle ne vivait
que dans le corps d'une issue (#38, « Out of Scope »), et un libellé écrit de
bonne foi a fini par promettre le contraire — « cet enregistrement n'a pas été
téléchargé » — c'est-à-dire une fonction de téléchargement qui n'existe pas.
C'est le document à lire avant de « rajouter le téléchargement, c'est juste un
cache ».

## 1. Ce qui est hors ligne, et ce qui ne l'est pas

| | hors ligne | peint par |
|---|---|---|
| titres, intervenants, rubriques, visuels, couleurs | **oui** | le magasin local Drift (ADR-0026) |
| progression de lecture (« où j'en étais ») | **oui** | `local_playback_positions` (#43) |
| **le média** (`playlistUrl`, flux HLS) | **non** | le réseau, à chaque écoute |

Le catalogue est hors ligne parce qu'il est **répliqué** : la synchronisation
écrit dans le magasin, les écrans lisent le magasin, et le réseau ne peint
jamais. C'est ce qui rend l'application utilisable dans une salle sans données
mobiles — on ouvre, on voit, on choisit.

Le son ne suit pas ce chemin. `playlistUrl` désigne un **manifeste HLS**, donc
une liste de segments tirés au fil de la lecture. Le magasin stocke l'URL ; il
ne stocke pas ce qu'elle désigne.

## 2. Pourquoi il n'y a pas de bouton de téléchargement

Ce n'est pas un oubli, ni une étape « pas encore faite ». Le téléchargement est
**explicitement hors périmètre** (#38), et ce qu'il coûterait n'est pas un
bouton :

- **stocker un HLS, ce n'est pas copier un fichier** — il faut tirer et ranger
  chaque segment, réécrire le manifeste vers des chemins locaux, et gérer la
  reprise d'un tirage interrompu ;
- **il faut alors une gestion de place** : quota, éviction, écran « mes
  téléchargements », et la question « pourquoi ce prêche a-t-il disparu ? » ;
- **et une politique de retrait** : un contenu rétracté par l'église (`{ id,
  deletedAt }`, ADR-0025) doit disparaître aussi de ce qui a été téléchargé,
  sinon l'application conserve et rejoue un contenu que l'église a retiré. C'est
  le point qui interdit de traiter la chose comme un simple cache.

Un cache implicite (« garder le dernier écouté ») ne sauve pas la mise : il
donne un hors-ligne **imprévisible** — ça marche parfois —, ce qui est pire
qu'un hors-ligne franc, parce que personne ne peut s'y fier ni le comprendre.

## 3. Ce que l'écran dit à la place

Hors ligne, l'écran de lecture affiche `ContentAbsence.offlineMedia`
(`lib/widgets/content_absence.dart`) :

> **Écoute impossible hors ligne**
> La médiathèque s'écoute en ligne. Reconnectez-vous à internet pour lancer la
> lecture.

Deux choses que ce libellé ne fait **pas**, et qui sont la raison d'être de sa
réécriture :

1. **il ne promet aucune affordance inexistante.** L'ancienne phrase disait
   « cet enregistrement n'a pas été téléchargé » ; un fidèle la lit comme
   « j'aurais dû le télécharger », cherche le bouton, ne le trouve pas, et
   conclut que l'application est cassée. On lui aura fait perdre du temps pour
   lui laisser croire à une panne ;
2. **il n'accuse pas l'utilisateur.** Il énonce une règle du produit — la
   médiathèque s'écoute en ligne — puis l'action qui débloque.

Le libellé est écrit dans les trois `.arb` (`app_fr`, `app_en`, `app_ee`), et le
`description` de chaque clé porte l'interdiction, comme le doc-comment de
l'énumération et le § « Les quatre absences » de `CLAUDE.md`. Les quatre
disent la même chose exprès : corriger le texte sans corriger les commentaires,
c'est laisser quelqu'un le rétablir plus tard en toute bonne foi.

## 4. Les quatre absences, et laquelle répond à quoi

Un contenu ouvert peut n'avoir rien à faire entendre pour quatre raisons. Elles
se ressemblent à l'écran et répondent à des questions différentes — le fidèle
n'en pose qu'une : *est-ce que je peux revenir plus tard ?*

| variante | ce qui s'est passé | réponse |
|---|---|---|
| `retracted` | l'identifiant a été valide, il ne l'est plus : l'église a dépublié ou reprogrammé | non, c'est définitif |
| `notSynced` | le magasin local n'a pas encore reçu ce contenu | oui, après la prochaine synchronisation |
| `noMedia` | contenu publié, `playlistUrl` nul : l'enregistrement n'est pas encore attaché | oui, dans quelques jours |
| `offlineMedia` | le média existe, l'appareil est hors ligne | oui, dès qu'il y a du réseau |

Deux confusions à ne pas commettre :

- **`offlineMedia` n'est pas `noMedia`.** L'une dit « votre appareil n'a pas de
  réseau », l'autre « l'église n'a pas encore mis l'enregistrement en ligne ».
  Le fidèle qui lit la mauvaise cherche le problème du mauvais côté ;
- **`noMedia` n'est pas `retracted`.** « Pas encore disponible » n'est pas
  « contenu retiré » : confondre les deux fait croire à une suppression, et le
  fidèle cesse d'attendre un enregistrement qui arrive. C'est pourquoi `noMedia`
  garde **la couleur du contenu** (il existe, son habillage aussi) là où
  `retracted` retombe sur le bleu de marque, la donnée ayant disparu.

## 5. Hors ligne ou panne : ça se déduit de l'échec

`offlineMedia` suppose de savoir que l'appareil est hors ligne. Cette
distinction — hors ligne / panne de lecture — se déduit de **l'échec lui-même**,
et **aucune bibliothèque de connectivité n'est utilisée** : un test de
connectivité affirme « connecté » derrière un portail captif, dans une salle
paroissiale ou un hôtel, c'est-à-dire qu'il ment exactement quand ça compte. Le
détail de cette déduction appartient à l'écran de lecture (issue #42).

Ce que la règle de ce document impose, elle, ne dépend d'aucune détection : quel
que soit le diagnostic, il n'y a **rien à proposer de local**, parce qu'il n'y a
rien en local.
