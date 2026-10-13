/// **Les rappels locaux** (M4, mobile#202, décision 14) : « Verset du jour » à
/// l'heure choisie et « Lecture du plan », **désactivés par défaut**.
///
/// Programmés sur l'appareil pour les **sept prochains jours**, un par jour :
/// chaque verset du jour a ainsi son propre texte, lu localement
/// (`bible_verse_of_days`, sinon la liste intégrée). Reprogrammés après
/// chaque synchronisation réussie (`app.dart`) et à chaque réglage.
///
/// Pour un membre, activer le verset du jour l'abonne aussi au push de
/// l'église (`PUT /bible/verse-of-day/subscription`).
///
/// Le greffon ne vit qu'ici, derrière [BibleReminderScheduler] (comme
/// `WakeNotifier`) ; il n'est **pas** réinitialisé ici — ce serait retirer
/// les gestes des notifications de messages posés par `WakeTaps`.
library;

import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/network/api_client.dart';
import '../../../data/local/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import 'bible_prefs.dart';

/// Ce que l'appli demande au système.
abstract interface class BibleReminderScheduler {
  Future<void> cancel(int id);
  Future<void> schedule(int id, DateTime at, String title, String body);
}

class LocalBibleReminderScheduler implements BibleReminderScheduler {
  LocalBibleReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Créé à la première notification ; le libellé est en dur, comme
  /// `kWakeChannelName` : un canal ne connaît pas `Localizations`.
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'bible_reminders',
      'Rappels de la Bible',
      channelDescription: 'Verset du jour et lecture du plan.',
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule(int id, DateTime at, String title, String body) =>
      _plugin.zonedSchedule(
        id: id,
        // L'instant exact, en UTC : la base des fuseaux n'est pas chargée, et
        // chaque jour est calculé à part (le passage à l'heure d'été tombe
        // juste).
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
}

final bibleReminderSchedulerProvider = Provider<BibleReminderScheduler>(
  (ref) => LocalBibleReminderScheduler(),
);

/// Les identifiants réservés : 7 versets du jour, puis 7 lectures du plan.
const int kVerseReminderBaseId = 920100;
const int kPlanReminderBaseId = 920200;
const int kReminderDays = 7;

/// La liste intégrée : un jour sans verset publié retombe dessus.
const List<BibleLink> kBuiltInVersesOfDay = [
  BibleLink('John', 3, from: 16),
  BibleLink('Ps', 23, from: 1),
  BibleLink('Phil', 4, from: 13),
  BibleLink('Rom', 8, from: 28),
  BibleLink('Isa', 41, from: 10),
  BibleLink('Prov', 3, from: 5, to: 6),
  BibleLink('Matt', 11, from: 28),
  BibleLink('Jer', 29, from: 11),
  BibleLink('Josh', 1, from: 9),
  BibleLink('Ps', 46, from: 1),
  BibleLink('2Cor', 5, from: 17),
  BibleLink('Lam', 3, from: 22, to: 23),
];

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

/// Le verset de [day] : celui de l'église, sinon la liste intégrée.
Future<BibleLink> verseOfDayFor(AppDatabase db, DateTime day) async {
  final row = await (db.select(db.bibleVerseOfDays)
        ..where((t) => t.day.equals(_isoDay(day)) & t.publishedAt.isNotNull())
        ..limit(1))
      .getSingleOrNull();
  if (row != null) {
    final link = BibleLink(
      row.book,
      row.chapter,
      from: row.verseFrom,
      to: row.verseFrom == null ? null : row.verseTo,
    );
    if (isValidBibleRef(link)) return link;
  }
  final index = DateTime.utc(day.year, day.month, day.day)
          .difference(DateTime.utc(day.year))
          .inDays %
      kBuiltInVersesOfDay.length;
  return kBuiltInVersesOfDay[index];
}

/// **Reprogramme** les rappels selon [prefs] : annule les quatorze, puis
/// programme ce qui est activé, à partir de [now].
Future<void> syncBibleReminders({
  required BiblePrefs prefs,
  required BibleReminderScheduler scheduler,
  required AppLocalizations l10n,
  required Future<BibleLink> Function(DateTime day) verseFor,
  required Future<String> Function(BibleLink link) textFor,
  required DateTime now,
}) async {
  for (var d = 0; d < kReminderDays; d++) {
    await scheduler.cancel(kVerseReminderBaseId + d);
    await scheduler.cancel(kPlanReminderBaseId + d);
  }
  final today = DateTime(now.year, now.month, now.day);
  for (var d = 0; d < kReminderDays; d++) {
    final day = DateTime(today.year, today.month, today.day + d);
    if (prefs.verseReminder) {
      final at = day.add(Duration(minutes: prefs.verseReminderMinutes));
      if (at.isAfter(now)) {
        final link = await verseFor(day);
        final text = await textFor(link);
        await scheduler.schedule(
          kVerseReminderBaseId + d,
          at,
          l10n.bibleM4VerseOfDayTitle,
          text.isEmpty ? link.labelFr : '$text — ${link.labelFr}',
        );
      }
    }
    if (prefs.planReminder) {
      final at = day.add(Duration(minutes: prefs.planReminderMinutes));
      if (at.isAfter(now)) {
        await scheduler.schedule(
          kPlanReminderBaseId + d,
          at,
          l10n.bibleM4PlanReminderTitle,
          l10n.bibleM4PlanReminderBody,
        );
      }
    }
  }
}

/// Le texte de [link] dans [source].
Future<String> verseTextIn(BibleSource? source, BibleLink link) async {
  if (source == null) return '';
  final verses = await source.chapter(link.book, link.chapter);
  final from = link.from ?? 1;
  final to = link.to ?? from;
  return [
    for (final v in verses)
      if (v.number >= from && v.number <= to) v.text,
  ].join(' ');
}

/// **Reprogramme les rappels** depuis le magasin : appelé après chaque
/// synchronisation réussie et à chaque réglage. Ne lève jamais.
final bibleRemindersRefreshProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(db.appSettings)
            ..where((t) => t.key.equals(kBiblePrefsKey)))
          .getSingleOrNull();
      final catalog = ref.read(bibleCatalogProvider);
      final source = catalog.sourceFor(ref.read(activeBibleVersionProvider));
      await syncBibleReminders(
        prefs: BiblePrefs.parse(row?.value),
        scheduler: ref.read(bibleReminderSchedulerProvider),
        l10n: _l10n(),
        verseFor: (day) => verseOfDayFor(db, day),
        textFor: (link) => verseTextIn(source, link),
        now: DateTime.now(),
      );
    } on Object {
      // Greffon absent (web, test), refus : pas de rappel, rien d'autre.
    }
  },
);

AppLocalizations _l10n() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  try {
    return lookupAppLocalizations(Locale(code));
  } on Object {
    return lookupAppLocalizations(const Locale('fr'));
  }
}

/// `PUT /bible/verse-of-day/subscription` — membres seulement.
final bibleVerseOfDaySubscriptionProvider =
    Provider<Future<void> Function(bool enabled)>(
  (ref) => (enabled) async {
    try {
      await ApiClient.instance.dio.put<Object?>(
        '/bible/verse-of-day/subscription',
        data: {'enabled': enabled},
      );
    } on DioException {
      // Hors ligne : le rappel local reste ; l'abonnement se refera au
      // prochain réglage.
    }
  },
);
