import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../local/playback_dao.dart';
import 'playback_progress_reporter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Les trois constantes de la politique de rapport — **écrites ici et nulle part
// ailleurs**. Chacune est une valeur de produit, pas un détail d'implémentation.
// ─────────────────────────────────────────────────────────────────────────────

/// **Le seuil de « terminé ».** Un contenu compte pour écouté quand il reste
/// moins que ça à entendre.
///
/// ⚠️ **Valeur à confirmer.** Le serveur ne peut pas trancher — il n'a de durée
/// nulle part, ni sur `teachings` ni sur `playback_progress` —, la décision est
/// donc entièrement ici, et elle n'a pas encore été validée par le produit
/// (question ouverte 1 de l'issue #43).
///
/// Trente secondes plutôt qu'un pourcentage : un pourcentage traite un
/// témoignage de six minutes et un culte de deux heures de la même façon, alors
/// que la queue d'un enregistrement — bénédiction finale, annonces, silence —
/// dure à peu près le même temps dans les deux cas.
///
/// Le seuil ne s'applique **jamais** sur une durée inconnue ou aberrante : voir
/// [readsAsCompleted]. Mieux vaut sous-déclarer que faire disparaître de la
/// liste « à reprendre » un prêche dont quelqu'un n'a entendu que dix minutes.
const Duration kPlaybackCompletionSlack = Duration(seconds: 30);

/// **Le pas du rapport périodique, en temps _joué_** — pas en temps écoulé.
///
/// La nuance est tout l'intérêt de la règle : une pause de dix minutes ne doit
/// pas produire vingt rapports identiques. Le temps joué se mesure sur
/// l'avancée de la tête de lecture, jamais sur une horloge — il n'y a donc
/// aucun `Timer` dans ce fichier, et le rythme appartient au lecteur.
const Duration kPlaybackReportInterval = Duration(seconds: 30);

/// **Le déplacement minimal** en deçà duquel un rapport périodique n'est pas
/// envoyé, même après trente secondes de temps joué.
///
/// Second garde-fou du précédent : allumer la radio d'un téléphone sur une
/// connexion facturée pour apprendre au serveur ce qu'il sait déjà à cinq
/// secondes près n'apporte rien à personne.
const Duration kPlaybackReportMinimumDelta = Duration(seconds: 5);

/// **Un contenu est-il terminé à cette position ?**
///
/// Trois refus avant le seuil, et ils comptent plus que le seuil lui-même :
///
/// - **durée inconnue** (`null`) — c'est le cas courant, pas l'exception : en
///   HLS sur iOS, `duration` est peu fiable et souvent nulle (bogue amont
///   ouvert depuis 2022) ;
/// - **durée nulle ou négative** — aberrante ;
/// - **durée inférieure au seuil** — un extrait de vingt secondes serait
///   « terminé » dès la première image, la soustraction passant sous zéro.
///
/// Dans ces trois cas, seul l'**état terminal du lecteur** peut marquer le
/// contenu comme écouté ([PlaybackProgressRecorder.onTerminated]) : c'est un
/// fait observé, pas une durée devinée.
bool readsAsCompleted({required Duration position, Duration? duration}) {
  if (duration == null) return false;
  if (duration <= kPlaybackCompletionSlack) return false;
  return position >= duration - kPlaybackCompletionSlack;
}

/// **Les déclencheurs du rapport de progression, et rien d'autre.**
///
/// Un enregistreur par ouverture de contenu. Il ne joue rien, ne dessine rien,
/// n'a pas d'horloge : le lecteur lui **pousse** sa position ([onPosition]) et
/// ses événements, il décide quoi écrire et quand parler au serveur. C'est ce
/// qui le rend pilotable depuis un test sans moteur audio — et c'est le même
/// partage que `StatusPlayer` a posé : *l'horloge appartient au lecteur, jamais
/// au widget*.
///
/// ## Deux régimes, et c'est la clé du fichier
///
/// - **L'écriture locale est continue et gratuite.** Chaque seconde entière
///   franchie remplace la ligne de `local_playback_positions`. C'est elle qui
///   sauve la place d'un fidèle dont le système tue l'application, et elle
///   n'attend aucun réseau.
/// - **L'appel réseau est espacé.** Cinq déclencheurs, jamais un sondage :
///
///   | Déclencheur | Méthode |
///   |---|---|
///   | pause | [onPaused] |
///   | sortie de l'écran | [onLeft] |
///   | complétion | [onTerminated], ou le seuil atteint dans [onPosition] |
///   | ~30 s de temps **joué** et plus de 5 s de déplacement | [onPosition] |
///   | `AppLifecycleState.paused` | [onAppPaused] — **sans arrêter la lecture** |
///
/// ## Le silence
///
/// Aucun de ces chemins ne lève. Le [PlaybackProgressReporter] est muet par
/// contrat, et cet objet s'en protège une seconde fois : une erreur de
/// programmation dans le rapport ne doit pas interrompre un prêche. L'échec se
/// retente au déclencheur suivant.
class PlaybackProgressRecorder {
  PlaybackProgressRecorder._({
    required PlaybackDao dao,
    required PlaybackProgressReporter reporter,
    required this.contentId,
    required this.progressId,
    required this.resume,
    required Duration position,
    required bool completed,
    required int? savedSeconds,
    required int? reportedSeconds,
  })  : _dao = dao,
        _reporter = reporter,
        _position = position,
        _completed = completed,
        _savedSeconds = savedSeconds,
        _reportedSeconds = reportedSeconds;

  /// **Ouvre un contenu** : résout où reprendre, et sous quel identifiant
  /// rapporter.
  ///
  /// [mintId] n'existe que pour les tests — en production, un UUIDv7 frais.
  /// L'identifiant n'est frappé que si **aucune** des deux sources n'en connaît
  /// un : dès que le serveur a une ligne pour ce contenu, c'est la sienne qui
  /// fait autorité.
  static Future<PlaybackProgressRecorder> open({
    required PlaybackDao dao,
    required PlaybackProgressReporter reporter,
    required String contentId,
    String Function()? mintId,
  }) async {
    final resume = await dao.resumeFor(contentId);
    return PlaybackProgressRecorder._(
      dao: dao,
      reporter: reporter,
      contentId: contentId,
      progressId: resume?.progressId ?? (mintId ?? _mintUuidV7)(),
      resume: resume,
      position: resume?.position ?? Duration.zero,
      completed: resume?.completed ?? false,
      savedSeconds: resume?.positionSeconds,
      // Une reprise venue de la **synchronisation** est, par construction, une
      // position que le serveur connaît déjà : inutile de la lui réapprendre au
      // premier geste. Une reprise venue de la table locale, elle, n'a peut-être
      // jamais réussi à partir — d'où le nul, qui fait retenter tout de suite.
      reportedSeconds:
          resume != null && resume.source == PlaybackResumeSource.synced
              ? resume.positionSeconds
              : null,
    );
  }

  static String _mintUuidV7() => const Uuid().v7();

  final PlaybackDao _dao;
  final PlaybackProgressReporter _reporter;

  /// L'enseignement **ou le rassemblement** écouté.
  final String contentId;

  /// L'UUIDv7 sous lequel ce contenu se rapporte, pour toute la session.
  final String progressId;

  /// Où reprendre, `null` si ce contenu n'a jamais été écouté. C'est l'écran
  /// qui décide d'y aller ou non — un contenu déjà terminé se rouvre
  /// vraisemblablement pour être réécouté.
  final PlaybackResume? resume;

  Duration _position;
  Duration? _duration;
  bool _completed;

  /// Temps **joué** accumulé depuis le dernier rapport réussi.
  Duration _playedSinceReport = Duration.zero;

  /// Dernière seconde écrite localement, pour ne pas réécrire la même ligne
  /// vingt fois par seconde.
  int? _savedSeconds;

  /// Dernière position **rapportée avec succès**. Nulle tant que rien n'est
  /// parti — et elle ne bouge pas sur un échec, ce qui fait que le déclencheur
  /// suivant retente au lieu de considérer le serveur au courant.
  int? _reportedSeconds;

  /// Vrai dès que ce contenu est tenu pour écouté.
  bool get isCompleted => _completed;

  Duration get position => _position;

  /// **Le lecteur pousse sa position.** Appelé aussi souvent qu'il le veut.
  ///
  /// [duration] est celle que le moteur déclare, `null` tant qu'il l'ignore —
  /// ce qui est fréquent en HLS sur iOS, et n'a rien d'anormal.
  ///
  /// Le temps joué se mesure sur l'**avancée** de la tête de lecture pendant
  /// que ça joue. Un saut en avant compte donc comme du temps joué : c'est
  /// voulu, il provoque un rapport, et c'est exactement après un saut qu'on
  /// veut en envoyer un.
  Future<void> onPosition(
    Duration position, {
    Duration? duration,
    required bool isPlaying,
  }) async {
    final advanced = position - _position;
    _position = position;
    if (duration != null) _duration = duration;
    if (isPlaying && advanced > Duration.zero) _playedSinceReport += advanced;

    await _saveLocalIfSecondChanged();

    // Terminé : on continue d'écrire la position localement — un fidèle qui
    // réécoute doit retrouver sa place —, mais on ne rapporte plus. Le serveur
    // sait déjà ce qu'il avait à savoir de ce contenu.
    if (_completed) return;

    if (readsAsCompleted(position: position, duration: _duration)) {
      await _complete();
      return;
    }

    if (_playedSinceReport >= kPlaybackReportInterval && _movedEnough()) {
      await _report();
    }
  }

  /// **Pause.** La position est figée : c'est le moment d'en informer le
  /// serveur, quelle que soit la durée jouée depuis le dernier rapport.
  Future<void> onPaused() => _reportOnEvent();

  /// **Sortie de l'écran du lecteur.**
  Future<void> onLeft() => _reportOnEvent();

  /// **`AppLifecycleState.paused`** — le cas le **plus fréquent** : le fidèle
  /// éteint son écran. Il ne quitte pas, il écoute.
  ///
  /// Cette méthode ne touche donc **pas** à la lecture : elle rapporte, et
  /// c'est tout. Arrêter le son ici serait la panne la plus visible de tout ce
  /// lot — un prêche qui se coupe dès qu'on range son téléphone dans sa poche.
  Future<void> onAppPaused() => _reportOnEvent();

  /// **L'état terminal du lecteur** : la piste est allée au bout.
  ///
  /// C'est le seul chemin qui marque « terminé » sans durée fiable — un fait
  /// observé plutôt qu'une soustraction. Il reste vrai même si la durée est
  /// nulle, aberrante, ou plus courte que le seuil.
  ///
  /// Remettre le lecteur d'aplomb (`pause()` **et** `seek(zero)` : à l'état
  /// terminal `just_audio` reste `playing == true`, curseur en fin, sans son)
  /// appartient au lecteur, pas à cet objet — il n'en connaît aucun.
  Future<void> onTerminated() async {
    if (_completed) {
      await _saveLocal(completed: true);
      return;
    }
    await _complete();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rouages
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _reportOnEvent() async {
    await _saveLocal();
    if (_completed) return;
    if (!_movedEnough(sinceLastReport: true)) return;
    await _report();
  }

  Future<void> _complete() async {
    _completed = true;
    await _saveLocal(completed: true);
    await _report(completed: true);
  }

  /// Y a-t-il de quoi parler ?
  ///
  /// Sur le rapport **périodique**, la barre est [kPlaybackReportMinimumDelta] :
  /// trente secondes de temps joué peuvent s'accumuler sur place, à coups de
  /// va-et-vient d'une seconde.
  ///
  /// Sur un **événement** (pause, sortie, écran éteint), la barre est
  /// simplement « quelque chose a bougé » : les trois peuvent s'enchaîner en
  /// une fraction de seconde — on éteint l'écran, puis on quitte —, et trois
  /// requêtes identiques réveilleraient la radio pour un upsert que le serveur
  /// traiterait en no-op.
  bool _movedEnough({bool sinceLastReport = false}) {
    final reported = _reportedSeconds;
    if (reported == null) return true;
    final moved = (_position.inSeconds - reported).abs();
    return sinceLastReport
        ? moved > 0
        : moved > kPlaybackReportMinimumDelta.inSeconds;
  }

  Future<void> _saveLocalIfSecondChanged() async {
    if (_position.inSeconds == _savedSeconds) return;
    await _saveLocal();
  }

  Future<void> _saveLocal({bool? completed}) async {
    _savedSeconds = _position.inSeconds;
    await _dao.saveLocalPosition(
      contentId: contentId,
      progressId: progressId,
      positionSeconds: _position.inSeconds,
      completed: completed ?? _completed,
    );
  }

  /// **Le seul endroit qui parle au réseau**, et il ne laisse rien passer.
  ///
  /// Le rapporteur est muet par contrat ; ce `catch` est la seconde ceinture.
  /// Une erreur de programmation — un identifiant nul, un `StateError` — ne
  /// doit pas plus interrompre un prêche qu'une coupure réseau.
  Future<void> _report({bool? completed}) async {
    final seconds = _position.inSeconds;
    try {
      final delivered = await _reporter.report(
        PlaybackProgressReport(
          contentId: contentId,
          progressId: progressId,
          positionSeconds: seconds,
          completed: completed ?? _completed,
        ),
      );
      // Le compteur ne se remet à zéro que sur un rapport **parti**. Un échec
      // laisse donc le prochain déclencheur retenter tout de suite, au lieu de
      // croire le serveur au courant et de se taire jusqu'au prochain
      // déplacement.
      if (!delivered) return;
      _reportedSeconds = seconds;
      _playedSinceReport = Duration.zero;
    } catch (error, stack) {
      // Muet à l'écran, visible au diagnostic. Une progression perdue est un
      // désagrément ; une erreur affichée pendant un prêche est une panne.
      debugPrint('[progression] rapport abandonné pour $contentId : $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }
}
