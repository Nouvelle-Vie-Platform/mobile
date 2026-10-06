/// **Effacer les notifications d'une conversation lue, application ouverte**
/// (tranche M5).
///
/// Les notifications sont dressées par le réveil de l'application **fermée**.
/// Quand on rouvre l'application et qu'on lit la conversation — ou qu'un autre
/// appareil la lit et que `read.advanced` arrive sur le canal `users/{id}` —, sa
/// notification doit partir : WhatsApp ne laisse pas dans la barre un message
/// qu'on vient de lire.
///
/// Le premier plan ne **dresse** rien (les écrans se repeignent du magasin) ;
/// il **efface**. Ce réconciliateur écoute la liste de mes conversations —
/// déjà un flux du magasin, déjà recalculé à chaque lecture, d'où qu'elle
/// vienne — et efface la notification de toute conversation dont les non-lus
/// retombent à zéro, ou qui passe en sourdine. Le résumé part quand il n'y a
/// plus rien à coiffer.
///
/// Il ne **remet** jamais de résumé : application ouverte, aucune notification
/// neuve ne s'affiche, et un résumé posé sans enfant s'afficherait seul.
library;

import '../local/group_dao.dart';
import 'wake_notifier.dart';

class NotificationReconciler {
  NotificationReconciler({
    required WakeNotifier notifier,
    DateTime Function()? now,
  })  : _notifier = notifier,
        _now = now ?? DateTime.now;

  final WakeNotifier _notifier;
  final DateTime Function() _now;

  /// L'état « notifiable » de chaque conversation à l'émission précédente :
  /// non lue **et** hors sourdine. `null` avant la première émission — tout ce
  /// qui n'est pas notifiable est alors effacé une fois, au cas où une
  /// notification d'avant l'ouverture traînerait.
  Map<String, bool>? _notifiable;

  /// Une émission de la liste de mes conversations. Ne lève jamais.
  Future<void> onConversations(List<ConversationRecord> conversations) async {
    final now = _now();
    final previous = _notifiable;
    final next = {
      for (final c in conversations)
        c.groupId: c.unreadCount > 0 && !c.isMutedAt(now),
    };
    _notifiable = next;

    for (final entry in next.entries) {
      if (entry.value) continue;
      // Effacer seulement ce qui **vient** de cesser d'être notifiable : une
      // conversation lue depuis longtemps n'a rien à effacer, et chaque
      // effacement est un aller-retour vers le greffon.
      if (previous != null && previous[entry.key] == false) continue;
      await _notifier.cancel(entry.key);
    }

    final anyLeft = next.values.any((notifiable) => notifiable);
    final hadAny = previous == null || previous.values.any((n) => n);
    if (!anyLeft && hadAny) await _notifier.cancelSummary();
  }
}
