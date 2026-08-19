# Réveil push — le maillon restant (le seam natif)

> Feuille de route du **dernier maillon** du réveil push mobile. Tout le squelette
> est livré, testé sur la VM, derrière des abstractions et des doubles inertes
> (`lib/data/push/`, providers dans `lib/state/push_providers.dart`, câblage dans
> `lib/app.dart`). Ce qui reste ici est **exactement** ce qui exige Firebase
> debout et des **dépendances natives** que `CLAUDE.md` interdit d'ajouter avant :
> iOS est SPM-only (un plugin sans `Package.swift` ressuscite CocoaPods) et
> Firebase n'est pas configuré (`google-services.json` / `GoogleService-Info.plist`
> absents → un build échouerait). Réf. PRD `docs/prd/notifications-push.md`
> (décisions **D1–D8**, §6 « Prérequis d'exploitation »).

## 0. Prérequis (porteur du projet, PRD §6) — à faire AVANT le code

- **Firebase** : projet créé ; `google-services.json` (Android) ;
  `GoogleService-Info.plist` (iOS) ; **clé d'authentification APNs** téléversée
  dans Firebase (sans elle, **aucun** push iOS) ; compte de service Firebase Admin
  côté serveur (déjà attendu par les pushers existants).
- **ntfy self-host** (incrément 2 seulement) : instance debout, contrôle d'accès,
  un **token publisher** `NTFY_PUBLISH_TOKEN` écrivant sur `up*`, l'app ntfy des
  devices authentifiée en lecture.

## 1. Ce qui est DÉJÀ livré (ne rien réécrire)

Tout se teste sur la VM, aucune dépendance native ajoutée :

| Fichier | Rôle |
|---|---|
| `lib/data/push/push_transport.dart` | contrat `PushTransport` + valeur `PushRegistration` (`{token, platform, transport}`), `kPushTransportFcm` / `kPushTransportUnifiedPush` |
| `lib/data/push/inert_push_transport.dart` | double inerte (`obtainRegistration → null`, `onRefresh` vide) |
| `lib/data/push/platform_push_capabilities.dart` | contrat des 3 faits (iOS ? GMS ? distributeur ?) + `FixedPushCapabilities` ; **seam `RuntimePushCapabilities` déjà esquissé en commentaire** |
| `lib/data/push/transport_selector.dart` | règle **D4** pure : `selectPushTransport(caps) → 'fcm' | 'unifiedpush' | null` |
| `lib/data/push/device_registrar.dart` | `HttpDeviceRegistrar` (**réel**, `POST /devices/tokens`, purge par `POST /auth/sign-out {deviceToken}`) + `InertDeviceRegistrar` |
| `lib/data/push/push_registration_service.dart` | `start` / `signOut` / `dispose` — obtient l'inscription et la POSTe, réenregistre sur rotation |
| `lib/data/push/push_wake_payload.dart` | décodage tolérant du réveil content-free `{type, groupId, messageId}` |
| `lib/data/push/local_notifier.dart` | contrat `LocalNotifier` + `InertLocalNotifier` |
| `lib/data/push/push_wake_handler.dart` | **D6** : `onSync()` → lit le magasin → compose → notifie ; silencieux si introuvable |
| `lib/state/push_providers.dart` | les 6 providers ci-dessous |
| `lib/app.dart` | démarre `PushRegistrationService` au premier frame (à côté du `RealtimeService`), gate session, dispose propre |
| `lib/data/sync/sync_scheduler.dart` | valeur d'enum `SyncTrigger.push` |

**Point d'articulation** : le service **n'obtient rien** aujourd'hui parce que
`pushTransportProvider` rend `InertPushTransport` (`obtainRegistration → null`).
Poser le transport réel « allume » toute la chaîne **sans toucher un autre
fichier**.

## 2. Les fichiers réels à CRÉER (Firebase debout)

Tous dans `lib/data/push/`, chacun **le seul** du dépôt à importer son plugin —
même discipline que `ConnectivityNetworkTransport` / `JustAudioContentPlayer`.

### 2.1 `FcmPushTransport` — `lib/data/push/fcm_push_transport.dart`

- **Dépendances** : `firebase_core`, `firebase_messaging` (`pubspec.yaml`).
- **Implémente** `PushTransport` :
  - `obtainRegistration()` : demande la permission (iOS/Android 13+), lit
    `FirebaseMessaging.instance.getToken()`, et compose une `PushRegistration`
    `{token, platform, transport}`. Le `transport` **se choisit** ici via
    `selectPushTransport(RuntimePushCapabilities())` (incrément 2) — en incrément
    FCM pur, c'est toujours `kPushTransportFcm`. Le `platform` = `ios`/`android`/
    `web` selon `Platform` / `kIsWeb`.
  - `onRefresh` : mappe `FirebaseMessaging.instance.onTokenRefresh` en
    `PushRegistration` (mêmes `platform`/`transport`).
  - `dispose()` : annule l'abonnement `onTokenRefresh`. **Ne purge pas** le
    serveur.
- **Dégradé** (comme les autres transports) : permission refusée ou token nul →
  `obtainRegistration()` rend **`null`** (pas une exception). Le service avale
  déjà `null` (dégradé propre **D4**).

### 2.2 `RuntimePushCapabilities` — dans `platform_push_capabilities.dart`

Le squelette est **déjà écrit en commentaire** en fin de fichier (`Platform.isIOS`,
`google_api_availability`, `unifiedpush`). Le décommenter, ajouter les deux
dépendances, et respecter la règle du dégradé : **toute panne de canal → `false`**
(un faux `true` prétendrait joignable un appareil qui ne l'est pas). Nécessaire
seulement pour l'**incrément 2** (choix FCM vs UnifiedPush) ; en incrément FCM
pur, `FcmPushTransport` peut coder `transport = fcm` en dur.

### 2.3 `FlutterLocalNotifier` — `lib/data/push/flutter_local_notifier.dart`

- **Dépendance** : `flutter_local_notifications`.
- **Implémente** `LocalNotifier.show(PushNotificationContent content)` :
  `FlutterLocalNotificationsPlugin().show(...)` avec `content.title` / `content.body`,
  et **`content.conversationId` posé dans le `payload`** de la notification — c'est
  la clé du **deep-link au tap** (ouvrir la conversation). Créer un canal Android
  dédié aux messages. Aucun changement au `PushWakeHandler` : c'est l'intérêt du
  seam.

### 2.4 Le **background isolate handler** FCM — `lib/data/push/fcm_background.dart`

Le maillon le plus subtil (**D6**), aujourd'hui **absent** (le `PushWakeHandler`
est prêt mais **jamais déclenché** — cf. `app.dart`). Il tourne dans un **isolate
séparé**, sans l'arbre de widgets ni le `ProviderContainer` de l'app :

- Fonction top-level annotée `@pragma('vm:entry-point')`, passée à
  `FirebaseMessaging.onBackgroundMessage(...)` dans `main()` (voir §3).
- Dedans, **tout se reconstruit à la main** (l'isolate ne partage rien) :
  `WidgetsFlutterBinding.ensureInitialized()`, `Firebase.initializeApp()`, ouvrir
  **une** `AppDatabase` (Drift rouvre le même fichier SQLite), instancier un
  `SyncScheduler`/`SyncEngine` pour le `onSync`, un `GroupDao`, un
  `FlutterLocalNotifier`, lire le `currentUserId` du coffre.
- Décoder : `PushWakePayload.tryParse(message.data)` → si `null`, **retour
  silencieux**.
- Exécuter : `PushWakeHandler(onSync: …, groupDao: …, notifier: …,
  currentUserId: …).handle(payload)`. Le handler fait déjà **sync → lecture →
  notif**, et reste **silencieux** si le message est introuvable après sync.
- **iOS best-effort assumé** (**D8**) : les pushs silencieux iOS sont bridés ;
  le patron fiable (push alerte + `mutable-content` + Notification Service
  Extension Swift lisant le magasin via app-group) est **reporté**, à ajouter
  seulement si la fiabilité iOS se révèle insuffisante.

> Le `pushWakeHandlerProvider` (dans `push_providers.dart`) reste utile pour le
> chemin **premier plan** (`FirebaseMessaging.onMessage`), où le `ProviderContainer`
> existe : on peut y lire le handler tout construit. L'isolate **background**, lui,
> ne peut pas lire ce provider (pas de container) et reconstruit à la main.

### 2.5 Le **tap → deep-link** (ouverture de la conversation)

Au tap d'une notification (app lancée par la notif, ou au premier plan), lire le
`payload` (= `conversationId` = `groups.id`) et router vers la conversation via
`go_router`. Point de branchement : `main.dart` / `app.dart` (là où le routeur
existe), sur le callback `onDidReceiveNotificationResponse` de
`flutter_local_notifications` et `FirebaseMessaging.onMessageOpenedApp` /
`getInitialMessage`.

## 3. Config native à ajouter (Firebase debout)

- **`main.dart`** : `await Firebase.initializeApp(...)` ; enregistrer le handler
  background (`FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler)`) ;
  câbler `onMessage` (premier plan) et le tap.
- **Android** : `google-services.json` ; plugin Gradle `com.google.gms.google-services` ;
  canal de notification ; permission `POST_NOTIFICATIONS` (déjà demandée à
  l'exécution pour l'audio — mutualiser).
- **iOS** (SPM-only, **ne pas** réintroduire CocoaPods) : `GoogleService-Info.plist` ;
  capacité **Push Notifications** ; **Background Modes → Remote notifications** ;
  clé APNs dans Firebase. Les paquets Firebase exposent `Package.swift` — vérifier
  qu'ils s'ajoutent bien via SPM.

## 4. Les providers à FLIPPER (Inert → réel) — et rien d'autre

Dans `lib/state/push_providers.dart`, **trois** lignes changent ; tout le reste du
câblage (gate session, `start()`/`dispose` dans `app.dart`, service, handler) est
déjà en place :

| provider | aujourd'hui | flipper vers |
|---|---|---|
| `pushTransportProvider` | `const InertPushTransport()` | `FcmPushTransport(...)` — **et le rendre `autoDispose` scopé sur la session** (comme `transmitClientProvider`) pour repartir d'un transport vierge à chaque session |
| `platformPushCapabilitiesProvider` | `const FixedPushCapabilities()` | `const RuntimePushCapabilities()` (incrément 2) |
| `localNotifierProvider` | `const InertLocalNotifier()` | `FlutterLocalNotifier(...)` |
| `deviceRegistrarProvider` | `HttpDeviceRegistrar` sous backend | **déjà réel — ne rien changer** |

Chaque `TODO(push, Firebase debout)` du fichier marque exactement la ligne.

## 5. Un piège à ne pas oublier — le double `sign-out`

Il **n'existe pas** de `DELETE /devices/tokens` (choix serveur délibéré,
`app/devices/routes.ts`). Purger l'inscription = `POST /auth/sign-out {deviceToken}`
= **révoquer la session** : c'est la **même** opération (voir l'en-tête de
`device_registrar.dart`). Donc, le jour où le transport réel obtient une vraie
inscription (`_current` non nul), le câblage de **déconnexion** doit veiller à
n'émettre **qu'un** sign-out : soit la déconnexion appelle
`PushRegistrationService.signOut()` (qui poste le sign-out **avec** `deviceToken`),
soit elle appelle le sign-out d'`AuthController`, **jamais les deux**. Tant que le
transport est inerte, `_current` reste `null` et `signOut()` est un no-op : **aucun
risque aujourd'hui**, mais à trancher avant de brancher `FcmPushTransport`.

## 6. Incrément 2 (ntfy/UnifiedPush) — réutilise tout le reste

Le PRD (**D7**, §8) impose l'ordre : (1) FCM bout-en-bout, (2) ntfy. L'incrément 2
n'ajoute, côté mobile, **que** :

- `RuntimePushCapabilities` réel (§2.2) — pour que `selectPushTransport` puisse
  rendre `unifiedpush` sur l'Android dé-googlé ;
- la voie d'enregistrement UnifiedPush dans `FcmPushTransport` (ou un
  `UnifiedPushTransport` jumeau) : négocier l'endpoint auprès du distributeur ntfy,
  le poser comme `token` avec `transport = unifiedpush`.

Le **handler**, la **notif locale**, le **registrar**, le **décodage du réveil** et
le **service** sont **partagés** — rien à refaire (c'est le sens de D7). Côté
serveur, l'incrément 2 ajoute `UnifiedPushPusher` + la couche de dispatch par
transport + `NTFY_PUBLISH_TOKEN` (hors périmètre mobile).
