import 'package:drift/drift.dart';

import '../../models/media_preferences.dart';
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
    return select(appSettings).watch().map((rows) {
      final byKey = {for (final row in rows) row.key: row.value};
      return MediaPreferences(
        streaming: MediaQuality.parse(byKey[MediaUsage.streaming.key]),
        live: MediaQuality.parse(byKey[MediaUsage.live.key]),
        download: MediaQuality.parse(byKey[MediaUsage.download.key]),
      );
    });
  }

  /// Pose la qualité d'un usage. Écrase la valeur précédente s'il y en avait
  /// une — le réglage n'a pas d'historique.
  Future<void> setMediaQuality(MediaUsage usage, MediaQuality quality) {
    return into(appSettings).insert(
      AppSettingsCompanion.insert(key: usage.key, value: quality.key),
      mode: InsertMode.insertOrReplace,
    );
  }
}
