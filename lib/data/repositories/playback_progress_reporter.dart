import 'package:flutter/foundation.dart';

/// **Ce qui part au serveur**, et rien d'autre.
///
/// Trois champs sur le fil (`id`, `positionSeconds`, `completed`), plus
/// l'identifiant du contenu, qui voyage dans le **chemin** de la route et non
/// dans le corps.
@immutable
class PlaybackProgressReport {
  const PlaybackProgressReport({
    required this.contentId,
    required this.progressId,
    required this.positionSeconds,
    required this.completed,
  });

  /// L'enseignement **ou le rassemblement** écouté : les deux familles sont la
  /// même table côté serveur, discriminée par `family`, et passent donc par la
  /// même route. Il occupe le `:teachingId` du chemin.
  final String contentId;

  /// L'**UUIDv7 fabriqué par le client** (ADR-0001/0018), conservé par le
  /// serveur à l'insert. C'est lui qui rend le rapport rejouable : un rejeu
  /// retombe sur la même ligne au lieu d'en créer une seconde.
  final String progressId;

  final int positionSeconds;

  /// Décidé **ici**, jamais par le serveur : il n'a de durée nulle part, donc
  /// pas de dénominateur. Voir `playback_progress_recorder.dart`.
  final bool completed;
}

/// **Le rapporteur de progression** — il poste, et c'est tout.
///
/// Séparé du DAO de lecture pour la même raison qu'`AnnouncementComposer` est
/// séparé d'`AnnouncementRepository` (CLAUDE.md, § « L'écriture (#36) ») : deux
/// sources, deux formes, deux régimes hors-ligne. Le DAO lit un magasin local
/// et marche en avion ; celui-ci parle au réseau et n'y arrive pas toujours.
///
/// **Il ne touche pas au magasin.** Après un rapport réussi il ne réécrit rien :
/// c'est le flux delta qui ramènera la ligne dans `playback_progress`. Le
/// réseau ne peint jamais (ADR-0026).
///
/// **Il est muet.** Aucune implémentation ne lève : hors ligne, 401, 409, 5xx —
/// rien ne s'affiche, rien ne bloque l'écoute, et l'échec se retente au
/// déclencheur suivant. Une progression perdue est un désagrément ; une erreur
/// affichée pendant un prêche est une panne.
///
/// **Muet ne veut pas dire aveugle.** [report] rend un booléen — *parti* ou
/// *pas parti* — et c'est la seule chose que l'appelant apprend d'un échec :
/// ni le code HTTP, ni le message, ni de quoi composer une phrase à l'écran.
/// Sans ce booléen, l'enregistreur croirait avoir informé le serveur et
/// n'aurait aucune raison de retenter : un fidèle qui met en pause hors ligne,
/// puis retrouve du réseau sans toucher à rien, perdrait sa position sans que
/// rien ne le signale.
abstract interface class PlaybackProgressReporter {
  /// Rapporte une position. Ne lève **jamais**.
  ///
  /// Rend `true` si le serveur a pris le rapport, `false` s'il s'est perdu —
  /// auquel cas le déclencheur suivant retentera.
  Future<bool> report(PlaybackProgressReport report);
}
