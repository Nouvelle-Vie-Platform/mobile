# Refonte « Groupes » → « Échanges » (mobile)

> Cahier de décisions issu de la session /grill-me du 2026-08-15.
> Sert de référence pendant l'implémentation ET de checklist de re-vérification à la fin.
>
> ⚠️ **Ce domaine n'est plus fictif depuis #96.** Les dix-sept décisions visuelles
> ci-dessous **tiennent toutes** — elles n'ont pas été rouvertes —, mais trois
> d'entre elles ont perdu leur matière, parce que leur matière était inventée
> (cadrage `server-portal/docs/echanges-branchement-plan.md`, décision 10 : « on
> retire ce qui ne peut pas être vrai, on garde ce qui le deviendra ») :
>
> - **D5** — la **pile d'avatars** du bandeau est retirée. « Estelle », « David »,
>   « Sarah » et une pastille « 5+ » qui ne comptait rien : trois personnes qui
>   n'existaient pas, sur l'écran d'une église où tout le monde se connaît. Le reste
>   de D5 est intact (titre à gauche, bouton Requêtes à droite, pas de hamburger).
> - **D6** — la rangée « groupes à rejoindre » **reste**, et elle est désormais
>   indispensable (décision 3 du cadrage) : la politique d'adhésion par défaut est
>   `invite_only`, donc sans elle le groupe créé au backoffice serait visible de
>   personne. Son **image de carte** part, en revanche : le serveur ne sert aucune
>   image de groupe. Un aplat dérivé du nom la remplace. Et le tap ouvre la **fiche
>   du groupe**, non plus le profil de l'animateur : on découvre un groupe.
> - **D15 / D16 / D17** — les **médias partagés** sont vides en tranche 1 et
>   remplis en tranche 3 (ce seront les images du fil). La galerie de fiche membre,
>   engendrée par hachage du nom, est retirée pour de bon. La visionneuse
>   (`media_viewer_screen.dart`), sa route et sa configuration native **restent en
>   place** : c'est la destination que la tranche 3 câblera.
>
> **D13 est confirmée et devient un fait notable** : `/prayers` garde sa route et
> son fictif, et c'est désormais le **dernier** reste fictif de l'application.
> `SampleData.prayers` le dit, `ChurchRepository` le dit, `repository_providers.dart`
> le dit.
>
> **D14 est caduque** : le modèle `Conversation` a été remplacé par les modèles de
> lecture de `lib/models/echanges_view.dart`, portés par le magasin.

## 1. Intention

Transformer l'onglet « Groupes » en un **hub de conversations « Échanges »** : les groupes et les discussions (inbox) sont réunis au même endroit, sans séparation par onglets. Les requêtes/suggestions sortent de la page derrière un bouton en haut à droite.

## 2. Décisions (verrouillées)

| # | Sujet | Décision |
|---|-------|----------|
| D1 | Nom | Page + onglet bottom nav = **« Échanges »** |
| D2 | Icône bottom nav | **Bulles de discussion** (`forum_outlined` / `forum`), plus `groups` |
| D3 | Onglets pilules | **Supprimés** (fini Groupes / Inbox / Requêtes) |
| D4 | Header | Structure de la maquette (bandeau diagonal) mais **couleurs New Life** (bleu/teal/jaune), pas le rose Dribbble |
| D5 | Contenu header | Titre « Échanges » à gauche ; à droite **pile d'avatars** (décorative/fictive) + **bouton icône Requêtes tout à droite**. **Pas** de hamburger, **pas** d'avatar central |
| D6 | Rangée du haut | **Groupes à rejoindre** (découverte : image + nom + animateur), jeu fictif **distinct** des conversations |
| D7 | Flux principal | **Liste à plat** triée par activité récente, **groupes + DM 1-à-1 mélangés**, **sans sections**. Tuile = avatar + nom + dernier message + heure. Tap → chat |
| D8 | Icônes visio/audio | **Retirées** (aucun backend d'appel). Tap conversation → ouvre le chat, point |
| D9 | FAB | **Aucun FAB** sur la page Échanges (le FAB central de la bottom nav → médiathèque reste inchangé) |
| D10 | Nouvelle discussion 1-à-1 | Démarrée **depuis un écran profil-membre** (nouveau, léger) via bouton « Message ». Portes d'entrée vers ce profil : carte « groupe à rejoindre » (→ animateur) ; **dans un chat de groupe**, tap sur le nom du groupe → **fiche de groupe** (voir D15) → section Membres → membre ; et tap sur un **message reçu** (auteur) → son profil |
| D15 | Fiche de groupe (Telegram) | Tap sur le nom d'un groupe → écran **fiche** inspiration Telegram : en-tête immersif (dégradé de marque, grand logo, nom, effectif), puis **Description**, **Médias partagés** (rangée de vignettes), puis **Membres**. Remplace l'ancienne simple liste de membres. `Conversation` gagne `description` + `sharedMedia` (fictifs). Écran : `lib/screens/group_info_screen.dart`, route `group-info` |
| D16 | Fiche membre détaillée | **Un utilisateur simple a droit à la même page détail.** Le profil-membre devient une vraie fiche façon Telegram : en-tête immersif (avatar, nom, statut), action **Message**, **Médias partagés** (déterministes depuis le nom). Le titre d'une **discussion privée** est désormais cliquable → cette fiche (avant : groupes seulement). Écran : `lib/screens/member_profile_screen.dart` (réécrit) |
| D17 | Ouvrir + télécharger les médias | Tap sur une vignette → **visionneuse plein écran** (zoom, défilement) `media_viewer_screen.dart`, route `media-viewer`. Bouton **télécharger** → enregistre dans **Photos** via le plugin **`gal`** (SPM, pas de CocoaPods ; vérifié). Effet natif derrière l'abstraction `MediaSaver` (`lib/data/media/`, provider `mediaSaverProvider`, `InertMediaSaver` pour les tests). Permissions : iOS `NSPhotoLibraryAddUsageDescription`, Android `WRITE_EXTERNAL_STORAGE` maxSdkVersion 28. **Pas de web** (`gal` ne le supporte pas) : bouton masqué via `kIsWeb`. Octets récupérés par `dio` puis `Gal.putImageBytes`. |
| D11 | Bouton Requêtes (haut-droite) | Ouvre un écran **« Requêtes »** = **liste avec état vide** au départ + bouton ajouter → formulaire existant `new_request_screen` |
| D12 | Data requêtes | **Pas** de nouveau modèle. Liste vide + formulaire existant |
| D13 | Espace de prière | **Laissé de côté** : route `/prayers` conservée, **non rebranchée** |
| D14 | Modèle conversation | Nouveau modèle `Conversation` (kind groupe\|direct), fictif/synchrone |

## 3. Plan d'implémentation

### Lot 1 — Modèle & données fictives
- `lib/models/models.dart` : `enum ConversationKind { group, direct }` + modèle `Conversation` (id, kind, name, avatarUrl, lastMessagePreview, time, **+ members, description, sharedMedia** ajoutés pour D10/D15).
- `lib/data/sample_data.dart` : jeu **conversations** (mix groupes + DM), jeu **groupes à rejoindre** (distinct), conserver `chat`.
- `lib/data/repositories/church_repository.dart` : `conversations()`, `groupsToJoin()`, `chatFor(Conversation)`.
- `lib/state/repository_providers.dart` : `conversationsProvider`, `groupsToJoinProvider`, `chatProvider` adapté à `Conversation`.

### Lot 2 — i18n
- `app_fr.arb` / `app_en.arb` / `app_ee.arb` : `navGroups` + `communityTitle` → « Échanges » ; retirer `communityTabInbox` / `communityTabRequests` / `groupsTitle` ; ajouter `echangesDiscover`, `requestsTitle`, `requestsEmpty`, `memberMessage`.
- Corriger le hardcodé FR de `prayer_request_card.dart:49` (`'... membres en prière'`).
- Puis `flutter gen-l10n`.

### Lot 3 — Bottom nav
- `lib/widgets/app_bottom_nav.dart` : icône `groups` → `forum_outlined`/`forum`, label `navGroups`.

### Lot 4 — Page Échanges
- Réécrire `lib/screens/groups_screen.dart` : supprimer `_PillTabs`, `_GroupsTab`, `_InboxTab`, `_RequestsTab`.
- Header (widget `community_header.dart`) : bandeau diagonal palette New Life, « Échanges » à gauche, pile d'avatars + bouton icône Requêtes à droite.
- Rangée horizontale **groupes à rejoindre** (carte `join_group_card.dart`).
- **Liste à plat** des conversations (tuile `conversation_tile.dart`), tap → chat.

### Lot 5 — Écrans & routes
- `lib/screens/group_chat_screen.dart` : accepter `Conversation` ; sous-titre « N membres » + titre cliquable (groupe) → fiche ; tap auteur d'un message reçu → profil (D10/D15).
- **Nouveau** `lib/screens/member_profile_screen.dart` : profil léger + bouton « Message » → conversation directe.
- **Nouveau** `lib/screens/group_info_screen.dart` : fiche de groupe façon Telegram (en-tête + description + médias + membres) — D15. Remplace l'éphémère `group_members_screen.dart` (supprimé).
- **Nouveau** `lib/screens/requests_screen.dart` : liste + état vide + bouton ajouter → `new_request_screen`.
- `lib/widgets/chat/chat_app_bar.dart` : `onTitleTap` ; `lib/widgets/chat/chat_bubble.dart` : `onAuthorTap`.
- `lib/router/app_router.dart` : routes `requests`, `member-profile`, `group-info` ; adapter `group-chat` à `Conversation`.

## 4. Checklist de re-vérification (à cocher en fin de travail)

- [ ] Bottom nav : label « Échanges » + icône bulles de discussion (D1, D2).
- [ ] Plus aucun onglet pilule dans la page (D3).
- [ ] Header : bandeau diagonal **couleurs New Life**, titre à gauche, pile d'avatars + bouton Requêtes à droite ; pas de hamburger ni avatar central (D4, D5).
- [ ] Rangée « groupes à rejoindre » présente et distincte des conversations (D6).
- [ ] Liste des conversations **à plat**, sans sections, groupes + DM mélangés, triée par récence (D7).
- [ ] Tap conversation → ouvre le chat ; aucune icône visio/audio nulle part (D8).
- [ ] Aucun FAB sur la page Échanges ; FAB central médiathèque intact (D9).
- [ ] Profil-membre accessible, bouton « Message » ouvre une conversation directe (D10).
- [ ] Tap sur le nom d'un groupe → fiche Telegram (en-tête + description + médias partagés + membres) ; tap membre → profil ; tap auteur d'un message reçu → profil (D15).
- [ ] Tap sur le nom d'une **discussion privée** → fiche membre détaillée (en-tête + Message + médias partagés) — parité utilisateur simple (D16).
- [ ] Tap sur une vignette média → visionneuse plein écran (zoom, défilement) ; bouton télécharger → enregistrement dans Photos ; erreurs gérées (permission/réseau) ; bouton masqué sur web (D17).
- [ ] Vérifier qu'aucun Podfile n'est réapparu (gal en SPM) ; permissions iOS/Android présentes.
- [ ] Rangée « groupes à rejoindre » : pas de débordement (RenderFlex overflow) sur un nom à 2 lignes.
- [ ] Bouton Requêtes (haut-droite) → écran Requêtes avec **état vide** + bouton ajouter → formulaire existant (D11, D12).
- [ ] Route `/prayers` toujours présente, non rebranchée dans Échanges (D13).
- [ ] Modèle `Conversation` en place, tout reste fictif/synchrone (D14).
- [ ] `flutter analyze` propre (0 erreur).
- [ ] i18n : aucune string en dur dans les nouveaux écrans ; `flutter gen-l10n` passé ; les 3 `.arb` cohérents.
- [ ] App lancée, parcours vérifié de bout en bout.

## 5. Notes & pièges

- **Une seule commande Flutter à la fois** (build_runner verrouille, `flutter test` rampe).
- `navGroups` servait bottom nav **et** 1er onglet — l'onglet disparaît, la clé ne sert plus que la bottom nav.
- `_InboxTab` réutilisait `groupsProvider` : bien basculer vers `conversationsProvider`.
- Nav domaines réels = id en `pathParameter` ; le `/group-chat` avec objet en `extra` est du legacy — acceptable ici tant que c'est fictif, mais préférer passer un id/`Conversation` proprement.
- Contrat futur messagerie documenté dans `mobile/docs/messagerie-groupe.md` (origine message sur `(authorId, isSystem)`, ADR-0032) — ne pas casser cette intention dans le modèle.
