/// **Le rechargement dans un navigateur** — le seul fichier du dépôt qui
/// parle au service worker.
///
/// ## Pourquoi `skipWaiting` avant le rechargement
///
/// Un service worker neuf reste en `waiting` tant qu'un onglet tient l'ancien :
/// recharger sans rien lui dire peut donc reservir exactement la version qu'on
/// voulait quitter, et le bouton semblerait ne rien faire. Le message le fait
/// passer devant.
///
/// ⚠️ **Il ne sert presque jamais aujourd'hui, et c'est mesuré, pas supposé.**
/// Le `flutter_service_worker.js` que produit Flutter 3.47.4 ne met plus rien
/// en cache : il appelle `skipWaiting()` à l'installation puis
/// `registration.unregister()` à l'activation — 31 lignes, un interrupteur de
/// secours et rien d'autre. Il n'y a donc pas de coquille hors ligne servie par
/// lui, et rarement un worker en attente. Le message reste pour les deux cas
/// qui existent quand même : un worker **à nous** (`sw-offline.js`, T4) et un
/// worker d'un ancien build encore enregistré chez un fidèle.
///
/// Le rechargement, lui, suffit à lui seul : c'est Caddy qui sert les quatre
/// fichiers d'amorçage en `no-cache` (T0), et le reste est versionné par son
/// nom.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_reloader.dart';

/// L'implémentation réelle. Construite par `main.dart` sous `kIsWeb`.
AppReloader createAppReloader() => const BrowserAppReloader();

class BrowserAppReloader implements AppReloader {
  const BrowserAppReloader();

  @override
  Future<void> reload() async {
    await _laisserPasserLeWorkerEnAttente();
    // Jamais `location.reload(true)` : le drapeau n'existe plus nulle part, et
    // ce qui doit échapper au cache y échappe par son en-tête.
    web.window.location.reload();
  }

  /// Dit au service worker en attente de prendre la place tout de suite.
  ///
  /// Tout y est facultatif et rien n'y est bloquant : sur une origine non
  /// sécurisée `navigator.serviceWorker` est **absent de l'objet global**
  /// (mesuré le 29/10 sur le banc en wifi), et un worker qui n'écoute pas les
  /// messages les ignore. Dans les deux cas on recharge quand même.
  Future<void> _laisserPasserLeWorkerEnAttente() async {
    try {
      final conteneur = web.window.navigator.serviceWorker;
      final enregistrement = await conteneur.getRegistration().toDart;
      enregistrement?.waiting?.postMessage('skipWaiting'.toJS);
    } on Object {
      // Pas de service worker, pas de rechargement raté : juste un message de
      // moins.
    }
  }
}
