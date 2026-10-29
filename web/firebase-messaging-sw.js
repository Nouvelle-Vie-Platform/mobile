// Le worker des annonces poussées (#283) — LE TROISIÈME, et il a sa propre
// portée.
//
//   flutter_service_worker.js  GÉNÉRÉ par le build, portée `/`. Ne jamais le
//                              modifier : le prochain build l'écraserait.
//   sw-offline.js              le nôtre, portée `offline/` (T4, #273).
//   firebase-messaging-sw.js   celui-ci. Le SDK de messagerie l'enregistre
//                              LUI-MÊME, à ce nom exact, sur la portée
//                              `/firebase-cloud-messaging-push-scope` — c'est
//                              son défaut, relevé dans ses octets
//                              (`web/firebase/firebase-messaging.js`), et c'est
//                              pourquoi ce fichier est à la racine de `web/` et
//                              ne s'appelle pas autrement.
//
// ─── IL N'EMBARQUE PAS LE SDK, ET C'EST UNE DÉCISION ────────────────────────
//
// La recette de Firebase fait ici trois `importScripts` de bundles « compat »
// pour appeler `onBackgroundMessage`. On ne le fait pas : ce que ce gestionnaire
// ferait de plus, nous ne l'utiliserions pas (il n'y a pas de magasin Drift
// lisible depuis un worker), et cela coûterait deux actifs tiers de plus à
// versionner, à empreinter et à retoucher. L'événement `push` du navigateur
// porte déjà la charge que FCM a envoyée ; la lire ici, c'est trois lignes.
//
// ─── CE QU'IL AFFICHE, ET CE QU'IL N'AFFICHE PAS ────────────────────────────
//
// La règle du dépôt est « la notification se dresse depuis le magasin, jamais
// depuis le push » (#97). Un worker n'a pas le magasin : il ne peut donc
// afficher QUE ce que le serveur a déjà rédigé, c'est-à-dire le bloc
// `notification` des notifications VISIBLES (annonces, changements
// d'événement) — celui que l'OS dessine seul sur mobile. Ici, c'est ce worker
// qui tient le rôle de l'OS.
//
// Les réveils SILENCIEUX (`group_message`, `sync_nudge`) ne portent aucun
// texte, par construction, et n'affichent donc RIEN. Ne jamais écrire
// « Nouveau message » depuis la charge utile : ce serait affirmer sur la seule
// foi du push l'existence de ce que la base ne porte pas, et le tap ouvrirait
// un fil qui ne le contient pas. Onglet ouvert, ces réveils arrivent en Dart
// (`FirebaseMessaging.onMessage`) et déclenchent une synchronisation, ce qui
// repeint les écrans : c'est là que le réveil silencieux sert, sur le web.
//
// ⚠️ Conséquence connue, qu'aucun test ne peut couvrir : FCM s'abonne en
// `userVisibleOnly`, et Chrome finit par afficher lui-même « Ce site a été mis
// à jour en arrière-plan » quand des pushs n'affichent rien trop souvent. Rien
// ici ne peut l'éviter — seul le serveur pourrait cesser d'envoyer des réveils
// silencieux à la plateforme `web`, et ce n'est pas le périmètre de la tranche.

self.addEventListener('push', function (event) {
  if (!event.data) return;

  var payload;
  try {
    payload = event.data.json();
  } catch (error) {
    // Une charge qui n'est pas du JSON n'est pas la nôtre : on se tait.
    return;
  }

  var notification = payload && payload.notification;
  if (!notification || !notification.title) return;

  event.waitUntil(
    self.registration.showNotification(notification.title, {
      body: notification.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      // Le `tag` fait qu'une annonce renvoyée remplace la précédente au lieu
      // d'empiler deux fois la même.
      tag: (payload.data && payload.data.type) || 'nouvelle-vie',
      data: payload.data || {}
    })
  );
});

// Un appui ramène l'onglet déjà ouvert au premier plan plutôt que d'en ouvrir
// un second : l'application y est déjà chargée, avec sa session et son magasin.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (clients) {
        for (var i = 0; i < clients.length; i++) {
          if ('focus' in clients[i]) return clients[i].focus();
        }
        return self.clients.openWindow('/');
      })
  );
});
