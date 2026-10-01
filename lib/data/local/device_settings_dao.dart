import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/device_tables.dart';

part 'device_settings_dao.g.dart';

/// **Les lectures du magasin, côté réglage d'appareil** (#91).
///
/// Une seule question : **quel est le seuil du bandeau de mise à jour ?** La
/// réponse tient en une ligne — `device_settings` est un singleton côté
/// serveur — et c'est ici, et nulle part ailleurs, que l'absence de seuil se
/// nomme.
///
/// ## Le repli vit ici, en un seul endroit : **pas de seuil, pas de bandeau**
///
/// Deux états différents côté serveur mènent au même `null` ici, et c'est
/// voulu :
///
/// - **table vide** — « je n'ai pas encore reçu les réglages », c'est-à-dire
///   avant le premier cycle, ou après un `404` de collection sur un serveur en
///   retard d'une version ;
/// - **ligne présente, colonne nulle** — « aucun seuil réglé », la valeur
///   livrée par la migration serveur.
///
/// Le client n'a aucune raison de les distinguer : dans les deux cas il n'y a
/// pas de seuil, donc aucun bandeau. Jamais l'inverse — c'est la décision
/// explicite de #80, et un bandeau « mettez à jour » apparu par défaut sur la
/// toute première version serait le plus mauvais premier contact possible.
///
/// Écrire cette règle dans le widget l'aurait dupliquée au premier second
/// lecteur, et deux replis finissent par ne plus dire la même chose.
@DriftAccessor(tables: [DeviceSettings])
class DeviceSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$DeviceSettingsDaoMixin {
  DeviceSettingsDao(super.db);

  /// Le seuil, **observé** : le portail peut le poser, le déplacer ou le
  /// retirer, et le bandeau doit suivre au cycle de synchronisation suivant —
  /// sans qu'on rouvre l'application.
  ///
  /// Un `Stream` et non un `Future`, pour la raison qui vaut partout dans ce
  /// dépôt : une photographie prise au montage figerait le seuil jusqu'à la
  /// prochaine navigation. Et elle compte ici dans les deux sens — se taire
  /// après qu'on a retiré le seuil est aussi important que paraître après qu'on
  /// l'a posé.
  Stream<String?> watchUpdateBannerMinVersion() =>
      _query().watch().map(_thresholdOf);

  /// Le même, **une fois**. Sert aux tests ; l'application, elle, observe.
  Future<String?> readUpdateBannerMinVersion() async =>
      _thresholdOf(await _query().get());

  /// La table n'a qu'une ligne (le singleton serveur), mais la lecture ne le
  /// suppose pas : `getSingleOrNull` sur une table qui en porterait deux
  /// lèverait, là où `limit(1)` rend simplement la première. Un magasin local
  /// n'a pas à se fier à un CHECK posé dans une autre base — et la coquille de
  /// l'application est le dernier endroit où l'on veut une exception.
  Selectable<DeviceSettingsRow> _query() => (select(deviceSettings)
    ..orderBy([(row) => OrderingTerm.asc(row.id)])
    ..limit(1));

  /// Table vide **et** colonne nulle rendent le même `null` : voir l'en-tête.
  String? _thresholdOf(List<DeviceSettingsRow> rows) =>
      rows.isEmpty ? null : rows.first.updateBannerMinVersion;
}
