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

  /// Les réglages média, recomposés à chaque changement de la table.
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
      download: MediaQuality.parse(byKey[MediaUsage.download.key]),
      // Absent = wifi seulement (F8), le défaut sûr. Seul `'true'` autorise le
      // cellulaire : toute autre valeur (base bricolée) retombe côté prudent.
      downloadOnCellular: byKey[_downloadOnCellularKey] == 'true',
      radio: RadioQuality.parse(byKey[MediaUsage.radio.key]),
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

  /// **Le dernier onglet de la page Bible** (#190) : `bible` ou `notes`, tel
  /// que la page l'a écrit. Nul tant qu'on n'y a jamais changé d'onglet.
  Future<String?> bibleTab() async {
    final row = await (select(appSettings)
          ..where((s) => s.key.equals(_bibleTabKey)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setBibleTab(String tab) => _put(_bibleTabKey, tab);

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

  /// La clé de l'onglet de la page Bible (#190).
  static const String _bibleTabKey = 'bible_tab';

  /// Pose la qualité d'un usage. Écrase la valeur précédente s'il y en avait
  /// une — le réglage n'a pas d'historique.
  Future<void> setMediaQuality(MediaUsage usage, MediaQuality quality) =>
      _put(usage.key, quality.key);

  /// Pose le choix de la radio (`RadioQuality`).
  Future<void> setRadioQuality(RadioQuality quality) =>
      _put(MediaUsage.radio.key, quality.key);

  /// Autorise (ou non) les téléchargements en données mobiles (F8).
  Future<void> setDownloadOnCellular(bool allowed) =>
      _put(_downloadOnCellularKey, allowed ? 'true' : 'false');

  // ───────────────────────────────────────────────────────────────────────────
  // La préférence de branche
  // ───────────────────────────────────────────────────────────────────────────

  /// La clé de la **préférence de branche**. Stable, comme les autres : la
  /// renommer basculerait silencieusement tous les appareils installés sur
  /// « toutes les branches », donc sur un catalogue soudain plus large, sans que
  /// personne ne l'ait demandé.
  static const String _preferredBranchKey = 'preferred_branch_id';

  /// La valeur qui dit « **toutes les branches**, et c'est un choix ».
  ///
  /// Une ligne absente et cette valeur-ci produisent le même comportement — pas
  /// de `branch_id` sur le fil, tout arrive. Elles ne disent pourtant pas la
  /// même chose, et écrire la ligne plutôt que de la supprimer garde la
  /// distinction disponible : l'absence est « je n'ai jamais choisi », d'où l'on
  /// a le droit d'adopter ce que le compte propose.
  static const String _allBranches = 'all';

  /// La branche préférée, `null` = toutes. **Ponctuelle, et il n'y a pas de
  /// variante en flux** — même partage que [downloadOnCellular], et pour une
  /// raison de plus.
  ///
  /// Le moteur de synchronisation, seul consommateur, la lit une fois par cycle.
  /// Et un `watch()` sur cette table est un piège avéré : son `QueryStream`
  /// programme un `Timer` de nettoyage à l'annulation, qui reste pendant sous
  /// l'horloge factice de `testWidgets` et fait mourir tout test montant l'écran
  /// de réglages (voir l'en-tête de `test/screens/media_settings_screen_test.dart`,
  /// qui raconte la première fois). `watchMediaPreferences` le paie encore : ses
  /// tests d'écran doivent la surcharger par un flux nu.
  ///
  /// **Une valeur illisible vaut « toutes »**, jamais une exception : une base
  /// bricolée ne doit pas vider le catalogue de quelqu'un. La panne va du côté
  /// large — le contraire montrerait un écran vide sans rien pour l'expliquer.
  Future<int?> readPreferredBranch() async =>
      _preferredBranchFrom(await select(appSettings).get());

  int? _preferredBranchFrom(List<AppSettingRow> rows) {
    for (final row in rows) {
      if (row.key != _preferredBranchKey) continue;
      if (row.value == _allBranches) return null;
      return int.tryParse(row.value);
    }
    return null;
  }

  /// La préférence a-t-elle été **choisie** au moins une fois sur cet appareil ?
  ///
  /// Distinct de [readPreferredBranch] rendant `null` : « je veux toutes les
  /// branches » et « je n'ai jamais choisi » se comportent pareil sur le fil,
  /// mais seul le second autorise à adopter ce que le compte propose sans
  /// écraser une décision.
  Future<bool> hasPreferredBranchChoice() async {
    final row = await (select(appSettings)
          ..where((t) => t.key.equals(_preferredBranchKey)))
        .getSingleOrNull();
    return row != null;
  }

  /// Pose la préférence de branche. `null` = toutes les branches.
  ///
  /// **Ne remet aucun curseur à zéro** : ce n'est pas le travail d'un DAO de
  /// réglages, et confondre les deux serait une faute silencieuse. C'est
  /// `BranchScopeStore.choose` qui compose les deux dans **une** transaction, et
  /// c'est le seul appelant que cette méthode doit avoir.
  Future<void> setPreferredBranch(int? branchId) =>
      _put(_preferredBranchKey, branchId?.toString() ?? _allBranches);

  // ───────────────────────────────────────────────────────────────────────────
  // La file des écoutes non remontées
  // ───────────────────────────────────────────────────────────────────────────

  /// Clé de la file d'attente des remontées d'écoute.
  static const String _pendingPlaysKey = 'plays_pending';

  /// La file d'attente, **telle quelle**.
  ///
  /// Le format est **opaque à ce DAO** : il appartient à `PlaySpool`
  /// (`lib/data/measurement/play_spool.dart`), qui est seul à l'écrire et seul à
  /// le lire. Le ranger ici plutôt que dans une table dédiée évite une migration
  /// Drift pour une liste bornée, jamais interrogée autrement qu'en entier —
  /// c'est précisément à ça que sert une table clé/valeur.
  Future<String?> pendingPlays() async {
    final row = await (select(appSettings)
          ..where((t) => t.key.equals(_pendingPlaysKey)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Remplace la file d'attente.
  Future<void> setPendingPlays(String encoded) =>
      _put(_pendingPlaysKey, encoded);

  // ───────────────────────────────────────────────────────────────────────────
  // L'aperçu des notifications de messagerie (tranche M5)
  // ───────────────────────────────────────────────────────────────────────────

  /// « Afficher le contenu » des notifications de messages. **Défaut : oui.**
  ///
  /// Lu par le réveil de l'application **fermée**, dans son isolate et avec sa
  /// propre connexion : c'est pourquoi le réglage vit ici, dans le magasin, et
  /// non dans un état Riverpod que cet isolate ne verrait pas. Une préférence
  /// d'appareil, pas de compte : elle ne voyage pas.
  static const String _notificationPreviewKey = 'notification_preview';

  /// Absent = oui. Seul `'false'` masque : une valeur bricolée retombe sur le
  /// défaut, comme `download_on_cellular` retombe sur le sien.
  static bool _previewFrom(String? raw) => raw != 'false';

  Future<bool> notificationPreview() async {
    final row = await (select(appSettings)
          ..where((t) => t.key.equals(_notificationPreviewKey)))
        .getSingleOrNull();
    return _previewFrom(row?.value);
  }

  Stream<bool> watchNotificationPreview() {
    return (select(appSettings)
          ..where((t) => t.key.equals(_notificationPreviewKey)))
        .watchSingleOrNull()
        .map((row) => _previewFrom(row?.value));
  }

  Future<void> setNotificationPreview(bool shown) =>
      _put(_notificationPreviewKey, shown ? 'true' : 'false');
}
