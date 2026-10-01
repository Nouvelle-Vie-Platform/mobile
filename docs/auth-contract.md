# Contrat d'authentification — Maison du Miracle

> **v2 — contrat négocié avec le backend** (`new-life-server`, AdonisJS 7).
> La v1 était définie unilatéralement par le front contre un backend imaginaire ; elle divergeait de
> l'implémentation réelle sur une dizaine de points (JWT, code à 4 chiffres, `PATCH /auth/me`,
> `GET /branches`, `fullName`, `channel: sms`, `expiredCode`…). Cette version fait foi.
> Côté serveur : [ADR-0020](../../new-life-server/docs/adr/0020-otp-facteur-authentification-primaire.md).

## Principes

- **Login et inscription sont un seul parcours.** On saisit un identifiant (téléphone **ou** email),
  on reçoit un code à **6 chiffres**, on entre. Si l'identité est nouvelle, on propose (facultatif) de
  compléter le profil. Le **serveur crée le compte** lors de la vérification du code — il n'y a pas
  d'inscription séparée.
- **Une seule abstraction : `AuthRepository`.** Surcharger `authRepositoryProvider` suffit à changer
  d'implémentation — aucun écran ne change.
- **Token opaque, pas JWT.** Chaîne `oat_…` émise et stockée en base par le serveur, transmise en
  `Authorization: Bearer <token>`. Elle ne contient **aucune information** : ne jamais tenter de la
  décoder.
- **`profileComplete` n'est jamais bloquant.** Il pilote une bannière d'invitation, rien d'autre.
- Le serveur est **seule source de vérité** pour `isNewUser` et `profileComplete`.
- Le serveur **normalise et valide** les identifiants. Le front normalise aussi, pour l'ergonomie —
  jamais parce que le serveur en dépend.

## Modèles (Dart / JSON)

```dart
enum IdentifierChannel { phone, email }   // JSON: "phone" | "email"
enum UserTitle { brother, sister }        // JSON: "brother" | "sister"
enum UserStatus { affiliated, newcomer }  // JSON: "affiliated" | "newcomer"

class User {
  final String id;             // uuid
  final String? phone;         // E.164, ex. "+22890123456"
  final String? email;         // minuscules
  final UserTitle? title;      // null tant que le profil n'est pas complété
  final String? firstName;     // prénom — le champ saisi au profil
  final String? lastName;      // nom de famille — renseigné plus tard, souvent null
  final int? branchId;         // null = « je suis nouveau » ou pas encore répondu
  final UserStatus status;     // dérivé côté serveur de branchId
  final String? avatarUrl;
  final bool profileComplete;  // calculé côté serveur
}

class Session {
  final String token;          // token opaque, PAS un JWT
  final User user;
  final bool isNewUser;
}

class Branch {
  final int id;                // SERIAL côté serveur
  final String name;           // composé par le serveur : église + ville
  final String? city;          // la ville seule, servie EN PLUS de `name`
  final String? address;
  final bool isMotherChurch;
}
```

### Le nom d'une branche : composé par le serveur, raccourci par le client

`branches.name` ne porte plus, en base, que **l'église** — la même valeur pour les neuf branches ;
c'est `city` qui les distingue. Le serveur recompose donc `name` à la sérialisation
(« Eglise Evangélique Nouvelle Vie Lomé ») **et** envoie `city` à côté, sans que le contrat mobile
ait bougé.

Le client s'en sert à deux endroits, différemment :

| écran | affiche | pourquoi |
| --- | --- | --- |
| sélecteur de branche (`ProfileFormScreen`, `ProfileSetupSheet`) | `city` — « Lomé · Église Mère » | l'écran dit déjà « Votre branche » ; répéter le nom de l'église sur neuf lignes pousse la ville hors de l'écran |
| en-tête de l'onglet Profil | `name` entier | on y lit sa fiche d'identité, pas une liste où l'on choisit |

La règle vit **une seule fois**, dans `utils/branch_label.dart` (`branchSelectionLabel`,
`branchesForSelection`) — le pendant mobile de `branch_display.ts`. Deux points qui s'y rattrapent :
`city` est **nullable** (le portail permet de la vider) et le libellé se replie alors sur `name` ;
et l'**ordre** vient du client, jamais de `/sync/branches`, dont le curseur `(updated_at, id)`
répond à « qu'est-ce qui a changé » et se réordonne dès qu'un administrateur corrige une branche.

**Ne jamais découper `name`** pour en retirer le nom de l'église : `city` existe précisément pour
éviter ça, et un découpage survivrait mal au jour où l'église se renomme.

**Affichage du nom** : `title` et le nom sont stockés **séparément** et recomposés à l'affichage —
`Frère Jean`, `Frère Jean Kossi` quand `lastName` existe. Ne jamais concaténer en base.

**Localisation de `title`** : `brother`/`sister` sont des **clés**, pas des libellés. Le rendu passe
par `context.l10n` (fr / en / ee) — jamais de chaîne en dur dans le modèle.

**`status` est dérivé** côté serveur : `branchId != null → affiliated`, sinon `newcomer`. L'envoyer
dans `updateProfile` ne fait qu'exprimer une intention (« je suis nouveau ») ; `branchId` fait foi.

## Interface `AuthRepository` (Dart)

```dart
abstract interface class AuthRepository {
  /// Envoie un code à 6 chiffres sur le canal choisi.
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  });

  /// Vérifie le code. Réussite → session (token + user + isNewUser).
  /// Crée le compte côté serveur si l'identifiant est inconnu.
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  });

  /// Connexion sociale — **non exposée dans l'UI** pour l'instant (voir « Hors périmètre »).
  Future<Session> signInWithGoogle();
  Future<Session> signInWithApple();

  /// Complète / met à jour le profil (nécessite un token). Facultatif.
  Future<User> updateProfile({
    UserTitle? title,
    String? firstName,
    String? lastName,
    int? branchId,             // null + status newcomer = « je suis nouveau »
    UserStatus? status,
  });

  /// Utilisateur courant : cache local d'abord, puis revalidation réseau.
  Future<User?> currentUser();

  Future<void> signOut();
}
```

## Erreurs

```dart
enum AuthErrorCode { invalidCode, tooManyAttempts, network, unknown }
```

`expiredCode` **n'existe plus** : le serveur fusionne délibérément « invalide » et « expiré » dans une
seule réponse générique, pour ne pas renseigner un attaquant sur l'état d'un code. Un seul message
utilisateur couvre les deux cas.

Le mapping se fait sur le champ **`code`** du corps, **jamais sur le statut HTTP seul** — deux erreurs
distinctes partagent le 429 :

| `code` serveur | HTTP | `AuthErrorCode` | message utilisateur |
| --- | --- | --- | --- |
| `E_INVALID_OTP_CODE` | 422 | `invalidCode` | « Code invalide ou expiré » |
| `E_OTP_TOO_MANY_ATTEMPTS` | 429 | `tooManyAttempts` | « Trop d'essais — demande un nouveau code » |
| `E_OTP_RATE_LIMITED` | 429 | `tooManyAttempts` | « Patiente avant de redemander un code » |
| `E_VALIDATION_ERROR` | 422 | `unknown` | message du validateur (déjà localisé) |
| `E_UNAUTHORIZED_ACCESS` | 401 | — | purge du token + retour à `/auth` |

Le 401 n'est **pas** une erreur d'authentification métier : il est intercepté globalement dans
`ApiClient` (purge du token, retour à `/auth`), pour que chaque repository n'ait pas à le refaire.

Les 429 portent un en-tête **`Retry-After`** et un `retryAfter` (secondes) : afficher **ce** décompte
plutôt qu'une valeur codée en dur.

## Endpoints HTTP

Base : `String.fromEnvironment('API_BASE_URL')`. **HTTPS obligatoire en release** — l'app refuse de
démarrer sur une URL en clair (le token Bearer y transiterait lisible).

| Méthode & chemin | Body | Réponse 2xx | Erreurs |
| --- | --- | --- | --- |
| `POST /auth/request-code` | `{ "identifier": "+22890123456", "channel": "phone" }` | `202 { "status": "sent" }` | `422` identifiant invalide, `429` |
| `POST /auth/verify-code` | `{ "identifier": "…", "code": "123456" }` | `200 { "token", "user", "isNewUser" }` | `422` code invalide, `429` |
| `GET /auth/me` | — (Bearer) | `200 User` | `401` |
| `PUT /auth/profile` | `{ "title"?, "firstName"?, "lastName"?, "branchId"?, "status"? }` (Bearer) | `200 User` | `401`, `422` |
| `POST /auth/sign-out` | — (Bearer) | `200` | — |
| `GET /sync/branches` | — (Bearer) | `200 { "items": Branch[], "next_cursor", "has_more", "full_resync" }` | `401` |

**Il n'y a pas de `GET /branches`** : les branches sont un référentiel servi par le module de
synchronisation. Pour ce jalon on appelle `/sync/branches` **sans `since`** et on ignore le curseur ;
le vrai protocole delta viendra avec la synchro complète. L'écran profil étant post-token, le guard
`api` ne pose aucun problème d'ordre.

### Enveloppe `data`

**Toutes** les réponses du serveur sont enveloppées : `{ "data": … }`. Le déballage se fait **une seule
fois**, dans un intercepteur de `ApiClient` — les repositories reçoivent le contenu à plat et n'ont
rien à savoir de l'enveloppe. Le tableau ci-dessus décrit ce que voit le **code Dart**, après
déballage.

### Notes de contrat

- **`identifier`** : téléphone normalisé **E.164** (indicatif déduit du locale, repli `+228`,
  modifiable) ou email en **minuscules**. Le serveur re-normalise et rejette en `422` un numéro
  invalide.
- **`channel`** : `phone` (et non `sms`) — il désigne un **type d'identifiant**, pas un transport. Le
  code peut partir par SMS, WhatsApp ou autre sans que le contrat change.
- **`isNewUser`** : `true` → écran profil (skippable) ; `false` → accueil.
- **Cooldown de renvoi : 60 s**, aligné sur le serveur (`E_OTP_RATE_LIMITED` en deçà).
- **`branchId` est un entier**, comme `Branch.id` — les deux se comparent directement.

## Stockage local

| donnée | où | pourquoi |
| --- | --- | --- |
| **token** | `flutter_secure_storage` | secret — Keychain / Keystore, adossé au matériel, hors sauvegardes |
| `User` en cache | `flutter_secure_storage` (JSON) | démarrage hors-ligne ; migrera vers ObjectBox au jalon synchro |
| référentiels, contenus | _(à venir)_ ObjectBox | ce qu'on peut re-télécharger |

Règle : **le coffre contient ce qu'on ne peut pas re-télécharger ; la base locale contient le reste.**
Le token ne va **jamais** en base locale — ObjectBox écrit un fichier non chiffré, susceptible de
remonter dans une sauvegarde iCloud/Android et d'être restauré sur un autre appareil.

**Démarrage** : le splash lit le `User` en cache et route **immédiatement**, pendant que `/auth/me`
revalide en arrière-plan. Pas d'aller-retour réseau bloquant avant d'afficher quoi que ce soit — et
l'app reste utilisable hors connexion.

## Cycle de vie du token

Émis pour **90 jours**, **repoussés automatiquement** tant que l'utilisateur est actif (plafond absolu :
un an). Le serveur fait glisser la date sans changer la chaîne — **le mobile n'a rien à implémenter,
ni rafraîchissement, ni rotation.** En pratique : 90 jours d'inactivité → déconnexion.

`signOut()` appelle le serveur (révocation du token courant, les autres appareils restent connectés)
puis supprime le token local **quoi qu'il arrive** — une erreur réseau ne doit jamais laisser
l'utilisateur connecté sur son appareil.

## Hors périmètre de ce jalon

- **Google / Apple** : les boutons sont **retirés** de l'écran identifiant (ils lèvent
  `UnimplementedError`). Les méthodes restent dans `AuthRepository`. Réactivation = plugins natifs +
  comptes développeur + `isNewUser` à ajouter côté serveur. À noter : ajouter Google **crée**
  l'obligation « Sign in with Apple » (règle App Store 4.8) ; ne rien proposer ne la crée pas.
- **Suppression de compte** (`DELETE /auth/me`) : **prérequis de première soumission App Store**
  (règle 5.1.1(v)) et exigence Google Play équivalente. À traiter juste après ce jalon.
- **Rattachement d'un second identifiant** : **prérequis bloquant avant l'ouverture du canal
  téléphone.** Un identifiant = une identité ; sans ce flux, les membres inscrits par email se
  recréeraient tous un compte le jour où le téléphone redeviendra le canal par défaut.
- **ObjectBox** : introduit au jalon synchro (où il porte une douzaine d'entités), pas ici pour un seul
  objet. Il ne supporte pas Flutter Web — l'abandon de cette cible se décidera à ce moment-là.
- **`Branch.city`** : *résolu.* Le serveur le sert depuis le découpage `name` / `city`
  (`BranchTransformer`), et le sélecteur affiche **la ville seule** — voir « Le nom d'une branche »
  ci-dessous.

## Décisions figées

1. Parcours unifié login/inscription ; le compte est créé à la **vérification du code**.
2. **Le sélecteur de canal est une offre, pas une préférence** (#83, jumelle serveur #468). Les canaux
   ouverts sont ceux que le portail déclare (collection `auth_channels`, servie **sans compte**) :
   deux ouverts ⇒ le toggle Téléphone/Email, **email présélectionné** ; un seul ⇒ **pas de toggle du
   tout** — on ne grise pas une option, on ne la propose pas —, le champ de ce canal, et l'annonce du
   portail à la place du sous-titre (`loginNotice`, `null` ou vide ⇒ le libellé du dépôt).
   **Avant la première synchronisation, le repli est l'e-mail seul** : jamais « tous les canaux » (ce
   serait reconduire la promesse d'un code que personne n'envoie), jamais « aucun canal » (ce serait
   fermer la porte). Le serveur refuse par ailleurs en **403** un identifiant dont le canal est fermé.
3. Indicatif déduit du **locale**, repli **`+228`**, modifiable.
4. Écran profil **skippable**.
5. Profil incomplet → **bannière douce** fermable (Accueil + onglet Profil).
6. « Je suis nouveau » = `branchId: null` + `status: newcomer`. Les branches viennent de
   `/sync/branches`.
7. **Frère/Sœur requis** dès qu'un nom est saisi ; `title` et nom stockés séparément.
8. Code **6 chiffres**, cases séparées, validation auto, renvoi après **60 s**.
9. Google/Apple hors périmètre, boutons retirés.
10. Token dans le **coffre sécurisé** ; `User` en cache pour le démarrage hors-ligne.
11. Routes séparées (`screens/auth/`), gardes `redirect` pilotées par `authProvider`.
12. Contrat **négocié** avec le backend (ce fichier) ; token **opaque**, jamais JWT.
13. **Splash = aiguillage automatique**, servi par le cache local.
14. Onglet Profil câblé au `User` réel, édition réutilisant l'écran profil, déconnexion confirmée.
15. **Écran de bienvenue** conservé en première page de `/auth`.
16. URL du backend par `--dart-define=API_BASE_URL` ; **HTTP clair refusé en release**.
