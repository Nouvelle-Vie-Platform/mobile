/// **La notification LOCALE, derrière une abstraction** — le dernier maillon du
/// réveil push (D6 de `docs/prd/notifications-push.md`).
///
/// Le réveil serveur est **content-free** : `{ type, groupId, messageId }`, jamais
/// le texte (ADR-0006 serveur — la base est la seule source de vérité, aucun
/// contenu ne fuit chez Google/Apple/ntfy). Une fois l'app réveillée et la sync
/// ciblée passée, [PushWakeHandler] **lit le message dans le magasin**, compose le
/// vrai titre/texte, et le remet ici pour peinture d'une notification système.
///
/// **Pourquoi une abstraction — et pourquoi l'implémentation réelle n'est PAS
/// dans ce lot.** La vraie notification passe par `flutter_local_notifications`,
/// un plugin natif. Or ce dépôt est **SPM-only côté iOS** (voir `CLAUDE.md`) : un
/// plugin sans `Package.swift` **ressusciterait CocoaPods**, et Firebase n'est pas
/// encore debout (pas de `google-services.json`/`plist`). Ajouter la dépendance
/// maintenant **casserait le build**. Le vrai câblage est donc un **maillon
/// séparé** que le main loop fera plus tard, Firebase en place ; tout le reste —
/// décodage du réveil, sync, lecture du magasin, composition — se construit et se
/// **prouve dès aujourd'hui sur la VM** derrière ce contrat, avec un double inerte.
///
/// Le futur `FlutterLocalNotifier` (à écrire dans ce même dossier) implémentera
/// [LocalNotifier] en appelant `FlutterLocalNotificationsPlugin.show(...)`, en
/// posant [PushNotificationContent.conversationId] dans le `payload` de la
/// notification pour le **deep-link au tap** (ouverture de la conversation). Il ne
/// change **rien** au handler : c'est tout l'intérêt du seam.
library;

import 'package:flutter/foundation.dart';

/// **Le contenu d'une notification locale**, entièrement dérivé du magasin — rien
/// n'y vient du réveil réseau (D1/D6).
///
/// - [title] : le nom du **groupe**, ou le nom du **pair** pour un DM (via
///   `profiles`). Peut être vide tant qu'un profil n'est pas synchronisé — le
///   rendu se débrouille (jamais un « Utilisateur inconnu » inventé).
/// - [body] : le **texte** du message.
/// - [conversationId] : l'identifiant du fil (`groups.id`), porté jusqu'au tap
///   pour le **deep-link** vers la conversation. Ce n'est pas peint, c'est routé.
@immutable
class PushNotificationContent {
  const PushNotificationContent({
    required this.title,
    required this.body,
    required this.conversationId,
  });

  /// Nom du groupe, ou du pair d'un DM.
  final String title;

  /// Texte du message.
  final String body;

  /// `groups.id` du fil — pour le deep-link au tap, jamais affiché.
  final String conversationId;

  @override
  bool operator ==(Object other) =>
      other is PushNotificationContent &&
      other.title == title &&
      other.body == body &&
      other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(title, body, conversationId);

  @override
  String toString() =>
      'PushNotificationContent(title: $title, body: $body, '
      'conversationId: $conversationId)';
}

/// **Contrat de peinture d'une notification locale.** Une seule opération : poser
/// [content] à l'écran. Rend un `Future` — la vraie implémentation appelle un
/// canal de plugin.
abstract interface class LocalNotifier {
  /// Peint une notification système à partir de [content].
  Future<void> show(PushNotificationContent content);
}

/// **Le double inerte** — le défaut testable, et le comportement sûr partout où
/// le plugin natif n'est pas (ou pas encore) branché : ne peint rien.
///
/// C'est ce double qui tourne sous `flutter test`, où un canal de plugin lèverait
/// `MissingPluginException` ; et c'est lui qui est injecté tant que le maillon
/// `flutter_local_notifications` n'existe pas — l'app se réveille et synchronise
/// sans jamais tenter d'atteindre une plateforme absente.
class InertLocalNotifier implements LocalNotifier {
  const InertLocalNotifier();

  @override
  Future<void> show(PushNotificationContent content) async {
    // No-op : aucune notification, aucun canal, aucune minuterie.
  }
}
