/// **La troisième implémentation de [ContentPlayer] : le web, par `hls.js`** —
/// et le seul fichier du dépôt qui touche au DOM.
///
/// Pourquoi elle existe : `just_audio_web` pose l'URL `.m3u8` dans un
/// `<audio src>` **sans aucun lecteur HLS** — sa classe de source HLS est une
/// sous-classe vide. Sur Chrome, cela donne un `MEDIA_ERR_SRC_NOT_SUPPORTED` et
/// un `play()` rejeté : l'application tourne, et ne joue rien. Le correctif
/// amont n'a jamais été fusionné ; on ne met pas un fork non maintenu sur le
/// chemin critique de l'écoute.
///
/// Ce fichier ne contient **aucune décision** : elles vivent toutes dans
/// [MediaElementPlayback], qui se teste sans navigateur. Ici il n'y a que des
/// câbles — les événements du DOM d'un côté, les commandes de transport de
/// l'autre.
///
/// Il n'est jamais compilé pour la VM ni pour le mobile : `web_content_player.dart`
/// ne l'importe que sous `dart.library.js_interop`. C'est ce qui permet à
/// `flutter test` de rester vert sans connaître `dart:js_interop`.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../downloads/offline_cache.dart';
import 'content_player.dart';
import 'media_element_playback.dart';

/// Construit le lecteur web. Point d'entrée de `web_content_player.dart`.
ContentPlayer createWebContentPlayer() => HlsContentPlayer();

/// **Le lecteur de la médiathèque sur le web.**
///
/// Hérite de [MediaElementPlayback] : la valeur observée par l'UI et toute sa
/// logique viennent de là, cette classe n'ajoute que l'élément `<audio>`, le
/// moteur `hls.js` et le transport.
class HlsContentPlayer extends MediaElementPlayback implements ContentPlayer {
  /// [element] n'est là que pour les tests de navigateur, qui ont besoin de
  /// tenir l'élément qu'ils pilotent. En production, le lecteur crée le sien.
  HlsContentPlayer({web.HTMLAudioElement? element})
      : _audio = element ?? web.HTMLAudioElement() {
    // **Le chien de garde du décrochage silencieux.** Il existe pour iOS, où
    // rien ne remonte ; il vaut ici aussi — `hls.js` abandonne après ses
    // propres réessais, et Safari partage le moteur natif de l'iPhone.
    armStallWatchdog((at) {
      final request = _request;
      // **Pas sur un direct** (#179) : l'antenne se répare chez
      // `RadioListening`, au bord du direct, et jamais à l'ancienne position.
      if (request == null || request.isLive) return;
      _reopenAt(request, at);
    });
    // `auto` et non `metadata` : un enseignement s'écoute d'un bout à l'autre,
    // et le tampon d'avance est ce qui absorbe une connexion irrégulière.
    _audio.preload = 'auto';
    // L'élément **n'est pas attaché au document**. Un `<audio>` détaché joue
    // parfaitement ; l'attacher au `<body>` le ferait cohabiter avec le canevas
    // de Flutter, qui reconstruit son sous-arbre à sa guise.

    // La correspondance événement → décision, et rien d'autre. Chaque nom de
    // méthode dit lequel : c'est `MediaElementPlayback` qui décide quoi en
    // faire.
    _on('timeupdate', (_) => updatePosition(_audio.currentTime));
    _on('durationchange', (_) => updateDuration(_audio.duration));
    _on('loadedmetadata', (_) {
      updateDuration(_audio.duration);
      // **La position d'une reprise se repose ici, et pas avant.** Écrire
      // `currentTime` sur un élément qui n'a pas encore ses métadonnées est
      // sans effet : le fidèle repartirait du début du prêche.
      final at = _resumeAt;
      if (at == null) return;
      _resumeAt = null;
      _audio.currentTime = seekTo(at);
    });
    _on('play', (_) => markPlayRequested());
    _on('playing', (_) => markRendering());
    _on('waiting', (_) => markWaiting());
    _on('canplay', (_) => markReady());
    _on('seeked', (_) => markReady());
    _on('pause', (_) => markPaused());
    _on('ended', (_) => markEnded());
    _on('error', (_) => fail(_elementError()));
  }

  final web.HTMLAudioElement _audio;

  /// L'élément piloté — pour les tests de navigateur seulement.
  web.HTMLAudioElement get element => _audio;

  /// Les écouteurs posés, gardés pour être retirés à la libération.
  ///
  /// Sans ce registre, `removeEventListener` ne pourrait rien retirer :
  /// `.toJS` produit une **nouvelle** fonction JS à chaque appel, et le DOM
  /// compare les fonctions par identité.
  final Map<String, JSFunction> _listeners = {};

  /// Le moteur `hls.js` du chargement en cours, `null` sur le chemin natif.
  _HlsEngine? _engine;

  /// Ce qui est tenu, et qu'une reprise rouvrirait. `null` après un [stop].
  ContentRequest? _request;

  /// Position à reposer dès que les métadonnées de la source rouverte
  /// arrivent. `null` hors d'une reprise.
  Duration? _resumeAt;

  void _on(String type, void Function(web.Event event) handler) {
    final listener = handler.toJS;
    _listeners[type] = listener;
    _audio.addEventListener(type, listener);
  }

  /// **Faut-il `hls.js`, ou le navigateur lit-il le HLS lui-même ?**
  ///
  /// L'ordre est celui que `hls.js` documente, et il n'est pas
  /// interchangeable : **Chrome répond `"maybe"`** à
  /// `canPlayType('application/vnd.apple.mpegurl')` alors qu'il échoue en
  /// `MEDIA_ERR_SRC_NOT_SUPPORTED` sur le premier segment (mesuré sur
  /// Chrome, hls.js 1.7.0). Interroger le natif d'abord ferait donc reprendre
  /// exactement la panne que ce lecteur existe pour corriger.
  ///
  /// `Hls.isSupported()` teste `MediaSource` : il rend faux là où le natif est
  /// la seule voie — Safari iOS — et vrai partout ailleurs. C'est la détection
  /// que la bibliothèque expose, et elle remplace tout reniflage d'agent
  /// utilisateur.
  bool get _useHlsJs => globalContext.has('Hls') && _HlsEngine.isSupported();

  @override
  Future<void> load({
    required String contentId,
    required String url,
    required String title,
    String? author,
    String? artUrl,
    // **La copie locale, par URL de blob** (#273). Dans un navigateur il n'y a
    // pas de chemin de fichier : ce que porte [localFilePath] est la **clé du
    // `Cache`** où le service worker a rangé le `.aac`
    // (`lib/data/downloads/offline_cache.dart`), et c'est le résolveur qui l'a
    // lue dans `downloads.localPath`, exactement comme sur un appareil.
    String? localFilePath,
    // **Désormais renseignée sur une copie locale** (#229, #273) : la durée du
    // contrat ne naît que d'une résolution locale, et le web en a une depuis
    // que le téléchargement y existe. Retenue dans la requête, comme le reste
    // — une réouverture doit rejouer la même source avec les mêmes promesses.
    Duration? contractDuration,
    // [isLive] (#104) ne sert qu'aux boutons de la notification et de l'écran
    // verrouillé — **qui n'existent ni l'un ni l'autre sur le web** : il n'y a
    // pas de session média ici, pour la même raison que [title] et [author] ne
    // servent à rien. Retenu dans la requête malgré tout, pour qu'une
    // réouverture rejoue le même régime si un jour le web en a un.
    bool isLive = false,
    // **Ignorés, et c'est le navigateur qui l'impose** (#108). Le bocal à
    // cookies est à lui, il le tient d'ailleurs très bien tout seul ; mais
    // `Cookie` est un *forbidden header name* de la spécification Fetch — ni
    // `fetch`, ni `XMLHttpRequest`, ni un élément `<audio>` ne laissent le poser.
    // Le pré-vol n'a donc pas lieu sur le web (`DirectRadioHandshake`), et ce
    // paramètre n'existe ici que pour satisfaire le contrat [ContentPlayer].
    //
    // ⚠️ Conséquence à connaître si l'antenne doit un jour jouer dans un
    // navigateur : ce qu'il faudrait, c'est que les requêtes de `hls.js` partent
    // avec les identifiants (`xhrSetup` + `withCredentials`) et que MediaMTX
    // réponde les en-têtes CORS qui vont avec. Ce n'est pas un en-tête à poser,
    // c'est un autre sujet — et il n'est pas celui de cette tranche.
    Map<String, String> headers = const {},
  }) async {
    if (isDisposed) return;
    _releaseSource();
    _revokeLocalUrl();
    _request = ContentRequest(
      contentId: contentId,
      url: url,
      title: title,
      author: author,
      artUrl: artUrl,
      contractDuration: contractDuration,
      isLive: isLive,
    );
    _resumeAt = null;
    startLoading(contentId);

    // La copie locale d'abord : `null` (copie évincée, jamais arrivée) retombe
    // sur le HLS, ce qui est le bon repli — le magasin croyait avoir un fichier,
    // le navigateur ne l'a plus, et l'écoute continue.
    if (localFilePath != null) {
      _localUrl = await offlineBlobUrl(localFilePath);
    }

    // [title], [author] et [artUrl] ne servent pas ici : ce sont les lignes de
    // la notification et de l'écran verrouillé, qui n'existent pas sur le web.
    // Les afficher demanderait l'API Media Session — un autre sujet, et pas
    // celui du son qui ne sort pas.

    _attach(url);

    // **Rend la main dès que la source est attachée**, sans attendre les
    // métadonnées. Attendre `loadedmetadata` donnerait un `Future` qui ne se
    // résout jamais quand le manifeste ne répond pas : l'écran resterait sur
    // son indicateur, pour toujours. Une panne de chargement arrive par
    // `value.error`, exactement comme sur mobile, où seul `setUrl` est attendu
    // et où les pannes de lecture voyagent par le flux.
  }

  /// **Reprendre une lecture interrompue, à la position atteinte.**
  ///
  /// Toujours une réouverture : sur le web il n'y a pas d'équivalent au
  /// lecteur inactif de `just_audio`, et l'élément dont la source a échoué ne
  /// rejouera pas. La décision — quelle position garder, quoi effacer — vient
  /// de `MediaElementPlayback.beginResume` ; ici il n'y a que des câbles.
  @override
  Future<void> resume() async {
    if (isDisposed) return;
    final request = _request;
    if (request == null) return;
    final at = beginResume();
    if (at == null) return;
    _reopenAt(request, at);
  }

  /// Rouvre la source et repart de [at] — le geste commun à la reprise
  /// manuelle et au chien de garde.
  void _reopenAt(ContentRequest request, Duration at) {
    _releaseSource();
    _resumeAt = at;
    _attach(request.url);
    play();
  }

  /// L'URL de blob de la copie locale en cours de lecture, `null` en HLS.
  /// Révoquée au chargement suivant, à l'arrêt et à la libération — **pas** à
  /// chaque détachement de source : le chien de garde rouvre la même copie.
  String? _localUrl;

  /// Attache une source à l'élément : la copie locale, `hls.js`, ou le natif.
  void _attach(String rawUrl) {
    final local = _localUrl;
    if (local != null) {
      // Un `.aac` n'est pas du HLS : l'élément le lit seul, et `hls.js` n'a
      // rien à y faire. Un partiel ne se présente jamais ici — Background Fetch
      // ne range dans le `Cache` que ce qui est arrivé entier.
      _audio.src = local;
      _audio.load();
      return;
    }
    final url = variantPlaylistUrl(rawUrl, _variant);
    if (_useHlsJs) {
      final engine = _HlsEngine();
      // Seules les pannes **fatales** remontent : `hls.js` se remet seul des
      // autres (un segment manqué, une bascule de qualité), et les faire
      // paraître à l'écran ferait clignoter un message d'erreur pendant une
      // lecture qui se poursuit.
      engine.on(
        _hlsErrorEvent,
        ((JSAny _, _HlsErrorData data) {
          if (!data.fatal) return;
          fail(MediaPlaybackError('hls.js', '${data.type} / ${data.details}'));
        }).toJS,
      );
      engine.loadSource(url);
      engine.attachMedia(_audio);
      _engine = engine;
      // Le plafond survit à la réouverture — voir `_cap`.
      _applyCap();
    } else {
      _audio.src = url;
      _audio.load();
    }
  }

  @override
  void play() {
    if (isDisposed) return;
    // `play()` rend une promesse qui **peut être rejetée** : politique de
    // lecture automatique du navigateur, ou source illisible. Sans ce
    // rattrapage, ce serait une erreur asynchrone non rattrapée.
    unawaited(
      _audio.play().toDart.then<void>(
        (_) {},
        onError: (Object error) {
          if (isDisposed) return;
          fail(MediaPlaybackError('play', error.toString()));
        },
      ),
    );
  }

  @override
  void pause() {
    if (isDisposed) return;
    _audio.pause();
  }

  @override
  void seek(Duration position) {
    if (isDisposed) return;
    _audio.currentTime = seekTo(position);
  }

  /// Dernier plafond demandé, **rejoué après chaque attache** : `hls.js`
  /// oublie `autoLevelCapping` quand on lui donne une nouvelle source, et une
  /// reprise après panne rouvre justement la source.
  int? _cap;

  /// Palier choisi par l'URL — voir `variantPlaylistUrl`. Sur le web il double
  /// `autoLevelCapping` ; il existe surtout pour Android, où rien d'autre ne
  /// marche, et le contrat doit rester le même partout.
  String? _variant;

  @override
  void setPreferredVariant(String? variant) {
    if (isDisposed) return;
    _variant = variant;
  }

  @override
  void setBitrateCap(int? bitsPerSecond) {
    if (isDisposed) return;
    _cap = bitsPerSecond;
    _applyCap();
  }

  /// Traduit un débit en **indice de rendu**, seule chose que `hls.js`
  /// comprenne.
  ///
  /// On garde le rendu le plus haut qui reste **sous** le plafond, et si aucun
  /// n'y tient on garde le plus bas : un plafond inatteignable ne doit pas
  /// couper le son, il doit laisser jouer ce qu'il y a de plus économe.
  ///
  /// Sans effet tant que le manifeste n'est pas analysé — `levels` est alors
  /// vide. C'est pour cela que le plafond est mémorisé et rejoué : l'écran le
  /// pose souvent avant que le manifeste ne soit revenu.
  void _applyCap() {
    final engine = _engine;
    if (engine == null) return;
    final cap = _cap;
    if (cap == null) {
      engine.autoLevelCapping = -1;
      return;
    }
    final levels = engine.levels.toDart;
    if (levels.isEmpty) return;
    var best = 0;
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].bitrate <= cap &&
          levels[i].bitrate >= levels[best].bitrate) {
        best = i;
      }
    }
    engine.autoLevelCapping = best;
  }

  /// Le web n'a ni notification ni écran verrouillé à tenir : la ligne d'état
  /// de l'antenne s'y lit seulement dans l'application.
  @override
  void setStatusLine(String? line) {}

  /// `hls.js` aurait l'heure de programme, mais le direct aligné ne vise que
  /// l'appli mobile : le web reste en temps réel.
  @override
  Future<DateTime?> heardTime() async => null;

  @override
  void stop() {
    if (isDisposed) return;
    _request = null;
    _resumeAt = null;
    _releaseSource();
    _revokeLocalUrl();
    clear();
  }

  @override
  void dispose() {
    if (isDisposed) return;
    for (final entry in _listeners.entries) {
      _audio.removeEventListener(entry.key, entry.value);
    }
    _listeners.clear();
    _releaseSource();
    _revokeLocalUrl();
    super.dispose();
  }

  /// Détache la source courante et rend le réseau.
  ///
  /// `removeAttribute('src')` puis `load()` — et **jamais `src = ''`**, qui
  /// ferait charger à l'élément la page elle-même, puis échouer dessus.
  void _releaseSource() {
    _engine?.destroy();
    _engine = null;
    _audio.pause();
    _audio.removeAttribute('src');
    _audio.load();
  }

  /// Rend la mémoire que tient l'URL de blob. Sans cet appel, le corps du
  /// `.aac` reste chargé jusqu'au rechargement de la page.
  void _revokeLocalUrl() {
    final url = _localUrl;
    if (url == null) return;
    _localUrl = null;
    web.URL.revokeObjectURL(url);
  }

  /// Traduit le `MediaError` de l'élément en panne lisible au journal.
  MediaPlaybackError _elementError() {
    final error = _audio.error;
    if (error == null) return MediaPlaybackError('media', 'erreur inconnue');
    // Le code suffit à distinguer les quatre cas de la spécification ; le 4
    // (`MEDIA_ERR_SRC_NOT_SUPPORTED`) est celui qu'on obtient quand du HLS
    // atterrit dans un `<audio>` sans lecteur — la panne d'origine.
    return MediaPlaybackError('media', 'code ${error.code} ${error.message}');
  }
}

/// Le nom de l'événement d'erreur de `hls.js` (`'hlsError'`), lu **dans la
/// bibliothèque** plutôt que recopié : un littéral se périmerait en silence.
@JS('Hls.Events.ERROR')
external String get _hlsErrorEvent;

/// La part de l'API de `hls.js` dont ce lecteur dépend — cinq membres.
///
/// La bibliothèque est chargée par une balise `<script>` de `web/index.html`,
/// et **versionnée dans le dépôt** (`web/hls.min.js`, voir `web/WEB_ASSETS.md`).
/// Pas de CDN : une dépendance réseau tierce au démarrage est une panne de plus
/// et un point de confiance de plus.
@JS('Hls')
extension type _HlsEngine._(JSObject _) implements JSObject {
  external factory _HlsEngine();

  /// Vrai quand `MediaSource` permet de démultiplexer le HLS en JavaScript.
  external static bool isSupported();

  external void loadSource(String url);
  external void attachMedia(web.HTMLMediaElement media);

  /// Les rendus annoncés par le manifeste maître, dans l'ordre du fichier.
  /// Vide tant que le manifeste n'est pas analysé.
  external JSArray<_HlsLevel> get levels;

  /// **Indice** du rendu le plus haut que l'adaptation automatique a le droit
  /// de choisir. `-1` = aucun plafond. C'est un indice, pas un débit : d'où la
  /// traduction dans `setBitrateCap`.
  external set autoLevelCapping(int index);
  external void on(String event, JSFunction listener);
  external void destroy();
}

/// La charge utile d'un événement d'erreur de `hls.js`.
/// Un rendu du manifeste maître — on n'en lit que le débit.
extension type _HlsLevel._(JSObject _) implements JSObject {
  external int get bitrate;
}

extension type _HlsErrorData._(JSObject _) implements JSObject {
  /// Vrai quand la lecture ne peut pas se poursuivre. Les autres pannes sont
  /// rattrapées par la bibliothèque elle-même.
  external bool get fatal;

  external String get type;
  external String get details;
}
