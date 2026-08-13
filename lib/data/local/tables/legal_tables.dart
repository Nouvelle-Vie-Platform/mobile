/// Table de la collection répliquée `legal_documents` — CGU, politique de
/// confidentialité et présentation.
///
/// Les trois règles de `mediatheque_tables.dart` valent ici mot pour mot :
/// aucune clé étrangère entre collections, **on stocke ce que le serveur
/// envoie**, chaque ligne porte son jeton d'écriture ([SyncedRow]).
///
/// ## Pourquoi la collection, et pas un `GET /legal/:kind`
///
/// La barrière de consentement (#56) doit afficher **hors ligne** le document
/// qu'elle demande d'accepter. Un endpoint de lecture ferait dépendre l'écran
/// le plus contraignant de l'application d'une requête réseau, et c'est le
/// fidèle au réseau intermittent qui le paierait. Le magasin est autoritaire ;
/// le réseau ne peint jamais (ADR-0026).
///
/// ## Ni tombstone, ni brouillon
///
/// **Un document ne se supprime pas, il s'édite** : le descripteur serveur
/// pose `tombstoneColumn: null`, comme `contributors` et `teaching_types`. La
/// table ne porte qu'une ligne courante par genre, et cette ligne *est*
/// l'édition publiée — il n'existe pas de brouillon à filtrer.
library;

import 'package:drift/drift.dart';

import '../converters/legal_sections_converter.dart';
import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `legal_documents` (partition `reference`, aucun filtre de
/// périmètre : un document légal n'appartient à aucune branche et part aux
/// trois lecteurs de la même façon).
///
/// **Deux colonnes du serveur ne voyagent pas et n'ont donc pas de place ici**
/// (`legal_document_transformer.ts`) : `publishedBy` — responsabilité interne,
/// le nom d'un pasteur n'a pas à voyager sur cinq mille téléphones — et
/// `requiresReacceptance`, dont le client n'a aucun usage. C'est
/// [lastMandatoryVersion] qui décide de la barrière, un entier contre un
/// entier ; servir le drapeau inviterait à recoder la règle côté mobile, et à
/// la recoder **faux**.
@DataClassName('LegalDocumentRow')
class LegalDocuments extends Table with SyncedRow {
  @override
  String get tableName => 'legal_documents';

  /// PK **SERIAL** côté serveur : un référentiel administrable ne se crée
  /// jamais hors ligne.
  IntColumn get id => integer()();

  /// `cgu`, `privacy` ou `about`. Stocké **tel quel**, jamais en enum : le
  /// magasin n'a pas à refuser une ligne dont il ne connaîtrait pas le genre —
  /// il n'aurait alors ni la ligne, ni le moyen d'apprendre qu'elle existe.
  /// C'est la lecture qui ne demande que les genres qu'un écran sait rendre.
  TextColumn get kind => text()();

  /// Numéro d'édition courante, écrit par le serveur. S'affiche au pied du
  /// document.
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// **Plancher d'acceptation** — la version en deçà de laquelle il faut
  /// ré-accepter. `null` = aucune acceptation exigée (c'est toujours le cas de
  /// `about`).
  ///
  /// Dérivée par le serveur à l'écriture, précisément pour que le client n'ait
  /// pas à la recalculer : un fidèle resté en v2 pendant que passaient 3
  /// (typo), 4 (substantielle) et 5 (typo) doit être arrêté, alors même que
  /// l'édition courante n'exige rien.
  IntColumn get lastMandatoryVersion => integer().nullable()();

  /// Les sections **brutes**, dans l'ordre de lecture, cartes de traduction
  /// entières comprises. La langue se décide à la lecture et **sur le document
  /// entier** (`resolveLegalLocale`, ADR-0035).
  TextColumn get sections => text().map(const LegalSectionsConverter())();

  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
