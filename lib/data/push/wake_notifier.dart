/// **La notification locale d'un réveil** — dressée depuis le magasin, jamais
/// depuis la charge utile du push (PRD D6, ADR-0006).
///
/// Le push est silencieux et ne porte **aucun** contenu : c'est le magasin qui
/// fournit le nom du fil, le nom de l'auteur et le texte. Une notification écrite
/// depuis la charge utile afficherait un message qui n'est pas en base, et le tap
/// ouvrirait un fil qui ne le contient pas.
///
/// Ce que la notification **dit** est décidé ailleurs, sans greffon
/// (`conversation_notification.dart`, M5 : une notification par conversation,
/// ses derniers non-lus, un résumé). Ici vivent les deux rôles qui parlent au
/// greffon :
///
/// - [WakeNotifier] — **afficher, mettre à jour, effacer**, derrière une
///   abstraction, avec son double inerte ;
/// - [WakeTaps] — **recevoir le tap**, derrière une seconde abstraction.
///
/// Et une porte de plus depuis M5 : [wakeActionEntryPoint], le point d'entrée
/// des **actions** de la notification (« Répondre », « Marquer comme lu »), que
/// le greffon appelle dans un isolate de fond.
///
/// Deux abstractions et non une, parce que les deux rôles ne vivent pas dans le
/// même isolate : c'est le réveil de l'application **fermée** qui affiche
/// (`push_background.dart`), et l'isolate **principal** qui reçoit le tap — lui seul
/// a un routeur. Les fondre donnerait un objet dont la moitié des méthodes ne sert
/// jamais, de chaque côté.
///
/// `flutter_local_notifications` est donc confiné à deux classes de ce fichier,
/// comme `just_audio` l'est à `JustAudioContentPlayer` — et un test de source le
/// vérifie (`test/data/push/push_seam_test.dart`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'conversation_notification.dart';
import 'notification_action_handler.dart';
import 'push_background.dart';

/// **Le canal Android des réveils de messagerie.**
///
/// Distinct de celui du lecteur (`…channel.audio`, posé par `audio_service`) : un
/// seul canal mêlerait « un prêche joue » et « quelqu'un vous a écrit », et le
/// fidèle qui coupe l'un couperait l'autre sans le savoir — Android règle les sons,
/// la vibration et l'importance **par canal**.
const String kWakeChannelId =
    'com.maisondumiracle.maison_du_miracle.channel.messages';

/// Le libellé que le fidèle lit dans les réglages Android, **en français en dur**.
///
/// Ce n'est pas un oubli d'i18n : un canal se crée hors de l'arbre de widgets — et
/// même, pour le réveil d'une application fermée, dans un **isolate sans
/// `BuildContext` ni `Localizations`** —, et Android retient le libellé **du jour
/// de la création** : le changer plus tard n'a d'effet qu'à la réinstallation. Même
/// précédent que `androidNotificationChannelName: 'Lecture des messages'` dans
/// `main.dart`, pour la même raison.
const String kWakeChannelName = 'Messages reçus';

/// **Afficher une notification locale.** Ne lève jamais : un réveil qui n'a pas pu
/// s'afficher ne doit rien casser.
abstract interface class WakeNotifier {
  /// Prépare le canal. Rejouable — c'est un `createNotificationChannel`, idempotent
  /// côté Android.
  Future<void> prepare();

  /// Affiche — ou **remplace**, même identifiant — la notification d'une
  /// conversation.
  Future<void> show(ConversationNotification notification);

  /// Affiche ou remplace le **résumé** qui coiffe les conversations.
  Future<void> showSummary(NotificationSummary summary);

  /// Efface la notification d'une conversation (lue, ici ou ailleurs). Sans
  /// effet si elle n'est pas affichée.
  Future<void> cancel(String groupId);

  /// Efface le résumé — plus rien à coiffer.
  Future<void> cancelSummary();
}

/// Le double **inerte** : n'affiche rien, n'efface rien.
///
/// Le défaut du provider, en production comme sous `flutter test` — et le câblage
/// réel du **premier plan** (voir `app.dart`) : application ouverte, les écrans se
/// repeignent du magasin tout seuls, et une bannière par-dessus la conversation
/// qu'on lit serait du bruit.
class InertWakeNotifier implements WakeNotifier {
  const InertWakeNotifier();

  @override
  Future<void> prepare() async {}

  @override
  Future<void> show(ConversationNotification notification) async {}

  @override
  Future<void> showSummary(NotificationSummary summary) async {}

  @override
  Future<void> cancel(String groupId) async {}

  @override
  Future<void> cancelSummary() async {}
}

/// L'implémentation réelle, et **le seul endroit du dépôt qui connaisse
/// `flutter_local_notifications`**.
///
/// Elle se construit dans `main.dart` (premier plan, pour **effacer** les
/// notifications d'une conversation lue) et dans les points d'entrée de fond
/// (réveil, action) — plusieurs isolates, donc plusieurs instances du greffon,
/// ce qui est le mode d'emploi du paquet et non un contournement.
///
/// ## La notification d'une conversation : le style « messagerie »
///
/// `MessagingStyle` d'Android, comme WhatsApp : le nom du groupe en titre de
/// conversation, chaque non-lu avec son auteur, « Vous » pour moi. Elle porte
/// deux actions — **Répondre**, avec un champ de saisie, et **Marquer comme
/// lu** —, toutes deux traitées **sans ouvrir l'application** (voir
/// [wakeActionEntryPoint]). Le compteur (`number`) est celui de mes non-lus, et
/// c'est lui que le lanceur reprend en pastille.
///
/// **Pas d'avatar** : `users` ne porte aucune image aujourd'hui
/// (`Profiles.avatarUrl` est toujours nul). Le jour où il en portera, c'est
/// `Person.icon` qu'il faudra remplir — et télécharger l'image *avant* de
/// l'afficher, dans un isolate de fond.
class LocalWakeNotifier implements WakeNotifier {
  LocalWakeNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> prepare() async {
    try {
      // Le point d'entrée des actions est déclaré **ici aussi**, et pas
      // seulement par l'isolate principal : un téléphone qui reçoit sa première
      // notification avant d'avoir rouvert l'application depuis la mise à jour
      // n'aurait sinon aucun point d'entrée enregistré, et « Répondre » se
      // perdrait sans bruit.
      await _plugin.initialize(
        settings: _initialization,
        onDidReceiveBackgroundNotificationResponse: wakeActionEntryPoint,
      );

      // Android 8+ : un canal **créé à l'avance**. Sans lui, la première
      // notification en crée un avec l'importance par défaut, et l'importance d'un
      // canal ne se corrige plus après coup.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              kWakeChannelId,
              kWakeChannelName,
              description: 'Les messages de vos conversations.',
              importance: Importance.high,
            ),
          );
    } on Object catch (error) {
      // Canal de plugin absent (web, harnais de test), plateforme récalcitrante :
      // on ne notifiera pas, et rien d'autre ne change.
      _traceNotifier('canal indisponible : $error');
    }
  }

  @override
  Future<void> show(ConversationNotification notification) async {
    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: conversationDetails(notification),
        // **La charge utile du tap est un identifiant de fil, et rien d'autre.**
        // Il vient du magasin, donc il désigne une conversation dont on sait
        // qu'elle contient les messages annoncés. Les deux actions le lisent
        // aussi : c'est la conversation à laquelle on répond, ou qu'on marque lue.
        payload: notification.groupId,
      );
    } on Object catch (error) {
      _traceNotifier('affichage impossible : $error');
    }
  }

  @override
  Future<void> showSummary(NotificationSummary summary) async {
    try {
      await _plugin.show(
        id: kMessagesSummaryId,
        title: summary.title,
        body: summary.text,
        notificationDetails: summaryDetails(summary),
        // Pas de charge utile : le résumé ne désigne aucune conversation, et le
        // tap ouvre simplement l'application.
      );
    } on Object catch (error) {
      _traceNotifier('résumé impossible : $error');
    }
  }

  @override
  Future<void> cancel(String groupId) async {
    try {
      await _plugin.cancel(id: conversationNotificationId(groupId));
    } on Object catch (error) {
      _traceNotifier('effacement impossible : $error');
    }
  }

  @override
  Future<void> cancelSummary() async {
    try {
      await _plugin.cancel(id: kMessagesSummaryId);
    } on Object catch (error) {
      _traceNotifier('effacement du résumé impossible : $error');
    }
  }

  /// **Le dessin d'une conversation**, exposé pour les tests : c'est la
  /// traduction d'une [ConversationNotification] dans le vocabulaire du
  /// greffon, et rien d'autre ne la fait.
  @visibleForTesting
  static NotificationDetails conversationDetails(
    ConversationNotification notification,
  ) {
    final texts = notification.texts;
    final me = Person(key: 'me', name: texts.you);
    final messages = [
      for (final line in notification.lines)
        Message(line.text, line.at, _sender(line, texts)),
    ];

    return NotificationDetails(
      android: AndroidNotificationDetails(
        kWakeChannelId,
        kWakeChannelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: MessagingStyleInformation(
          me,
          // Le titre de conversation n'a de sens que pour un groupe : dans un
          // tête-à-tête, l'auteur de chaque ligne **est** la conversation.
          conversationTitle: notification.isGroup ? notification.title : null,
          groupConversation: notification.isGroup,
          messages: messages,
        ),
        groupKey: kMessagesGroupKey,
        number: notification.unreadCount,
        when: notification.lines.last.at.millisecondsSinceEpoch,
        // Une mise à jour silencieuse (le contenu change, rien de neuf n'est
        // arrivé) ne doit ni sonner ni vibrer.
        silent: !notification.alert,
        onlyAlertOnce: !notification.alert,
        actions: [
          AndroidNotificationAction(
            kReplyActionId,
            texts.reply,
            inputs: [AndroidNotificationActionInput(label: texts.replyHint)],
            semanticAction: SemanticAction.reply,
            // Traitée **sans ouvrir l'application** : voir
            // [wakeActionEntryPoint]. Et la notification part au geste —
            // Android garderait sinon son indicateur d'envoi tournant.
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            kMarkReadActionId,
            texts.markRead,
            semanticAction: SemanticAction.markAsRead,
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(threadIdentifier: kMessagesGroupKey),
    );
  }

  /// **Le dessin du résumé**, exposé pour les tests.
  @visibleForTesting
  static NotificationDetails summaryDetails(NotificationSummary summary) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        kWakeChannelId,
        kWakeChannelName,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: InboxStyleInformation(
          summary.lines,
          contentTitle: summary.title,
          summaryText: summary.text,
        ),
        groupKey: kMessagesGroupKey,
        setAsGroupSummary: true,
        number: summary.totalUnread,
        // Le résumé ne sonne jamais : c'est la conversation qui vient
        // d'arriver qui alerte, pas son rappel.
        groupAlertBehavior: GroupAlertBehavior.children,
        onlyAlertOnce: true,
      ),
      iOS: const DarwinNotificationDetails(threadIdentifier: kMessagesGroupKey),
    );
  }

  /// Qui a écrit une ligne. Un auteur retiré se dit comme dans le fil
  /// (« Membre retiré ») ; un profil pas encore arrivé, par une absence de nom.
  static Person _sender(NotificationLine line, NotificationTexts texts) {
    if (line.authorKey == 'removed') {
      return Person(key: 'removed', name: texts.removedAuthor);
    }
    return Person(key: line.authorKey, name: line.authorName);
  }
}

/// **Recevoir le tap sur une notification de réveil.** Ne lève jamais.
abstract interface class WakeTaps {
  /// Branche [onTap], et rejoue le tap qui a **lancé** l'application s'il y en a un.
  Future<void> listen(void Function(String groupId) onTap);
}

/// Le double **inerte** : aucun tap n'arrive. Le défaut du provider, donc l'état
/// d'un appareil sans transport et de tout test.
class InertWakeTaps implements WakeTaps {
  const InertWakeTaps();

  @override
  Future<void> listen(void Function(String groupId) onTap) async {}
}

/// Le tap réel, dans l'isolate **principal** — le seul qui ait un routeur.
class LocalWakeTaps implements WakeTaps {
  LocalWakeTaps({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> listen(void Function(String groupId) onTap) async {
    try {
      await _plugin.initialize(
        settings: _initialization,
        onDidReceiveNotificationResponse: (response) =>
            _deliver(response, onTap),
        // Les actions **sans interface** (« Répondre », « Marquer comme lu ») ne
        // passent jamais par le rappel ci-dessus : le greffon les confie à un
        // isolate de fond, application ouverte ou non. Voir
        // [wakeActionEntryPoint].
        onDidReceiveBackgroundNotificationResponse: wakeActionEntryPoint,
      );

      // **Le tap qui a lancé l'application** ne passe pas toujours par le rappel
      // ci-dessus : quand l'application était tuée, c'est par là qu'il arrive. Sans
      // cette lecture, ouvrir l'application depuis une notification déposerait le
      // fidèle sur l'accueil, et il n'aurait aucun moyen de savoir où aller.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        _deliver(response, onTap);
      }
    } on Object catch (error) {
      // Canal absent (web, harnais) : il n'y aura pas de tap, et rien d'autre ne
      // change. Ce chemin ne doit jamais empêcher l'application de s'ouvrir.
      _traceNotifier('taps indisponibles : $error');
    }
  }

  /// Seul le **tap sur la notification** ouvre une conversation : une action
  /// (« Répondre », « Marquer comme lu ») n'est pas une demande d'ouverture, et
  /// la rejouer ici ferait sauter l'écran sous les doigts de qui vient de
  /// répondre depuis sa barre de notifications.
  void _deliver(
    NotificationResponse response,
    void Function(String groupId) onTap,
  ) {
    if (response.actionId != null) return;
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    onTap(payload);
  }
}

/// **Le point d'entrée des actions de notification** (M5) — « Répondre » et
/// « Marquer comme lu ».
///
/// Le greffon l'appelle dans un **isolate de fond** qu'il démarre lui-même,
/// application ouverte ou fermée : rien de `main()` n'y existe. Ce fichier
/// n'y fait qu'**aplatir** la réponse du greffon (le seul type qu'il connaisse),
/// et confie le reste à `push_background.dart`, qui remonte le magasin et le
/// client HTTP le temps du geste — exactement le partage du réveil push.
///
/// `@pragma('vm:entry-point')` n'est pas décoratif : sans lui, le compilateur
/// d'une version *release* retire la fonction, que rien n'appelle depuis Dart.
@pragma('vm:entry-point')
void wakeActionEntryPoint(NotificationResponse response) {
  final action = readNotificationAction(
    actionId: response.actionId,
    payload: response.payload,
    input: response.input,
  );
  if (action == null) return;
  unawaited(handleBackgroundNotificationAction(action));
}

/// Les réglages d'initialisation, **partagés par les deux rôles** : les deux parlent
/// du même canal et de la même icône, et deux copies divergeraient.
///
/// **Aucune permission demandée ici.** Sur iOS, c'est
/// `FirebaseMessaging.requestPermission()` qui la demande — la même autorisation
/// système, et la demander deux fois au démarrage poserait deux fenêtres l'une sur
/// l'autre au premier lancement.
const InitializationSettings _initialization = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);

void _traceNotifier(String message) {
  assert(() {
    debugPrint('[push] notification locale — $message');
    return true;
  }());
}
