/// **Le modèle de lecture des rassemblements** — ce qu'un écran affiche d'un
/// rassemblement, et rien de plus.
///
/// Le jumeau de `mediatheque_view.dart` pour l'autre famille, et **délibérément
/// mince** : les quatre règles de présentation (cascade de couleur, repli du
/// libellé par `pick`, résolution des URL par `resolveMediaUrl`, absence
/// d'intervenant dessinée comme une absence) sont écrites **une fois** dans
/// `content_view.dart` et valent pour les deux familles.
///
/// Ce qui justifie deux types plutôt qu'un seul, c'est ce que le système de
/// types interdit alors : un `GatheringView` ne se construit que depuis la
/// collection `gatherings`, et aucun provider, aucune route, aucun repository de
/// médiathèque ne peut en recevoir un. La clé de collection est le discriminant
/// (ADR-0026, décision 1) ; ces deux classes en sont le reflet côté client.
///
/// **Aucun champ de famille**, ici non plus : le serveur ne le sert pas, et le
/// type Dart le dit déjà.
library;

import 'content_view.dart';

export 'content_view.dart' show ContentView, SectionView, kBrandFallbackColor;

/// Un **rassemblement** tel qu'un écran l'affiche.
class GatheringView extends ContentView {
  const GatheringView({
    required super.id,
    required super.title,
    required super.color,
    super.authorName,
    super.teachingTypeId,
    super.branchId,
    super.typeLabel,
    super.imageLandscapeUrl,
    super.imagePortraitUrl,
    super.playlistUrl,
    super.description,
    super.recordedAt,
    super.publishedAt,
    super.isFullService,
  });

  /// Applique les quatre règles de lecture à une ligne `gatherings` et à ce que
  /// le magasin possède de ses références.
  ///
  /// `teachingTypeId` porte le nom du champ du fil — la verrue assumée du
  /// protocole — et désigne une ligne de **`gathering_types`**.
  GatheringView.resolve({
    required super.id,
    required super.title,
    required super.locale,
    super.contributorName,
    super.teachingTypeId,
    super.branchId,
    super.typeLabel,
    super.color,
    super.typeColor,
    super.imageLandscapeUrl,
    super.imagePortraitUrl,
    super.playlistUrl,
    super.description,
    super.recordedAt,
    super.publishedAt,
    super.isFullService,
  }) : super.resolve();
}

/// Une **rubrique de rassemblement** de l'accueil, telle qu'un écran l'affiche.
///
/// `teachingTypeId` désigne une ligne de **`gathering_types`**, jamais de
/// `teaching_types`.
class GatheringSectionView extends SectionView {
  const GatheringSectionView({
    required super.teachingTypeId,
    required super.label,
    required super.slug,
    required super.color,
    required super.itemCount,
    super.layout,
    super.position,
  });

  GatheringSectionView.resolve({
    required super.teachingTypeId,
    required super.label,
    required super.slug,
    required super.locale,
    required super.itemCount,
    super.color,
    super.layout,
    super.position,
  }) : super.resolve();
}
