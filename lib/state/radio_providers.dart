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
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../core/config/radio_config.dart';
import '../data/players/content_player.dart';
import '../data/radio/http_radio_repository.dart';
import '../data/radio/radio_antenna.dart';
import '../data/radio/radio_failure.dart';
import '../data/radio/radio_handshake.dart';
import '../data/radio/radio_repository.dart';
import '../data/radio/radio_retry.dart';
import '../data/radio/radio_status.dart';
import '../models/gathering_view.dart';
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

/// **Le contrôleur d'écoute** : il lance, il arrête, et il insiste.
///
/// Jamais `autoDispose`, pour la raison de `contentPlayerProvider` : l'écoute
/// survit à l'écran. Une reprise en cours doit survivre au retour à l'accueil, et
/// un contrôleur jeté avec le dernier écran qui l'observe laisserait une antenne
/// cassée sans personne pour la rattraper.
final radioListeningProvider =
    NotifierProvider<RadioListening, RadioStatus>(RadioListening.new);

class RadioListening extends Notifier<RadioStatus> {
  /// **Vrai pendant qu'un démarrage est en vol** — résolution de l'URL, puis
  /// `load`.
  ///
  /// Il existe parce que, pendant ces quelques millisecondes, le lecteur ne tient
  /// **pas encore** la radio : sans ce drapeau, une émission du lecteur portant
  /// encore l'enseignement précédent ferait retomber le bouton au repos juste
  /// après qu'on l'a touché.
  bool _starting = false;

  /// **Les deux minutes**, armées au premier échec de la rafale et à lui seul.
  ///
  /// Son existence distingue « la première panne » de « encore une » : tant
  /// qu'elle court, on est dans la même rafale, et c'est depuis le premier échec
  /// que l'abandon se compte. Un succès l'efface.
  Timer? _deadline;

  /// La prochaine tentative, déjà programmée.
  Timer? _attempt;

  /// Combien des six attentes ont été consommées par la rafale en cours.
  int _attempts = 0;

  /// La dernière cause lue, celle qui s'affichera si l'on renonce.
  RadioFailureKind? _cause;

  /// Vrai quand on a renoncé : le bouton est éteint et porte le motif. Un geste
  /// de l'auditeur l'efface — c'est lui qui décide de réessayer.
  bool _abandoned = false;

  /// Le dernier titre annoncé au système, pour qu'une tentative puisse rouvrir la
  /// source sans écran devant elle.
  String? _title;

  @override
  RadioStatus build() {
    final player = ref.watch(contentPlayerProvider);
    void onChanged() => _onPlayback(player.value);
    player.addListener(onChanged);
    ref.onDispose(() {
      player.removeListener(onChanged);
      _cancelRetry();
    });
    // L'état se **dérive** du lecteur, il ne part pas de zéro : revenir à
    // l'accueil pendant que l'antenne joue doit retrouver un bouton allumé.
    return _derive(player.value);
  }

  /// **Lance l'écoute.** Idempotent : rappelé pendant qu'un démarrage est en vol,
  /// il ne fait rien.
  Future<void> start({required String title}) async {
    if (_starting) return;
    _title = title;
    // Un geste efface le renoncement : c'est l'auditeur qui décide de réessayer,
    // et un bouton éteint qui refuserait de repartir serait un interdit de plus.
    _abandoned = false;

    final player = ref.read(contentPlayerProvider);
    final held = player.value.contentId == RadioConfig.contentId;
    if (held && !player.value.hasError) {
      // Déjà en main — mis en pause depuis l'écran d'antenne ou la notification.
      // On ne recharge pas : rouvrir la source couperait le tampon déjà rempli.
      if (_cause == null) state = RadioStatus.connecting;
      player.play();
      return;
    }

    _starting = true;
    if (_cause == null) state = RadioStatus.connecting;
    try {
      final url = await _resolveUrl();
      if (url == null) return; // `_fail` a déjà parlé
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
      // ⚠️ **Il est renégocié à chaque fois, et c'est le cœur de la tranche.**
      // Rien n'est mis en cache entre deux `start` : une session expire, donc une
      // reprise après deux minutes de coupure ne peut pas rejouer l'ancien
      // cookie. Mémoriser le résultat pour épargner un aller-retour rendrait
      // l'antenne muette précisément dans le cas où l'auditeur insiste.
      //
      // ⚠️ **Son échec n'a pas de voix à lui.** Il lève, la prise d'erreur de
      // cette méthode le range par `classifyRadioFailure`, et il se lit donc
      // comme les autres : réponse absente → « vérifiez votre connexion » ;
      // 401 / 404 / 5xx → « antenne indisponible ». Sa borne de temps lui est en
      // revanche propre (`kRadioHandshakeTimeout`), parce qu'il est **sur le
      // chemin critique de l'écoute** et que ce qu'il consomme est pris sur la
      // fenêtre de rattrapage de 40 secondes de l'antenne.
      final resolver = ref.read(radioHandshakeProvider);
      final handshake = await resolver.resolve(url);
      _traceHandshake(resolver, handshake);
      await player.load(
        contentId: RadioConfig.contentId,
        // L'URL **finale**, pas celle de départ : le `Location` du 302 est
        // absolu et à la racine, et rouvrir l'adresse de départ referait la
        // négociation sans le bocal — c'est-à-dire la panne.
        url: handshake.url,
        title: title,
        // Ils descendent jusqu'à la source (#108), donc jusqu'aux
        // sous-playlists et aux segments, et ils sont retenus par
        // `ContentRequest` pour que le chien de garde ne rouvre pas sans eux.
        headers: handshake.headers,
        // **Pas de ±30 s ni de barre de progression sur un direct** : c'est ce
        // drapeau, et lui seul, qui le dit à la notification et à l'écran
        // verrouillé.
        isLive: true,
      );
      player.play();
    } catch (error) {
      _fail(_classify(error));
    } finally {
      _starting = false;
    }
  }

  /// **Range la panne, et laisse une trace de ce qu'on n'a pas su lire.**
  ///
  /// Le journal n'est pas de la décoration : l'écoute qui a coûté une soirée
  /// s'est présentée comme « vérifiez votre connexion » sur un téléphone
  /// connecté, et le message brut de la plateforme était le **seul** indice de la
  /// vraie cause — il n'allait nulle part. Il va désormais dans le journal, en
  /// debug, pour que la prochaine enquête commence par le lire au lieu de le
  /// deviner. En release, rien.
  RadioFailureKind _classify(Object error) {
    final kind = classifyRadioFailure(error);
    if (kind == RadioFailureKind.unknown) {
      assert(() {
        debugPrint('[radio] panne non classée, message brut : $error');
        return true;
      }());
    }
    return kind;
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

  /// **Arrête l'écoute**, et renonce à toute reprise en cours.
  ///
  /// Un arrêt demandé est une décision : relancer dans son dos après coup serait
  /// faire sortir du son que personne n'a demandé.
  void stop() {
    _cancelRetry();
    _cause = null;
    _abandoned = false;
    _starting = false;
    ref.read(contentPlayerProvider).stop();
    state = RadioStatus.idle;
  }

  /// L'adresse à ouvrir : celle que la route a déjà rendue, sinon une lecture
  /// fraîche.
  ///
  /// La lecture fraîche n'est pas un doublon du provider : au premier appui, la
  /// route peut n'avoir jamais répondu (échec au lancement, application ouverte
  /// hors ligne puis réseau revenu), et refuser de lancer pour cette raison
  /// transformerait une information en interdit.
  Future<String?> _resolveUrl() async {
    final known = ref.read(radioAntennaProvider).value?.streamUrl;
    if (known != null) return known;
    try {
      final fresh = await ref.read(radioRepositoryProvider).antenna();
      if (fresh.streamUrl != null) return fresh.streamUrl;
      // Le serveur a répondu, et il n'a pas d'antenne à donner.
      _fail(RadioFailureKind.antenna);
      return null;
    } catch (error) {
      _fail(_classify(error));
      return null;
    }
  }

  /// Une émission du lecteur. C'est **la** source de vérité de l'état.
  void _onPlayback(ContentPlayback playback) {
    final held = playback.contentId == RadioConfig.contentId;
    if (!held) {
      // Un démarrage en vol n'a pas encore posé son contenu : ne pas prendre
      // l'émission précédente pour un abandon.
      if (_starting) return;
      _cancelRetry();
      _cause = null;
      _abandoned = false;
      state = RadioStatus.idle;
      return;
    }

    final error = playback.error;
    if (error != null) {
      _fail(_classify(error));
      return;
    }

    // **Le son coule vraiment** : la rafale s'efface, et l'insistance repart de
    // zéro pour la prochaine panne.
    //
    // ⚠️ `!isBuffering` est ce qui sépare « ça joue » de « ça vient de rouvrir »,
    // et sans lui la reprise ne reprendrait rien : `resume()` publie
    // `isPlaying` **et** `isBuffering` avant le moindre aller-retour réseau
    // (c'est écrit dans les deux implémentations), si bien que chaque tentative
    // passerait pour un succès. Les six attentes deviendraient six attentes d'une
    // seconde, et rien dans l'affichage ne l'aurait montré.
    if (playback.hasStarted && playback.isPlaying && !playback.isBuffering) {
      _heard();
      return;
    }

    // Une rafale en cours garde la main sur l'affichage : la panne a disparu de
    // la valeur, mais on réessaie toujours, et c'est ce que le bouton doit dire.
    if (_abandoned || _cause != null) return;

    // **`hasStarted` est la frontière, et il ne redevient jamais faux** sur un
    // même contenu. Au-delà, il ne peut plus s'agir d'une connexion initiale :
    //
    // - elle joue — y compris pendant qu'elle regarnit son tampon, et c'est ce qui
    //   laisse arrêter une antenne qui hoquette ;
    // - elle est **en pause** : le lecteur de l'écran d'antenne et la notification
    //   savent tous deux mettre en pause, et ce n'est pas une connexion en cours.
    //   La prendre pour telle laisserait un bouton qui tourne et qui refuse de
    //   s'arrêter (l'inertie), sur une antenne parfaitement silencieuse. Au repos,
    //   un appui redémarre — `start` voit le contenu déjà en main et se contente
    //   d'un `play()`, sans rouvrir la source.
    if (playback.hasStarted) {
      state = playback.isPlaying ? RadioStatus.playing : RadioStatus.idle;
      return;
    }
    state = RadioStatus.connecting;
  }

  /// **Le son est sorti** : la rafale s'efface, et l'insistance repart de zéro
  /// pour la prochaine panne.
  void _heard() {
    _cancelRetry();
    _cause = null;
    _abandoned = false;
    state = RadioStatus.playing;
  }

  /// Un échec : on retient la cause, on arme la borne de deux minutes au premier,
  /// et on programme la tentative suivante.
  ///
  /// ⚠️ **Une seconde émission de la même panne ne repousse pas la tentative**, et
  /// ce garde-là n'est pas défensif : `ContentPlayback.copyWith` **ne sait pas
  /// effacer** une panne, donc toute émission suivante du lecteur — un dernier
  /// battement de position, un changement d'état — la porte encore. Sans ce
  /// `return`, chaque battement réarmerait l'attente, et la tentative n'aurait
  /// jamais lieu : une reprise qui ne reprend rien, sans qu'aucun test d'unité du
  /// contrôleur ne rougisse.
  void _fail(RadioFailureKind cause) {
    if (_abandoned) return;
    _cause = cause;
    _deadline ??= Timer(kRadioRetryDeadline, _abandon);
    state = RadioStatus.retrying;
    if (_attempt != null) return;
    _schedule();
  }

  void _schedule() {
    if (_attempts >= kRadioRetryDelays.length) {
      // Les six attentes sont consommées : l'insistance s'arrête, même si les
      // deux minutes ne sont pas écoulées.
      _abandon();
      return;
    }
    final delay = kRadioRetryDelays[_attempts];
    _attempt = Timer(delay, () {
      _attempt = null;
      _attempts++;
      _retry();
    });
  }

  /// **Une tentative, et elle réutilise ce qui existe.**
  ///
  /// `ContentPlayer.resume()` est le chemin à deux voies documenté dans
  /// `just_audio_content_player.dart` : le raccourci quand la plateforme a gardé
  /// la source, le repli explicite sinon. On ne réécrit pas une troisième
  /// réouverture. Quand le lecteur ne tient plus rien — l'échec est arrivé avant
  /// le `load`, ou sur la route d'antenne —, la tentative est un démarrage
  /// complet, qui relit l'adresse au passage.
  void _retry() {
    final player = ref.read(contentPlayerProvider);
    if (player.value.contentId == RadioConfig.contentId) {
      unawaited(player.resume());
      return;
    }
    final title = _title;
    if (title == null) {
      _abandon();
      return;
    }
    unawaited(start(title: title));
  }

  /// On renonce : le bouton s'éteint **et dit pourquoi**.
  void _abandon() {
    _cancelRetry();
    _abandoned = true;
    state = RadioStatus.failed(_cause ?? RadioFailureKind.connection);
  }

  void _cancelRetry() {
    _attempt?.cancel();
    _attempt = null;
    _deadline?.cancel();
    _deadline = null;
    _attempts = 0;
  }

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
