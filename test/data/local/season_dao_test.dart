/// **La saison du jour se décide ici**, et nulle part ailleurs.
///
/// Le serveur sert la table entière et ne tranche pas : il ne peut pas, parce
/// que le jour qui compte est celui du téléphone — y compris hors ligne, et y
/// compris à minuit, quand aucune synchronisation n'a lieu.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/season_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert({
    required int id,
    required String name,
    required String startsOn,
    required String endsOn,
    String background = '/uploads/backgrounds/seasons/a-1920w.webp',
    String? vertical,
  }) {
    return db.into(db.seasons).insert(
          SeasonsCompanion.insert(
            id: Value(id),
            name: name,
            backgroundUrl: background,
            backgroundVerticalUrl: Value(vertical),
            startsOn: startsOn,
            endsOn: endsOn,
          ),
        );
  }

  Future<SeasonRow?> of(String day) =>
      db.seasonDao.seasonOfDay(day).getSingleOrNull();

  group('La saison du jour', () {
    test('les deux bornes sont incluses', () async {
      await insert(
        id: 1,
        name: 'Noël',
        startsOn: '2026-12-01',
        endsOn: '2026-12-31',
      );

      // Le premier jour **et** le dernier. Exclure le dernier ferait disparaître
      // le décor de Noël le 25 au matin, et personne ne s'en apercevrait avant
      // l'année suivante.
      expect((await of('2026-12-01'))?.name, 'Noël');
      expect((await of('2026-12-31'))?.name, 'Noël');
      expect(await of('2026-11-30'), isNull);
      expect(await of('2027-01-01'), isNull);
    });

    test('hors saison, rien — et ce n\'est pas une erreur', () async {
      expect(await of('2026-06-15'), isNull);
    });

    test('deux saisons du même jour : le plus grand id gagne', () async {
      // Le serveur interdit le chevauchement ; il ne peut pourtant pas empêcher
      // celui-ci. `seasons` n'a pas de tombstone : une saison **supprimée puis
      // recréée** sur les mêmes dates laisse l'ancienne en magasin. Le `SERIAL`
      // étant croissant, prendre le plus grand c'est prendre la recréée.
      await insert(
        id: 4,
        name: 'Effacée par erreur',
        startsOn: '2026-12-01',
        endsOn: '2026-12-31',
      );
      await insert(
        id: 9,
        name: 'Recréée',
        startsOn: '2026-12-01',
        endsOn: '2026-12-31',
      );

      expect((await of('2026-12-15'))?.name, 'Recréée');
    });

    test('la comparaison est lexicographique, et c\'est exact', () async {
      // Le piège qu'un tri naïf sur des dates non normalisées ferait tomber :
      // `2026-9-05` trierait après `2026-12-01`. Les deux bornes viennent du
      // serveur en ISO **rempli**, et `seasonDay` remplit de la même façon.
      await insert(
        id: 1,
        name: 'Septembre',
        startsOn: '2026-09-01',
        endsOn: '2026-09-30',
      );

      expect((await of('2026-09-05'))?.name, 'Septembre');
      expect(await of('2026-12-01'), isNull);
    });
  });

  group('Le jour du téléphone', () {
    test('se remplit de zéros, des deux côtés', () {
      expect(seasonDay(DateTime(2026, 1, 5)), '2026-01-05');
      expect(seasonDay(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('c\'est le jour **local**, jamais UTC', () {
      // Un instant, converti en heure locale, puis réduit à son jour. Comparer
      // en UTC ferait basculer la saison à l'heure du méridien de Greenwich, ce
      // qui se voit à l'œil nu partout sauf au Togo.
      final moment = DateTime(2026, 12, 25, 23, 30);
      expect(seasonDay(moment), '2026-12-25');
    });
  });
}
