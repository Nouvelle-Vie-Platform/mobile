/// **Les textes d'interface des notifications de messages**, dans la langue du
/// téléphone (tranche M5).
///
/// Une notification se dresse souvent dans un isolate **sans `BuildContext`** —
/// le réveil d'une application fermée, l'action « Répondre » —, donc sans
/// `Localizations`. On lit alors la langue du système (`PlatformDispatcher`),
/// on la confronte aux langues de l'application, et on demande au code généré
/// la classe de traductions correspondante. C'est exactement la résolution que
/// `MaterialApp` fait au premier plan (langues du système ✕
/// `appSupportedLocales`, repli sur le français).
///
/// Le **nom du canal**, lui, reste en français en dur (`kWakeChannelName`) :
/// Android le retient du jour de sa création, et il ne suivrait de toute façon
/// pas un changement de langue.
library;

import 'dart:ui' show Locale, PlatformDispatcher;

import '../../l10n/app_localizations.dart';
import 'conversation_notification.dart';

/// Les textes, depuis une classe de traductions déjà résolue.
NotificationTexts notificationTextsOf(AppLocalizations l) => NotificationTexts(
      you: l.notificationYou,
      newMessage: l.notificationNewMessage,
      newMessageFrom: l.notificationNewMessageFrom,
      media: l.echangesMediaPreview,
      removedAuthor: l.chatAuthorRemoved,
      reply: l.notificationReply,
      replyHint: l.notificationReplyHint,
      markRead: l.notificationMarkRead,
      summaryTitle: l.notificationSummaryTitle,
      summaryText: l.notificationSummaryText,
    );

/// Les textes dans la **langue du système**, ou en français si l'application ne
/// la parle pas. Pour les isolates de fond.
NotificationTexts notificationTextsForSystem() {
  final languages = [
    for (final locale in PlatformDispatcher.instance.locales)
      locale.languageCode,
  ];
  for (final language in languages) {
    final supported = AppLocalizations.supportedLocales
        .any((locale) => locale.languageCode == language);
    if (supported) {
      return notificationTextsOf(lookupAppLocalizations(Locale(language)));
    }
  }
  return notificationTextsOf(lookupAppLocalizations(const Locale('fr')));
}
