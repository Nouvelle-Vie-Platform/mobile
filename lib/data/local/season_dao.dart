import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/season_tables.dart';

part 'season_dao.g.dart';

/// **Les lectures du magasin, côté saisons.**
///
/// Une seule question : quelle saison habille **aujourd'hui** ? Le serveur sert
/// la table entière et ne tranche pas — lui seul ne peut pas, parce que le jour
/// qui compte est celui du téléphone, y compris hors ligne, et parce qu'une
/// saison qui commence à minuit ne doit pas attendre un aller-retour réseau
/// pour habiller l'écran.
@DriftAccessor(tables: [Seasons])
class SeasonDao extends DatabaseAccessor<AppDatabase> with _$SeasonDaoMixin {
  SeasonDao(super.db);

  /// La saison qui couvre [day] (`YYYY-MM-DD`), ou `null` — hors saison, le
  /// lecteur garde son aplat de couleur.
  ///
  /// ## Bornes **incluses**, des deux côtés
  ///
  /// C'est le contrat du portail (« premier et dernier jour, inclus ») et la
  /// comparaison de la vitrine. Exclure le dernier jour ferait disparaître le
  /// décor de Noël **le 25 au matin**, et personne ne s'en apercevrait avant
  /// l'année suivante.
  ///
  /// ## Deux chaînes, comparées comme des chaînes
  ///
  /// En ISO, l'ordre lexicographique **est** l'ordre chronologique. Convertir
  /// en `DateTime` pour comparer poserait un instant, donc un fuseau, donc un
  /// décalage possible d'un jour — exactement ce que le stockage en texte
  /// existe pour éviter.
  ///
  /// ## Le plus grand `id` gagne, et ce n'est pas arbitraire
  ///
  /// Deux saisons ne peuvent pas se chevaucher côté serveur (contrainte
  /// d'exclusion), il ne devrait donc jamais y en avoir deux. Il peut pourtant
  /// y en avoir deux **ici** : `seasons` n'a pas de tombstone, donc une saison
  /// supprimée puis recréée sur les mêmes dates laisse l'ancienne en magasin.
  /// Le `SERIAL` étant croissant, prendre le plus grand, c'est prendre la
  /// **recréée** — c'est-à-dire réparer, sur le seul cas qui se produise en
  /// vrai, une limite qu'on ne peut pas fermer côté serveur sans reprendre la
  /// contrainte d'exclusion.
  Selectable<SeasonRow> seasonOfDay(String day) {
    return (select(seasons)
      ..where((row) => row.startsOn.isSmallerOrEqualValue(day))
      ..where((row) => row.endsOn.isBiggerOrEqualValue(day))
      ..orderBy([(row) => OrderingTerm.desc(row.id)])
      ..limit(1));
  }
}

/// Le jour de [moment] en `YYYY-MM-DD`, **tel que le téléphone le voit**.
///
/// Écrit ici et pas dans un widget : c'est la seule autorité sur la forme du
/// jour comparé aux deux bornes, et une seconde écriture finirait par différer
/// d'un zéro de remplissage — la saison ne s'allumerait alors qu'un jour sur
/// dix.
String seasonDay(DateTime moment) {
  final local = moment.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$month-$day';
}
