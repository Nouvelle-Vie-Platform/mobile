/// **La notification locale d'un réveil** — dressée depuis le magasin, jamais
/// depuis la charge utile du push (PRD D6, ADR-0006).
///
/// Le push est silencieux et ne porte **aucun** contenu : c'est le magasin qui
/// fournit le nom du fil, le nom de l'auteur et le texte. Une notification écrite
/// depuis la charge utile afficherait un message qui n'est pas en base, et le tap
/// ouvrirait un fil qui ne le contient pas.
///
/// Quatre pièces, et la frontière entre elles est le point du fichier :
///
/// - [WakeNotification] — ce qui s'affiche, déjà décidé. Une valeur, sans plugin ;
/// - [announcementNotification] — la **règle** qui transforme une ligne de magasin
///   en titre et corps. Fonction pure, testée sans canal natif ;
/// - [WakeNotifier] — **afficher**, derrière une abstraction, avec son double inerte ;
/// - [WakeTaps] — **recevoir le tap**, derrière une seconde abstraction.
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

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../local/group_dao.dart';

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

/// Ce qui s'affiche, et où le tap mène. Aucune décision ne reste à prendre.
@immutable
class WakeNotification {
  const WakeNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.groupId,
  });

  /// L'identifiant **système** de la notification. Un entier : c'est ce qu'Android
  /// et iOS attendent, et c'est lui qui fait qu'un second message **remplace** la
  /// notification du même fil au lieu d'en empiler une seconde. Dérivé du
  /// `groupId`, donc une notification par conversation.
  final int id;

  final String title;
  final String body;

  /// La conversation à ouvrir au tap — **lue du magasin**, jamais du push.
  final String groupId;

  @override
  bool operator ==(Object other) =>
      other is WakeNotification &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(id, title, body, groupId);

  @override
  String toString() => 'WakeNotification($id, "$title", "$body", $groupId)';
}

/// **La règle**, et le seul endroit qui la porte.
///
/// Rend `null` quand il n'y a rien à annoncer — un corps vide, ou un groupe que le
/// magasin ne nomme pas encore. Mieux vaut se taire qu'annoncer « (sans titre) » :
/// une notification vide ressemble à une donnée perdue, exactement comme un titre
/// blanc dans le vocabulaire du portail (#81).
///
/// Trois formes, et aucune n'invente de nom :
///
/// | cas | titre | corps |
/// |---|---|---|
/// | tête-à-tête | le nom de l'auteur, sinon celui du groupe | le texte |
/// | groupe, auteur connu | le nom du groupe | `Auteur : texte` |
/// | message système, auteur retiré, profil pas encore reçu | le nom du groupe | le texte seul |
///
/// Le troisième cas couvre les **trois** sens du nom absent, et c'est délibéré :
/// « Membre retiré » est un **fait**, pas un nom (CLAUDE.md), et le préfixer ici
/// ferait du nul de l'auteur retiré et du nul du profil en retard la même chose à
/// l'écran — alors que le second se remplira au prochain cycle.
WakeNotification? announcementNotification(MessageAnnouncement message) {
  // Un message-média (`body` nul, #140) n'a pas encore de phrase à annoncer :
  // la notification se tait plutôt que de montrer un corps vide. Les
  // notifications de média reviendront avec leur tranche (M4/M5).
  final body = message.body?.trim() ?? '';
  if (body.isEmpty) return null;

  final group = message.groupName?.trim();
  final author = message.authorName?.trim();
  final named = author != null && author.isNotEmpty;

  if (message.isDirect) {
    final title = named ? author : (group?.isNotEmpty == true ? group! : null);
    if (title == null) return null;
    return WakeNotification(
      id: _systemId(message.groupId),
      title: title,
      body: body,
      groupId: message.groupId,
    );
  }

  if (group == null || group.isEmpty) return null;
  return WakeNotification(
    id: _systemId(message.groupId),
    title: group,
    // Pas de préfixe pour un message système : le serveur ne se présente pas.
    body: named && !message.isSystem ? '$author : $body' : body,
    groupId: message.groupId,
  );
}

/// Un entier stable et positif, dérivé du `groupId`.
///
/// Positif : Android accepte les négatifs, iOS non. Stable : c'est ce qui fait
/// qu'un second message du même fil **remplace** la notification au lieu d'en
/// ajouter une — le groupage et les badges sont hors périmètre, mais empiler dix
/// notifications pour une conversation n'en serait pas un, ce serait un défaut.
int _systemId(String groupId) => groupId.hashCode & 0x7fffffff;

/// **Afficher une notification locale.** Ne lève jamais : un réveil qui n'a pas pu
/// s'afficher ne doit rien casser.
abstract interface class WakeNotifier {
  /// Prépare le canal. Rejouable — c'est un `createNotificationChannel`, idempotent
  /// côté Android.
  Future<void> prepare();

  Future<void> show(WakeNotification notification);
}

/// Le double **inerte** : n'affiche rien.
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
  Future<void> show(WakeNotification notification) async {}
}

/// L'implémentation réelle, et **le seul endroit du dépôt qui connaisse
/// `flutter_local_notifications`**.
///
/// Elle se construit dans `main.dart` (premier plan) et dans le point d'entrée du
/// réveil en arrière-plan — deux isolates, donc deux instances du greffon, ce qui
/// est le mode d'emploi du paquet et non un contournement.
class LocalWakeNotifier implements WakeNotifier {
  LocalWakeNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> prepare() async {
    try {
      await _plugin.initialize(settings: _initialization);

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
  Future<void> show(WakeNotification notification) async {
    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kWakeChannelId,
            kWakeChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // **La charge utile du tap est un identifiant de fil, et rien d'autre.**
        // Il vient du magasin (voir `MessageAnnouncement.groupId`), donc il désigne
        // une conversation dont on sait qu'elle contient le message annoncé.
        payload: notification.groupId,
      );
    } on Object catch (error) {
      _traceNotifier('affichage impossible : $error');
    }
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
            _deliver(response.payload, onTap),
      );

      // **Le tap qui a lancé l'application** ne passe pas toujours par le rappel
      // ci-dessus : quand l'application était tuée, c'est par là qu'il arrive. Sans
      // cette lecture, ouvrir l'application depuis une notification déposerait le
      // fidèle sur l'accueil, et il n'aurait aucun moyen de savoir où aller.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _deliver(launch?.notificationResponse?.payload, onTap);
      }
    } on Object catch (error) {
      // Canal absent (web, harnais) : il n'y aura pas de tap, et rien d'autre ne
      // change. Ce chemin ne doit jamais empêcher l'application de s'ouvrir.
      _traceNotifier('taps indisponibles : $error');
    }
  }

  void _deliver(String? payload, void Function(String groupId) onTap) {
    if (payload == null || payload.isEmpty) return;
    onTap(payload);
  }
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
