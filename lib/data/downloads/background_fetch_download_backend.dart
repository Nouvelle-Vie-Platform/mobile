/// **Le moteur de transfert du navigateur : Background Fetch** (#273) — la
/// troisième implémentation de [DownloadBackend], et le seul fichier de `lib/`
/// qui connaisse cette API.
///
/// Il est ici pour la même raison que `HlsContentPlayer` est à côté de
/// `JustAudioContentPlayer` : la logique du `DownloadManager` — états,
/// pré-check, réconciliation — ne bouge pas d'une ligne, et c'est exactement ce
/// que l'interface existait pour permettre.
///
/// Compilé **seulement** pour le web : `web_downloads.dart` est la porte
/// conditionnelle, sur le modèle de `web_content_player.dart`.
///
/// ## Background Fetch ne met pas en pause, et c'est la décision du cadrage
///
/// Le navigateur ne donne pas les deux : soit le transfert survit à la
/// fermeture de l'onglet, soit il se reprend à l'octet (`fetch` + `Range`). Un
/// fidèle lance un enseignement de deux heures et range son téléphone — c'est
/// ce cas-là qui compte. [pause] ne fait donc **rien** et [resume] ne reprend
/// rien : c'est `DownloadCapabilities.canPause` qui empêche l'écran de
/// l'offrir, et il est faux ici.
///
/// ## Le service worker ne nous parle pas, et on ne lui demande rien
///
/// `web/sw-offline.js` range la réponse dans le `Cache` à
/// `backgroundfetchsuccess` — c'est le seul code qui tourne encore quand
/// l'onglet est parti. Il **ne prévient personne** : ce côté-ci relève le
/// `Cache` lui-même, à deux moments, et ça supprime tout protocole entre les
/// deux moitiés.
///
/// - **l'onglet est ouvert** : l'événement `progress` de la souscription dit
///   `result == 'success'`, et on attend de **voir** la clé dans le `Cache`
///   avant d'annoncer la complétion (le worker range en parallèle). Rien vu ⇒
///   on ne dit rien : la ligne reste « en cours », et le démarrage suivant la
///   rattrape. Annoncer un échec serait mentir sur une copie qui arrive peut-être
///   une seconde plus tard.
/// - **l'onglet était fermé** : [initialize] relève le `Cache` au démarrage et
///   annonce chaque copie trouvée. C'est aussi pourquoi [activeTaskIds] les
///   compte — sans quoi la réconciliation du manager verrait une tâche
///   « oubliée du moteur » et re-téléchargerait 80 Mo déjà sur l'appareil.
///
/// ## Ce qu'il ne sait pas faire, et qu'il ne faut pas croire
///
/// La contrainte **wifi** ne traverse pas : l'API n'a aucune option de réseau,
/// et un transfert part donc sur les données mobiles. Le manager continue de
/// calculer son état d'attente ; sur le web il ne décrit pas la réalité.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'disk_space.dart';
import 'download_backend.dart';
import 'download_capabilities.dart';
import 'offline_cache.dart';

/// Le chemin du worker, et sa portée **à lui**.
///
/// ⚠️ `web/flutter_service_worker.js` est **généré par le build** : tout ce
/// qu'on y écrirait disparaîtrait à la compilation suivante. Celui-ci est un
/// fichier du dépôt, enregistré sur une portée distincte — celle de Flutter
/// garde la coquille, celle de Firebase (T2) prendra la sienne.
const String _workerUrl = 'sw-offline.js';
const String _workerScope = 'offline/';

/// Construit le moteur de transfert web et **lance son relevé de démarrage**
/// sans l'attendre (même esprit que `BackgroundDownloaderBackend.initialize`,
/// que le provider appelle sans attendre).
DownloadBackend createWebDownloadBackend() {
  final backend = BackgroundFetchDownloadBackend();
  unawaited(backend.initialize());
  return backend;
}

/// Ce que le navigateur permet — voir [BrowserDownloadCapabilities].
DownloadCapabilities createWebDownloadCapabilities() =>
    const BrowserDownloadCapabilities();

/// La place libre, par `navigator.storage.estimate()`.
DiskSpace createWebDiskSpace() => const BrowserDiskSpace();

/// Voir l'en-tête du fichier.
class BackgroundFetchDownloadBackend implements DownloadBackend {
  /// **Contrôleur à abonné unique**, et c'est voulu : le relevé de démarrage
  /// parle avant que le manager n'ait eu le temps d'écouter, et un flux diffusé
  /// jette ce qu'il émet sans auditeur — les copies descendues onglet fermé
  /// seraient perdues à chaque lancement. Le manager est le seul auditeur
  /// (`DownloadManager.start`, idempotent).
  final _events = StreamController<DownloadBackendEvent>();

  /// Les identifiants de transfert déjà écoutés, pour ne pas poser deux fois le
  /// même écouteur (l'enqueue, puis un relevé de démarrage).
  final _watched = <String>{};

  /// Les transferts dont l'issue est déjà annoncée : `progress` continue d'être
  /// émis après coup, et il ne doit pas redire la même chose.
  final _settled = <String>{};

  @override
  Stream<DownloadBackendEvent> get events => _events.stream;

  /// Relève ce qui s'est passé sans nous, et se rebranche sur ce qui court.
  Future<void> initialize() async {
    for (final key in await offlineKeys()) {
      final taskId = offlineTaskIdOf(key);
      if (taskId == null) continue;
      _settled.add(taskId);
      _events.add(
        DownloadStatusEvent(
          taskId,
          status: DownloadBackendStatus.complete,
          filePath: key,
        ),
      );
    }
    // Les transferts encore en vol : on se rebranche sur leur progression, pour
    // que l'écran avance comme si l'onglet n'avait jamais été rechargé.
    for (final registration in await _inFlight()) {
      _watch(registration);
    }
  }

  @override
  Future<bool> enqueue(DownloadTaskSpec spec) async {
    final manager = await _manager();
    if (manager == null) return false;
    // La copie précédente du même fichier avant la neuve : elle porte un autre
    // identifiant de tâche, donc une autre clé, et rien ne la remplacerait.
    await offlineForget(spec.filename);
    final id = '${spec.taskId}/${spec.filename}';
    try {
      final registration =
          await manager.fetch(id, spec.url.toJS, _options()).toDart;
      _settled.remove(spec.taskId);
      _watch(registration);
      return true;
    } on Object catch (error) {
      // Un transfert déjà en cours sous le même identifiant, un stockage
      // refusé, une origine non sûre : le manager marque la ligne en échec, et
      // le bouton proposera de relancer.
      debugPrint('Background Fetch refusé: $error');
      return false;
    }
  }

  /// **Sans effet, et sans équivalent** : voir l'en-tête. L'écran ne l'offre
  /// pas (`DownloadCapabilities.canPause`), et lever ici ferait rougir un
  /// chemin qui n'est qu'inutile.
  @override
  Future<void> pause(String taskId) async {}

  /// Il n'y a rien à reprendre : un transfert ne s'interrompt pas tout seul.
  /// S'il court encore, dire oui est la vérité ; sinon le manager marque la
  /// ligne en échec et l'écran propose de relancer — le seul geste que le
  /// navigateur offre.
  @override
  Future<bool> resume(String taskId) async {
    final ids = await _inFlightTaskIds();
    return ids.contains(taskId);
  }

  @override
  Future<void> cancel(String taskId) async {
    for (final registration in await _inFlight()) {
      if (offlineTaskIdOf(offlineKeyFor(registration.id)) != taskId) continue;
      try {
        await registration.abort().toDart;
      } on Object catch (error) {
        debugPrint('Abandon du transfert impossible: $error');
      }
    }
    // Les octets déjà rangés partent par `deleteFile`, que le manager appelle
    // juste après avec le chemin de la ligne.
  }

  @override
  Future<void> deleteFile(String path) => offlineDelete(path);

  @override
  Future<Set<String>> activeTaskIds() async {
    final ids = await _inFlightTaskIds();
    // **Et les copies déjà dans le `Cache`** : sans elles, un transfert terminé
    // pendant que l'onglet était fermé passerait pour oublié du moteur, et la
    // réconciliation le reprendrait depuis zéro.
    for (final key in await offlineKeys()) {
      final taskId = offlineTaskIdOf(key);
      if (taskId != null) ids.add(taskId);
    }
    return ids;
  }

  Future<void> dispose() => _events.close();

  // ───────────────────────────────────────────────────────────────────────────
  // Rouages
  // ───────────────────────────────────────────────────────────────────────────

  /// Le gestionnaire de Background Fetch de **notre** enregistrement, ou `null`
  /// là où il n'existe pas (Safari, Firefox, origine non sûre).
  Future<_BackgroundFetchManager?> _manager() async {
    final existing = _registration;
    if (existing != null) return _managerOf(await existing);
    if (!_browserSupportsBackgroundFetch) return null;
    final container = web.window.navigator.serviceWorker;
    final pending = container
        .register(
          _workerUrl.toJS,
          web.RegistrationOptions(scope: _workerScope),
        )
        .toDart;
    _registration = pending;
    try {
      return _managerOf(await pending);
    } on Object catch (error) {
      // Enregistrement refusé : on ne garde pas l'échec, une visite suivante
      // sur une origine en règle doit pouvoir réessayer.
      _registration = null;
      debugPrint('Service worker hors ligne non enregistré: $error');
      return null;
    }
  }

  Future<web.ServiceWorkerRegistration>? _registration;

  _BackgroundFetchManager? _managerOf(web.ServiceWorkerRegistration r) =>
      (r as JSObject).getProperty<_BackgroundFetchManager?>(
        'backgroundFetch'.toJS,
      );

  /// Les transferts que le navigateur porte encore.
  Future<List<_BackgroundFetchRegistration>> _inFlight() async {
    final manager = await _manager();
    if (manager == null) return const [];
    try {
      final ids = (await manager.getIds().toDart).toDart;
      final found = <_BackgroundFetchRegistration>[];
      for (final id in ids) {
        final registration = await manager.get(id.toDart).toDart;
        if (registration != null) found.add(registration);
      }
      return found;
    } on Object catch (error) {
      debugPrint('Transferts en cours illisibles: $error');
      return const [];
    }
  }

  Future<Set<String>> _inFlightTaskIds() async {
    final ids = <String>{};
    for (final registration in await _inFlight()) {
      final taskId = offlineTaskIdOf(offlineKeyFor(registration.id));
      if (taskId != null) ids.add(taskId);
    }
    return ids;
  }

  void _watch(_BackgroundFetchRegistration registration) {
    if (!_watched.add(registration.id)) return;
    registration.addEventListener(
      'progress',
      ((web.Event _) => _onProgress(registration)).toJS,
    );
    // Un transfert déjà terminé au moment où l'on s'y branche n'émettra plus
    // rien : on lit son état tout de suite.
    _onProgress(registration);
  }

  void _onProgress(_BackgroundFetchRegistration registration) {
    final key = offlineKeyFor(registration.id);
    final taskId = offlineTaskIdOf(key);
    if (taskId == null) return;
    if (_settled.contains(taskId)) return;

    final total = registration.downloadTotal;
    _events.add(
      DownloadProgressEvent(
        taskId,
        bytesReceived: registration.downloaded,
        bytesTotal: total > 0 ? total : null,
      ),
    );

    switch (registration.result) {
      case 'success':
        _settled.add(taskId);
        unawaited(_announceCopy(taskId, key));
      case 'failure':
        _settled.add(taskId);
        _events.add(
          DownloadStatusEvent(
            taskId,
            status: DownloadBackendStatus.failed,
            failure: _failureOf(registration.failureReason),
          ),
        );
      default:
        // Toujours en cours : la progression suffit.
        break;
    }
  }

  /// Attend que le worker ait rangé la réponse, **puis** annonce la complétion :
  /// le manager écrit le chemin dans la ligne, et il doit désigner quelque chose.
  ///
  /// Rien vu au bout du compte ⇒ **on ne dit rien**. La ligne reste « en
  /// cours », [initialize] l'annoncera au démarrage suivant si la copie finit
  /// par arriver, et la réconciliation la reprendra sinon.
  Future<void> _announceCopy(String taskId, String key) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (await offlineHas(key)) {
        _events.add(
          DownloadStatusEvent(
            taskId,
            status: DownloadBackendStatus.complete,
            filePath: key,
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('Copie hors ligne jamais rangée: $key');
  }

  /// Le motif, en vocabulaire d'interface. `quota-exceeded` est le seul qui ait
  /// un geste à lui — garder le partiel n'a pas de sens ici, il n'y en a pas,
  /// mais la phrase d'écran est juste : il n'y a plus de place.
  DownloadBackendFailure _failureOf(String reason) => switch (reason) {
        'quota-exceeded' => DownloadBackendFailure.insufficientSpace,
        _ => DownloadBackendFailure.other,
      };

  /// Les options du transfert. `title` est ce que Chrome affiche dans son propre
  /// bandeau de téléchargement — en français en dur, comme la notification du
  /// moteur natif et pour la même raison : aucune localisation ici.
  ///
  /// Pas de `downloadTotal` : le spec ne porte pas la taille, et Chrome
  /// **abandonne** un transfert qui dépasse la valeur annoncée. Sans elle, sa
  /// barre est indéterminée ; le manager, lui, connaît la taille par le contrat
  /// (`download.bytes`) et n'en dépend pas.
  JSObject _options() {
    final options = JSObject();
    options.setProperty('title'.toJS, 'Téléchargement de l\'enseignement'.toJS);
    return options;
  }
}

/// **Ce que le navigateur permet** (#273).
class BrowserDownloadCapabilities implements DownloadCapabilities {
  const BrowserDownloadCapabilities();

  /// Background Fetch existe-t-il ? Chrome et Chrome Android depuis la **74**
  /// (donc jusque sur le Chrome 106 d'un Android 6, mesuré le 29/10/2026) ;
  /// **absent de Firefox et de Safari**, quel que soit le code.
  @override
  bool get available => _browserSupportsBackgroundFetch;

  /// Jamais : l'API n'a ni pause ni reprise. Voir l'en-tête du backend.
  @override
  bool get canPause => false;

  /// `navigator.storage.persisted()`, et sinon une demande.
  ///
  /// Chrome l'accorde **silencieusement** à un site installé (ou dont la
  /// permission de notification est accordée) et la refuse sinon — mesuré le
  /// 29/10/2026 : *non* avant l'installation, *oui* après. Sans elle, il évince
  /// tout le stockage de l'origine d'un coup, enseignements **et** magasin
  /// Drift ensemble.
  ///
  /// Pas de `navigator.storage` du tout ⇒ **vrai**, comme [DiskSpace] laisse
  /// passer l'inconnu : on ne ferme pas une fonction sur une question qu'on n'a
  /// pas pu poser. Là où elle manque, Background Fetch manque aussi en pratique,
  /// et l'écran est de toute façon masqué.
  @override
  Future<bool> ensureDurable() async {
    try {
      final storage = web.window.navigator.storage;
      if ((await storage.persisted().toDart).toDart) return true;
      return (await storage.persist().toDart).toDart;
    } on Object catch (error) {
      debugPrint('Durabilité du stockage non mesurable: $error');
      return true;
    }
  }
}

/// **La place libre dans un navigateur** — `navigator.storage.estimate()` à la
/// place du canal natif de `BestEffortDiskSpace`, qui n'existe pas ici.
///
/// Le quota est celui de **l'origine entière** (il couvre donc aussi le magasin
/// Drift), et il est annoncé par le navigateur, pas par le disque : 14,8 Go sur
/// le téléphone du banc du 29/10/2026. `null` dès que quelque chose manque — le
/// pré-check laisse alors passer (voir [DiskSpace]).
class BrowserDiskSpace implements DiskSpace {
  const BrowserDiskSpace();

  @override
  Future<int?> freeBytes() async {
    try {
      final estimate = await web.window.navigator.storage.estimate().toDart;
      final free = estimate.quota - estimate.usage;
      if (free < 0) return null;
      return free;
    } on Object catch (error) {
      debugPrint('Quota de stockage non mesurable: $error');
      return null;
    }
  }
}

bool get _browserSupportsBackgroundFetch =>
    globalContext.has('BackgroundFetchManager');

/// La part de l'API de Background Fetch dont ce moteur dépend. `package:web` ne
/// la porte pas (elle n'est pas standardisée au-delà de Chrome).
extension type _BackgroundFetchManager._(JSObject _) implements JSObject {
  /// [requests] est une URL, une `Request`, ou un tableau des deux. On n'en
  /// passe qu'une : un enseignement est un fichier.
  external JSPromise<_BackgroundFetchRegistration> fetch(
    String id,
    JSAny requests, [
    JSObject options,
  ]);

  external JSPromise<_BackgroundFetchRegistration?> get(String id);

  /// Les transferts que le navigateur porte encore, y compris ceux lancés par
  /// une visite précédente.
  external JSPromise<JSArray<JSString>> getIds();
}

extension type _BackgroundFetchRegistration._(JSObject _)
    implements web.EventTarget {
  external String get id;
  external int get downloaded;

  /// Zéro quand l'appelant ne l'a pas annoncé — c'est notre cas.
  external int get downloadTotal;

  /// `''` tant que le transfert court, puis `'success'` ou `'failure'`.
  external String get result;

  /// `''`, `'aborted'`, `'bad-status'`, `'fetch-error'`, `'quota-exceeded'` ou
  /// `'download-total-exceeded'`.
  external String get failureReason;

  external JSPromise<JSBoolean> abort();
}
