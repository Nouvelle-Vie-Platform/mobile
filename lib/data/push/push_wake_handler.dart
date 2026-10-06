/// **Ce que fait un réveil** : synchroniser, lire le magasin, annoncer ce que le
/// magasin contient. Dans cet ordre, et jamais autrement.
///
/// C'est la pièce sur laquelle toute la tranche se juge, et elle tient en une
/// règle : **la notification se dresse depuis le magasin, jamais depuis la charge
/// utile du push** (ADR-0006, PRD D6). Une notification écrite depuis la charge
/// utile afficherait un message qui n'est pas en base, et le tap ouvrirait un fil
/// qui ne le contient pas.
///
/// Trois raisons de n'avoir qu'**un** handler pour les deux chemins — application
/// ouverte et application fermée :
///
/// 1. la règle ci-dessus ne doit pas être écrite deux fois ;
/// 2. le chemin du fond n'est **pas** testable (il vit dans un autre isolate,
///    réveillé par Firebase). Celui-ci, lui, l'est entièrement : il ne connaît ni
///    Firebase, ni `flutter_local_notifications`, ni Drift — il prend une fonction
///    de synchronisation, une lecture et un notifieur ;
/// 3. ce qui diffère entre les deux chemins est **injecté**, jamais branché par un
///    drapeau. Au premier plan, le notifieur est inerte et la synchronisation est
///    celle du planificateur ; en fond, le notifieur est réel et la synchronisation
///    est un cycle **ciblé** sur un moteur neuf. Voir `push_background.dart` et
///    `app.dart`.
///
/// ## Depuis M5 : la notification d'une **conversation**, ses non-lus, la sourdine
///
/// Le réveil désigne un message ; la notification, elle, montre la
/// **conversation** — ses derniers non-lus, avec leurs auteurs
/// (`conversation_notification.dart`). Quatre règles s'ajoutent, toutes lues
/// dans le magasin après la synchronisation :
///
/// 1. **le message du réveil doit être un non-lu** de la conversation (ni le
///    mien, ni du serveur, ni déjà lu) — sinon rien ne sonne. C'est la règle
///    « pas de ligne en magasin, pas de notification » de #97, resserrée ;
/// 2. **la sourdine tait** : celle que le serveur a dite (`group_message_muted`)
///    comme celle que le magasin connaît ;
/// 3. **une conversation sans non-lu efface sa notification** : lue sur un autre
///    appareil, la synchronisation du réveil a ramené sa lecture
///    (`group_reads`), et il n'y a plus rien à montrer ;
/// 4. **le résumé suit** ([NotificationRefresher]).
///
/// ## Pourquoi l'application ouverte ne notifie pas
///
/// Les écrans lisent le magasin, qu'un cycle vient de remplir : la conversation se
/// réordonne et le fil s'allonge sous les yeux du fidèle, sans qu'une bannière
/// vienne par-dessus l'écran qu'il regarde. L'immédiateté d'un fil **ouvert** est le
/// sujet du temps réel SSE (#101), pas celui du push.
library;

import 'package:flutter/foundation.dart';

import '../local/group_dao.dart';
import 'conversation_notification.dart';
import 'push_wake.dart';
import 'wake_notifier.dart';

/// Tire les collections nommées. Ne lève pas : un cycle raté laisse le magasin en
/// l'état, comme partout ailleurs dans ce dépôt.
typedef TargetedSync = Future<void> Function(Set<String> collections);

/// **Ce que le réveil lit du magasin** — et rien d'autre. Une interface et non
/// le DAO : c'est ce qui permet au handler de ne rien savoir de Drift, et aux
/// tests de l'exercer sur un magasin en mémoire comme sur un double.
///
/// Le câblage réel est [StoreWakeStore].
abstract interface class WakeStore {
  /// La conversation à notifier, ou `null` (pas membre, inconnue, ou pas de
  /// compte sur ce téléphone).
  Future<ConversationDigest?> digest(String groupId);

  /// Mes conversations, pour le résumé et les notifications à effacer.
  Future<List<ConversationRecord>> conversations();

  /// Le réglage « Afficher le contenu ».
  Future<bool> showPreview();
}

/// [WakeStore] sur le magasin, pour **moi** ([userId]). Sans compte, il ne rend
/// rien : un appareil invité n'a pas de conversation.
///
/// [userId] est une **fonction**, lue au moment de chaque lecture : au premier
/// plan, la session peut changer entre deux réveils (et la lire à la
/// construction du handler forcerait la résolution de session pour un réveil
/// qu'on ne comprendra peut-être même pas).
class StoreWakeStore implements WakeStore {
  StoreWakeStore({
    required GroupDao groups,
    required Future<bool> Function() showPreview,
    required String? Function() userId,
  })  : _groups = groups,
        _showPreview = showPreview,
        _userId = userId;

  final GroupDao _groups;
  final Future<bool> Function() _showPreview;
  final String? Function() _userId;

  @override
  Future<ConversationDigest?> digest(String groupId) async {
    final me = _userId();
    if (me == null) return null;
    return _groups.conversationDigestOf(
      groupId,
      me,
      limit: kNotificationMessageLimit,
    );
  }

  @override
  Future<List<ConversationRecord>> conversations() async {
    final me = _userId();
    if (me == null) return const [];
    return _groups.conversationsOf(me).get();
  }

  @override
  Future<bool> showPreview() => _showPreview();
}

/// **Remet les notifications d'accord avec le magasin** : efface celles des
/// conversations qui n'ont plus de non-lu (lues ici ou ailleurs), et pose — ou
/// retire — le résumé.
///
/// Partagé par le réveil et par les actions de notification : les deux
/// changent ce qui est lu, et le résumé ne doit jamais annoncer ce qu'aucune
/// notification ne montre plus.
class NotificationRefresher {
  NotificationRefresher({
    required WakeStore store,
    required WakeNotifier notifier,
    required NotificationTexts texts,
    DateTime Function()? now,
  })  : _store = store,
        _notifier = notifier,
        _texts = texts,
        _now = now ?? DateTime.now;

  final WakeStore _store;
  final WakeNotifier _notifier;
  final NotificationTexts _texts;
  final DateTime Function() _now;

  /// Ne lève jamais.
  ///
  /// [repost] : remettre le résumé à jour s'il reste quelque chose à coiffer.
  /// Faux, on ne fait qu'**effacer** — le résumé n'est jamais posé par un
  /// réveil qui n'a rien montré (muet, déjà lu, message absent) : posé seul,
  /// sans notification de conversation sous lui, Android l'afficherait comme
  /// une notification à part entière, annonçant ce que plus rien ne montre.
  Future<void> refresh({bool repost = true}) async {
    try {
      final conversations = await _store.conversations();
      for (final conversation in conversations) {
        if (conversation.unreadCount == 0) {
          await _notifier.cancel(conversation.groupId);
        }
      }
      final summary = notificationSummary(
        conversations,
        texts: _texts,
        now: _now(),
      );
      if (summary == null) {
        await _notifier.cancelSummary();
      } else if (repost) {
        await _notifier.showSummary(summary);
      }
    } on Object catch (error) {
      _trace('résumé impossible : $error');
    }
  }
}

class PushWakeHandler {
  PushWakeHandler({
    required TargetedSync synchronize,
    required WakeStore store,
    required WakeNotifier notifier,
    required NotificationTexts texts,
    DateTime Function()? now,
  })  : _synchronize = synchronize,
        _store = store,
        _notifier = notifier,
        _texts = texts,
        _now = now ?? DateTime.now,
        _refresher = NotificationRefresher(
          store: store,
          notifier: notifier,
          texts: texts,
          now: now,
        );

  final TargetedSync _synchronize;
  final WakeStore _store;
  final WakeNotifier _notifier;
  final NotificationTexts _texts;
  final DateTime Function() _now;
  final NotificationRefresher _refresher;

  /// **Traite un bloc `data` de push.** Ne lève jamais.
  ///
  /// La carte brute entre ici et ne va pas plus loin : [readPushWake] n'en retient
  /// qu'un type et des identifiants, et [PushWake] n'a **aucun** champ de texte où
  /// un contenu pourrait se ranger. C'est structurel, pas une discipline à tenir.
  Future<void> handle(Map<String, Object?> data) async {
    final wake = readPushWake(data);
    if (wake == null) {
      // Type inconnu, ou réveil tronqué. Rien à faire — et surtout pas « au
      // mieux » : synchroniser tout le magasin sur un push qu'on ne comprend pas
      // réveillerait la radio d'un téléphone pour rien.
      return;
    }

    try {
      await _synchronize(wake.collections);
    } on Object catch (error) {
      // Le cycle a échoué (avion, 5xx). On continue quand même vers la lecture :
      // le magasin porte peut-être déjà le message, ramené par un cycle antérieur.
      // Ce qu'on n'a pas, on ne l'annoncera pas — c'est la suite qui le dit.
      _trace('synchronisation du réveil échouée : $error');
    }

    switch (wake) {
      case SyncNudgeWake():
        // Un nudge **pousse le moteur**, et c'est tout ce qu'il fait. L'UX de
        // réveil des domaines autres que les messages est hors périmètre (#97) :
        // la synchronisation ci-dessus est son effet entier.
        return;
      case GroupMessageWake():
        final shown = await _announce(wake);
        await _refresher.refresh(repost: shown);
    }
  }

  /// Rend `true` si une notification de conversation a été affichée.
  Future<bool> _announce(GroupMessageWake wake) async {
    final ConversationDigest? digest;
    try {
      digest = await _store.digest(wake.groupId);
    } on Object catch (error) {
      _trace('lecture du magasin impossible : $error');
      return false;
    }

    // Plus rien de non lu — lue ailleurs, ou le message a été retiré : la
    // notification, s'il y en avait une, n'a plus rien à dire.
    if (digest == null || digest.unreadCount == 0) {
      await _notifier.cancel(wake.groupId);
      return false;
    }

    // **Pas de ligne en magasin, pas de notification** — resserré depuis M5 :
    // le message du réveil doit être un **non-lu** de cette conversation. Un
    // message absent (cycle raté, modération entre l'envoi et le tirage), un
    // message du serveur (« X a rejoint le groupe »), un message déjà lu
    // ailleurs : rien ne sonne. Annoncer quand même serait affirmer sur la seule
    // foi du push ce que la base ne porte pas (ADR-0006).
    final announced =
        digest.messages.any((message) => message.id == wake.messageId);
    if (!announced) {
      _trace('message ${wake.messageId} hors des non-lus — rien à annoncer');
      return false;
    }

    // **La sourdine tait.** Celle que le serveur a dite à l'envoi, ou celle que
    // le magasin connaît — posée depuis ce téléphone et pas encore arrivée au
    // serveur, ou échue entre-temps (c'est alors le magasin qui a raison).
    if (wake.muted || digest.isMutedAt(_now())) {
      _trace('conversation ${wake.groupId} en sourdine — rien ne sonne');
      return false;
    }

    final bool showPreview;
    try {
      showPreview = await _store.showPreview();
    } on Object catch (error) {
      // Réglage illisible : on retombe sur le côté discret. Mieux vaut un
      // « Nouveau message » de trop qu'un texte montré contre la volonté de qui
      // avait demandé à le cacher.
      _trace('réglage d\'aperçu illisible : $error');
      return _show(digest, showPreview: false);
    }
    return _show(digest, showPreview: showPreview);
  }

  Future<bool> _show(
    ConversationDigest digest, {
    required bool showPreview,
  }) async {
    final notification = conversationNotification(
      digest,
      showPreview: showPreview,
      texts: _texts,
    );
    if (notification == null) return false;
    await _notifier.show(notification);
    return true;
  }
}

void _trace(String message) {
  assert(() {
    debugPrint('[push] $message');
    return true;
  }());
}
