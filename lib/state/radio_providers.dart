/// **L'écoute de New Life Radio — un seul endroit qui la pilote.**
///
/// Trois providers, et une seule règle : *le contrôleur observe le lecteur*. Ce
/// n'est pas un détail d'implémentation, c'est ce qui rend tenable qu'il y ait
/// **deux** gestes capables de lancer l'antenne — le bouton de l'accueil et
/// l'ouverture de l'écran d'antenne, qui démarre au montage (`isLive: true`). Le
/// contrôleur n'a pas besoin de savoir lequel a parlé : il reconnaît la radio dans
/// la main du lecteur unique, et c'est lui qui gouverne la reprise, quoi qu'il
/// arrive.
///
/// ⚠️ **Un seul lecteur, et c'est un constat, pas un choix.**
/// `contentPlayerProvider` est « un seul, global, jamais `autoDispose` », et le
/// direct le partage **déjà** avec les enseignements. La radio **remplace** : un
/// second `AudioPlayer` fait lever le service audio.
///
/// ⚠️ **Conséquence à connaître, et que cette tranche ne résout pas** :
/// l'enseignement interrompu n'est **pas mis en pause**, il est remplacé. Sa
/// position n'est sauvée que par le hasard du `PlaybackProgressRecorder` — le
/// déclencheur « sortie d'écran » n'a pas lieu, celui de la pause non plus, et ce
/// qui reste est l'écriture locale continue faite jusqu'au dernier battement de
/// position. Il n'existe **aucune** notion de priorité, de file, ni de « reprendre
/// ce qui jouait », et il ne faut pas en inventer une ici : ce serait une règle
/// éditoriale invisible, prise par le premier écran qui en a eu besoin.
///
/// **Une exception, et elle est écrite** (#130, décision du 05/10/2026) : un
/// statut à son met la radio ou l'enseignement en pause, et la visionneuse les
/// fait reprendre en sortant — l'antenne **au direct** ([RadioListening.rejoinLive]),
/// l'enseignement à sa position. Ce n'est ni une file ni une priorité : une
/// parenthèse, tenue par le contrôleur global (`PlaybackController.interruptForStatus`
/// / `resumeAfterStatus`), qui ne survit pas à un autre chargement.
library;

import 'dart:async';

import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../core/config/radio_config.dart';
import '../data/network/network_transport.dart';
import '../data/players/content_player.dart';
import '../data/radio/http_radio_repository.dart';
import '../data/radio/radio_antenna.dart';
import '../data/radio/radio_failure.dart';
import '../data/radio/radio_handshake.dart';
import '../data/radio/radio_heartbeat.dart';
import '../data/radio/radio_repository.dart';
import '../data/radio/radio_retry.dart';
import '../data/radio/radio_status.dart';
import '../l10n/app_localizations.dart';
import '../models/gathering_view.dart';
import '../models/media_preferences.dart';
import 'locale_providers.dart';
import 'media_settings_providers.dart';
import 'playback_controller.dart';
import 'player_providers.dart';

/// Politique de réessai des providers d'antenne : **aucun réessai automatique**.
///
/// Même raison que l'agenda et la médiathèque : Riverpod 3 réessaie tout seul
/// jusqu'à dix fois en doublant l'attente, et le bouton resterait une minute à ne
/// rien dire. Ici c'est pire qu'ailleurs — l'insistance est **déjà** gérée, par
/// `radio_retry.dart`, et deux mécanismes de reprise superposés donneraient une
/// cadence que personne n'a écrite.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// D'où vient l'état de l'antenne — HTTP avec backend, double fixe sinon, comme
/// `calendarRepositoryProvider`.
final radioRepositoryProvider = Provider<RadioRepository>(
  (ref) => AppEnv.useBackend
      ? HttpRadioRepository()
      : const FixedRadioRepository.trenched(),
);

/// **Qui négocie la session de MediaMTX avant d'ouvrir le flux** (#108).
///
/// Le web est écarté, et ce n'est pas une mise de côté par prudence : le bocal à
/// cookies y appartient au navigateur, un `Set-Cookie` ne se lit pas depuis
/// JavaScript et `Cookie` est un *forbidden header name* de la spécification
/// Fetch. Un pré-vol y échouerait **et** serait inutile — voir
/// [DirectRadioHandshake] et `hls_content_player.dart`.
///
/// Partout ailleurs le pré-vol est **réel, y compris sans backend** : la route
/// d'antenne peut être doublée (`FixedRadioRepository`), mais le serveur de flux
/// qu'elle désigne, lui, est le vrai — et il demande sa session. C'est pourquoi
/// ce provider ne regarde pas `AppEnv.useBackend` ; les tests le surchargent
/// eux-mêmes (`pumpScreen(handshake: …)`).
final radioHandshakeProvider = Provider<RadioHandshakeResolver>(
  (ref) => const DirectRadioHandshake(),
);

/// **L'état de l'antenne, lu au lancement et au retour à l'écran.**
///
/// Pas d'écoute continue, pas de sondage : c'est la fraîcheur retenue par la
/// décision 3 du cadrage, et ce qui la rend acceptable est que **l'information
/// guide le geste sans l'interdire** — le bouton éteint reste appuyable. C'est le
/// bouton lui-même qui redemande (`ref.invalidate`) au retour au premier plan.
///
/// Un échec **ne devient jamais « hors antenne »** : l'`AsyncValue` reste en
/// erreur, et le bouton se présente au repos. Dire « Hors antenne » parce qu'on
/// n'a pas pu lire affirmerait une panne de l'église dont on n'a aucune preuve.
final radioAntennaProvider = FutureProvider<RadioAntenna>(
  (ref) => ref.watch(radioRepositoryProvider).antenna(),
  retry: _noAutomaticRetry,
);

/// **Ce que l'écran d'antenne donne à lire au lecteur**, dans la forme que
/// `ContentPlayerView` attend.
///
/// Le **titre est une clé de famille**, et c'est le seul moyen honnête de le
/// faire descendre jusqu'ici : « New Life Radio » est un texte destiné à
/// l'auditeur, il vit donc dans les `.arb` (`radioTitle`), et `context.l10n`
/// n'existe pas dans un provider. Le passer en clé plutôt qu'en constante garde
/// l'unique source du libellé **et** le fait arriver jusqu'à la notification de
/// l'écran verrouillé, qui lit `ContentView.title`.
///
/// Une antenne sans URL rend `null`, c'est-à-dire l'absence que
/// `ContentPlayerView` sait déjà dessiner (`ContentAbsence.retracted`, habillée
/// par l'écran) : « je ne sais pas où est l'antenne » n'est pas « pas de média ».
final radioContentProvider =
    Provider.family<AsyncValue<ContentView?>, String>((ref, title) {
  return ref.watch(radioAntennaProvider).whenData(
        (antenna) => antenna.streamUrl == null
            ? null
            : GatheringView(
                id: RadioConfig.contentId,
                title: title,
                color: kBrandFallbackColor,
                playlistUrl: antenna.streamUrl,
              ),
      );
});

/// **« Le réseau a changé »** — l'accélérateur de la reprise (#179, décision 9
/// du plan radio adaptative).
///
/// Écouté **seulement** pendant un état instable ou une reconnexion, et
/// seulement pour avancer un essai : il ne suspend jamais rien (voir
/// `radio_retry.dart`). Les tests le surchargent (`pumpScreen(radioNetwork:
/// …)`) : l'implémentation réelle ouvre un canal de plugin que `flutter test`
/// n'a pas.
final radioNetworkChangesProvider = Provider<Stream<void>>(
  (ref) => ConnectivityNetworkStatus().onTransportChanged,
);

/// **Le contrôleur d'écoute** : il lance, il arrête, et il insiste — sans fin.
///
/// Jamais `autoDispose`, pour la raison de `contentPlayerProvider` : l'écoute
/// survit à l'écran. Une reprise en cours doit survivre au retour à l'accueil, et
/// un contrôleur jeté avec le dernier écran qui l'observe laisserait une antenne
/// cassée sans personne pour la rattraper.
final radioListeningProvider =
    NotifierProvider<RadioListening, RadioStatus>(RadioListening.new);

/// **La machine d'états de l'écoute** (#179).
///
/// ```
/// idle ──start──► connecting ──son──► playing ◄──────────── son ──┐
///                    │                 │ tampon ≥ 2 s             │
///                    │                 ▼                          │
///                    │              unstable                      │
///                    │                 │ tampon ≥ 8 s : relance   │
///                    │ panne, ou 20 s  ▼                          │
///                    └────────────► retrying ── essai frais ──────┘
///                                    ▲   │ panne, ou 20 s sans son :
///                                    └───┘ attente 1, 2, 4, 5, 5… s
/// ```
///
/// - **Un seul essai en vol** : un essai est un `start(fresh: true)` — route
///   d'antenne, pré-vol, ouverture au bord du direct. [_starting] le garde
///   pendant qu'il résout, [_attemptDeadline] le borne jusqu'au premier son.
///   La relance à 8 s, l'essai programmé ([_retry]) et le signal réseau passent
///   tous par [start], qui annule les deux autres avant de partir.
/// - **Aucun abandon** : seul [stop] (le bouton, la ✕, la notification balayée)
///   arrête — et il arrête tout, y compris un démarrage en vol ([_generation]).
/// - Le réseau qui revient ou change, pendant `unstable` ou `retrying`, lance
///   un essai tout de suite et réarme la séquence ; il ne suspend rien.
class RadioListening extends Notifier<RadioStatus> {
  /// **Vrai pendant qu'un démarrage résout** — route d'antenne, pré-vol, puis
  /// `load`.
  ///
  /// Pendant ce temps, le lecteur tient encore l'ancienne source (ou
  /// l'enseignement remplacé) : ses émissions — une panne, un tampon — ne
  /// disent rien de la tentative en cours, et sont ignorées.
  bool _starting = false;

  /// **Le numéro du démarrage courant.** Un démarrage en vol qui le trouve
  /// changé à son réveil renonce sans toucher au lecteur : c'est ce qui rend
  /// l'arrêt définitif, même pendant les cinq secondes d'un pré-vol.
  int _generation = 0;

  /// Vrai de la première panne (ou de la relance à 8 s) jusqu'au son : on
  /// est en reconnexion, et c'est ce que l'état affiche, quoi que le lecteur
  /// émette entre-temps.
  bool _reconnecting = false;

  /// Combien d'attentes de la séquence 1, 2, 4, 5… ont été consommées.
  int _attempts = 0;

  /// La prochaine tentative, déjà programmée.
  Timer? _retry;

  /// La borne d'une tentative sans son ([kRadioAttemptTimeout]).
  Timer? _attemptDeadline;

  /// Les deux seuils du tampon après le premier son : 2 s, puis 8 s.
  Timer? _unstable;
  Timer? _stalled;

  /// L'écoute du réseau, ouverte pendant `unstable` et `retrying` seulement.
  StreamSubscription<void>? _network;

  /// La dernière émission tenait-elle l'antenne ? Sert à reconnaître l'arrêt
  /// venu du système (notification balayée) pendant un démarrage en vol.
  bool _heldRadio = false;

  /// La dernière émission de l'antenne la disait-elle en lecture ? C'est ce
  /// qui reconnaît une **pause** : le bouton de l'auditeur, la notification,
  /// ou une interruption du système (appel) — `just_audio` met lui-même le
  /// lecteur en pause, sans passer par le contrôleur.
  bool _wasPlaying = false;

  /// Vrai le temps de l'appel synchrone à `load`, qui émet une valeur neuve
  /// (`isPlaying` faux sur les doubles) : ce n'est pas une pause.
  bool _loadingReset = false;

  /// **La source tenue est périmée** : une pause est tombée pendant un état
  /// instable ou une reconnexion. La reprise, quel que soit le geste — bouton,
  /// notification, fin d'appel —, rouvre au bord du direct.
  bool _reopenOnResume = false;

  /// Le dernier titre annoncé au système, pour qu'une tentative puisse rouvrir la
  /// source sans écran devant elle.
  String? _title;

  @override
  RadioStatus build() {
    final player = ref.watch(contentPlayerProvider);
    void onChanged() => _onPlayback(player.value);
    player.addListener(onChanged);
    _heldRadio = player.value.contentId == RadioConfig.contentId;
    _wasPlaying = _heldRadio && player.value.isPlaying;
    // **La notification suit l'état**, d'un seul endroit : « Connexion
    // instable… » et « Reconnexion… » y remplacent la seconde ligne.
    listenSelf((_, next) => _announce(next));
    ref.onDispose(() {
      player.removeListener(onChanged);
      _reset();
    });
    _wireEconomyAndHeartbeat();
    // L'état se **dérive** du lecteur, il ne part pas de zéro : revenir à
    // l'accueil pendant que l'antenne joue doit retrouver un bouton allumé.
    return _derive(player.value);
  }

  /// **Lance l'écoute.** Idempotent : rappelé pendant qu'un démarrage est en vol,
  /// il ne fait rien.
  ///
  /// [fresh] force la **réouverture** de la source au bord du direct, route
  /// d'antenne relue et pré-vol compris, même quand le lecteur tient déjà
  /// l'antenne en pause : c'est ce que fait toute relance (#179) et ce qui rend
  /// le direct après une interruption (voir [rejoinLive]). Sans lui, un lecteur
  /// qui tient l'antenne saine reçoit un simple `play()`, qui reprendrait là où
  /// le tampon s'est arrêté. Une reconnexion en cours ou une panne en main
  /// valent [fresh] : un geste de l'auditeur à ce moment-là est une relance.
  Future<void> start({required String title, bool fresh = false}) async {
    if (_starting) return;
    _title = title;

    // **Le transport passe par le contrôleur global** (#114), comme partout :
    // ce qui reste propre à l'antenne — l'adresse, le pré-vol, l'insistance —
    // vit ici, et seulement ici.
    final controller = ref.read(playbackControllerProvider.notifier);
    final playback = controller.playback;
    final held = playback.contentId == RadioConfig.contentId;
    final reopen = fresh ||
        _reconnecting ||
        _reopenOnResume ||
        (held && playback.hasError);
    if (held && !reopen) {
      // Déjà en main — mis en pause depuis l'écran d'antenne ou la notification.
      // On ne recharge pas : rouvrir la source couperait le tampon déjà rempli.
      state = RadioStatus.connecting;
      controller.play();
      return;
    }

    _cancelTimers();
    _reopenOnResume = false;
    final generation = ++_generation;
    _starting = true;
    if (!_reconnecting) state = RadioStatus.connecting;
    // **La tentative a une durée de vie**, du premier octet au premier son :
    // une ouverture HLS pendue ne lève rien sur iOS, et sans cette borne elle
    // resterait « en vol » pour toujours.
    _attemptDeadline = Timer(kRadioAttemptTimeout, () {
      _attemptDeadline = null;
      if (generation != _generation) return;
      _generation++; // le démarrage pendu renonce à son réveil
      _starting = false;
      _fail(TimeoutException('aucun son', kRadioAttemptTimeout));
    });
    try {
      final url = await _resolveUrl(fresh: reopen);
      if (generation != _generation) return;
      // **LA POIGNÉE DE MAIN PAR COOKIE, HONORÉE ICI** (#108) — et c'est ce qui
      // décide si l'écoute marche en vrai.
      //
      // MediaMTX n'ouvre pas son antenne à qui ne porte pas sa session. Mesuré
      // le 2026-10-01 depuis l'extérieur du VPS : sans cookie, `401
      // {"status":"error","error":"session not found"}` ; avec, la playlist
      // complète. La négociation se fait en **deux temps** — un 302 qui pose
      // `cookieCheck`, puis un 200 qui pose `hlsSession` — et `just_audio` ne
      // garde ni l'un ni l'autre (relevé dans son source 0.10.6 : Android jette,
      // faute de `CookieHandler` par défaut ; Darwin ne pose jamais
      // `AVURLAssetHTTPCookiesKey`). On la fait donc nous-mêmes, puis on passe au
      // lecteur l'**URL absolue finale** et l'en-tête `Cookie:` —
      // `radio_handshake.dart` porte tout le détail, bocal compris.
      //
      // ⚠️ **Il est renégocié à chaque fois, et c'est le cœur de la reprise.**
      // Rien n'est mis en cache entre deux `start` : une session expire, donc une
      // reprise après une coupure ne peut pas rejouer l'ancien cookie.
      //
      // ⚠️ **Son échec n'a pas de voix à lui** : il lève, et la tentative échoue
      // comme les autres. Sa borne de temps lui est en revanche propre
      // (`kRadioHandshakeTimeout`), parce qu'il est **sur le chemin critique de
      // l'écoute** et que ce qu'il consomme est pris sur la fenêtre de rattrapage
      // de 40 secondes de l'antenne.
      final resolver = ref.read(radioHandshakeProvider);
      final handshake = await resolver.resolve(url);
      if (generation != _generation) return;
      _traceHandshake(resolver, handshake);
      _loadingReset = true;
      final loading = controller.load(
        ContentRequest(
          contentId: RadioConfig.contentId,
          // L'URL **finale**, pas celle de départ : le `Location` du 302 est
          // absolu et à la racine, et rouvrir l'adresse de départ referait la
          // négociation sans le bocal — c'est-à-dire la panne.
          url: handshake.url,
          title: title,
          // Ils descendent jusqu'à la source (#108), donc jusqu'aux
          // sous-playlists et aux segments.
          headers: handshake.headers,
          // **Pas de ±30 s ni de barre de progression sur un direct**, et pas
          // de position d'ouverture : la source s'ouvre **au bord du direct**.
          // C'est aussi ce drapeau qui écarte le chien de garde de 25 s des
          // lecteurs — l'antenne a le sien, ici.
          isLive: true,
        ),
      );
      _loadingReset = false;
      await loading;
      if (generation != _generation) return;
      // Une ouverture refusée se lit sur la valeur du lecteur, pas sur une
      // exception : `load` la range dans `error` et rend normalement.
      final error = controller.playback.error;
      if (error != null) throw error;
    } catch (error) {
      if (generation != _generation) return;
      _starting = false;
      _fail(error);
      return;
    }
    // **Avant `play()`, et pas après** : l'émission « ça joue » doit trouver le
    // démarrage terminé, sans quoi elle serait ignorée et le bouton resterait
    // en connexion.
    _starting = false;
    // `load` a effacé la ligne de la notification : on la repose.
    _announce(state);
    controller.play();
  }

  /// **Range la panne dans le journal, en debug** — la cause ne s'affiche plus
  /// (la reprise ne s'arrête jamais), mais le message brut de la plateforme
  /// reste le **seul** indice d'une vraie panne. En release, rien.
  void _trace(Object error) {
    assert(() {
      final kind = classifyRadioFailure(error);
      debugPrint('[radio] échec ($kind) : $error');
      return true;
    }());
  }

  /// **Dit, en debug, qu'une négociation réelle n'a rapporté aucun cookie.**
  ///
  /// Ce n'est pas un échec, et ça ne lève donc pas : un MediaMTX configuré sans
  /// session rend 200 du premier coup, et l'antenne jouerait sans cookie. Mais
  /// c'est **exactement l'état dans lequel elle rend 401 en silence**, et rien ne
  /// permettait de le constater depuis l'extérieur — un flux qui ne joue pas
  /// ressemble à un réseau lent, et c'est ce qui a coûté une soirée.
  ///
  /// ⚠️ **Un [DirectRadioHandshake] est écarté, et ce n'est pas une exception de
  /// confort** : il *est* « le pré-vol qui n'en fait pas », par conception, sur le
  /// web et dans tous les tests d'écran. L'y faire parler noierait le seul cas
  /// suspect sous une ligne par montage, c'est-à-dire rendrait cette trace
  /// inutile — un avertissement qui crie toujours n'avertit plus de rien.
  void _traceHandshake(
    RadioHandshakeResolver resolver,
    RadioHandshake handshake,
  ) {
    assert(() {
      if (resolver is! DirectRadioHandshake && handshake.headers.isEmpty) {
        debugPrint('[radio] pré-vol sans cookie — l\'antenne sera ouverte nue '
            '(${handshake.url})');
      }
      return true;
    }());
  }

  /// **Rejoint l'antenne au direct** — la reprise après un statut à son
  /// (#130).
  ///
  /// Le statut a mis l'antenne en pause, et la pause a duré le temps d'écouter
  /// une annonce : souvent plus que les quarante secondes de rattrapage du
  /// flux, et toujours assez pour qu'un `play()` reparte **en retard** sur ce
  /// que l'église diffuse. Rouvrir la source rend le direct ; la renégociation
  /// du cookie de MediaMTX vient avec (#108), et une session expirée pendant
  /// l'annonce n'y survivrait pas autrement.
  ///
  /// [title] est celui de la requête interrompue ; à défaut, celui du dernier
  /// démarrage. Sans aucun des deux — l'antenne n'a jamais été lancée par ici —
  /// il n'y a rien d'honnête à annoncer au système, et la reprise se contente
  /// d'un `play()`.
  Future<void> rejoinLive({String? title}) async {
    final known = title ?? _title;
    if (known == null) {
      ref.read(playbackControllerProvider.notifier).play();
      return;
    }
    await start(title: known, fresh: true);
  }

  /// **Arrête l'écoute**, et renonce à toute reprise en cours — tentative
  /// programmée, relance à 8 s, écoute du réseau, et démarrage en vol.
  ///
  /// Un arrêt demandé est une décision : relancer dans son dos après coup serait
  /// faire sortir du son que personne n'a demandé.
  void stop() {
    _reset();
    ref.read(playbackControllerProvider.notifier).stop();
    state = RadioStatus.idle;
  }

  /// **Le réglage radio et le battement d'écoute** (M2 du plan radio
  /// adaptative) — tout ce que cette tranche ajoute au contrôleur, hors le
  /// choix d'URL de [_resolveUrl].
  ///
  /// - changer Automatique / Économie pendant l'écoute **relance** l'antenne
  ///   (`fresh`), donc sur l'URL du nouveau choix. Le `listen` garde aussi le
  ///   réglage chargé, pour que [_resolveUrl] lise le vrai choix et non le
  ///   défaut d'un flux pas encore ouvert ;
  /// - le battement suit l'état du contrôleur : voir [RadioHeartbeat].
  void _wireEconomyAndHeartbeat() {
    ref.listen<RadioQuality>(radioQualityProvider, (previous, next) {
      final title = _title;
      if (previous == next || title == null || !state.isOn) return;
      unawaited(start(title: title, fresh: true));
    });
    final heartbeat = RadioHeartbeat(
      send: (listenId) =>
          ref.read(radioRepositoryProvider).reportListening(listenId),
    );
    ref.onDispose(heartbeat.dispose);
    listenSelf((_, next) => heartbeat.onStatus(next));
  }

  /// **L'adresse à ouvrir — le seul endroit où elle se choisit**, selon le
  /// choix radio (`RadioAntenna.streamUrlFor`).
  ///
  /// Sans [fresh], celle que la route a déjà rendue, sinon une lecture
  /// fraîche : au premier appui, la route peut n'avoir jamais répondu (échec au
  /// lancement, application ouverte hors ligne puis réseau revenu), et refuser
  /// de lancer pour cette raison transformerait une information en interdit.
  /// Avec [fresh] — toute relance —, **toujours** une lecture fraîche de
  /// `GET /radio/antenna` : l'adresse a pu changer pendant la coupure.
  ///
  /// Une antenne sans adresse lève : la tentative échoue, et la séquence
  /// continue — l'adresse peut revenir.
  Future<String> _resolveUrl({required bool fresh}) async {
    final quality = ref.read(radioQualityProvider);
    final known = fresh ? null : ref.read(radioAntennaProvider).value;
    final antenna = known?.streamUrlFor(quality) != null
        ? known!
        : await ref.read(radioRepositoryProvider).antenna();
    final url = antenna.streamUrlFor(quality);
    if (url == null) throw StateError('antenne sans adresse');
    return url;
  }

  /// Une émission du lecteur. C'est **la** source de vérité de l'état.
  void _onPlayback(ContentPlayback playback) {
    final held = playback.contentId == RadioConfig.contentId;
    final wasHeld = _heldRadio;
    _heldRadio = held;
    final paused = held && !_loadingReset && _wasPlaying && !playback.isPlaying;
    _wasPlaying = held && playback.isPlaying;
    if (!held) {
      // Pendant un démarrage, le contenu remplacé bat encore : seule une
      // émission qui **quitte** l'antenne — la ✕, la notification balayée, un
      // autre contenu chargé — arrête, et elle arrête aussi le démarrage en
      // vol. Sans quoi le son reviendrait après la notification balayée.
      if (_starting && !wasHeld) return;
      _reset();
      state = RadioStatus.idle;
      return;
    }

    // **Une pause pendant la réparation l'arrête net** — essai programmé,
    // seuils, réseau, et l'essai en vol, qui renonce avant de rendre le son.
    // Avant le garde du démarrage : c'est la seule émission qu'un essai en vol
    // ne peut pas ignorer.
    if (paused && (_reconnecting || state.phase == RadioPhase.unstable)) {
      _reset();
      _reopenOnResume = true;
      state = RadioStatus.idle;
      return;
    }

    // Un démarrage en vol décide seul de son issue : l'ancienne source peut
    // encore émettre sa panne ou son tampon.
    if (_starting) return;

    // **La reprise après cette pause**, par un geste qui ne passe pas par
    // [start] (notification, mini-lecteur, fin d'appel) : la source périmée
    // n'est pas reprise, on rouvre au bord du direct.
    if (_reopenOnResume && playback.isPlaying) {
      unawaited(start(title: _title ?? _l10n.radioTitle, fresh: true));
      return;
    }

    final error = playback.error;
    if (error != null) {
      _fail(error);
      return;
    }

    // **Le son coule vraiment** : la reconnexion s'efface, et la séquence
    // repart de zéro pour la prochaine panne.
    //
    // ⚠️ `hasStarted` **et** `!isBuffering` : les deux implémentations posent
    // `isBuffering` dès le chargement, avant tout aller-retour, et `hasStarted`
    // ne se pose qu'au premier instant où le média peut sortir du son.
    if (playback.hasStarted && playback.isPlaying && !playback.isBuffering) {
      _heard();
      return;
    }

    // **L'antenne devrait jouer, et le tampon attend** : les deux seuils
    // s'arment, une seule fois par attente continue.
    if (playback.hasStarted && playback.isPlaying) {
      _watchStall();
    } else {
      _cancelStall();
    }

    // Une reconnexion garde la main sur l'affichage, quoi que la source
    // émette en attendant le son.
    if (_reconnecting) return;

    // **`hasStarted` est la frontière, et il ne redevient jamais faux** sur un
    // même contenu. Au-delà, il ne peut plus s'agir d'une connexion initiale :
    //
    // - elle joue — y compris pendant qu'elle regarnit son tampon, et c'est ce
    //   qui laisse arrêter une antenne qui hoquette ; « Connexion instable… »
    //   ne vient qu'au bout de deux secondes, et reste jusqu'au son ;
    // - elle est **en pause** : le lecteur de l'écran d'antenne et la
    //   notification savent tous deux mettre en pause, et ce n'est pas une
    //   connexion en cours. Au repos, un appui redémarre.
    if (playback.hasStarted) {
      if (!playback.isPlaying) {
        state = RadioStatus.idle;
      } else if (state.phase != RadioPhase.unstable) {
        state = RadioStatus.playing;
      }
      return;
    }
    state = RadioStatus.connecting;
  }

  /// **Le son est sorti** : tout s'efface, et la séquence repart de zéro.
  void _heard() {
    _cancelTimers();
    _closeNetwork();
    _reconnecting = false;
    _attempts = 0;
    state = RadioStatus.playing;
  }

  /// **Les deux seuils du tampon** : « Connexion instable… » à 2 s, relance au
  /// bord du direct à 8 s. Rien si une attente est déjà armée, ou si une
  /// tentative est déjà programmée — elle partira de toute façon.
  void _watchStall() {
    if (_stalled != null || _retry != null) return;
    _unstable = Timer(kRadioUnstableAfter, () {
      _unstable = null;
      if (_reconnecting) return;
      state = RadioStatus.unstable;
      _listenNetwork();
    });
    _stalled = Timer(kRadioStallRelaunchAfter, () {
      _stalled = null;
      _relaunch();
    });
  }

  /// **Une tentative tout de suite**, au bord du direct. [start] annule
  /// l'essai programmé et les seuils : rien ne se cumule.
  void _relaunch() {
    _reconnecting = true;
    state = RadioStatus.retrying;
    _listenNetwork();
    final title = _title ?? _l10n.radioTitle;
    unawaited(start(title: title, fresh: true));
  }

  /// Un échec : on passe en reconnexion, et on programme la tentative suivante.
  ///
  /// ⚠️ **Une seconde émission de la même panne ne repousse pas la tentative**,
  /// et ce garde-là n'est pas défensif : `ContentPlayback.copyWith` **ne sait
  /// pas effacer** une panne, donc toute émission suivante du lecteur — un
  /// dernier battement de position, un changement d'état — la porte encore.
  /// Sans ce `return`, chaque battement réarmerait l'attente, et la tentative
  /// n'aurait jamais lieu.
  void _fail(Object error) {
    _trace(error);
    _cancelStall();
    _attemptDeadline?.cancel();
    _attemptDeadline = null;
    _reconnecting = true;
    state = RadioStatus.retrying;
    _listenNetwork();
    if (_retry != null) return;
    _retry = Timer(radioRetryDelay(_attempts++), () {
      _retry = null;
      _relaunch();
    });
  }

  /// **Le réseau est revenu ou a changé** : pendant un état instable ou une
  /// reconnexion, un essai part tout de suite et la séquence est réarmée.
  ///
  /// Un démarrage déjà en vol n'est pas doublé — un seul essai à la fois : la
  /// séquence réarmée servira s'il échoue.
  void _onNetwork() {
    if (!_reconnecting && state.phase != RadioPhase.unstable) return;
    _attempts = 0;
    if (_starting) return;
    _relaunch();
  }

  void _listenNetwork() {
    _network ??=
        ref.read(radioNetworkChangesProvider).listen((_) => _onNetwork());
  }

  void _closeNetwork() {
    unawaited(_network?.cancel());
    _network = null;
  }

  void _cancelStall() {
    _unstable?.cancel();
    _unstable = null;
    _stalled?.cancel();
    _stalled = null;
  }

  void _cancelTimers() {
    _cancelStall();
    _retry?.cancel();
    _retry = null;
    _attemptDeadline?.cancel();
    _attemptDeadline = null;
  }

  /// **Tout s'arrête** : minuteries, écoute du réseau, et le démarrage en vol
  /// renonce à son réveil.
  void _reset() {
    _cancelTimers();
    _closeNetwork();
    _generation++;
    _starting = false;
    _reconnecting = false;
    _reopenOnResume = false;
    _attempts = 0;
  }

  /// **La seconde ligne de la notification**, posée d'après l'état — et
  /// seulement sur l'antenne : un enseignement qui l'a remplacée garde son
  /// auteur.
  void _announce(RadioStatus status) {
    final controller = ref.read(playbackControllerProvider.notifier);
    if (controller.playback.contentId != RadioConfig.contentId) return;
    final l10n = _l10n;
    controller.setStatusLine(switch (status.phase) {
      RadioPhase.unstable => l10n.radioUnstable,
      RadioPhase.retrying => l10n.radioRetrying,
      _ => null,
    });
  }

  /// Les textes de l'interface, **hors de l'arbre** : la langue que
  /// `MaterialApp` a résolue, recopiée dans [contentLocaleProvider].
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(ref.read(contentLocaleProvider)));

  /// L'état de départ, **lu sur le lecteur**.
  ///
  /// Une panne déjà présente à la naissance de ce contrôleur rend
  /// [RadioStatus.idle] et non « en reprise » : personne ne réessaie encore, et
  /// afficher un bouton qui annonce des tentatives qu'aucune minuterie ne porte
  /// serait le seul mensonge que ce bouton puisse dire. Au repos, il invite — et
  /// un appui repart proprement.
  RadioStatus _derive(ContentPlayback playback) {
    if (playback.contentId != RadioConfig.contentId) return RadioStatus.idle;
    if (playback.hasError) return RadioStatus.idle;
    if (playback.hasStarted) {
      return playback.isPlaying ? RadioStatus.playing : RadioStatus.idle;
    }
    return RadioStatus.connecting;
  }
}
