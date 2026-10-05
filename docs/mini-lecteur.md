# Mini-lecteur — cadrage

> Cadrage validé le 2026-10-05. Pendant mobile de la barre persistante de la vitrine
> (`server-portal/docs/prd/accueil-public.md`, D21), adapté aux contraintes de l'app.

## Objectif

Dès qu'un enseignement est chargé dans le lecteur global, un mini-lecteur flottant le montre et le
pilote depuis n'importe quel écran. Aujourd'hui, la lecture survit déjà au `context.pop()`
(`contentPlayerProvider` n'est jamais autoDispose), mais rien ne montre ensuite ce qui joue.

## Décisions

| # | Sujet | Décision |
|---|-------|----------|
| 1 | Déclenchement | Il apparaît dès qu'un contenu est chargé, qu'il ait été lancé depuis l'écran de détail ou depuis une carte de l'accueil (`playHomeContent`). |
| 2 | Contenu | Vignette carrée, titre, orateur, barre de progression, puis **−30 s / play-pause / +30 s**, puis ✕. Les boutons ⏮/⏭ de la maquette deviennent des sauts : il n'existe aucune file et il ne faut pas en inventer une (voir CLAUDE.md). |
| 3 | Portée | Au-dessus de `AppBottomNav` dans les 4 onglets ; collé en bas sur les écrans empilés (médiathèque, recherche…). **Masqué** sur `/teaching/:id`, qui a déjà le lecteur plein, et sur `/radio`. |
| 4 | Radio | Variante « antenne » : logo et titre de l'antenne, ni progression ni sauts (même logique que `isLive` sur l'écran verrouillé). Badge **« À l'antenne »** par défaut, **« EN DIRECT »** seulement quand l'antenne connue signale un direct de la régie (`radioAntennaProvider`, `live != null`) — les mots de la page live (#135). Lecture de l'état déjà connu : ni canal, ni sondage (#149). |
| 5 | Bouton central | Inchangé : il ouvre toujours la médiathèque. Le play/pause ne se fait que dans le mini-lecteur. |
| 6 | Appui sur la vignette ou le titre | Ouvre `/teaching/:id` sans recharger ni redémarrer (`_open` ne recharge pas un contenu déjà chargé). Pour la radio, ouvre `/radio`. |
| 7 | ✕ | Arrête le son, retire la notification système et ferme le mini-lecteur. La position de reprise est enregistrée. |
| 8 | Fin de lecture | Le mini-lecteur reste, barre pleine, et le bouton devient ↻ Rejouer. Seule la croix ✕ le ferme. |
| 9 | Relance de l'app | Départ à vide. On ne mémorise pas « ce qui jouait » ; la reprise passe par les positions sauvegardées. |
| 10 | Suivi | `PlaybackProgressRecorder` et la mesure d'écoute quittent `ContentPlayerView` et s'attachent au lecteur global, **dans la même tranche**. Ils couvrent alors les cartes de l'accueil, le mini-lecteur et les sauts. |

## Choix par défaut

- **Métadonnées** : `ContentPlayback` ne porte ni titre, ni auteur, ni image. Le lecteur expose donc
  la requête courante (`title`, `author`, `artUrl`, `isLive`), plutôt que de les retrouver à partir
  de `contentId`. Cela sert aussi à la radio.
- **Orateur absent** (`authorName` null) : la ligne est masquée. Ne jamais afficher « Auteur inconnu ».
- **Durée inconnue** (HLS sur iOS, `progress == null`) : barre indéterminée.
- **Mise en page** : carte flottante arrondie avec ombre, au-dessus de la barre, en suivant le
  précédent des bandeaux de `HomeShell` (`bottom: paddingOf.bottom + AppBottomNav.barHeight`). Les
  listes reçoivent une marge basse pour que le mini-lecteur ne masque pas leurs derniers éléments.
- **Visionneuse de statuts (Annonces)** : le mini-lecteur est masqué dès qu'un statut est affiché —
  image, texte ou vidéo — tant que l'onglet Annonces est actif, et revient quand on le quitte (ou que
  le mur se vide). La lecture continue dessous — **sauf sous un statut à son** (#130) : un statut
  audio ou vidéo **joué son actif** (pas coupé par le bouton muet) met la radio ou l'enseignement en pause, et la sortie de la visionneuse les fait
  reprendre (la radio au direct, l'enseignement à sa position). Le masquage est posé par `AnnouncementsScreen`
  (`MiniPlayerShield`), indépendamment du bouton central, qui ne s'estompe, lui, que sur un statut
  vidéo.
- **Masquages ajoutés par #117** : `/gathering/:id` (sa fiche est un `ContentPlayerView`), les parcours
  bloquants (`/`, `/auth*`, `/legal/accept`), la visionneuse `/media-viewer`, le menu latéral ouvert,
  toute fenêtre surgissante (dialogue, feuille du bas) et le clavier ouvert.
- **Mode invité** : même comportement que pour un compte connecté.
- **Position** : la progression change plusieurs fois par seconde, donc on lit `contentPlaybackProvider`
  avec `select`.

## Points d'attention

- Les routes sont plates (pas de `ShellRoute`). Pour que le mini-lecteur apparaisse sur les écrans
  empilés, il est monté au-dessus du `Navigator` (`MaterialApp.router` → `builder`, `MiniPlayerHost`,
  #117), et non dans `HomeShell`. Il lit la route du sommet dans `routerDelegate.currentConfiguration`.
- Marges des listes (#117) : la hauteur mesurée de la carte est ajoutée à `MediaQuery.padding.bottom`
  de toute la pile ; la coquille la retire autour de son `Scaffold` (sa barre grandirait) et la rend à
  ses onglets. Voir CLAUDE.md, « Le mini-lecteur partout ».
- Le CLAUDE.md fait de `ContentPlayerView` « le seul endroit qui pilote le lecteur ». Le mini-lecteur
  y déroge, comme `playHomeContent` y déroge déjà. Il faut donc réécrire cette règle (transport
  centralisé dans un contrôleur global, et non plus dans un widget), et non la contourner en silence.
- La radio **remplace** l'enseignement (CLAUDE.md). Une fois le suivi global, la position de
  l'enseignement doit être écrite avant que la radio ne prenne le lecteur.
