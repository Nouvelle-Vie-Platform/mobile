/// **Le contrôleur global de lecture — le seul point d'entrée du transport**
/// (#114), **et le seul suivi d'écoute** (#115).
///
/// Charger, lire, mettre en pause, sauter de ±30 s, arrêter, rejouer, reprendre
/// après une panne : tout geste qui **commande** le lecteur passe par ici, d'où
/// qu'il vienne — la fiche d'un enseignement (`ContentPlayerView`), les cartes
/// de l'accueil (`playHomeContent`), l'antenne (`RadioListening`) et le
/// mini-lecteur (#116), qui l'appelle. Observer le lecteur reste libre :
/// `contentPlaybackProvider`, par `select`, comme avant.
///
/// La règle était écrite sur un widget — « `ContentPlayerView` est le seul
/// endroit qui pilote le lecteur » — et un widget ne peut pas la tenir :
/// `playHomeContent` y dérogeait déjà, et un mini-lecteur présent sur tous les
/// écrans y aurait dérogé à son tour. Elle vit donc ici, sur un provider qui
/// survit à tous les écrans.
///
/// ## Le suivi d'écoute vit ici, et plus sur la fiche (#115)
///
/// La position de reprise (`PlaybackProgressRecorder`) et la mesure d'écoute
/// (`PlayTracker`) étaient attachées au cycle de vie de la fiche : un
/// enseignement lancé depuis une carte de l'accueil n'enregistrait rien, et
/// quitter la fiche coupait le suivi d'un prêche qui continuait de sonner. Elles
/// s'attachent désormais à **ce qui est chargé dans le lecteur global** — une
/// [_ListeningSession] par chargement —, quel que soit l'écran affiché.
///
/// Les cinq déclencheurs de l'enregistreur, et d'où chacun part :
///
/// | Déclencheur | D'où |
/// |---|---|
/// | pause | une émission du lecteur qui passe de « joue » à « ne joue pas » |
/// | **contenu arrêté ou remplacé** (l'ancienne « sortie d'écran ») | [stop], et [load] d'un autre contenu — radio comprise —, **avant** que le lecteur ne change de main |
/// | complétion | l'état terminal du lecteur, ou le seuil dans la position poussée — **jamais sur un fichier partiel** (#228, voir [_playsPartialFile]) |
/// | ~30 s de temps joué | la position poussée à chaque émission |
/// | `AppLifecycleState.paused` | un observateur du cycle de vie — **sans arrêter la lecture** |
///
/// ⚠️ **L'antenne n'est jamais suivie ni comptée** : ni position de reprise
/// (un direct n'en a pas), ni écoute (la route veut un identifiant
/// d'enseignement). Voir [_tracks].
///
/// ⚠️ **La fin de lecture reste visible.** Le suivi marque le contenu terminé,
/// mais ne remet **pas** le lecteur à zéro : le mini-lecteur lit
/// `ContentPlayback.isCompleted` pour afficher la barre pleine et « Rejouer »,
/// et `seek(zero)` le ferait retomber sur `just_audio`. C'est [replay] qui
/// repart du début. Seule la fiche, qui a son propre bouton, se remet d'aplomb
/// à la fin.
///
/// La **rétractation** suit le même chemin : un contenu retiré par le serveur
/// pendant qu'il joue s'arrête, que sa fiche soit ouverte ou non — le contrôleur
/// observe le magasin pour le contenu chargé.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/radio_config.dart';
import '../data/local/tables/download_tables.dart';
import '../data/measurement/play_tracker.dart';
import '../data/players/content_player.dart';
import '../data/repositories/playback_progress_recorder.dart';
import '../models/content_view.dart';
import 'downloads_providers.dart';
import 'gathering_providers.dart';
import 'measurement_providers.dart';
import 'mediatheque_providers.dart';
import 'playback_progress_providers.dart';
import 'player_providers.dart';
import 'radio_providers.dart';

/// **Le contrôleur, et la requête courante qu'il publie.**
///
/// Jamais `autoDispose`, pour la raison de `contentPlayerProvider` : la lecture
/// survit à l'écran qui l'a lancée, donc ce qui la pilote aussi.
///
/// Sa valeur est la [ContentRequest] du contenu chargé — identifiant, titre,
/// auteur, image, direct ou non —, `null` quand rien n'est chargé ou après un
/// arrêt. C'est ce que lira le mini-lecteur : `ContentPlayback` ne porte ni
/// titre, ni auteur, ni image, et on ne les retrouve pas depuis l'identifiant —
/// la radio n'est pas un enseignement du magasin.
final playbackControllerProvider =
    NotifierProvider<PlaybackController, ContentRequest?>(
  PlaybackController.new,
);

class PlaybackController extends Notifier<ContentRequest?> {
  /// **La requête est retenue par le contrôleur, pas demandée au lecteur.**
  ///
  /// Les trois lecteurs la retiennent déjà, mais en privé, pour leurs
  /// réouvertures. La publier aurait élargi le contrat et touché les trois
  /// implémentations — dont deux qu'aucun test ne monte — pour une information
  /// que le contrôleur possède déjà, puisque tout chargement passe par lui.
  ///
  /// ⚠️ **Le lecteur reste juge de ce qu'il tient.** Dès que son `contentId`
  /// cesse d'être celui de la requête — un arrêt, ou un chargement qui n'est pas
  /// passé par ici —, la requête retombe à `null`. Une requête périmée afficherait
  /// le titre d'un prêche qui ne joue plus ; une requête absente n'affiche rien,
  /// ce qui est la panne la moins grave des deux.
  @override
  ContentRequest? build() {
    ref.listen<String?>(
      contentPlaybackProvider.select((playback) => playback.contentId),
      (_, contentId) {
        final request = state;
        if (request != null && request.contentId != contentId) state = null;
        // Un contenu que le lecteur a lâché sans passer par ici n'a plus rien à
        // suivre. Tous les chemins connus passent par [load] ou [stop], qui
        // ferment la session eux-mêmes — ceci n'est que le filet.
        final session = _session;
        if (session != null &&
            session.reachedPlayer &&
            session.contentId != contentId) {
          _leaveSession();
        }
      },
    );
    // **Toutes les émissions**, et pas un `select` : l'enregistreur et la mesure
    // ont besoin de la position, de la durée, de l'état de lecture et de la fin.
    // C'est le seul abonné de ce genre dans l'application, et il ne reconstruit
    // rien — il pousse.
    ref.listen<ContentPlayback>(
      contentPlaybackProvider,
      (_, next) => _session?.follow(next),
    );
    ref.onDispose(() {
      // Un conteneur qui meurt n'écrit plus rien : la base meurt avec lui, et
      // l'ordre des deux morts n'est pas garanti. Les abonnements au magasin
      // sont fermés ici, sans rien écrire : ils sont portés par le conteneur,
      // qui peut survivre à ce contrôleur s'il est seulement invalidé.
      _session?.close();
      _session = null;
      final lifecycle = _lifecycle;
      if (lifecycle != null) {
        WidgetsBinding.instance.removeObserver(lifecycle);
      }
    });
    return null;
  }

  ContentPlayer get _player => ref.read(contentPlayerProvider);

  /// **Ce qui est suivi en ce moment** — position de reprise et mesure d'écoute
  /// du contenu chargé —, `null` sur l'antenne et quand rien n'est chargé.
  _ListeningSession? _session;

  /// L'observateur du cycle de vie, posé au premier contenu suivi.
  _AppPausedObserver? _lifecycle;

  /// **Ce qu'un statut à son a mis en pause** (#130), `null` sinon.
  ///
  /// Retenu par son identifiant, et lu **sur le lecteur** à la reprise : le
  /// lecteur reste juge de ce qu'il tient. Un contenu arrêté ou remplacé
  /// pendant le statut ne revient pas.
  ({String contentId, String? title})? _interruptedByStatus;

  /// L'état du lecteur **à cet instant** — pour l'appelant qui doit le relire
  /// après un `await`, quand son propre `ref` n'est peut-être plus monté.
  ///
  /// Lire n'est pas piloter : un widget qui s'y abonne passe par
  /// `contentPlaybackProvider`, et par `select`.
  ContentPlayback get playback => _player.value;

  /// **Charge un contenu, sans le jouer** — la requête est publiée avant que le
  /// lecteur ne parle, pour qu'aucune émission ne la trouve en retard.
  ///
  /// Tout ce que porte [request] descend au lecteur, en-têtes compris : c'est
  /// le chemin du cookie de l'antenne (#108), et le perdre ici rendrait la radio
  /// muette sans qu'aucun écran ne le montre.
  ///
  /// **Le suivi, dans cet ordre** (#115) :
  ///
  /// 1. le contenu qui jouait est **quitté** — sa position s'écrit *avant* que
  ///    le lecteur ne change de main. C'est le cas de la radio qui prend la
  ///    place d'un prêche : l'enseignement est remplacé, pas mis en pause, et
  ///    sans cette écriture sa position ne tiendrait qu'au dernier battement ;
  /// 2. le nouveau contenu ouvre sa session — reprise résolue, mesure ouverte —,
  ///    **sauf l'antenne** ;
  /// 3. le média est chargé, puis placé à la position de reprise si elle existe
  ///    et que le contenu n'était pas terminé. D'où que vienne le chargement —
  ///    fiche ou carte de l'accueil : une carte qui repartait de zéro aurait
  ///    écrit zéro par-dessus la place du fidèle, et « la plus récente gagne ».
  ///
  /// Un second chargement arrivé pendant l'ouverture de la session gagne : le
  /// premier renonce sans toucher au lecteur. Un [stop] pendant ce temps aussi.
  Future<void> load(ContentRequest request) async {
    _leaveSession();
    state = request;
    if (_tracks(request)) {
      final session = await _openSession(request);
      if (!ref.mounted || !identical(state, request)) {
        session.close();
        return;
      }
      _session = session;
    }
    await _player.load(
      contentId: request.contentId,
      url: request.url,
      title: request.title,
      author: request.author,
      artUrl: request.artUrl,
      localFilePath: request.filePath,
      // **Jusqu'au système, pas seulement jusqu'à l'écran** (#229) : l'écran
      // verrouillé et le centre de contrôle ne lisent pas ce que l'application
      // affiche, ils lisent le `MediaItem`. Perdue ici, la durée du contrat
      // laissait le système montrer l'estimation du lecteur — deux durées pour
      // le même enseignement.
      contractDuration: request.contractDuration,
      isLive: request.isLive,
      headers: request.headers,
    );
    if (!ref.mounted || !identical(state, request)) return;
    final resumeAt = _session?.resumeAt;
    if (resumeAt != null && _player.value.contentId == request.contentId) {
      _player.seek(resumeAt);
    }
  }

  /// **Ce qui est suivi, et ce qui ne l'est jamais.**
  ///
  /// L'antenne de New Life Radio — ou tout autre direct — n'a ni position de
  /// reprise ni enseignement derrière elle : la suivre écrirait une ligne de
  /// progression sur un identifiant qui n'existe pas au serveur, et la compter
  /// enverrait une écoute sur la vignette du direct. Les deux gardes, et non une
  /// seule : un direct se dit par le drapeau, l'antenne par son identifiant.
  static bool _tracks(ContentRequest request) =>
      !request.isLive && request.contentId != RadioConfig.contentId;

  /// Ouvre la session d'un contenu : enregistreur, mesure, cycle de vie et
  /// surveillance du magasin.
  ///
  /// Les deux mesures s'ouvrent **chacune sous sa propre garde** : un
  /// enregistreur qui n'a pas pu s'ouvrir — base illisible, reprise
  /// introuvable — ne doit pas emporter l'audience avec lui. Ce sont deux
  /// mesures indépendantes, y compris en panne.
  Future<_ListeningSession> _openSession(ContentRequest request) async {
    final contentId = request.contentId;
    PlaybackProgressRecorder? recorder;
    try {
      recorder = await ref.read(playbackProgressRecorderProvider)(
        contentId,
        // Un partiel ne peut pas être « écouté » (#228) : le magasin fait foi,
        // et il est lu ici, au chargement, où la source ouverte est connue.
        partialSource: await _playsPartialFile(request),
      );
    } catch (error, stack) {
      debugPrint(
          '[progression] enregistreur indisponible pour $contentId : $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }

    final session = _ListeningSession(
      contentId: contentId,
      recorder: recorder,
      // La durée qui fait foi sur une copie locale (#222) : une progression
      // écrite contre une durée estimée se corrige mal après coup.
      contractDuration: request.contractDuration,
    );
    if (!ref.mounted) return session;

    try {
      session.tracker = ref.read(playTrackerProvider)(contentId);
    } catch (error, stack) {
      // Une mesure qui ne s'ouvre pas est une mesure perdue, pas une panne.
      debugPrint('[mesure] traqueur indisponible pour $contentId : $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }

    _observeLifecycle();
    _watchRetraction(session);
    return session;
  }

  /// **La source ouverte est-elle un fichier incomplet ?** (#228)
  ///
  /// Deux faits, et il faut les deux. Le premier est la décision du résolveur,
  /// qu'on relit sur la requête : un `filePath` nul, c'est le HLS — un flux
  /// entier, dont la fin est une vraie fin, partiel téléchargé ou non. Le
  /// second est le magasin, qui fait foi (ADR-0026) : un état non terminé avec
  /// des octets reçus, c'est la ligne « partiel » de la matrice du résolveur
  /// (PRD §3.3, F11), le seul cas où un fichier sur le disque s'arrête avant
  /// l'enseignement.
  ///
  /// Relu ici plutôt que porté par la requête : cette question se pose à
  /// **chaque** chargement d'une copie locale, d'où qu'il vienne, et un
  /// appelant qui oublierait de la porter ferait revenir le faux « écouté »
  /// sans que rien ne le dise.
  Future<bool> _playsPartialFile(ContentRequest request) async {
    if (request.filePath == null) return false;
    final row =
        await ref.read(downloadsDaoProvider).forContent(request.contentId);
    if (row == null) return false;
    return switch (row.state) {
      DownloadState.complete || DownloadState.outdated => false,
      _ => row.bytesReceived > 0,
    };
  }

  /// **Le contenu chargé est-il encore au catalogue ?** — l'arrêt sur
  /// rétractation, que la fiche faisait seule tant qu'elle était à l'écran.
  ///
  /// Le contrôleur ne sait pas si l'identifiant est un enseignement ou un
  /// rassemblement — la requête ne le dit pas, et la radio n'est ni l'un ni
  /// l'autre. Il écoute donc les deux familles, et **ne coupe que ce qu'il a vu
  /// présent** : un enseignement est toujours absent de la famille des
  /// rassemblements, et couper là-dessus couperait tout.
  ///
  /// ⚠️ **Le déclencheur est la valeur, jamais l'`AsyncValue`.** Une
  /// resynchronisation repasse par « chargement » en gardant la valeur
  /// précédente ; couper sur l'état couperait le son à chaque cycle.
  ///
  /// ⚠️ **Par le conteneur, pas par `ref.listen`.** Riverpod 3 désactive les
  /// abonnements d'un provider qui perd son dernier auditeur, et un
  /// `StreamProvider` dont tous les auditeurs sont désactivés **met son flux en
  /// pause**. Le mini-lecteur, qui s'abonne à ce contrôleur et se masque sur la
  /// fiche et la radio, suffirait à faire taire la surveillance. Un abonnement
  /// du conteneur ne dépend que de lui-même ; il est fermé avec la session.
  void _watchRetraction(_ListeningSession session) {
    void onValue(ContentView? previous, ContentView? next) {
      if (previous == null || next != null) return;
      if (!identical(_session, session)) return;
      debugPrint('[lecture] ${session.contentId} retiré du catalogue : arrêt');
      stop();
    }

    session.watches
      ..add(
        ref.container.listen<ContentView?>(
          teachingByIdProvider(session.contentId)
              .select((async) => async.value),
          onValue,
        ),
      )
      ..add(
        ref.container.listen<ContentView?>(
          gatheringByIdProvider(session.contentId)
              .select((async) => async.value),
          onValue,
        ),
      );
  }

  /// **`AppLifecycleState.paused`** — le fidèle éteint son écran. On enregistre,
  /// **sans arrêter** : couper ici serait couper un prêche dès qu'on range son
  /// téléphone dans sa poche.
  ///
  /// Posé au premier contenu suivi, et pas dans [build] : le contrôleur se
  /// construit aussi dans des conteneurs sans moteur Flutter, que l'antenne
  /// seule traverse.
  void _observeLifecycle() {
    if (_lifecycle != null) return;
    final observer = _AppPausedObserver(() => _session?.appPaused());
    WidgetsBinding.instance.addObserver(observer);
    _lifecycle = observer;
  }

  /// **Le contenu est arrêté ou remplacé** : l'ancien déclencheur « sortie
  /// d'écran ». La position s'écrit maintenant, tant que l'enregistreur tient
  /// encore la dernière que le lecteur lui a poussée.
  void _leaveSession() {
    final session = _session;
    if (session == null) return;
    _session = null;
    session.leave();
  }

  /// Démarre ou reprend la lecture.
  void play() => _player.play();

  /// Suspend la lecture en figeant la position.
  void pause() => _player.pause();

  /// Déplace la tête de lecture ; le lecteur la borne au média.
  void seek(Duration position) => _player.seek(position);

  /// Recule de [kContentSkipInterval] — le pas de la notification et de
  /// l'écran verrouillé, et aucun autre.
  ///
  /// Sans effet sur un direct, comme sur l'écran verrouillé : la fenêtre de
  /// l'antenne ne porte que quarante secondes de rattrapage.
  void skipBackward() => _skip(-kContentSkipInterval);

  /// Avance de [kContentSkipInterval]. Sans effet sur un direct.
  void skipForward() => _skip(kContentSkipInterval);

  void _skip(Duration delta) {
    if (state?.isLive ?? false) return;
    final player = _player;
    player.seek(player.value.position + delta);
  }

  /// **Relâche le média** : le son s'arrête, la notification disparaît, et la
  /// requête courante retombe à `null`.
  ///
  /// La position de reprise s'écrit **avant** que le lecteur ne relâche le
  /// média (#115) : c'est la croix du mini-lecteur, l'arrêt de l'antenne et la
  /// rétractation, et aucun de ces gestes ne doit faire perdre sa place.
  void stop() {
    _leaveSession();
    state = null;
    _player.stop();
  }

  /// **Rejoue depuis le début** — le geste de la fin de lecture.
  void replay() {
    final player = _player;
    player.seek(Duration.zero);
    player.play();
  }

  /// **Repart d'une panne à la position atteinte**, jamais du début : c'est la
  /// promesse du bouton « Reprendre » (#42).
  Future<void> resume() => _player.resume();

  /// **La seconde ligne de la notification**, par-dessus l'auteur — l'état
  /// d'une antenne qui se répare (#179). Voir [ContentPlayer.setStatusLine].
  void setStatusLine(String? line) => _player.setStatusLine(line);

  /// **Un statut à son commence : ce qui joue se tait** (#130, décision du
  /// 05/10/2026).
  ///
  /// Une annonce vocale ou vidéo par-dessus un prêche ou l'antenne, c'est deux
  /// voix à la fois : on n'entend ni l'une ni l'autre. Le lecteur principal se
  /// met donc en **pause** — pas en arrêt : la notification reste, la position
  /// aussi, et l'enregistreur de reprise écrit sur cette pause comme sur toute
  /// autre (#115).
  ///
  /// Sans effet quand rien ne joue — une lecture déjà en pause n'a pas à
  /// reprendre ensuite, et la relancer serait faire sortir du son que personne
  /// n'a demandé — et idempotent : chaque statut à son du même passage dans la
  /// visionneuse le rappelle, seule la première interruption compte.
  ///
  /// Un statut **sans son** (texte, image) n'appelle pas cette méthode : il
  /// n'interrompt rien. C'est l'écran qui en décide (`AnnouncementsScreen`).
  void interruptForStatus() {
    if (_interruptedByStatus != null) return;
    final playback = _player.value;
    final contentId = playback.contentId;
    if (contentId == null || !playback.isPlaying) return;
    _interruptedByStatus = (contentId: contentId, title: state?.title);
    _player.pause();
  }

  /// **La visionneuse se ferme : ce qu'elle a mis en pause reprend tout seul**
  /// (#130).
  ///
  /// - l'**antenne** reprend **au direct** : rouvrir la source, cookie
  ///   renégocié ([RadioListening.rejoinLive]). Un `play()` repartirait là où le
  ///   tampon s'est arrêté, en retard sur l'église — ou dans le vide, la
  ///   fenêtre de rattrapage ne portant que quarante secondes ;
  /// - un **enseignement** reprend **à sa position** : la pause l'y a laissé.
  ///
  /// Rien ne reprend si le lecteur ne tient plus ce qui a été interrompu
  /// (arrêté depuis la notification, ou remplacé), ni s'il joue déjà (relancé
  /// depuis l'écran verrouillé). Sans interruption en cours, sans effet.
  Future<void> resumeAfterStatus() async {
    final interrupted = _interruptedByStatus;
    _interruptedByStatus = null;
    if (interrupted == null || !ref.mounted) return;
    final playback = _player.value;
    if (playback.contentId != interrupted.contentId) return;
    if (playback.isPlaying) return;
    if (interrupted.contentId == RadioConfig.contentId) {
      await ref
          .read(radioListeningProvider.notifier)
          .rejoinLive(title: interrupted.title);
      return;
    }
    _player.play();
  }
}

/// **Le suivi d'un contenu chargé** : son enregistreur de progression et sa
/// mesure d'écoute, côte à côte et jamais l'un dans l'autre.
///
/// Deux champs, deux appels, aucun chemin de l'un vers l'autre : la reprise de
/// lecture est un confort personnel attaché à un compte, l'écoute comptée est
/// une statistique d'église, et les deux n'ont ni la même durée de vie ni le
/// même statut au regard du RGPD.
///
/// « Une écoute par ouverture » se lit désormais « une écoute par
/// chargement » : rejouer ou reprendre après une pause ne recompte pas, charger
/// de nouveau le même prêche, si.
class _ListeningSession {
  _ListeningSession({
    required this.contentId,
    this.recorder,
    this.contractDuration,
  });

  final String contentId;
  final PlaybackProgressRecorder? recorder;

  /// **La durée du contrat de synchronisation**, ou `null` en HLS (#222).
  ///
  /// Voir [ContentRequest.contractDuration] : sur un `.aac` téléchargé, la durée
  /// du lecteur n'est qu'une estimation, et l'enregistreur s'en sert pour
  /// trancher « terminé ». Une durée trop courte de 5 % marque un enseignement
  /// comme écouté six minutes avant la fin — au serveur, et durablement.
  final Duration? contractDuration;
  PlayTracker? tracker;

  /// Les abonnements au magasin, fermés avec la session.
  final List<ProviderSubscription<Object?>> watches = [];

  /// La dernière émission **de ce contenu** — de quoi reconnaître une pause et
  /// une fin comme des transitions, et non comme des états.
  ContentPlayback? _last;

  /// Vrai dès que le lecteur a émis ce contenu : avant, il tient encore le
  /// précédent, et ce n'est pas une raison de fermer.
  bool get reachedPlayer => _last != null;

  /// Où placer la tête de lecture après le chargement, `null` pour le début.
  ///
  /// Un contenu terminé se rouvre vraisemblablement pour être réécouté : il
  /// repart de zéro.
  Duration? get resumeAt {
    final resume = recorder?.resume;
    if (resume == null || resume.completed) return null;
    if (resume.position <= Duration.zero) return null;
    return resume.position;
  }

  /// **Le lecteur a émis.** La mesure d'abord, et avec sa propre garde.
  void follow(ContentPlayback next) {
    if (next.contentId != contentId) return;
    final previous = _last;
    _last = next;

    final tracker = this.tracker;
    if (tracker != null) {
      _fireAndForget(
        tracker.onPosition(next.position, isPlaying: next.isPlaying),
        label: 'mesure',
      );
    }

    final recorder = this.recorder;
    if (recorder == null) return;

    if (next.isCompleted && !(previous?.isCompleted ?? false)) {
      _fireAndForget(recorder.onTerminated());
      return;
    }

    _fireAndForget(
      recorder.onPosition(
        next.position,
        duration: contractDuration ?? next.duration,
        isPlaying: next.isPlaying,
      ),
    );
    if ((previous?.isPlaying ?? false) && !next.isPlaying) {
      _fireAndForget(recorder.onPaused());
    }
  }

  void appPaused() => _fireAndForget(recorder?.onAppPaused());

  /// Arrêté ou remplacé : on écrit, puis on cesse d'écouter le magasin.
  void leave() {
    close();
    _fireAndForget(recorder?.onLeft());
  }

  /// Cesse d'écouter le magasin, **sans rien écrire**.
  void close() {
    for (final watch in watches) {
      watch.close();
    }
    watches.clear();
  }

  static void _fireAndForget(
    Future<void>? work, {
    String label = 'progression',
  }) {
    if (work == null) return;
    unawaited(
      work.catchError((Object error) {
        debugPrint('[$label] déclencheur abandonné : $error');
      }),
    );
  }
}

/// Le seul passage du cycle de vie qui compte ici : l'écran qui s'éteint.
///
/// Un `WidgetsBindingObserver` plutôt qu'un `AppLifecycleListener` : celui-ci
/// vérifie l'enchaînement des états et refuse un `inactive → paused` direct,
/// que certains appareils — et les tests — produisent.
class _AppPausedObserver with WidgetsBindingObserver {
  _AppPausedObserver(this.onPaused);

  final VoidCallback onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) onPaused();
  }
}
