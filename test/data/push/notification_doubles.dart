import 'package:maison_du_miracle/data/push/conversation_notification.dart';
import 'package:maison_du_miracle/data/push/wake_notifier.dart';

/// **Les textes d'interface des notifications, en français**, tels que les
/// `.arb` les donnent — sans passer par `AppLocalizations`, que ces tests n'ont
/// pas à monter.
final NotificationTexts kTestNotificationTexts = NotificationTexts(
  you: 'Vous',
  newMessage: 'Nouveau message',
  newMessageFrom: (name) => 'Nouveau message de $name',
  media: 'Pièce jointe',
  removedAuthor: 'Membre retiré',
  reply: 'Répondre',
  replyHint: 'Votre message',
  markRead: 'Marquer comme lu',
  summaryTitle: (n) => n == 1 ? '1 nouveau message' : '$n nouveaux messages',
  summaryText: (n) => n == 1 ? 'dans 1 discussion' : 'dans $n discussions',
);

/// Un notifieur qui **note** au lieu d'afficher : aucun canal de greffon, et ce
/// que le test lit est exactement ce qui serait parti à l'écran.
class RecordingNotifier implements WakeNotifier {
  final List<ConversationNotification> shown = [];
  final List<NotificationSummary> summaries = [];
  final List<String> cancelled = [];
  int summaryCancelled = 0;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> show(ConversationNotification notification) async =>
      shown.add(notification);

  @override
  Future<void> showSummary(NotificationSummary summary) async =>
      summaries.add(summary);

  @override
  Future<void> cancel(String groupId) async => cancelled.add(groupId);

  @override
  Future<void> cancelSummary() async => summaryCancelled++;
}
