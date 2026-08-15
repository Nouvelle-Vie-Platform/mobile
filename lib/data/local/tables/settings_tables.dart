/// Table des **réglages de l'application** — locale seule, jamais synchronisée.
///
/// Elle n'appartient à aucune collection du protocole : le serveur ne la sert
/// pas, ne la reçoit pas, et n'a aucune raison de la connaître. Une préférence
/// de débit décrit **le forfait de cet appareil-ci**, pas la personne : le même
/// fidèle veut la qualité maximale sur la tablette du salon et le minimum sur
/// le téléphone qu'il emporte au marché. La faire voyager d'un appareil à
/// l'autre serait un contresens, pas un confort.
///
/// **Pourquoi une table Drift et pas `shared_preferences`.** Le dépôt a déjà un
/// magasin local ; en ajouter un second ferait vivre les réglages **hors** du
/// fichier de base, et la suppression de compte — qui vide ce fichier — les
/// laisserait derrière elle. Il faudrait alors se souvenir d'un second
/// effacement, et personne ne s'en souviendrait. Ici, ils partent avec le reste
/// sans qu'on ait rien à écrire.
///
/// **Clé/valeur, et en texte.** Un réglage est ajouté par une constante, pas
/// par une migration : c'est ce qui rend l'ajout du quatrième gratuit. Le prix
/// est qu'aucune contrainte de base ne valide la valeur — c'est la lecture qui
/// s'en charge, et elle est **tolérante** : une valeur inconnue (réglage retiré
/// d'une version à l'autre, base bricolée) retombe sur le défaut plutôt que de
/// faire échouer la requête qui rendait tout un écran.
library;

import 'package:drift/drift.dart';

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  @override
  String get tableName => 'app_settings';

  /// Nom du réglage. Les valeurs vivent dans `MediaPreferenceKind`, jamais en
  /// littéral dispersé.
  TextColumn get key => text()();

  /// Valeur **brute**, telle que l'appelant l'a écrite. La conversion vers un
  /// type applicatif se fait à la lecture, avec repli.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
