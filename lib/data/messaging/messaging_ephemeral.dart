/// **« écrit… » et « en ligne / vu à » — en mémoire, jamais dans le magasin**
/// (#142, tranche M3).
///
/// Le plan (§4) est net : frappe et présence sont **éphémères**. Le serveur ne
/// les stocke pas, la synchronisation ne les sert pas, et ce client ne les range
/// pas non plus : elles vivent ici, le temps de la session, et s'effacent
/// seules.
///
/// - **La frappe** expire seule au bout de [kTypingVisibleFor] ; un nouveau
///   signal la prolonge, un message reçu de la même personne l'éteint.
/// - **La présence** est remplacée par chaque `presence.changed`, et lue à
///   l'ouverture d'un tête-à-tête (`GET /groups/:id/presence`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'messaging_channel.dart';

/// Combien de temps un « écrit… » reste affiché sans nouveau signal. Le
/// client qui écrit en renvoie un toutes les [kTypingSendInterval] : la marge
/// absorbe un signal en retard sans faire clignoter l'en-tête.
const Duration kTypingVisibleFor = Duration(seconds: 5);

/// L'intervalle entre deux « j'écris » envoyés pendant la frappe.
const Duration kTypingSendInterval = Duration(seconds: 3);

/// **L'état éphémère de la messagerie**, immuable.
@immutable
class MessagingEphemeralState {
  const MessagingEphemeralState({
    this.typing = const {},
    this.presence = const {},
  });

  /// Par groupe : qui écrit en ce moment (dans l'ordre d'arrivée).
  final Map<String, List<String>> typing;

  /// Par personne : sa dernière présence connue.
  final Map<String, MessagingPresenceEvent> presence;

  /// Qui écrit dans [groupId], [me] exclu.
  List<String> typingIn(String groupId, {String? me}) => [
        for (final userId in typing[groupId] ?? const <String>[])
          if (userId != me) userId,
      ];
}

/// **Tient l'état éphémère** et le fait expirer. Une classe nue, sans
/// Riverpod : les tests la conduisent avec `fake_async`, et le provider
/// (`messagingEphemeralProvider`) la publie.
class MessagingEphemeralStore extends ChangeNotifier {
  MessagingEphemeralStore({this.typingVisibleFor = kTypingVisibleFor});

  final Duration typingVisibleFor;

  MessagingEphemeralState _state = const MessagingEphemeralState();
  final Map<String, Timer> _expiries = {};
  bool _disposed = false;

  MessagingEphemeralState get state => _state;

  /// Remet un signal du canal : frappe, présence, ou ligne rangée (un message
  /// d'un autre éteint sa frappe).
  void apply(MessagingEvent event) {
    switch (event) {
      case MessagingTypingEvent(:final groupId, :final userId):
        typingStarted(groupId, userId);
      case final MessagingPresenceEvent presence:
        presenceChanged(presence);
      case MessagingRowEvent(:final type, :final row)
          when type == 'message.created':
        final groupId = row['groupId'];
        final authorId = row['authorId'];
        if (groupId is String && authorId is String) {
          typingStopped(groupId, authorId);
        }
      default:
        break;
    }
  }

  /// [userId] écrit dans [groupId] — affiché [typingVisibleFor], puis oublié.
  void typingStarted(String groupId, String userId) {
    final key = '$groupId|$userId';
    _expiries.remove(key)?.cancel();
    _expiries[key] =
        Timer(typingVisibleFor, () => typingStopped(groupId, userId));

    final current = _state.typing[groupId] ?? const <String>[];
    if (current.contains(userId)) return;
    _set(
      MessagingEphemeralState(
        typing: {
          ..._state.typing,
          groupId: [...current, userId],
        },
        presence: _state.presence,
      ),
    );
  }

  /// [userId] n'écrit plus dans [groupId] (expiration, ou son message arrivé).
  void typingStopped(String groupId, String userId) {
    _expiries.remove('$groupId|$userId')?.cancel();
    final current = _state.typing[groupId];
    if (current == null || !current.contains(userId)) return;
    final rest = [...current]..remove(userId);
    final typing = {..._state.typing};
    if (rest.isEmpty) {
      typing.remove(groupId);
    } else {
      typing[groupId] = rest;
    }
    _set(MessagingEphemeralState(typing: typing, presence: _state.presence));
  }

  /// La présence de quelqu'un vient de changer (ou vient d'être lue).
  void presenceChanged(MessagingPresenceEvent presence) {
    _set(
      MessagingEphemeralState(
        typing: _state.typing,
        presence: {..._state.presence, presence.userId: presence},
      ),
    );
  }

  /// **Oublie toutes les présences** — mes réglages ont changé : ce que je
  /// pouvais voir n'est plus forcément ce que je peux voir. Les en-têtes ouverts
  /// relisent la leur.
  void forgetPresence() {
    if (_state.presence.isEmpty) return;
    _set(MessagingEphemeralState(typing: _state.typing));
  }

  void _set(MessagingEphemeralState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _expiries.values) {
      timer.cancel();
    }
    _expiries.clear();
    super.dispose();
  }
}

/// **Envoie « j'écris » à intervalle borné** pendant la frappe (#142).
///
/// Le champ appelle [onTextChanged] à chaque frappe ; au plus un signal part
/// toutes les [interval]. Un champ vidé n'envoie rien. Le serveur borne
/// lui aussi (2 s), et ne stocke rien.
class TypingSignaler {
  TypingSignaler({
    required Future<void> Function() send,
    this.interval = kTypingSendInterval,
    DateTime Function()? now,
  })  : _send = send,
        _now = now ?? DateTime.now;

  final Future<void> Function() _send;
  final Duration interval;
  final DateTime Function() _now;

  DateTime? _lastSent;

  /// Le texte du champ vient de changer.
  void onTextChanged(String text) {
    if (text.trim().isEmpty) return;
    final now = _now();
    final last = _lastSent;
    if (last != null && now.difference(last) < interval) return;
    _lastSent = now;
    unawaited(_send().catchError((Object _) {}));
  }

  /// Le message vient de partir : la prochaine frappe signale aussitôt.
  void reset() => _lastSent = null;
}
