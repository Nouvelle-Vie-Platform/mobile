/// Rendu des dates et heures d'un [ChurchEvent].
library;

import 'package:intl/intl.dart';

import '../models/models.dart';

/// Décalages fixes des fuseaux que l'église utilise réellement.
///
/// **Limite assumée** : il n'y a pas de base de fuseaux IANA complète sans
/// plugin natif (l'app doit tourner sur web), donc pas de règles d'heure d'été.
/// Cette table ne contient que des fuseaux **à décalage constant toute
/// l'année** — c'est le cas de toute l'Afrique de l'Ouest et centrale, où sont
/// les branches. Un fuseau à heure d'été (`Europe/Paris`…) n'y a pas sa place :
/// on l'afficherait faux la moitié de l'année.
///
/// Un fuseau inconnu est traité comme UTC (voir [branchOffset]).
const Map<String, Duration> _fixedOffsets = {
  'UTC': Duration.zero,
  'GMT': Duration.zero,
  'Etc/UTC': Duration.zero,
  'Etc/GMT': Duration.zero,
  'Africa/Lome': Duration.zero, // Togo — aucun changement d'heure.
  'Africa/Abidjan': Duration.zero,
  'Africa/Accra': Duration.zero,
  'Africa/Bamako': Duration.zero,
  'Africa/Conakry': Duration.zero,
  'Africa/Dakar': Duration.zero,
  'Africa/Ouagadougou': Duration.zero,
  'Africa/Lagos': Duration(hours: 1),
  'Africa/Porto-Novo': Duration(hours: 1),
  'Africa/Douala': Duration(hours: 1),
  'Africa/Libreville': Duration(hours: 1),
  'Africa/Kinshasa': Duration(hours: 1),
  'Africa/Brazzaville': Duration(hours: 1),
  'Africa/Bangui': Duration(hours: 1),
  'Africa/Ndjamena': Duration(hours: 1),
  'Africa/Nairobi': Duration(hours: 3),
};

/// Décalage du fuseau [timezone] par rapport à UTC.
///
/// Accepte un identifiant IANA connu (voir [_fixedOffsets]) ou un décalage
/// explicite (`+01:00`, `UTC+1`, `GMT-3`). Tout le reste vaut **UTC** : c'est
/// le décalage du Togo, donc le repli le moins faux pour ce dépôt, et il ne
/// ment jamais sur l'heure affichée (seul le suffixe pourrait manquer).
Duration branchOffset(String timezone) {
  final name = timezone.trim();
  final known = _fixedOffsets[name];
  if (known != null) return known;

  final explicit = RegExp(r'^(?:UTC|GMT)?([+-])(\d{1,2})(?::?(\d{2}))?$')
      .firstMatch(name.toUpperCase());
  if (explicit == null) return Duration.zero;

  final sign = explicit.group(1) == '-' ? -1 : 1;
  final hours = int.parse(explicit.group(2)!);
  final minutes = int.parse(explicit.group(3) ?? '0');
  return Duration(hours: sign * hours, minutes: sign * minutes);
}

/// Heure **murale** de [instant] dans le fuseau [timezone].
///
/// Le résultat est marqué UTC à dessein : ses champs (`hour`, `day`…) portent
/// déjà l'heure de la branche, et le marquer UTC empêche `intl` — ou un
/// `toLocal()` distrait — de le reconvertir une seconde fois.
DateTime wallClockAt(DateTime instant, String timezone) =>
    instant.toUtc().add(branchOffset(timezone));

/// Libellé d'un décalage, en **chiffres** : « GMT », « GMT+1 », « GMT-3:30 ».
///
/// Jamais d'abréviation (« WAT », « CET ») : elles sont ambiguës, non
/// traduisibles, et illisibles pour un non-technicien.
String offsetLabel(Duration offset) {
  if (offset == Duration.zero) return 'GMT';
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final minutes = abs.inMinutes.remainder(60);
  final suffix = minutes == 0 ? '' : ':${minutes.toString().padLeft(2, '0')}';
  return 'GMT$sign${abs.inHours}$suffix';
}

/// Heure de l'évènement, dans le fuseau de la **branche**, suffixée du
/// décalage **uniquement s'il diffère de celui du lecteur**.
///
/// « 17:30 » au Togo, « 17:30 (GMT) » vu de Paris. On ne convertit pas : c'est
/// un rassemblement physique, l'heure annoncée est vraie **sur place**. Le
/// suffixe lève l'ambiguïté pour le lecteur en transit sans déplacer l'heure
/// pour tous les autres — au Togo (`Africa/Lome`, UTC+0 toute l'année), le cas
/// dominant ne paie donc rien.
///
/// [readerOffset] permet de figer le fuseau du lecteur dans les tests ; par
/// défaut c'est celui de l'appareil au moment de l'évènement.
///
/// [startOnly] omet l'heure de fin (étiquettes étroites de l'accueil). Le
/// suffixe, lui, reste : c'est précisément ce qui désambiguïse l'heure.
String formatEventTime(
  ChurchEvent event,
  String locale, {
  Duration? readerOffset,
  bool startOnly = false,
}) {
  final format = DateFormat.Hm(locale);
  final start = format.format(wallClockAt(event.startsAt, event.timezone));
  final end = event.endsAt == null || startOnly
      ? null
      : format.format(wallClockAt(event.endsAt!, event.timezone));

  final range = end == null ? start : '$start - $end';

  final branch = branchOffset(event.timezone);
  final reader = readerOffset ?? event.startsAt.toLocal().timeZoneOffset;
  if (branch == reader) return range;
  return '$range (${offsetLabel(branch)})';
}

/// Quantième du mois (« 26 »), dans le fuseau de la branche.
String formatEventDay(ChurchEvent event, String locale) =>
    DateFormat.d(locale).format(wallClockAt(event.startsAt, event.timezone));

/// Mois abrégé (« mai »), dans le fuseau de la branche.
String formatEventMonth(ChurchEvent event, String locale) =>
    DateFormat.LLL(locale).format(wallClockAt(event.startsAt, event.timezone));

/// Jour de la semaine en toutes lettres, capitalisé (« Dimanche »).
String formatEventWeekday(ChurchEvent event, String locale) {
  final day = DateFormat.EEEE(locale)
      .format(wallClockAt(event.startsAt, event.timezone));
  if (day.isEmpty) return day;
  return day[0].toUpperCase() + day.substring(1);
}
