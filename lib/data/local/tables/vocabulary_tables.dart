/// Table de la collection répliquée `presentation_vocabulary` — **les mots que
/// l'église a réglés depuis le portail** (#81, jumelle serveur #466).
///
/// Les règles de `mediatheque_tables.dart` valent ici mot pour mot : aucune clé
/// étrangère entre collections, **on stocke ce que le serveur envoie**, chaque
/// ligne porte son jeton d'écriture ([SyncedRow]).
///
/// ## Une surcharge, jamais une traduction
///
/// La traduction vit dans les `.arb` et continue d'évoluer avec le code. Ce que
/// cette table porte la **recouvre**, clé par clé. `null` n'est donc pas un
/// champ vide à remplir : c'est « garde le mot du dépôt » — et c'est la seule
/// forme sous laquelle un retour en arrière peut voyager, puisque la ligne ne
/// se supprime jamais côté serveur (`SaveVocabulary` écrit `null`, il ne
/// `delete` pas). D'où l'absence de tombstone, qui n'est pas un oubli.
///
/// ## Une table, deux natures
///
/// [kind] vaut `'term'` ou `'label'`. Un **terme** remplit [singular] et
/// [plural] — un mot métier et ses deux formes, pour les endroits où il est
/// *seul*. Une **surcharge de libellé** remplit [label] — une carte posée sur
/// une clé de dictionnaire existante. Un CHECK serveur interdit de mélanger les
/// deux ; le magasin ne le rejoue pas, il n'a pas à refuser une ligne dont le
/// serveur est l'autorité.
///
/// Une seule table ici parce qu'il n'y a **qu'une** collection sur le fil : une
/// collection est adossée à un modèle et à un curseur, et deux tables auraient
/// imposé deux clés de protocole figées à vie pour une distinction que le
/// client lit de toute façon dans [kind].
///
/// ## `id` est la clé du catalogue, en **texte**
///
/// `teaching` pour un terme, `sectionLatestTeachings` ou `home.rail.label` pour
/// une surcharge. La colonne s'appelle `id` et non `key` parce que *toute
/// collection synchronisable porte `(updated_at, id)`* — le curseur composé
/// l'exige, et le serveur l'écrit en SQL brut.
library;

import 'package:drift/drift.dart';

import '../converters/i18n_map_converter.dart';
import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `presentation_vocabulary` (partition `reference` : un mot
/// n'appartient à aucune branche, et le porteur sans compte lit la même façade
/// qu'un membre).
@DataClassName('VocabularyRow')
class PresentationVocabulary extends Table with SyncedRow {
  @override
  String get tableName => 'presentation_vocabulary';

  /// La clé du catalogue — **une chaîne**, à la différence des autres
  /// référentiels (PK `SERIAL`). C'est le premier référentiel du dépôt dans ce
  /// cas, et le tri `(updated_at, id)` y reste total et déterministe.
  TextColumn get id => text()();

  /// `'term'` ou `'label'`. Stockée **telle quelle**, jamais refermée sur un
  /// enum : le magasin n'a pas à refuser une nature qu'il ne connaîtrait pas
  /// encore. La déduire de la forme de la clé — « contient-elle un point ? » —
  /// serait une convention qu'un seul renommage casserait en silence.
  TextColumn get kind => text()();

  /// Le singulier d'un **terme**. `null` = le mot du dépôt. Toujours `null`
  /// pour une surcharge de libellé.
  TextColumn get singular => text().map(const I18nMapConverter()).nullable()();

  /// Le pluriel d'un **terme**, écrit à la main au portail. **Aucun accord
  /// n'est jamais calculé** : une phrase composée est sa propre clé, surchargée
  /// entière (décision de cadrage, pas un report).
  TextColumn get plural => text().map(const I18nMapConverter()).nullable()();

  /// La surcharge d'un **libellé**. `null` = le libellé du dépôt. Toujours
  /// `null` pour un terme.
  TextColumn get label => text().map(const I18nMapConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
