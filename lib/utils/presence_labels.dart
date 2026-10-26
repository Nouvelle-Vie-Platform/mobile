/// **Ce que l'en-tête d'un fil et la tuile d'une conversation disent de
/// l'autre** (#142, tranche M3) : « écrit… », « en ligne », « vu à ».
///
/// Des fonctions pures, [now] injectable : « aujourd'hui » et « hier »
/// dépendent de l'heure qu'il est, et une règle de calendrier non injectable
/// est intestable.
library;

import 'package:intl/intl.dart';

import '../data/messaging/messaging_channel.dart' show MessagingPresenceEvent;
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';

/// **« écrit… »** — `null` si personne n'écrit.
///
/// - tête-à-tête : « écrit… », sans nom (l'en-tête porte déjà le nom) ;
/// - groupe, une personne : « Ama écrit… » — son **prénom** (le premier mot du
///   nom servi), ou « écrit… » seul si son nom n'est pas encore arrivé (jamais
///   un nom inventé) ;
/// - groupe, plusieurs : « 2 personnes écrivent… ».
String? typingLabel(
  AppLocalizations l, {
  required List<String> typers,
  required bool isDirect,
  String? Function(String userId)? nameOf,
}) {
  if (typers.isEmpty) return null;
  if (isDirect) return l.chatTyping;
  if (typers.length > 1) return l.chatTypingSeveral(typers.length);
  final name = nameOf?.call(typers.single)?.trim();
  if (name == null || name.isEmpty) return l.chatTyping;
  return l.chatTypingNamed(name.split(RegExp(r'\s+')).first);
}

/// **« en ligne » / « vu à »** de l'autre, dans un tête-à-tête — `null` quand
/// il n'y a rien à dire : présence inconnue, cachée par la réciprocité
/// (`visible == false`), ou « vu à » perdu par un redémarrage du serveur.
/// Une absence se rend comme une absence, jamais par une date inventée.
String? presenceLabel(
  AppLocalizations l,
  MessagingPresenceEvent? presence, {
  DateTime? now,
}) {
  if (presence == null || !presence.visible) return null;
  if (presence.online) return l.chatPresenceOnline;
  final seen = presence.lastSeenAt;
  if (seen == null) return null;

  final local = seen.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final time = DateFormat.Hm(l.intlLocale).format(local);
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return l.chatLastSeenToday(time);
  if (days == 1) return l.chatLastSeenYesterday(time);
  return l.chatLastSeenOn(DateFormat.MMMd(l.intlLocale).format(local), time);
}

/// **L'instant d'un accusé** dans « Infos du message » : « aujourd'hui à
/// 14:05 », « hier à 14:05 », « 3 oct. à 14:05 ».
String receiptInstantLabel(
  AppLocalizations l,
  DateTime instant, {
  DateTime? now,
}) {
  final local = instant.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final time = DateFormat.Hm(l.intlLocale).format(local);
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days <= 0) return l.messageInfoToday(time);
  if (days == 1) return l.messageInfoYesterday(time);
  return l.messageInfoOn(DateFormat.MMMd(l.intlLocale).format(local), time);
}
