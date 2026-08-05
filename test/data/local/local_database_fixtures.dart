/// Fabriques partagées des tests du magasin local.
///
/// Tout se joue sur une base **en mémoire**, donc sur la VM Dart, **sans
/// appareil** : le magasin est la pièce du chantier qui se corrige le plus mal
/// une fois publiée, il doit se vérifier en une seconde.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

/// Ouvre une base neuve, vide, en mémoire.
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Une branche minimale.
BranchesCompanion branchRow(int id, String name) =>
    BranchesCompanion.insert(id: Value(id), name: name);

/// Un intervenant minimal.
ContributorsCompanion contributorRow(int id, String name) =>
    ContributorsCompanion.insert(id: Value(id), name: name);

/// Une rubrique. [label] est la carte de traduction **entière**, telle que le
/// serveur l'envoie.
TeachingTypesCompanion teachingTypeRow(
  int id, {
  required Map<String, String> label,
  String slug = 'rubrique',
  String? color,
  int position = 0,
  bool visibleOnHome = true,
  String? layout,
}) =>
    TeachingTypesCompanion.insert(
      id: Value(id),
      label: label,
      slug: slug,
      color: Value(color),
      position: Value(position),
      visibleOnHome: Value(visibleOnHome),
      layout: Value(layout),
    );

/// Un enseignement. `contributorId` et `teachingTypeId` sont des **entiers
/// nus** : rien n'oblige la cible à exister.
TeachingsCompanion teachingRow(
  String id, {
  String title = 'Dieu a le dernier mot',
  int? contributorId,
  int? teachingTypeId,
  String? color,
  DateTime? publishedAt,
  String? recordedAt,
}) =>
    TeachingsCompanion.insert(
      id: id,
      title: title,
      contributorId: Value(contributorId),
      teachingTypeId: Value(teachingTypeId),
      color: Value(color),
      publishedAt: Value(publishedAt),
      recordedAt: Value(recordedAt),
    );
