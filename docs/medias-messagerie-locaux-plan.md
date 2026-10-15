# Les médias de la messagerie vivent sur le téléphone

**Statut** : cadrage validé le 2026-10-15. Quatre tranches, dépôt `mobile` seul.
**Origine** : une remarque de l'utilisateur — « tout ce qui est envoyé dans la messagerie doit être
enregistré en local et dès là servi en local ; si déjà présent en local, pas de requête au serveur ».

## 1. Ce que l'application fait aujourd'hui — constaté dans le code, pas supposé

| Média | Comportement actuel | Où |
| --- | --- | --- |
| **ce que j'envoie** | le fichier est **effacé après l'envoi**, puis retéléchargé pour s'afficher | `GroupDao.pendingMediaFiles()` ne garde que « les fichiers encore cités par un écho » ; `mediaPath` vit dans `PendingGroupMessages`, pas dans `GroupMessages` |
| **image, vidéo, vocal reçus** | **jamais** enregistrés : URL présignée relue **à chaque affichage** | `message_media_view.dart` → `GroupMediaUrls.resolve()` |
| **document reçu** | mis en cache, mais **inutilisable hors ligne** | `group_media_urls.dart` |
| URL présignées | cache **en mémoire**, 50 min | `HttpGroupMediaUrls._cache` |

### Le défaut du cache des documents

```dart
final url = await resolve(...);                   // requête réseau
if (url == null) return null;                     // hors ligne : abandon
...
if (await File(target).exists()) return target;   // le test arrive trop tard
```

L'ordre est inversé : on demande l'URL présignée **avant** de regarder si le fichier est déjà là.
Deux conséquences : **un document déjà téléchargé est illisible hors ligne**, et chaque ouverture
coûte une requête pour rien. Le dossier est en plus `getTemporaryDirectory()`, que le système peut
vider quand il veut — « enregistré en local » n'y est donc jamais durable.

## 2. Ce qui est déjà acquis — ne pas le refaire

- `GroupMessages.mediaSize` (`group_tables.dart:350`) : **le serveur donne déjà la taille**. Aucun
  travail serveur dans ce chantier.
- `MessageMedia.fromColumns()` accepte **déjà** `localPath` et `localThumbPath` : le modèle sait
  porter un chemin local, personne ne le lui donne pour un message reçu.
- `MediaOutbox` sait déjà garder un fichier à travers un redémarrage.
- Le moteur du téléchargement offline (`lib/data/downloads/`) sait déjà faire une file de fond,
  l'attente du wifi et le pré-check d'espace. **S'en inspirer, ne pas le dupliquer.**

## 3. Décisions (grilling du 2026-10-15) et leur raison

| Décision | Raison |
| --- | --- |
| **On garde tout ; c'est le fidèle qui purge**, par un écran « Stockage » qui montre ce que chaque conversation occupe. | Rien ne doit disparaître dans le dos de quelqu'un. Un mécanisme d'éviction automatique se trompe toujours sur le média auquel on tenait. |
| **Un média reçu descend à la réception, en wifi seulement.** | Le fil est consultable hors ligne sans un geste, et les données mobiles ne partent jamais sans accord — au Togo c'est un vrai coût. |
| Le réglage vit dans un **quatrième onglet MESSAGERIE** de `/settings/media` (RADIO · ÉCOUTE · TÉLÉCHARGEMENT · MESSAGERIE). | Toute la consommation de données se décide au même endroit. Réutiliser l'interrupteur de l'onglet TÉLÉCHARGEMENT aurait mis deux gestes très différents sous un seul bouton : un enseignement d'une heure et les vidéos d'un groupe. |
| **Un média d'un message ne change jamais** : la clé locale est l'identité du message. | Pas de validation à inventer. Et c'est heureux : sur cette origine, `If-Range` est **ignoré** (ADR-0012 de `streaming-service`), donc aucune garde conditionnelle n'est fiable. |
| Pas d'enregistrement dans la galerie du téléphone. | Hors de la remarque d'origine ; à rouvrir si on le demande. |

## 4. Les tranches

**T1 bloque les trois autres.**

- **T1 — le magasin durable et la règle « local d'abord »**. Un dossier qui survit au système (pas
  `getTemporaryDirectory()`), une clé par message et par variante (fichier, vignette), la colonne
  Drift qui manque sur `GroupMessages`, et **le test du disque avant toute requête**. Les bulles
  image, vidéo et vocal servent le fichier local quand il est là.
- **T2 — mes envois ne quittent plus le téléphone**. À l'envoi réussi, le fichier de l'outbox
  **passe** dans le magasin au lieu d'être balayé. On n'a jamais à retélécharger ce qu'on a envoyé.
- **T3 — la descente automatique, en wifi**. File de fond, attente du wifi, et le quatrième onglet
  MESSAGERIE. L'historique se remplit au fil de la navigation : un média affiché est gardé.
- **T4 — l'écran « Stockage » et la purge manuelle**. Ce que chaque conversation occupe, et de quoi
  vider. Ce qui est purgé redevient téléchargeable à la demande.

## 5. Ce qui ne s'automatisera pas

La survie d'un fichier à une mise en veille prolongée, le comportement réel du système quand il
réclame de la place, et la descente en wifi sur un réseau qui bascule. À ajouter au protocole
`docs/verification-sur-appareil.md`, qui ne couvre aujourd'hui que le lecteur et les fichiers
tronqués.
