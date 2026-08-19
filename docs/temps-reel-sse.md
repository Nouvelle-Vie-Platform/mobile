# Temps-réel des messages — SSE (Transmit) côté mobile

> Note de conception issue d'une session `/grill-me` (2026-08-19). Elle fige les décisions
> **avant** le code ; les subtilités iront ensuite dans les en-têtes des fichiers concernés
> (idiome du dépôt). Fait suite à [`messagerie-groupe.md`](messagerie-groupe.md) et à la messagerie
> directe (PRD serveur `messagerie-directe.md`).

## 0. Ce qui existe déjà (et ce qui manque)

- **Serveur : prêt, rien à faire.** `@adonisjs/transmit` est câblé (`config/transmit.ts`,
  `start/transmit.ts`). `TransmitGroupBroadcaster` diffuse **chaque message** sur le canal
  `groups/{groupId}` **après le commit**. Un DM **est** une ligne `groups`, donc
  `SendDirectMessageController` diffuse déjà sur `groups/{idDuDM}`. L'abonnement à `groups/:groupId`
  est **réservé aux membres** (`transmit.authorize` → `CheckGroupMembership`) : un DM a exactement
  ses 2 membres, un tiers est refusé sans code de plus. Routes `/__transmit/*` sous guard `api`.
- **Mobile : rien.** Le client ne s'abonne pas ; il ne synchronise que sur ses 3 déclencheurs
  (`SyncTrigger { appStart, foreground, pullToRefresh }`).

**L'invariant du dépôt tient et guide tout** : la base est la seule source de vérité, le SSE est un
**accélérateur** ; une coupure ne perd rien (repli sur le curseur `?since`).

## 1. Décisions

- **D1 — SSE → sync, pas SSE → peindre.** Un événement déclenche un **cycle de sync** (nouveau
  `SyncTrigger.realtime`) ; le message arrive par le flux delta comme d'habitude. « Le réseau ne
  peint jamais » (ADR-0026). Latence : un aller-retour `/sync`.
- **D2 — Abonnement large.** À **tous mes groupes/DM** — canaux `groups/{id}` lus depuis
  `group_members` **local** —, sur **une seule** connexion (Transmit multiplexe). Comme tout
  événement déclenche le *même* cycle de sync, s'abonner large ne coûte pas plus par événement mais
  rend la liste « Échanges » **et** le fil ouvert temps-réel.
- **D3 — Connexion au premier plan seulement.** Ouverte à `AppLifecycleState.resumed`, fermée à
  `paused`. L'arrière-plan (app fermée) est le rôle du **FCM**, hors périmètre.
- **D4 — Sync de rattrapage à chaque (re)connexion.** Le premier plan déclenche déjà une sync ; on
  la garde comme filet : ce qui a été émis pendant un trou SSE est rejoué par le curseur. **Non-perte
  garantie.**
- **D5 — Coalescing ~300 ms.** Les événements rapprochés (fil actif) se regroupent en **une** sync,
  pour ne pas marteler `/sync`.
- **D6 — Client Transmit maison.** Sur le `Dio` d'`ApiClient` (Bearer + 401 déjà gérés). Protocole
  Transmit : flux `GET /__transmit/events?uid={uid}` + `POST /__transmit/subscribe` `{uid, channel}`
  + `unsubscribe`. `uid` généré (paquet `uuid` déjà présent). **Derrière une abstraction**, avec un
  **double inerte** pour les tests.
- **D7 — Réabonnement réactif.** Le service **observe le flux Drift `group_members`** et
  (dés)abonne les canaux au changement. Couvre les **nouveaux DM** : la première ligne d'appartenance
  arrive par la sync (qui amène aussi le 1ᵉʳ message), on s'abonne alors au canal, les messages
  suivants sont live.
- **D8 — Web inclus, mais par un lecteur `fetch`.** `EventSource` natif **ne porte pas d'en-tête
  `Authorization`** — inutilisable avec le Bearer (guard `api`). Le chemin web utilise donc un
  **lecteur SSE basé sur `fetch`/`ReadableStream`** qui envoie l'en-tête (token **jamais** dans
  l'URL). Import conditionnel, patron `web_content_player.dart` (natif Dio ⟂ web fetch, une porte
  `if (dart.library.js_interop)`).

## 2. Surface (mobile)

- **`RealtimeService`** (nouveau), **dédié** — pas fondu dans `SyncScheduler` : il possède le client
  Transmit, observe le cycle de vie (`WidgetsBindingObserver`) et le flux `group_members`, coalesce,
  et appelle `SyncScheduler.trigger(SyncTrigger.realtime)`. Câblé dans `app.dart` sous
  `AppEnv.useBackend`, à côté de `SyncScheduler.start()`.
- **`TransmitClient`** (abstraction) + `HttpTransmitClient` (natif, Dio stream) +
  `WebTransmitClient` (fetch/EventSource, import conditionnel) + `InertTransmitClient` (tests).
- **`SyncScheduler`** : ajouter la valeur `SyncTrigger.realtime` (le corps de `trigger`/`synchronize`
  ne change pas — c'est un cycle de plus, jamais un polling ; le garde-fou « aucun `Timer` dans
  `lib/data/sync/` » reste vrai : la minuterie de coalescing vit dans `RealtimeService`, pas dans le
  moteur).

## 3. Points figés par cohérence

- Aucun `Timer` dans `lib/data/sync/` (règle existante) : le debounce de coalescing vit dans
  `RealtimeService`.
- Le canal est le même pour groupes et DM (`groups/{id}`) : le temps-réel des deux arrive d'un coup.
- Reconnexion : backoff simple + relecture ; à chaque réouverture, D4 (sync de rattrapage).

## 4. Vérification

- **Unitaire** : `TransmitClient` derrière abstraction, double inerte ; tester le `RealtimeService`
  (coalescing, réabonnement sur changement de `group_members`, déclenchement du bon `SyncTrigger`)
  avec un client factice.
- **Intégration `live-server`** : s'abonner au vrai serveur, faire émettre (un `sendDirect`), prouver
  qu'une sync se déclenche et que le message atterrit dans le magasin — dans la lignée de
  `test/integration/direct_messages_live_test.dart`.

## 5. Hors périmètre

- **FCM / réveil en arrière-plan** (app fermée) — le serveur émet déjà les push (`groupPusher`), la
  réception mobile est un autre slice.
- **Présence / « en train d'écrire »** — le broadcast ne porte que des messages aujourd'hui.

## 6. Ordre d'implémentation

1. `SyncTrigger.realtime` + `RealtimeService` (lifecycle, coalescing, réabonnement) contre un
   `TransmitClient` inerte — prouvé par tests unitaires.
2. `HttpTransmitClient` natif (Dio stream) + câblage `app.dart`.
3. `WebTransmitClient` (lecteur `fetch`, import conditionnel).
4. Test d'intégration `live-server`.
