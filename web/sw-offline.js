// Le service worker du HORS-LIGNE — le nôtre, sur notre portée (#273).
//
// Il a une seule raison d'être : quand un Background Fetch aboutit, la réponse
// n'est gardée que le temps de l'événement `backgroundfetchsuccess`. Qui ne la
// range pas là la perd. Et seul un service worker tourne encore à ce
// moment-là — l'onglet peut être fermé depuis une heure, c'est précisément le
// cas pour lequel Background Fetch a été choisi contre `fetch` + `Range`.
//
// ⚠️ NE JAMAIS écrire ceci dans `flutter_service_worker.js` : ce fichier est
// GÉNÉRÉ par `flutter build web`, et tout ce qu'on y met disparaît à la
// compilation suivante. Trois workers, trois portées : celui de Flutter garde
// la coquille et les actifs, celui de Firebase (T2) prendra le push, celui-ci
// range les enseignements.
//
// Il n'écoute AUCUN `fetch` : la coquille appartient au worker de Flutter, et
// intercepter des requêtes ici serait s'en mêler.
//
// Il ne parle à personne non plus : l'application relève le Cache elle-même
// (`lib/data/downloads/background_fetch_download_backend.dart`), au démarrage
// et à la fin d'un transfert. Un `postMessage` depuis une portée qui ne
// contrôle pas la page demanderait `includeUncontrolled`, et le relevé est de
// toute façon indispensable pour les transferts finis onglet fermé.

// Le contrat avec Dart, et le seul : ces deux valeurs sont recopiées dans
// `lib/data/downloads/offline_cache.dart`. Les désaccorder rendrait les copies
// introuvables — sans aucune erreur.
const CACHE = 'nv-offline-v1';
const PREFIX = '/offline/';

// Prendre la main tout de suite : un worker en attente ne recevrait rien, et un
// transfert lancé juste après la mise à jour n'aurait personne pour le ranger.
self.addEventListener('install', (event) => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('backgroundfetchsuccess', (event) => {
  const registration = event.registration;
  // `waitUntil` tient le worker en vie le temps d'écrire : sans lui, le
  // navigateur peut l'arrêter au milieu du rangement.
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE);
      const records = await registration.matchAll();
      for (const record of records) {
        const response = await record.responseReady;
        // Un 4xx/5xx arrive jusqu'ici comme un succès de transfert : ce n'est
        // pas une copie, et la ranger ferait jouer une page d'erreur.
        if (!response || !response.ok) continue;
        // La clé porte l'identifiant du transfert ET le nom du fichier :
        // le premier recolle la copie à sa ligne, le second permet de jeter la
        // précédente. Voir `offline_cache.dart`.
        await cache.put(PREFIX + registration.id, response);
      }
    } catch (error) {
      // Quota dépassé, Cache indisponible : rien n'est rangé, l'application le
      // constate (elle attend de VOIR la clé) et laisse la ligne en cours.
      console.warn('Copie hors ligne non rangée', error);
    }
  })());
});

// `backgroundfetchfail` et `backgroundfetchabort` n'ont rien à faire ici :
// aucune copie n'a été écrite, donc il n'y a rien à nettoyer, et l'application
// lit l'issue sur la souscription elle-même.
