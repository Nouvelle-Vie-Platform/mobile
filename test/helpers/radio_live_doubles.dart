/// Doubles de **la page live de la radio** (#135) : un canal qu'on pilote à la
/// main, et des routes qui notent ce qu'on leur demande.
library;

import 'dart:async';
import 'dart:collection';

import 'package:maison_du_miracle/data/radio/radio_channel.dart';
import 'package:maison_du_miracle/data/radio/radio_live.dart';
import 'package:maison_du_miracle/data/radio/radio_live_repository.dart';

/// **Un canal qu'on ouvre, alimente et coupe à la main.**
///
/// Il ne s'ouvre **jamais tout seul** : un test dit quand la connexion réussit
/// ([open]), ce qu'elle porte ([emit]) et quand elle tombe ([drop]). C'est ce
/// qui permet de prouver « la reconnexion relit » sans réseau.
class ControllableRadioChannel implements RadioChannel {
  /// Chaque ouverture demandée, avec son drapeau de modération.
  final List<bool> watches = [];

  /// Combien de connexions ont été rendues (abonnement annulé).
  int cancels = 0;

  StreamController<RadioChannelEvent>? _current;

  /// Une connexion est tenue en ce moment.
  bool get isOpen => _current != null;

  @override
  Stream<RadioChannelEvent> watch({required bool moderation}) {
    watches.add(moderation);
    late final StreamController<RadioChannelEvent> controller;
    controller = StreamController<RadioChannelEvent>(
      onCancel: () {
        cancels++;
        if (identical(_current, controller)) _current = null;
      },
    );
    _current = controller;
    return controller.stream;
  }

  /// La connexion réussit : l'abonnement est accepté.
  void open({bool moderation = false}) =>
      emit(RadioChannelOpened(moderation: moderation));

  void emit(RadioChannelEvent event) => _current?.add(event);

  /// La connexion tombe (redéploiement, réseau).
  Future<void> drop() async {
    final current = _current;
    _current = null;
    await current?.close();
  }

  /// L'abonnement est refusé.
  void refuse() => _current?.addError(const RadioChannelRefused(403));
}

/// **Des routes qui répondent ce qu'on leur dit et notent tout.**
class RecordingRadioLiveRepository implements RadioLiveRepository {
  RecordingRadioLiveRepository({
    RadioThread thread = RadioThread.closed,
    this.queue = RadioModerationQueue.empty,
  }) : threadValue = thread;

  /// Ce que rend la prochaine lecture du fil — modifiable en cours de test,
  /// pour qu'une relecture rende autre chose que la première.
  RadioThread threadValue;
  RadioModerationQueue queue;

  int threadReads = 0;
  int queueReads = 0;
  final List<RadioReaction> reactions = [];
  final List<String> posted = [];
  final List<String> pseudonyms = [];
  final List<String> reports = [];
  final List<String> moderation = [];

  /// Les réponses programmées des envois, dans l'ordre : une
  /// [RadioLiveException] est levée, sinon un commentaire est rendu.
  final Queue<Object> postResults = Queue();

  /// Idem pour les signalements et les réactions.
  final Queue<Object> reportResults = Queue();
  Object? reactionError;
  Object? pseudonymError;
  Object? moderationError;

  /// Le prochain identifiant de commentaire rendu par un envoi réussi.
  int _next = 0;

  @override
  Future<RadioThread> thread() async {
    threadReads++;
    return threadValue;
  }

  @override
  Future<void> react(RadioReaction reaction) async {
    reactions.add(reaction);
    final error = reactionError;
    if (error != null) throw error;
  }

  @override
  Future<RadioComment> postComment(String body) async {
    posted.add(body);
    if (postResults.isNotEmpty) {
      final result = postResults.removeFirst();
      if (result is RadioLiveException) throw result;
      if (result is RadioComment) return result;
    }
    return RadioComment(
      id: 'posted-${_next++}',
      body: body,
      createdAt: DateTime.utc(2026, 10, 5, 18, 5),
      authorKind: RadioAuthorKind.guest,
      authorName: pseudonyms.isEmpty ? 'Moi' : pseudonyms.last,
    );
  }

  @override
  Future<String> savePseudonym(String pseudonym) async {
    pseudonyms.add(pseudonym);
    final error = pseudonymError;
    if (error != null) throw error;
    return pseudonym;
  }

  @override
  Future<void> report(String commentId) async {
    reports.add(commentId);
    if (reportResults.isNotEmpty) {
      final result = reportResults.removeFirst();
      if (result is RadioLiveException) throw result;
    }
  }

  @override
  Future<RadioModerationQueue> moderationQueue() async {
    queueReads++;
    return queue;
  }

  Future<void> _moderate(String action, String id) async {
    moderation.add('$action:$id');
    final error = moderationError;
    if (error != null) throw error;
  }

  @override
  Future<void> hide(String commentId) => _moderate('hide', commentId);

  @override
  Future<void> keep(String commentId) => _moderate('keep', commentId);

  @override
  Future<void> silence(String commentId) => _moderate('silence', commentId);

  @override
  Future<void> resetPseudonym(String commentId) =>
      _moderate('reset-pseudonym', commentId);
}

/// Un direct ouvert à 18 h.
final RadioLive kTestLive = RadioLive(startedAt: DateTime.utc(2026, 10, 5, 18));

/// Un commentaire de test.
RadioComment testComment(
  String id,
  String body, {
  String name = 'Ama K.',
  RadioAuthorKind kind = RadioAuthorKind.member,
}) =>
    RadioComment(
      id: id,
      body: body,
      createdAt: DateTime.utc(2026, 10, 5, 18, 2),
      authorKind: kind,
      authorName: name,
    );

/// Les refus du serveur, sous la forme que le repository lève.
const RadioLiveException kPseudonymRequired =
    RadioLiveException(RadioLiveRefusal.pseudonymRequired, status: 403);
const RadioLiveException kSilenced =
    RadioLiveException(RadioLiveRefusal.silenced, status: 403);
const RadioLiveException kClosed =
    RadioLiveException(RadioLiveRefusal.closed, status: 409);
const RadioLiveException kThrottled =
    RadioLiveException(RadioLiveRefusal.throttled, status: 429);
