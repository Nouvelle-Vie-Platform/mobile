import 'package:flutter/material.dart';

/// **Ce que le fidèle a choisi**, à distinguer de ce qui s'affiche.
///
/// Quatre positions, et deux d'entre elles se ressemblent assez pour qu'on
/// écrive ici ce qui les sépare :
///
/// - [system] suit le réglage **du téléphone**. L'app ne décide de rien ;
/// - [auto] suit une **règle horaire de l'application**, réglable, que le
///   téléphone ignore.
///
/// Elles peuvent donc se contredire, et c'est normal : un téléphone jamais
/// programmé restera clair la nuit sous [system], là où [auto] basculera.
enum ThemeChoice {
  light('light'),
  system('system'),
  auto('auto'),
  dark('dark');

  const ThemeChoice(this.key);

  /// Clé de rangement dans `app_settings`. Stable : la renommer basculerait
  /// silencieusement tous les appareils installés sur le défaut.
  final String key;

  /// Relit une valeur stockée. **Tolérante** : une clé inconnue — réglage écrit
  /// par une version plus récente, base bricolée — retombe sur [system] plutôt
  /// que de faire échouer la lecture.
  static ThemeChoice parse(String? raw) {
    for (final value in ThemeChoice.values) {
      if (value.key == raw) return value;
    }
    return ThemeChoice.system;
  }
}

/// Une heure de la journée, sans date ni fuseau — « 19:00 ».
///
/// `TimeOfDay` de Flutter ferait l'affaire, mais il ne sait ni se sérialiser ni
/// se comparer, et les deux servent ici.
@immutable
class DayTime implements Comparable<DayTime> {
  const DayTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get inMinutes => hour * 60 + minute;

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  static DayTime fromTimeOfDay(TimeOfDay time) =>
      DayTime(time.hour, time.minute);

  /// Sérialisation `HH:mm` — lisible dans la base, et triable comme du texte.
  String get key => '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  /// Relit `HH:mm`. Toute forme inattendue rend [fallback] : un réglage
  /// illisible ne doit pas priver l'application de thème.
  static DayTime parse(String? raw, {required DayTime fallback}) {
    if (raw == null) return fallback;
    final parts = raw.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return DayTime(hour, minute);
  }

  @override
  int compareTo(DayTime other) => inMinutes.compareTo(other.inMinutes);

  @override
  bool operator ==(Object other) =>
      other is DayTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => key;
}

/// Les valeurs par défaut de la règle horaire : sombre le soir, clair au matin.
const DayTime kDefaultDarkFrom = DayTime(19, 0);
const DayTime kDefaultLightFrom = DayTime(6, 0);

/// L'état des réglages d'apparence, tel qu'un écran le lit.
@immutable
class ThemePreferences {
  const ThemePreferences({
    this.choice = ThemeChoice.system,
    this.darkFrom = kDefaultDarkFrom,
    this.lightFrom = kDefaultLightFrom,
  });

  final ThemeChoice choice;

  /// Heure à partir de laquelle le mode [ThemeChoice.auto] passe en sombre.
  final DayTime darkFrom;

  /// Heure à partir de laquelle il revient au clair.
  final DayTime lightFrom;

  @override
  bool operator ==(Object other) =>
      other is ThemePreferences &&
      other.choice == choice &&
      other.darkFrom == darkFrom &&
      other.lightFrom == lightFrom;

  @override
  int get hashCode => Object.hash(choice, darkFrom, lightFrom);
}

/// **La règle horaire, écrite une seule fois.**
///
/// « Sombre entre [darkFrom] et [lightFrom] », en passant minuit s'il le faut.
/// Les deux sens sont volontairement acceptés : `19:00 → 06:00` est le cas
/// courant, `06:00 → 19:00` est un réglage **valide** pour qui veille la nuit.
/// Aucun des deux n'est un cas particulier — c'est la même comparaison, prise
/// dans un sens ou dans l'autre.
///
/// Deux heures **identiques** donnent un intervalle vide, donc toujours clair.
/// C'est le sens le moins surprenant : `ThemeChoice.dark` existe déjà, en un
/// geste, pour qui veut du sombre en permanence.
bool isDarkAt(DateTime now,
    {required DayTime darkFrom, required DayTime lightFrom}) {
  final minutes = now.hour * 60 + now.minute;
  final from = darkFrom.inMinutes;
  final to = lightFrom.inMinutes;
  if (from == to) return false;
  if (from < to) return minutes >= from && minutes < to;
  // L'intervalle passe minuit.
  return minutes >= from || minutes < to;
}

/// **Quand la prochaine bascule aura-t-elle lieu ?**
///
/// Sert à armer une minuterie *unique* plutôt qu'à sonder l'horloge. Rend `null`
/// quand aucune bascule n'est prévue — les deux heures étant identiques, il n'y
/// a rien à attendre.
DateTime? nextThemeSwitch(
  DateTime now, {
  required DayTime darkFrom,
  required DayTime lightFrom,
}) {
  if (darkFrom == lightFrom) return null;
  DateTime at(DayTime time) {
    final today =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    // Strictement après maintenant : une bascule à l'instant présent vient
    // d'avoir lieu, la prochaine est demain.
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  final candidates = [at(darkFrom), at(lightFrom)]..sort();
  return candidates.first;
}
