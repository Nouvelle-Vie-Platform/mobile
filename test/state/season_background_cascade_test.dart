/// **La cascade du fond**, en entier, sur un vrai magasin.
///
/// Quatre étages — vertical de la saison, son paysage, vertical du décor, son
/// paysage — et l'ordre *est* la règle. Aucun écran ne la vérifierait : un fond
/// pris au mauvais étage s'affiche parfaitement, il est simplement le mauvais,
/// et personne ne le remarque avant la saison suivante.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/state/season_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> season({
    required String startsOn,
    required String endsOn,
    String landscape = '/uploads/backgrounds/seasons/paysage.webp',
    String? vertical,
    int id = 1,
  }) {
    return db.into(db.seasons).insert(
          SeasonsCompanion.insert(
            id: Value(id),
            name: 'Saison',
            backgroundUrl: landscape,
            backgroundVerticalUrl: Value(vertical),
            startsOn: startsOn,
            endsOn: endsOn,
          ),
        );
  }

  Future<void> decor({String? landscape, String? vertical}) {
    return db.into(db.decor).insert(
          DecorCompanion.insert(
            id: const Value(1),
            backgroundUrl: Value(landscape),
            backgroundVerticalUrl: Value(vertical),
          ),
        );
  }

  Future<String?> resolve({String day = '2026-12-15'}) async {
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        seasonDayProvider.overrideWithValue(day),
      ],
    );
    return container.read(seasonBackgroundUrlProvider.future);
  }

  test('1er étage — le vertical de la saison gagne sur tout', () async {
    await season(
      startsOn: '2026-12-01',
      endsOn: '2026-12-31',
      vertical: '/uploads/backgrounds/seasons/vertical.webp',
    );
    await decor(
      landscape: '/uploads/decor/paysage.webp',
      vertical: '/uploads/decor/vertical.webp',
    );

    expect(await resolve(),
        endsWith('/uploads/backgrounds/seasons/vertical.webp'));
  });

  test('2e étage — sans vertical, le paysage de la saison, pas le décor',
      () async {
    await season(startsOn: '2026-12-01', endsOn: '2026-12-31');
    await decor(vertical: '/uploads/decor/vertical.webp');

    // Une image mal cadrée reste plus informative qu'une image qui n'est pas
    // celle de la saison en cours. Descendre à l'étage suivant ferait afficher
    // le décor ordinaire pendant Noël.
    expect(
        await resolve(), endsWith('/uploads/backgrounds/seasons/paysage.webp'));
  });

  test('3e étage — hors saison, le vertical du décor', () async {
    await season(
      startsOn: '2026-12-01',
      endsOn: '2026-12-31',
      vertical: '/uploads/backgrounds/seasons/vertical.webp',
    );
    await decor(
      landscape: '/uploads/decor/paysage.webp',
      vertical: '/uploads/decor/vertical.webp',
    );

    expect(await resolve(day: '2026-06-15'),
        endsWith('/uploads/decor/vertical.webp'));
  });

  test('4e étage — décor sans vertical, son paysage', () async {
    await decor(landscape: '/uploads/decor/paysage.webp');

    expect(await resolve(), endsWith('/uploads/decor/paysage.webp'));
  });

  test('rien du tout → null, et ce n\'est pas une erreur', () async {
    // Magasin vide : premier lancement, ou installation sans décor déposé.
    // L'appelant retombe sur l'image de son dépôt, puis sur l'aplat de couleur.
    expect(await resolve(), isNull);
  });

  test('une ligne de décor vide n\'est pas une absence de ligne', () async {
    // Le serveur sert la ligne même sans décor déposé : c'est ce qui distingue
    // « pas encore reçu les réglages » de « il n'y a pas de décor ». Les deux
    // rendent `null` ici, mais par des chemins différents — et ce test existe
    // pour que le second ne devienne jamais une exception.
    await decor();

    expect(await resolve(), isNull);
  });

  test('l\'adresse est résolue contre l\'hôte de l\'API', () async {
    await decor(vertical: '/uploads/decor/vertical.webp');

    final url = await resolve();
    // Relative en base, absolue à la sortie : sans quoi `Image` échoue faute de
    // schéma, et le fond manque sans que rien ne le dise.
    expect(url, startsWith('http'));
  });
}
