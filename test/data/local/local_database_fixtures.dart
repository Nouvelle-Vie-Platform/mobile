/// Fabriques partagées des tests du magasin local.
///
/// Tout se joue sur une base **en mémoire**, donc sur la VM Dart, **sans
/// appareil** : le magasin est la pièce du chantier qui se corrige le plus mal
/// une fois publiée, il doit se vérifier en une seconde.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';

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

/// Une rubrique de **rassemblement**. Même forme que [teachingTypeRow] — c'est
/// le même référentiel côté serveur, l'autre famille — mais une **destination
/// différente** : la barrière de type est ce qui rend impossible d'écrire une
/// rubrique de concert dans le référentiel de la médiathèque.
GatheringTypesCompanion gatheringTypeRow(
  int id, {
  required Map<String, String> label,
  String slug = 'rubrique',
  String? color,
  int position = 0,
  bool visibleOnHome = true,
  String? layout,
}) =>
    GatheringTypesCompanion.insert(
      id: Value(id),
      label: label,
      slug: slug,
      color: Value(color),
      position: Value(position),
      visibleOnHome: Value(visibleOnHome),
      layout: Value(layout),
    );

/// Un rassemblement. `teachingTypeId` porte le nom de la colonne FK du fil
/// (la verrue assumée du protocole) et désigne une ligne de `gathering_types`.
GatheringsCompanion gatheringRow(
  String id, {
  String title = 'Concert de louange',
  int? contributorId,
  int? teachingTypeId,
  String? color,
  DateTime? publishedAt,
  String? recordedAt,
}) =>
    GatheringsCompanion.insert(
      id: id,
      title: title,
      contributorId: Value(contributorId),
      teachingTypeId: Value(teachingTypeId),
      color: Value(color),
      publishedAt: Value(publishedAt),
      recordedAt: Value(recordedAt),
    );

/// Un **fond de statut**. Les trois arrêts du dégradé arrivent dérivés par le
/// serveur (ADR-0030) : le magasin les stocke bruts, le client peint.
StatusBackgroundsCompanion statusBackgroundRow(
  int id, {
  /// Carte de traduction entière, comme le serveur la sert (`jsonb`, ADR-0023).
  Map<String, String> label = const {'fr': 'Bleu de marque'},
  String baseColor = '#223B8C',
  String topColor = '#2E4CAE',
  String bottomColor = '#16265C',
  String ink = 'light',
  int position = 0,
  bool isActive = true,
}) =>
    StatusBackgroundsCompanion.insert(
      id: Value(id),
      label: label,
      baseColor: baseColor,
      topColor: topColor,
      bottomColor: bottomColor,
      ink: ink,
      position: Value(position),
      isActive: Value(isActive),
    );

/// Un **compte officiel d'église**. C'est lui qui porte l'en-tête d'un statut :
/// `shortName ?? name`, résolu à la lecture.
OfficialAccountsCompanion officialAccountRow(
  int id, {
  String name = 'Maison du Miracle',
  String? shortName,
  int? branchId,
  String? avatarUrl,
  int? backgroundId,
  bool isActive = true,
}) =>
    OfficialAccountsCompanion.insert(
      id: Value(id),
      name: name,
      shortName: Value(shortName),
      branchId: Value(branchId),
      avatarUrl: Value(avatarUrl),
      backgroundId: Value(backgroundId),
      isActive: Value(isActive),
    );

/// Une **appartenance** — la mienne, par construction de la collection.
OfficialAccountMembershipsCompanion membershipRow(
  int id, {
  int accountId = 1,
  String userId = 'b6f0a1c2-0000-4000-8000-000000000001',
}) =>
    OfficialAccountMembershipsCompanion.insert(
      id: Value(id),
      accountId: accountId,
      userId: userId,
    );

/// Une **annonce**. `accountId` et `backgroundId` sont des **entiers nus** :
/// rien n'oblige la cible à exister, et l'annonce s'affiche quand même.
AnnouncementsCompanion announcementRow(
  String id, {
  int accountId = 1,
  String? title,
  String? body,
  DateTime? publishedAt,
  DateTime? expiresAt,
  int? backgroundId,
  String? backgroundImageUrl,
  bool isPinned = false,
}) =>
    AnnouncementsCompanion.insert(
      id: id,
      accountId: accountId,
      title: Value(title),
      body: Value(body),
      publishedAt: publishedAt ?? DateTime.utc(2026, 5, 1, 8),
      expiresAt: Value(expiresAt),
      backgroundId: Value(backgroundId),
      backgroundImageUrl: Value(backgroundImageUrl),
      isPinned: Value(isPinned),
    );

/// Un **invité** d'un contenu de médiathèque (#77).
///
/// `teachingId` et `contributorId` sont des **valeurs nues** : rien n'oblige ni
/// l'enseignement ni l'intervenant à être déjà en magasin, et c'est ce qui permet
/// d'écrire le cas qui compte — un crédit dont la ligne `contributors` n'est pas
/// encore arrivée.
///
/// `position` est **1-based**, comme côté serveur.
TeachingGuestsCompanion teachingGuestRow(
  int id, {
  required int contributorId,
  String teachingId = 't-1',
  int position = 1,
}) =>
    TeachingGuestsCompanion.insert(
      id: Value(id),
      teachingId: teachingId,
      contributorId: contributorId,
      position: Value(position),
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
  String? playlistUrl,
}) =>
    TeachingsCompanion.insert(
      id: id,
      title: title,
      contributorId: Value(contributorId),
      teachingTypeId: Value(teachingTypeId),
      color: Value(color),
      publishedAt: Value(publishedAt),
      recordedAt: Value(recordedAt),
      playlistUrl: Value(playlistUrl),
    );

/// Un **document légal**. Les sections arrivent **brutes**, cartes de
/// traduction entières comprises : la langue se décide à la lecture et sur le
/// document entier (`resolveLegalLocale`, ADR-0035).
LegalDocumentsCompanion legalDocumentRow(
  int id, {
  String kind = 'cgu',
  int version = 1,
  int? lastMandatoryVersion,
  List<LegalSection> sections = const [],
  DateTime? publishedAt,
  DateTime? updatedAt,
}) =>
    LegalDocumentsCompanion.insert(
      id: Value(id),
      kind: kind,
      version: Value(version),
      lastMandatoryVersion: Value(lastMandatoryVersion),
      sections: sections,
      publishedAt: Value(publishedAt),
      updatedAt: Value(updatedAt),
    );
