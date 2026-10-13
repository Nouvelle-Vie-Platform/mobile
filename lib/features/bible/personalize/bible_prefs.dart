/// **Les réglages locaux du module Bible** (M4, mobile#202) : thème et police
/// du lecteur, voix et vitesse de lecture, rappels.
///
/// Une seule ligne `app_settings` (clé [kBiblePrefsKey], JSON) : aucune
/// migration, et l'appareil seul les connaît — ce sont des goûts, pas des
/// données du compte. Lue **une fois** puis tenue en mémoire : un `watch()` sur
/// `app_settings` laisse un `Timer` pendant sous l'horloge factice (voir
/// `SettingsDao.readPreferredBranch`). Une valeur illisible retombe sur le
/// défaut, champ par champ.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';

const String kBiblePrefsKey = 'bible_personalize';

enum BibleReaderTheme { light, dark, sepia }

/// Atkinson (la police de l'appli), Literata (serif de lecture embarquée,
/// OFL), et la police du système.
enum BibleReaderFont { atkinson, literata, system }

/// Les vitesses proposées, dans l'ordre du bouton.
const List<double> kBibleSpeechRates = [0.75, 1.0, 1.25, 1.5];

final class BiblePrefs {
  const BiblePrefs({
    this.theme = BibleReaderTheme.light,
    this.font = BibleReaderFont.atkinson,
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.speechRate = 1.0,
    this.verseReminder = false,
    this.verseReminderMinutes = 7 * 60,
    this.planReminder = false,
    this.planReminderMinutes = 20 * 60,
  });

  static const double minFontSize = 14;
  static const double maxFontSize = 30;
  static const double minLineHeight = 1.2;
  static const double maxLineHeight = 2.2;

  final BibleReaderTheme theme;
  final BibleReaderFont font;
  final double fontSize;
  final double lineHeight;
  final double speechRate;

  /// Rappels locaux, **désactivés par défaut** ; l'heure en minutes depuis
  /// minuit.
  final bool verseReminder;
  final int verseReminderMinutes;
  final bool planReminder;
  final int planReminderMinutes;

  BiblePrefs copyWith({
    BibleReaderTheme? theme,
    BibleReaderFont? font,
    double? fontSize,
    double? lineHeight,
    double? speechRate,
    bool? verseReminder,
    int? verseReminderMinutes,
    bool? planReminder,
    int? planReminderMinutes,
  }) =>
      BiblePrefs(
        theme: theme ?? this.theme,
        font: font ?? this.font,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        speechRate: speechRate ?? this.speechRate,
        verseReminder: verseReminder ?? this.verseReminder,
        verseReminderMinutes: verseReminderMinutes ?? this.verseReminderMinutes,
        planReminder: planReminder ?? this.planReminder,
        planReminderMinutes: planReminderMinutes ?? this.planReminderMinutes,
      );

  Map<String, Object> toJson() => {
        'theme': theme.name,
        'font': font.name,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'speechRate': speechRate,
        'verseReminder': verseReminder,
        'verseReminderMinutes': verseReminderMinutes,
        'planReminder': planReminder,
        'planReminderMinutes': planReminderMinutes,
      };

  /// Lit [raw] ; tout champ absent ou illisible garde son défaut.
  static BiblePrefs parse(String? raw) {
    const d = BiblePrefs();
    Object? decoded;
    try {
      decoded = raw == null ? null : jsonDecode(raw);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map) return d;
    T? pick<T>(String key) =>
        decoded is Map && decoded[key] is T ? decoded[key] as T : null;
    E? named<E extends Enum>(List<E> values, String key) =>
        values.asNameMap()[pick<String>(key)];
    double? clamp(num? v, double lo, double hi) => v?.toDouble().clamp(lo, hi);
    int? minutes(int? v) => v != null && v >= 0 && v < 24 * 60 ? v : null;
    return BiblePrefs(
      theme: named(BibleReaderTheme.values, 'theme') ?? d.theme,
      font: named(BibleReaderFont.values, 'font') ?? d.font,
      fontSize:
          clamp(pick<num>('fontSize'), minFontSize, maxFontSize) ?? d.fontSize,
      lineHeight:
          clamp(pick<num>('lineHeight'), minLineHeight, maxLineHeight) ??
              d.lineHeight,
      speechRate: clamp(pick<num>('speechRate'), 0.5, 2) ?? d.speechRate,
      verseReminder: pick<bool>('verseReminder') ?? d.verseReminder,
      verseReminderMinutes:
          minutes(pick<int>('verseReminderMinutes')) ?? d.verseReminderMinutes,
      planReminder: pick<bool>('planReminder') ?? d.planReminder,
      planReminderMinutes:
          minutes(pick<int>('planReminderMinutes')) ?? d.planReminderMinutes,
    );
  }
}

/// Les réglages, chargés une fois puis tenus en mémoire.
final biblePrefsProvider =
    NotifierProvider<BiblePrefsNotifier, BiblePrefs>(BiblePrefsNotifier.new);

class BiblePrefsNotifier extends Notifier<BiblePrefs> {
  /// `false` jusqu'à la première lecture : un réglage fait avant ne doit pas
  /// être écrasé par la lecture qui arrive après.
  bool _touched = false;

  @override
  BiblePrefs build() {
    unawaited(_load());
    return const BiblePrefs();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    try {
      final row = await (db.select(db.appSettings)
            ..where((t) => t.key.equals(kBiblePrefsKey)))
          .getSingleOrNull();
      if (!_touched && ref.mounted) state = BiblePrefs.parse(row?.value);
    } on Object {
      // Base fermée (test, sortie) : les défauts restent.
    }
  }

  /// Applique [change] et l'écrit.
  Future<void> update(BiblePrefs Function(BiblePrefs) change) async {
    _touched = true;
    state = change(state);
    final db = ref.read(appDatabaseProvider);
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(kBiblePrefsKey),
            value: Value(jsonEncode(state.toJson())),
          ),
        );
  }
}
