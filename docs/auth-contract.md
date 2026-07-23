# Contrat d'authentification — Maison du Miracle

> Source de vérité du parcours **login/inscription unifié** (téléphone/email + code
> OTP, avec Google/Apple sans code). Le **front définit ce contrat**, le **backend
> s'aligne dessus** (décision : approche « A »). Phase actuelle : **C (mock)** —
> `AuthRepository` factice ; phase suivante : **B (vrai backend)** = une autre
> implémentation de la même interface, **aucun écran ne change**.

## Principes

- **Login et inscription sont un seul parcours.** L'utilisateur saisit un
  identifiant (téléphone **ou** email) → reçoit un code à **4 chiffres** → le
  saisit → entre dans l'app. S'il est **nouveau**, on lui propose (facultatif) de
  compléter son profil. Google/Apple = même chose **sans l'étape code**.
- **Une seule abstraction : `AuthRepository`.** Surcharger le provider suffit à
  brancher le vrai backend (même pattern que `churchRepositoryProvider`).
- **Token : JWT Bearer** dans l'en-tête `Authorization: Bearer <token>`.
- **`profileComplete` n'est jamais bloquant** (profil skippable). Il pilote
  seulement une **bannière douce** d'invitation.
- Le back est la **seule source de vérité** pour « nouvel utilisateur »
  (`isNewUser`) : un numéro peut être nouveau sur ce téléphone mais déjà connu.

## Modèles (Dart / JSON)

```dart
enum IdentifierChannel { sms, email }   // JSON: "sms" | "email"
enum UserTitle { frere, soeur }         // JSON: "frere" | "soeur"
enum UserStatus { membre, nouveau }     // JSON: "membre" | "nouveau"

class User {
  final String id;
  final String? phone;         // format E.164, ex. "+22890123456"
  final String? email;
  final UserTitle? title;      // null tant que profil non complété
  final String? fullName;      // nom seul, SANS préfixe Frère/Sœur
  final String? branchId;      // null si "Je suis nouveau" / non rattaché
  final UserStatus status;     // "nouveau" par défaut, "membre" si branche choisie
  final String? avatarUrl;
  final bool profileComplete;  // calculé côté back (title + fullName + (branchId|status nouveau))
}

class Session {
  final String token;          // JWT
  final User user;
  final bool isNewUser;        // true = première connexion de cette identité
}
```

### Affichage du nom
`title` + `fullName` sont stockés **séparément** et recomposés à l'affichage :
`Frère Jean Kossi`. Ne jamais concaténer en base.

## Interface `AuthRepository` (Dart)

```dart
abstract interface class AuthRepository {
  /// Envoie un code à 4 chiffres sur le canal choisi.
  /// [identifier] : téléphone E.164 (ex. "+22890123456") ou email.
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  });

  /// Vérifie le code. Réussite → session (token + user + isNewUser).
  /// Échec → AuthException(code: invalidCode | expiredCode | tooManyAttempts).
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  });

  /// Connexion sociale : saute l'étape code. isNewUser possible = true.
  Future<Session> signInWithGoogle();
  Future<Session> signInWithApple();

  /// Complète / met à jour le profil (nécessite un token). Facultatif.
  Future<User> updateProfile({
    UserTitle? title,
    String? fullName,
    String? branchId,          // null = "Je suis nouveau"
    UserStatus? status,
  });

  /// Utilisateur courant depuis le token stocké (null si déconnecté).
  Future<User?> currentUser();

  Future<void> signOut();
}
```

### Erreurs

```dart
enum AuthErrorCode { invalidCode, expiredCode, tooManyAttempts, network, unknown }
class AuthException implements Exception { final AuthErrorCode code; final String? message; }
```

## Endpoints HTTP (phase B — vrai backend)

Base : `https://<api>/`. Toutes les réponses en JSON. Token JWT en `Bearer`.

| Méthode & chemin | Body | Réponse 2xx | Erreurs |
|---|---|---|---|
| `POST /auth/request-code` | `{ "identifier": "+22890123456", "channel": "sms" }` | `204 No Content` | `429` (trop de demandes), `400` (identifiant invalide) |
| `POST /auth/verify-code` | `{ "identifier": "...", "code": "1234" }` | `200 { "token", "user", "isNewUser" }` | `401` invalidCode, `410` expiredCode, `429` tooManyAttempts |
| `POST /auth/google` | `{ "idToken": "<google id token>" }` | `200 { "token", "user", "isNewUser" }` | `401` |
| `POST /auth/apple` | `{ "identityToken": "...", "authorizationCode": "..." }` | `200 { "token", "user", "isNewUser" }` | `401` |
| `GET /auth/me` | — (Bearer) | `200 { "user" }` | `401` |
| `PATCH /auth/me` | `{ "title": "frere", "fullName": "Jean Kossi", "branchId": null, "status": "nouveau" }` (Bearer) | `200 { "user" }` | `401`, `400` |
| `GET /branches` | — | `200 { "branches": [ { "id", "name", "city" } ] }` | — |
| `DELETE /auth/me` | — (Bearer) | `204` (suppression de compte — phase B) | `401` |

### Notes de contrat
- **`identifier`** : le front envoie le **téléphone déjà normalisé E.164** (indicatif
  déduit du locale, repli `+228`, modifiable) ou l'**email en minuscules**.
- **`channel`** est déterminé par le front selon le type saisi (`sms` pour un
  numéro, `email` pour un email).
- **`isNewUser`** : renvoyé à chaque `verify-code` / social. `true` → le front
  propose l'écran profil (skippable) ; `false` → home direct.
- **`profileComplete`** est calculé et renvoyé **par le back** dans `user` ; le
  front s'en sert uniquement pour la bannière.
- **`branchId: null` + `status: "nouveau"`** = « Je suis nouveau » (pas encore
  rattaché). Choisir une branche → `status: "membre"`.

## Comportement du mock (phase C, sans réseau)

- `requestCode` : ne fait rien (log), réussit toujours après un court délai simulé.
- `verifyCode` : code **`0000`** = succès ; tout autre = `AuthException(invalidCode)`.
  Une petite liste d'identifiants « déjà connus » dans `SampleData` renvoie
  `isNewUser: false` (→ home) ; sinon `isNewUser: true` (→ profil).
- `signInWithGoogle/Apple` : succès immédiat, `isNewUser: true` (→ profil).
- `updateProfile` : met à jour le `User` en mémoire, passe `profileComplete: true`.
- `currentUser` : session **en mémoire seule** (pas de persistance en phase C ;
  `flutter_secure_storage` ajouté en phase B). Redémarrage = déconnecté.
- Liste des **branches** : statique dans `SampleData` → `branchesProvider`
  (remplacée par `GET /branches` en phase B).

## Décisions figées (grilling)

1. **C** (mock) maintenant → **B** (vrai back) ensuite, sans toucher l'UI.
2. Toggle **Téléphone/Email**, téléphone en premier.
3. Indicatif déduit du **locale**, repli **`+228`**, modifiable.
4. Écran profil **skippable** (« Nous aimerions en savoir plus sur vous »).
5. Profil incomplet → **bannière douce** fermable (Accueil + onglet Profil).
6. Branche = liste **statique** pour l'instant ; « Je suis nouveau » = `branchId
   null` + `status nouveau`.
7. **Frère/Sœur requis** dès qu'on saisit le nom ; `title` + `fullName` séparés.
8. Code **4 chiffres**, cases séparées, validation auto, renvoi (cooldown ~45 s),
   erreurs incorrect/expiré.
9. Google/Apple **sautent l'OTP mais pas le profil** ; tout derrière
   `AuthRepository` ; boutons conditionnés à la plateforme le moment venu.
10. Session **en mémoire** (mock) ; persistance sécurisée en phase B.
11. **Routes séparées** (`screens/auth/`), suppression de `login_screen` +
    `register_screen`, gardes `redirect` pilotées par `authProvider`.
12. Contrat défini par le **front** (ce fichier) ; token **JWT Bearer**.
13. **Splash = aiguillage automatique** (connecté → `/home`, sinon → `/auth`),
    plus de tap.
14. Onglet **Profil** câblé au `User` réel, **édition** réutilisant l'écran profil,
    **déconnexion confirmée** ; suppression de compte = phase B (`DELETE /auth/me`).
15. **Écran de bienvenue** (verset + visuels) conservé en première page de `/auth`,
    avec « Déjà membre ? » menant au même écran identifiant (flow unifié).
