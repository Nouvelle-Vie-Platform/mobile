/// **La mémoire de la mention légale**, contre une vraie base.
///
/// Le bandeau se vérifie à l'écran ailleurs (`test/screens/legal_notice_test.dart`)
/// avec un double en mémoire. Ce qu'un double ne peut pas prouver est ici : que la
/// fermeture **survit au lancement suivant**, et qu'elle ne marche pas sur les
/// autres réglages de la même table clé/valeur.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/legal_notice_store.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';

import 'local/local_database_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('une base neuve n\'a rien vu : le bandeau paraît', () async {
    // **L'absence de ligne est le défaut**, comme pour tous les réglages de cette
    // table : rien n'est pré-rempli à la migration. Une valeur écrite d'office
    // serait indiscernable d'une fermeture par le fidèle.
    expect(await SettingsLegalNoticeStore(db).seen(), isFalse);
  });

  test('la fermeture survit au lancement suivant', () async {
    await SettingsLegalNoticeStore(db).markSeen();

    // Un **autre** exemplaire, comme au lancement suivant : ce qui est vérifié
    // est la ligne en base, pas un champ retenu en mémoire.
    expect(await SettingsLegalNoticeStore(db).seen(), isTrue);
  });

  test('deux fermetures ne font pas deux lignes', () async {
    final store = SettingsLegalNoticeStore(db);
    await store.markSeen();
    await store.markSeen();

    final rows = await db.select(db.appSettings).get();
    // `InsertMode.insertOrReplace` sur une clé primaire textuelle : le double
    // appui d'un bouton ne doit pas lever sur une contrainte d'unicité.
    expect(rows.where((row) => row.key == SettingsLegalNoticeStore.key),
        hasLength(1));
    expect(await store.seen(), isTrue);
  });

  test('elle ne marche pas sur les autres réglages de la table', () async {
    // La table est clé/valeur et **partagée** : apparence, réglages média, file
    // des écoutes, branche préférée. Un drapeau qui écraserait la ligne voisine
    // éteindrait le thème choisi, et personne ne ferait le lien.
    await db.settingsDao.setThemeChoice(ThemeChoice.dark);
    await SettingsLegalNoticeStore(db).markSeen();

    final theme = await db.settingsDao.watchThemePreferences().first;
    expect(theme.choice, ThemeChoice.dark);
    expect(await SettingsLegalNoticeStore(db).seen(), isTrue);
  });

  test('une valeur inconnue retombe du côté qui informe', () async {
    // Base bricolée, ou version antérieure du drapeau : seule `'true'` vaut
    // « déjà vu ». Se tromper ici coûte un bandeau de trop, jamais une mention
    // légale escamotée.
    await db.customStatement(
      "INSERT INTO app_settings (key, value) VALUES ('${SettingsLegalNoticeStore.key}', 'oui')",
    );

    expect(await SettingsLegalNoticeStore(db).seen(), isFalse);
  });
}
