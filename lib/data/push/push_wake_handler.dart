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
/// ## Pourquoi l'application ouverte ne notifie pas
///
/// Les écrans lisent le magasin, qu'un cycle vient de remplir : la conversation se
/// réordonne et le fil s'allonge sous les yeux du fidèle, sans qu'une bannière
/// vienne par-dessus l'écran qu'il regarde. L'immédiateté d'un fil **ouvert** est le
/// sujet du temps réel SSE (#101), pas celui du push.
library;

import 'package:flutter/foundation.dart';

import '../local/group_dao.dart';
import 'push_wake.dart';
import 'wake_notifier.dart';

/// Lit le magasin pour un identifiant de message. `null` = le magasin ne l'a pas.
///
/// Une fonction et non le DAO lui-même : c'est ce qui permet au handler de ne rien
/// savoir de Drift, et aux tests d'exercer les deux cas — ligne présente, ligne
/// absente — en une ligne. Le câblage réel passe par `GroupDao.announcementFor`.
typedef AnnouncementLookup = Future<MessageAnnouncement?> Function(
    String messageId);

/// Tire les collections nommées. Ne lève pas : un cycle raté laisse le magasin en
/// l'état, comme partout ailleurs dans ce dépôt.
typedef TargetedSync = Future<void> Function(Set<String> collections);

class PushWakeHandler {
  PushWakeHandler({
    required TargetedSync synchronize,
    required AnnouncementLookup announcement,
    required WakeNotifier notifier,
  })  : _synchronize = synchronize,
        _announcement = announcement,
        _notifier = notifier;

  final TargetedSync _synchronize;
  final AnnouncementLookup _announcement;
  final WakeNotifier _notifier;

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
      case GroupMessageWake(:final messageId):
        await _announce(messageId);
    }
  }

  Future<void> _announce(String messageId) async {
    final MessageAnnouncement? stored;
    try {
      stored = await _announcement(messageId);
    } on Object catch (error) {
      _trace('lecture du magasin impossible : $error');
      return;
    }

    // **Pas de ligne, pas de notification.** Le cas est normal et fréquent : le
    // cycle a échoué, ou la modération a retiré le message entre l'envoi du push et
    // le tirage. Annoncer quand même — « Nouveau message » — serait affirmer sur la
    // seule foi du push l'existence de quelque chose que la base ne porte pas, donc
    // exactement l'inverse d'ADR-0006 ; et le tap ouvrirait un fil où le fidèle ne
    // trouverait rien.
    if (stored == null) {
      _trace('message $messageId absent du magasin — rien à annoncer');
      return;
    }

    final notification = announcementNotification(stored);
    if (notification == null) return;
    await _notifier.show(notification);
  }

  void _trace(String message) {
    assert(() {
      debugPrint('[push] $message');
      return true;
    }());
  }
}
