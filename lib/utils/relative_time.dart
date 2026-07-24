import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Formate un instant en horodatage **relatif et localisé**.
///
/// La date de publication est une donnée (ISO 8601 UTC côté back), jamais du
/// texte d'interface : une chaîne pré-formatée casserait l'i18n et se
/// périmerait instantanément.
///
/// Paliers : « à l'instant » (< 1 min), minutes (< 1 h), heures (< 24 h),
/// « hier » (< 48 h), jours (< 7 j), puis date courte localisée.
///
/// Prend directement les [AppLocalizations] (et non un `BuildContext`) pour
/// rester testable sans monter de widget. [now] permet de figer l'horloge dans
/// les tests.
String relativeTime(AppLocalizations l10n, DateTime when, {DateTime? now}) {
  // Comparaison en heure locale : `when` arrive en UTC côté back.
  final moment = when.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final elapsed = reference.difference(moment);

  // Une date future (horloges désynchronisées) est traitée comme « maintenant ».
  if (elapsed.isNegative || elapsed.inMinutes < 1) return l10n.timeJustNow;
  if (elapsed.inHours < 1) return l10n.timeMinutesAgo(elapsed.inMinutes);
  if (elapsed.inHours < 24) return l10n.timeHoursAgo(elapsed.inHours);
  if (elapsed.inHours < 48) return l10n.timeYesterday;
  if (elapsed.inDays < 7) return l10n.timeDaysAgo(elapsed.inDays);
  return DateFormat.yMMMd(l10n.localeName).format(moment);
}
