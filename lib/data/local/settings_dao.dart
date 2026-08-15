import 'package:drift/drift.dart';

import '../../models/media_preferences.dart';
import '../../models/theme_preferences.dart';
import 'app_database.dart';
import 'tables/settings_tables.dart';

part 'settings_dao.g.dart';

/// Lecture et écriture des **réglages locaux**.
///
/// C'est le seul DAO du dépôt qui écrive sur ordre d'un écran, et c'est normal :
/// `app_settings` n'est pas une collection répliquée. La règle « le client
/// n'écrit jamais dans une collection synchronisée » ne la concerne pas — rien
/// ici ne remonte au serveur, et rien n'en redescend.
///
/// Les préférences se lisent en **`Stream`**, comme le reste du magasin : le
/// panneau de réglages et le lecteur observent la même source, et changer la
/// qualité pendant qu'un prêche joue doit atteindre le lecteur sans que
/// personne ne les recâble.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Les trois réglages, recomposés à chaque changement de la table.
  ///
  /// Une ligne absente **n'est pas une erreur** : c'est le cas normal d'une
  /// installation neuve, et `MediaQuality.parse` rend alors le défaut. On ne
  /// pré-remplit donc pas la table à la migration — une valeur écrite d'office
  /// serait indiscernable d'un choix, et changer le défaut dans une version
  /// suivante ne toucherait plus personne.
  Stream<MediaPreferences> watchMediaPreferences() {
    return select(appSettings).watch().map(_mediaPreferencesFrom);
  }

  MediaPreferences _mediaPreferencesFrom(List<AppSettingRow> rows) {
    final byKey = {for (final row in rows) row.key: row.value};
    return MediaPreferences(
      streaming: MediaQuality.parse(byKey[MediaUsage.streaming.key]),
      live: MediaQuality.parse(byKey[MediaUsage.live.key]),
      download: MediaQuality.parse(byKey[MediaUsage.download.key]),
      // Absent = wifi seulement (F8), le défaut sûr. Seul `'true'` autorise le
      // cellulaire : toute autre valeur (base bricolée) retombe côté prudent.
      downloadOnCellular: byKey[_downloadOnCellularKey] == 'true',
    );
  }

  /// La contrainte réseau des téléchargements, en une lecture **ponctuelle** —
  /// pas un flux : `DownloadManager.mobileDataAllowed` la consulte au moment de
  /// lancer ou reprendre, et un flux Drift jamais refermé n'a pas sa place dans
  /// ce chemin. Absent = `false` (wifi seulement, F8).
  Future<bool> downloadOnCellular() async {
    return _mediaPreferencesFrom(await select(appSettings).get())
        .downloadOnCellular;
  }

  /// Les réglages d'**apparence**, recomposés à chaque changement.
  ///
  /// Trois clés dans la même table clé/valeur que les réglages média : le
  /// choix, et les deux heures de la règle `auto`. Aucune migration n'a été
  /// nécessaire — c'est précisément ce pour quoi cette table est clé/valeur.
  ///
  /// Comme ailleurs, **une ligne absente n'est pas une erreur** : c'est le cas
  /// normal d'une installation neuve, et chaque `parse` rend alors le défaut.
  Stream<ThemePreferences> watchThemePreferences() {
    return select(appSettings).watch().map((rows) {
      final byKey = {for (final row in rows) row.key: row.value};
      return ThemePreferences(
        choice: ThemeChoice.parse(byKey[_themeChoiceKey]),
        darkFrom:
            DayTime.parse(byKey[_darkFromKey], fallback: kDefaultDarkFrom),
        lightFrom:
            DayTime.parse(byKey[_lightFromKey], fallback: kDefaultLightFrom),
      );
    });
  }

  Future<void> setThemeChoice(ThemeChoice choice) =>
      _put(_themeChoiceKey, choice.key);

  Future<void> setDarkFrom(DayTime time) => _put(_darkFromKey, time.key);

  Future<void> setLightFrom(DayTime time) => _put(_lightFromKey, time.key);

  Future<void> _put(String key, String value) {
    return into(appSettings).insert(
      AppSettingsCompanion.insert(key: key, value: value),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Les clés sont **stables** : les renommer basculerait silencieusement tous
  /// les appareils installés sur le défaut.
  static const String _themeChoiceKey = 'theme_choice';
  static const String _darkFromKey = 'theme_dark_from';
  static const String _lightFromKey = 'theme_light_from';

  /// La clé du toggle « données mobiles » des téléchargements. Distincte des
  /// clés d'usage (`download` porte la **qualité**) : le réseau autorisé et le
  /// débit sont deux réglages, pas un.
  static const String _downloadOnCellularKey = 'download_on_cellular';

  /// Pose la qualité d'un usage. Écrase la valeur précédente s'il y en avait
  /// une — le réglage n'a pas d'historique.
  Future<void> setMediaQuality(MediaUsage usage, MediaQuality quality) =>
      _put(usage.key, quality.key);

  /// Autorise (ou non) les téléchargements en données mobiles (F8).
  Future<void> setDownloadOnCellular(bool allowed) =>
      _put(_downloadOnCellularKey, allowed ? 'true' : 'false');
}
