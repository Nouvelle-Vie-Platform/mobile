/// Table de la collection répliquée `device_settings` — le **réglage
/// d'exploitation du parc installé**, et par lui le seuil du bandeau de mise à
/// jour (#91, jumelle serveur #475).
///
/// Les règles de `mediatheque_tables.dart` valent ici mot pour mot : aucune clé
/// étrangère entre collections, **on stocke ce que le serveur envoie**, chaque
/// ligne porte son jeton d'écriture ([SyncedRow]).
///
/// ## Un **réglage d'appareil**, et le vocabulaire est à respecter
///
/// « Réglage d'appareil » = ce qui vaut pour le parc installé. Distinct du
/// **vocabulaire** (`presentation_vocabulary`, les mots que l'église règle) et
/// des **canaux** (`auth_channels`, par quelles portes on entre), qui ont
/// chacun leur collection. Ni « configuration » ni « préférence » : une
/// préférence serait celle d'une personne, celle-ci est celle de
/// l'exploitation.
///
/// ## Une collection **neuve**, jamais l'élargissement d'une autre
///
/// `decor` et `auth_channels` ont à un champ près la même forme, et le réflexe
/// aurait été d'ajouter le seuil à l'un des deux. Ce serait faux, et le
/// descripteur serveur le dit : un réglage d'**exploitation** n'habille rien et
/// n'ouvre aucune porte, et surtout une collection élargie **contamine** les
/// clients qui ne savent pas la lire, là où une collection neuve est simplement
/// ignorée par eux.
///
/// ## Une table pour **une ligne**
///
/// Côté serveur, `device_settings` est un singleton (`id = 1`, garanti par la
/// clé primaire **et** un CHECK `device_settings_single_row`). La table n'en
/// portera donc jamais qu'une — même patron que `decor` et `auth_channels`, et
/// le même argument : passer par le flux delta donne gratuitement ce qu'il
/// aurait fallu écrire à la main derrière une route dédiée, à savoir *quand* la
/// valeur a changé. Un `GET /device-settings` obligerait à choisir entre
/// redemander à chaque ouverture et garder indéfiniment un seuil que le portail
/// a déplacé — c'est-à-dire, ici, inviter à monter vers une version qu'on vient
/// de retirer, ou se taire après qu'on a décidé d'inviter.
///
/// ## Aucune ligne et une colonne nulle mènent au **même repli**
///
/// Une table **vide** veut dire « je n'ai pas encore reçu les réglages » ; une
/// ligne dont le seuil est `null` veut dire « aucun seuil réglé ». Côté serveur
/// la distinction existe et voyage exprès ; côté client elle ne change **rien** :
/// dans les deux cas il n'y a pas de seuil, donc **pas de bandeau**. C'est
/// `DeviceSettingsDao` qui le dit, en un seul endroit, et c'est la décision
/// explicite de #80 — un bandeau qui apparaîtrait par défaut sur la toute
/// première version serait le plus mauvais premier contact possible.
///
/// ## Pas de tombstone, et aucun besoin
///
/// Le singleton ne se supprime pas : **retirer** le seuil met la colonne à
/// `null`, et c'est cette ligne-là qui voyage. La disparition se propage donc
/// par le flux normal, sans mécanisme de plus.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `device_settings` (partition `reference`, aucun filtre de
/// périmètre : un parc d'appareils n'appartient à aucune branche — il n'y a pas
/// une version recommandée à Lomé et une autre à Aného).
///
/// Elle est servie **sans compte** côté serveur (`servesAnonymous: true`), et
/// ce n'est pas un confort : un invité utilise l'application, et son APK est
/// exactement aussi vieux que celui du membre assis à côté de lui. Sans ce
/// drapeau, deux téléphones côte à côte sur la même version périmée n'auraient
/// qu'un seul avertissement.
@DataClassName('DeviceSettingsRow')
class DeviceSettings extends Table with SyncedRow {
  @override
  String get tableName => 'device_settings';

  /// `integer` côté serveur et non `SERIAL` — il n'y aura jamais qu'une ligne.
  /// Vaut toujours `1`, mais la colonne existe parce que le curseur composé du
  /// protocole en a besoin, et parce qu'une table locale n'a pas à supposer ce
  /// que le serveur garantit.
  IntColumn get id => integer()();

  /// **La plus basse version encore recommandée**, telle que `1.4.0`. `null` =
  /// aucun seuil réglé, donc **aucun bandeau pour personne**.
  ///
  /// Une **chaîne**, et pas trois entiers : c'est la version que l'application
  /// annonce (`package_info_plus`), et la comparer est l'affaire de qui la lit
  /// (`compareAppVersions`). La découper au stockage inventerait ici une
  /// sémantique de version que le client détient déjà.
  ///
  /// ⚠️ `null`, jamais la chaîne vide — le transformer serveur le garantit et
  /// le dit : une chaîne vide passerait le test `threshold == null`, irait
  /// jusqu'à `compareAppVersions` et s'y ferait rejeter **par chance**, pas par
  /// contrat.
  TextColumn get updateBannerMinVersion => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
