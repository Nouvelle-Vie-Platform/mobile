/// **L'invite d'installation dans un navigateur** — le seul fichier du dépôt
/// qui connaisse `beforeinstallprompt`.
///
/// ## L'événement arrive avant Flutter, donc il se capte avant Flutter
///
/// Chrome émet `beforeinstallprompt` pendant le chargement de la page, souvent
/// **avant** que `main()` ne s'exécute — et l'événement ne se rejoue pas. Un
/// écouteur posé depuis Dart le raterait une fois sur deux, et le bandeau ne
/// paraîtrait jamais sur un téléphone lent, c'est-à-dire précisément sur le
/// parc visé. C'est donc `web/index.html` qui l'attrape, le range dans
/// `window.nvInstall` et prévient par `nv-install-available` ; ce fichier ne
/// fait que lire.
///
/// ## iOS se reconnaît par une capacité, jamais par l'agent utilisateur
///
/// Safari n'a pas `beforeinstallprompt` — mais Firefox non plus, ni Safari sur
/// Mac, et proposer « touchez Partager » sur un ordinateur serait absurde. Le
/// départage se fait sur `navigator.standalone`, **propriété qui n'existe que
/// sur Safari iOS** : sa seule présence dit la plateforme, et sa valeur dit si
/// l'on est déjà installé. C'est la règle du lecteur web (« aucun reniflage
/// d'agent utilisateur »), tenue ici par une propriété au lieu d'une chaîne.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'install_prompt.dart';

/// Le dépôt que `web/index.html` remplit.
@JS('nvInstall')
external _InstallSlot? get _slot;

extension type _InstallSlot._(JSObject _) implements JSObject {
  external JSObject? get event;
  external set event(JSObject? value);
}

extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
}

/// L'implémentation réelle. Construite par `main.dart` sous `kIsWeb`.
InstallPrompt createInstallPrompt() => BrowserInstallPrompt();

class BrowserInstallPrompt implements InstallPrompt {
  BrowserInstallPrompt() {
    // Le même événement sert les deux sens : l'invite devient disponible, ou
    // l'application vient d'être installée et il n'y a plus rien à offrir.
    _listener = (web.Event _) {
      _changes.add(offer);
    }.toJS;
    web.window.addEventListener('nv-install-available', _listener);
  }

  final StreamController<InstallOffer> _changes =
      StreamController<InstallOffer>.broadcast();
  late final JSFunction _listener;

  @override
  InstallOffer get offer {
    if (_isStandalone) return InstallOffer.none;
    if (_slot?.event != null) return InstallOffer.prompt;
    if (_isIosSafari) return InstallOffer.manualIos;
    return InstallOffer.none;
  }

  @override
  Stream<InstallOffer> get changes => _changes.stream;

  @override
  Future<void> show() async {
    final stored = _slot?.event;
    if (stored == null) return;
    // L'événement ne sert **qu'une fois** : Chrome refuse un second `prompt()`
    // sur le même objet. On l'oublie avant même de savoir si le fidèle a
    // accepté — un refus ne se re-propose pas dans la foulée, et l'événement
    // reviendra de lui-même à la visite suivante.
    _slot?.event = null;
    try {
      await (stored as _BeforeInstallPromptEvent).prompt().toDart;
    } on Object {
      // Une invite refusée par le navigateur n'est pas une panne de
      // l'application : le bandeau se taira, et c'est tout.
    }
    _changes.add(offer);
  }

  /// Déjà installée : la fenêtre n'a plus de barre d'adresse (tous les
  /// navigateurs), ou Safari iOS le dit lui-même.
  bool get _isStandalone {
    if (web.window.matchMedia('(display-mode: standalone)').matches)
      return true;
    return _navigatorStandalone == true;
  }

  bool get _isIosSafari => _navigatorStandalone != null;

  /// `null` quand la propriété n'existe pas — c'est-à-dire partout sauf sur
  /// Safari iOS.
  bool? get _navigatorStandalone {
    final navigator = web.window.navigator as JSObject;
    if (!navigator.has('standalone')) return null;
    return navigator.getProperty<JSBoolean?>('standalone'.toJS)?.toDart;
  }

  void dispose() {
    web.window.removeEventListener('nv-install-available', _listener);
    _changes.close();
  }
}
