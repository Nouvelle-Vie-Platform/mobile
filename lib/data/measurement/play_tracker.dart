/// **Quand une écoute est comptée** — la seule décision de ce dossier, et elle
/// est révocable.
///
/// Un traqueur par **ouverture de contenu** — un chargement dans le lecteur
/// global, ouvert par le contrôleur global (#115) quel que soit l'écran —,
/// exactement comme `PlaybackProgressRecorder` : il ne joue rien, ne dessine rien, n'a pas
/// d'horloge. Le lecteur lui **pousse** sa position, il décide s'il y a lieu de
/// parler au serveur.
///
/// ## Le moment retenu : trente secondes de temps **joué**
///
/// Trois candidats se présentaient, et le troisième est retenu :
///
/// 1. **à l'ouverture de la fiche** — écarté : depuis le changement de règle du
///    lecteur, ouvrir une fiche **ne joue plus** (seul le direct démarre seul).
///    Compter là compterait des coups d'œil ;
/// 2. **au démarrage réel de la lecture** — la tête de lecture avance pour la
///    première fois. Tenable, et c'est le repli si celle-ci ne plaît pas : il
///    suffit de ramener [kPlayCountThreshold] à zéro. Ce qu'on y perdrait : un
///    appui malheureux suivi d'un retour arrière compterait pour une écoute ;
/// 3. **un seuil d'écoute franchi** — [kPlayCountThreshold] de temps joué.
///    C'est ce qui est écrit ici. Une écoute est alors un fait observé (« ce
///    téléphone a rendu trente secondes de ce prêche ») et non une intention
///    devinée.
///
/// **Le temps joué, jamais le temps écoulé.** Une pause de dix minutes
/// n'avance rien. C'est la même mesure que `kPlaybackReportInterval`, et pour
/// la même raison : l'horloge appartient au lecteur, il n'y a **aucun `Timer`**
/// dans ce fichier.
///
/// **Un déplacement n'est pas une écoute.** Le rapport de progression compte
/// délibérément un saut en avant comme du temps joué — il *veut* rapporter
/// après un saut. Ici c'est l'inverse : tirer le curseur jusqu'à la fin ne doit
/// pas fabriquer une écoute. Une avancée supérieure à
/// [kPlayAdvanceTolerance] entre deux poussées est donc tenue pour un
/// **déplacement** et ne s'accumule pas. Le prix de cette règle est écrit plus
/// bas, sur la constante.
///
/// ## Une seule émission par ouverture
///
/// Le serveur déduplique déjà (au plus une par porteur, par contenu et par
/// jour, `counted: false` sur un rejeu), donc une émission de trop ne fausse
/// aucun chiffre. Elle coûte en revanche une requête, et une requête pendant
/// qu'un prêche joue se paie en batterie et en forfait. Le drapeau est posé
/// **avant** l'`await`, pas après : un échec ne se retente pas ici, il part en
/// file d'attente (`PlaySpool`). Sans cela, chaque poussée de position
/// suivante relancerait un appel qui vient d'échouer.
///
/// ## Rien de tout ceci ne touche la reprise de lecture
///
/// Ce fichier ne connaît ni `PlaybackDao`, ni `PlaybackProgressRecorder`, ni
/// `local_playback_positions`, ni `playback_progress`. Il n'a aucun moyen d'y
/// écrire, et c'est la forme que prend ici la séparation : elle n'est pas une
/// consigne, c'est une absence d'importation.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'play_reporter.dart';
import 'play_spool.dart';

/// **Le seuil au-delà duquel une ouverture devient une écoute.**
///
/// ⚠️ **Valeur à confirmer**, comme `kPlaybackCompletionSlack` : le produit n'a
/// pas tranché. Trente secondes est ce que font les plateformes d'écoute, et
/// c'est déjà le pas du rapport de progression de ce dépôt — deux mesures de
/// « il a vraiment écouté » qui se contrediraient seraient un piège pour la
/// personne qui lira les chiffres.
///
/// Ce que ce seuil fait perdre : une écoute **sincère mais courte** — vingt
/// secondes d'un témoignage — n'est pas comptée. Et une écoute interrompue par
/// une application tuée avant la trentième seconde n'est jamais émise, la file
/// d'attente ne recevant que ce qui a déjà été décidé.
const Duration kPlayCountThreshold = Duration(seconds: 30);

/// **Au-delà de quoi une avancée n'est plus de la lecture mais un saut.**
///
/// Le lecteur pousse sa position plusieurs fois par seconde ; deux poussées
/// consécutives séparées de plus de deux secondes ne décrivent pas une lecture
/// continue.
///
/// Ce que cette règle fait perdre : une lecture **réellement** continue dont
/// les poussées se sont espacées — application en arrière-plan, écran éteint
/// sur un appareil économe — voit son temps joué sous-compté, donc son écoute
/// déclarée plus tard, voire pas du tout. C'est un défaut assumé, et il va du
/// bon côté : la mesure sous-déclare, elle n'invente pas.
const Duration kPlayAdvanceTolerance = Duration(seconds: 2);

/// **Les déclencheurs de la remontée d'écoute, et rien d'autre.**
class PlayTracker {
  PlayTracker._({
    required PlayReporter reporter,
    required PlaySpool spool,
    required this.contentId,
    required Duration threshold,
  })  : _reporter = reporter,
        _spool = spool,
        _threshold = threshold;

  /// **Ouvre un contenu.**
  ///
  /// Profite du passage pour **vider la file d'attente** : les écoutes classées
  /// hors ligne repartent au moment où quelqu'un ouvre un contenu, c'est-à-dire
  /// au moment où l'on a le plus de chances d'avoir du réseau et où une requête
  /// de plus ne réveille aucune radio qui dormait.
  ///
  /// Ce n'est délibérément **pas** branché sur les déclencheurs de
  /// synchronisation : le moteur a une discipline (curseurs, resync, version de
  /// périmètre) dans laquelle une remontée d'audience n'a rien à faire, et un
  /// échec de télémétrie n'a pas à croiser un cycle de synchronisation.
  ///
  /// Ne lève **jamais**.
  static PlayTracker open({
    required PlayReporter reporter,
    required PlaySpool spool,
    required String contentId,
    Duration threshold = kPlayCountThreshold,
  }) {
    unawaited(
      spool.drain(reporter).catchError((Object error) {
        debugPrint('[mesure] drainage abandonné : $error');
        return 0;
      }),
    );
    return PlayTracker._(
      reporter: reporter,
      spool: spool,
      contentId: contentId,
      threshold: threshold,
    );
  }

  final PlayReporter _reporter;
  final PlaySpool _spool;
  final Duration _threshold;

  /// L'enseignement **ou le rassemblement** écouté.
  final String contentId;

  Duration _played = Duration.zero;
  Duration? _last;
  bool _emitted = false;

  /// Temps **joué** accumulé depuis l'ouverture, déplacements exclus.
  ///
  /// **Il s'arrête à l'émission**, et reste donc figé au seuil pour le reste de
  /// la session d'écoute. Ce n'est pas une remise à zéro : le compteur n'a plus
  /// de consommateur une fois l'écoute émise — sa seule question est « le seuil
  /// est-il franchi ? ». Continuer à l'alimenter ferait de l'arithmétique à
  /// chaque poussée de position pendant une heure de prêche, pour personne. Un
  /// échec ne le concerne pas davantage : l'événement part en file d'attente, et
  /// le rattrapage est un drainage, jamais un second franchissement.
  Duration get playedTime => _played;

  /// Vrai dès que l'écoute a été émise — **une fois par ouverture**, qu'elle
  /// soit partie ou qu'elle ait été classée.
  bool get emitted => _emitted;

  /// **Le lecteur pousse sa position.** Appelé aussi souvent qu'il le veut.
  ///
  /// Ne lève **jamais** : la télémétrie n'interrompt pas une écoute.
  Future<void> onPosition(Duration position, {required bool isPlaying}) async {
    final previous = _last;
    _last = position;

    if (_emitted) return;
    if (!isPlaying || previous == null) return;

    final advanced = position - previous;
    // Un retour en arrière, une position figée, ou un saut : rien de joué.
    if (advanced <= Duration.zero || advanced > kPlayAdvanceTolerance) return;

    _played += advanced;
    if (_played < _threshold) return;

    await _emit();
  }

  /// **Le seul endroit qui parle au réseau**, et il ne laisse rien passer.
  Future<void> _emit() async {
    // Posé **avant** l'`await` : « une seule fois par ouverture » porte sur
    // l'émission, pas sur son succès. Un échec part en file d'attente ; le
    // retenter ici rappellerait le serveur à chaque poussée de position.
    _emitted = true;
    try {
      if (await _reporter.report(contentId)) return;
      await _spool.add(contentId);
    } catch (error, stack) {
      debugPrint('[mesure] écoute abandonnée pour $contentId : $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }
}
