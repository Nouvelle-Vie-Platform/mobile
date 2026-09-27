/// **La fusion de la progression à l'ouverture d'une session de membre** — ce
/// qu'un invité a écouté rejoint son compte, et la position la plus **avancée**
/// gagne.
///
/// ## La décision du client, et les deux qu'elle a écartées
///
/// Un invité qui écoute garde sa progression **en local seulement** : la
/// collection répliquée `playback_progress` est `private`, un porteur anonyme n'y
/// a pas de ligne. À la connexion, cette trace part vers le compte. En cas de
/// conflit sur un même enseignement, **la position la plus avancée gagne** :
///
/// - « la plus récente gagne » supposait une **horloge d'appareil de confiance**,
///   et une écoute invitée d'hier écraserait une écoute du compte faite la
///   semaine dernière sur un autre téléphone ;
/// - « le compte gagne toujours » perdait purement la reprise de l'invité.
///
/// « La plus avancée » ne fait **jamais reculer** une position, se dit en une
/// phrase, et ne demande **aucune horloge**. Contrepartie assumée : quelqu'un qui
/// recommence volontairement un enseignement se voit repoussé en avant.
///
/// C'est une règle **différente** de celle de la reprise (`PlaybackDao.resumeFor`
/// : la plus **récente** gagne), et les deux cohabitent exprès. La reprise
/// répond à « où remettre la tête de lecture maintenant », où renvoyer à la fin
/// quelqu'un qui réécoute serait la pire réponse ; la fusion répond à « que doit
/// savoir le compte », où perdre de l'avance est la pire réponse.
///
/// ## Qui arbitre le conflit — et sur quelle preuve
///
/// **Le client arbitre, parce que le serveur écrase sans comparer. Vérifié à la
/// source**, dans le dépôt du serveur (`server-portal`, qui sert l'API mobile) :
///
/// - `app/mediatheque/actions/report_playback_progress.ts` passe la position au
///   repository **telle quelle** (`payload: { teachingId, positionSeconds,
///   completed }`) : aucune comparaison, aucun `GREATEST` ;
/// - `app/shared/repositories/owned_content_repository.ts` (`upsertOwned`,
///   ADR-0018) insère si la ligne est absente, refuse en **409** si elle
///   appartient à quelqu'un d'autre, ne ressuscite pas un tombstone — et sinon
///   **écrit tout champ qui diffère**. Une position *inférieure* diffère : elle
///   est écrite. Le « no-op sémantique » de l'ADR ne protège que `created_at` et
///   le cas où rien n'a changé.
///
/// Donc : **la dernière écriture gagne, même en retard.** Une poussée aveugle
/// ferait reculer la reprise d'un membre — trente minutes écoutées sur un
/// téléphone ramenées à cinq par une écoute invitée sur un autre. Le même défaut
/// existe d'ailleurs déjà hors de cette tranche, entre deux appareils d'un même
/// membre : l'issue **#421** du dépôt serveur propose un upsert **monotone**
/// (maximum sur la position, `completed` collant) et, si elle est tenue, **tout
/// ce mécanisme de lecture préalable pourra fondre en une poussée aveugle**.
/// Tant qu'elle ne l'est pas, ne pas lire avant de pousser abîme une donnée.
/// (L'issue porte aussi la réserve inverse : un maximum monotone interdit la
/// reprise **volontaire** depuis le début.)
///
/// Le corollaire, moins visible : **`completed` n'est pas collant côté serveur
/// non plus** — envoyer `false` par-dessus un `true` l'effacerait. C'est la
/// seconde raison pour laquelle [verdictFor] ne pousse **jamais** quand le compte
/// a terminé.
///
/// On ne pousse donc que ce qui est plus avancé, et pour savoir ce que le compte
/// porte il n'existe qu'une lecture — `GET /sync/playback_progress`, c'est-à-dire
/// la collection répliquée du magasin. Il n'y a **aucun endpoint REST de
/// lecture** (CLAUDE.md, § reprise) : on ne peut pas demander « où en étais-je ? ».
///
/// D'où l'ordre imposé, et la seule chose de cette classe qui coûte du réseau
/// avant de décider :
///
/// 1. y a-t-il quelque chose en local ? Sinon on **s'arrête là**, sans un octet ;
/// 2. **un cycle de synchronisation qui soit entièrement postérieur à la
///    connexion** ([_pullAccountProgress]) ramène ce que le compte porte. Le
///    porteur vient de changer, la `scope_version` présentée est donc périmée et
///    le serveur réclame un resync de la partition `private` : c'est ce qui rend
///    la comparaison possible, et c'est aussi l'hypothèse la plus fragile de
///    cette tranche (elle tient au serveur, pas à ce code) ;
/// 3. le miroir n'est pas frais → **on ne pousse rien**. Ne rien faire perd une
///    commodité ; pousser à l'aveugle abîme une donnée.
///
/// ## Comment se marque ce qui a été transféré
///
/// **Par la collection répliquée elle-même, et par rien d'autre.** Aucune colonne
/// « déjà poussé » n'est ajoutée : une fois la position rangée par le serveur, le
/// flux delta ramène la ligne, le compte n'est plus en retard, et la fusion
/// suivante n'a plus rien à pousser pour ce contenu. Le marqueur *est* l'accusé
/// de réception, et il vient de la seule source qui fasse foi.
///
/// Ce que ça donne quand l'application est **tuée en plein transfert** : ce qui
/// est parti est parti (l'upsert est idempotent, le rejeu retombe sur la même
/// ligne), ce qui n'est pas parti reste dans la table locale et repart à la
/// prochaine ouverture de session. Entre la poussée et le retour du delta, une
/// connexion immédiate pourrait rejouer la **même** position sous le **même**
/// identifiant : c'est un no-op côté serveur, pas un doublon.
///
/// **Le seul déclencheur est l'ouverture d'une session, et c'est assumé** : voir
/// `AuthController._adoptLocalTrail`, qui dit ce qu'on paierait pour en ajouter
/// un au démarrage d'une session déjà en cache.
///
/// ## Le silence
///
/// Cette classe ne lève **jamais** et n'affiche **rien** : elle est appelée dans
/// la foulée d'une connexion, et une connexion doit aboutir même si la fusion
/// échoue. Le [PlaybackHandoverReport] rendu n'existe que pour le diagnostic et
/// les tests — aucun écran ne le lit.
library;

import 'package:flutter/foundation.dart';

import '../local/playback_dao.dart';
import 'playback_progress_reporter.dart';

/// **Ce que la fusion décide pour un contenu.** Trois issues, et aucune ne fait
/// reculer quoi que ce soit.
enum PlaybackMergeVerdict {
  /// La trace locale est plus avancée : elle part vers le compte.
  handOver,

  /// Le compte en sait plus : c'est la ligne **locale** qu'on relève — à la
  /// position du compte quand elle est devant, à son `completed` quand c'est lui
  /// qui l'apporte. Une ligne locale n'est jamais **abaissée** :
  /// [mergedPositionSeconds] est un maximum.
  raiseLocal,

  /// Les deux disent la même chose, ou le compte a déjà terminé ce contenu :
  /// rien à faire, et surtout rien à envoyer.
  agreed,
}

/// **La règle de conflit, écrite une seule fois.**
///
/// Pure, sans base ni réseau : c'est ce qui permet de la relire d'un bloc et de
/// la couvrir cas par cas. Les quatre refus de pousser sont aussi importants que
/// le cas qui pousse :
///
/// - le compte est **plus avancé** → on relève le local, on ne pousse pas. Sans
///   ce relèvement, la reprise de cet appareil resterait sur la position invitée
///   (`resumeFor` prend la plus **récente**, et la ligne locale vient d'être
///   écrite) — et le premier rapport du lecteur, lui, **écraserait** le compte
///   avec cette position en retard, puisque le serveur ne compare rien (voir
///   l'en-tête). Relever est donc ce qui ferme la porte par laquelle une position
///   pouvait reculer après la fusion ;
/// - le compte a **terminé** ce contenu → plus rien ne se rapporte, règle de
///   l'issue #43 (« une fois `completed`, la position n'est plus rapportée ») —
///   et rien ne doit lui renvoyer un `completed: false`, que son upsert
///   écrirait ;
/// - **la même seconde** des deux côtés → un upsert pour rien ;
/// - **position zéro** jamais commencée → un contenu ouvert puis refermé ne vaut
///   pas un aller-retour réseau.
PlaybackMergeVerdict verdictFor(PlaybackHandover candidate) {
  final account = candidate.accountPositionSeconds;

  if (account == null) {
    // Le compte ne connaît **rien** de ce contenu : tout ce qui est local est du
    // gain. Zéro seconde jamais commencée n'en est pas.
    final worthTelling =
        candidate.localPositionSeconds > 0 || candidate.localCompleted;
    return worthTelling
        ? PlaybackMergeVerdict.handOver
        : PlaybackMergeVerdict.agreed;
  }

  if (account > candidate.localPositionSeconds) {
    return PlaybackMergeVerdict.raiseLocal;
  }

  // Le compte a **terminé** : on ne rapporte plus ce contenu, quelle que soit la
  // position locale (règle #43). Il reste à adopter son `completed` ici, sans
  // toucher à la position locale, qui est devant ou à égalité.
  if (candidate.accountCompleted) {
    return candidate.localCompleted
        ? PlaybackMergeVerdict.agreed
        : PlaybackMergeVerdict.raiseLocal;
  }

  if (account < candidate.localPositionSeconds) {
    return PlaybackMergeVerdict.handOver;
  }

  // Même seconde : il ne reste que la complétion à transmettre.
  return candidate.localCompleted
      ? PlaybackMergeVerdict.handOver
      : PlaybackMergeVerdict.agreed;
}

/// **La position sur laquelle les deux tables s'accordent** : un maximum, jamais
/// autre chose. C'est cette fonction qui garantit que relever une ligne locale ne
/// puisse pas, par un chemin de travers, l'abaisser — le cas existe (un compte
/// qui a marqué « terminé » à une seconde plus basse que la position locale).
int mergedPositionSeconds(PlaybackHandover candidate) {
  final account = candidate.accountPositionSeconds ?? 0;
  return account > candidate.localPositionSeconds
      ? account
      : candidate.localPositionSeconds;
}

/// **`completed` est collant** : il ne se retire jamais, d'aucun côté. Un
/// enseignement tenu pour écouté ici et pas là-bas l'est après la fusion.
bool mergedCompleted(PlaybackHandover candidate) =>
    candidate.localCompleted || candidate.accountCompleted;

/// **Ce qu'une fusion a fait**, pour le diagnostic et les tests. Aucun écran ne
/// le lit — la fusion est muette.
@immutable
class PlaybackHandoverReport {
  const PlaybackHandoverReport({
    this.candidates = 0,
    this.accountIsFresh = false,
    this.handedOver = const [],
    this.raised = const [],
    this.deferred = const [],
  });

  /// Rien en local : la fusion s'arrête avant le réseau.
  static const PlaybackHandoverReport nothingToHandOver =
      PlaybackHandoverReport();

  /// Nombre de contenus examinés.
  final int candidates;

  /// La collection répliquée a-t-elle été rafraîchie **après** la connexion ?
  /// `false` = rien n'a été poussé, et c'est la bonne réponse : voir l'en-tête.
  final bool accountIsFresh;

  /// Les contenus dont la position est partie vers le compte.
  final List<String> handedOver;

  /// Les contenus dont la position **locale** a été relevée à celle du compte.
  final List<String> raised;

  /// Les contenus dont la poussée ne s'est pas faite (réseau) et qui repartiront
  /// à la prochaine ouverture de session.
  final List<String> deferred;
}

/// **Ce qui transfère la trace locale vers le compte.** Une interface, comme le
/// rapporteur : le mode maquette en a un double inerte, et l'ouverture de session
/// n'a pas à savoir lequel elle tient.
abstract interface class PlaybackProgressHandover {
  /// Ne lève **jamais**. Rend ce qu'elle a fait.
  Future<PlaybackHandoverReport> run();
}

/// La fusion adossée au **magasin** : deux tables lues, une seule écrite (la
/// locale), et le rapporteur pour tout le reste.
///
/// Elle n'écrit **jamais** dans `playback_progress` — la règle 4 du moteur de
/// synchronisation (CLAUDE.md) —, et elle n'a d'ailleurs aucun moyen de le
/// faire : `PlaybackDao` n'expose pas d'écriture vers la collection répliquée.
/// Ce que le serveur a pris redescend par le flux delta, comme tout le reste.
class StorePlaybackProgressHandover implements PlaybackProgressHandover {
  StorePlaybackProgressHandover({
    required PlaybackDao dao,
    required PlaybackProgressReporter reporter,
    required Future<bool> Function() pullAccountProgress,
  })  : _dao = dao,
        _reporter = reporter,
        _pullAccountProgress = pullAccountProgress;

  final PlaybackDao _dao;
  final PlaybackProgressReporter _reporter;

  /// **Ramène ce que le compte porte, et dit si c'est frais.** Injecté parce que
  /// cette couche n'a pas à connaître `SyncScheduler` — même raison que
  /// `BranchScope`, qui reçoit sa resynchronisation au lieu de l'importer.
  final Future<bool> Function() _pullAccountProgress;

  /// **La** fusion en vol, s'il y en a une. Deux ouvertures de session
  /// rapprochées (une connexion, puis une revalidation qui republie l'état)
  /// rejoignent la même au lieu de pousser deux fois les mêmes positions.
  Future<PlaybackHandoverReport>? _inFlight;

  @override
  Future<PlaybackHandoverReport> run() {
    final pending = _inFlight;
    if (pending != null) return pending;

    final started = _runOnce();
    _inFlight = started;
    return started.whenComplete(() {
      if (identical(_inFlight, started)) _inFlight = null;
    });
  }

  Future<PlaybackHandoverReport> _runOnce() async {
    try {
      // **Rien en local, rien à faire — et surtout aucun réseau.** C'est le cas
      // de la très grande majorité des connexions : quelqu'un qui n'a jamais
      // écouté en invité ne paie pas un octet pour cette tranche.
      if ((await _dao.handoverCandidates()).isEmpty) {
        return PlaybackHandoverReport.nothingToHandOver;
      }

      final fresh = await _pullAccountProgress();

      // Relu **après** le cycle : le tirage vient de changer la collection
      // répliquée, et ce sont ces positions-là qui arbitrent. Comparer aux
      // valeurs d'avant reviendrait à pousser contre un miroir périmé.
      final candidates = await _dao.handoverCandidates();

      if (!fresh) {
        // On ne sait pas ce que le compte porte, et le serveur écrirait ce qu'on
        // lui enverrait, même en retard (vérifié : voir l'en-tête). Ne rien
        // faire perd une commodité, pousser abîmerait la reprise. La fusion
        // repartira à la prochaine ouverture de session.
        return PlaybackHandoverReport(
          candidates: candidates.length,
          accountIsFresh: false,
        );
      }

      final handedOver = <String>[];
      final raised = <String>[];
      final deferred = <String>[];

      for (final candidate in candidates) {
        await _apply(candidate, handedOver, raised, deferred);
      }

      return PlaybackHandoverReport(
        candidates: candidates.length,
        accountIsFresh: true,
        handedOver: List.unmodifiable(handedOver),
        raised: List.unmodifiable(raised),
        deferred: List.unmodifiable(deferred),
      );
    } catch (error, stack) {
      // Muette à l'écran, visible au diagnostic — comme le rapport de
      // progression. Une connexion ne peut pas échouer parce qu'une commodité a
      // échoué.
      debugPrint('[progression] fusion abandonnée : $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
      return PlaybackHandoverReport.nothingToHandOver;
    }
  }

  /// Un contenu, une décision. Le `try` est par contenu exprès : une ligne
  /// bancale ne doit pas retenir les suivantes.
  Future<void> _apply(
    PlaybackHandover candidate,
    List<String> handedOver,
    List<String> raised,
    List<String> deferred,
  ) async {
    try {
      switch (verdictFor(candidate)) {
        case PlaybackMergeVerdict.agreed:
          return;

        case PlaybackMergeVerdict.raiseLocal:
          // Ce que le compte sait descend dans la table locale, **sous l'identité
          // du compte** : à partir de là les deux tables disent la même chose, le
          // lecteur reprendra là où le compte en était, et son premier rapport ne
          // ramènera pas le compte en arrière. La position écrite est un maximum
          // ([mergedPositionSeconds]) : ce chemin ne peut pas abaisser une ligne
          // locale.
          await _dao.saveLocalPosition(
            contentId: candidate.contentId,
            progressId: candidate.progressId,
            positionSeconds: mergedPositionSeconds(candidate),
            completed: mergedCompleted(candidate),
          );
          raised.add(candidate.contentId);

        case PlaybackMergeVerdict.handOver:
          final delivered = await _reporter.report(
            PlaybackProgressReport(
              contentId: candidate.contentId,
              progressId: candidate.progressId,
              positionSeconds: candidate.localPositionSeconds,
              completed: candidate.localCompleted,
            ),
          );
          // **Rien n'est réécrit localement après une poussée réussie** : le
          // réseau ne peint jamais, et c'est le flux delta qui ramènera la
          // ligne — laquelle devient du même coup la marque de ce qui est
          // transféré.
          (delivered ? handedOver : deferred).add(candidate.contentId);
      }
    } catch (error) {
      // Le rapporteur est muet par contrat ; ceci est la seconde ceinture, celle
      // qui couvre une erreur de programmation.
      debugPrint(
        '[progression] fusion ignorée pour ${candidate.contentId} : $error',
      );
      deferred.add(candidate.contentId);
    }
  }
}

/// Fusion **inerte** : elle ne lit rien, n'envoie rien, n'écrit rien.
///
/// Le défaut du mode maquette (`AppEnv.useBackend == false`), pour la raison qui
/// vaut déjà pour le rapporteur et le miroir de branche : sans serveur il n'y a
/// pas de compte où transférer quoi que ce soit, et ouvrir le magasin ou une
/// socket pour l'apprendre laisserait une base sur le disque et une minuterie de
/// Dio derrière elle.
class InertPlaybackProgressHandover implements PlaybackProgressHandover {
  const InertPlaybackProgressHandover();

  @override
  Future<PlaybackHandoverReport> run() async =>
      PlaybackHandoverReport.nothingToHandOver;
}
