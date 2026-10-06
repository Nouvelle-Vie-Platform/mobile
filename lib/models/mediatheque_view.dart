/// **Le modèle de lecture de la médiathèque** — ce qu'un écran affiche d'un
/// **enseignement**, et rien de plus.
///
/// Décision 3 d'ADR-0026 : *le magasin stocke ce que le serveur envoie ; la
/// présentation se calcule à la lecture*. Les lignes répliquées portent donc
/// une carte de traduction entière, une couleur **brute** (`null` = « hérite de
/// ma rubrique »), des URL **relatives** et des références qui peuvent manquer.
///
/// **Les quatre règles de présentation ne sont pas écrites ici** : elles vivent
/// dans `content_view.dart`, partagées avec les rassemblements
/// (`gathering_view.dart`). Les recopier une seconde fois aurait donné deux
/// mécaniques presque identiques, donc deux occasions de diverger.
///
/// Ce qui reste ici est ce qui **appartient à la médiathèque** : deux types que
/// rien d'autre ne peut se voir attribuer. Un `TeachingView` ne se construit que
/// depuis la collection `teachings`, un `GatheringView` que depuis
/// `gatherings` — la clé de collection est le discriminant (ADR-0026,
/// décision 1), et le système de types en est le reflet. Un type commun unique
/// rendrait possible — donc, un jour, réel — un rassemblement rendu par la
/// médiathèque.
library;

import 'content_view.dart';

export 'content_view.dart' show ContentView, SectionView, kBrandFallbackColor;

/// Un **enseignement** tel qu'un écran l'affiche.
///
/// Se construit **uniquement** par [TeachingView.resolve], comme tout
/// [ContentView] : c'est là que les quatre règles s'appliquent.
class TeachingView extends ContentView {
  const TeachingView({
    required super.id,
    required super.title,
    required super.color,
    super.authorName,
    super.teachingTypeId,
    super.branchId,
    super.typeLabel,
    super.imageLandscapeUrl,
    super.imagePortraitUrl,
    super.imageSquareUrl,
    super.playlistUrl,
    super.description,
    super.recordedAt,
    super.publishedAt,
    super.isFullService,
  });

  /// Applique les quatre règles de lecture à une ligne `teachings` et à ce que
  /// le magasin possède de ses références.
  TeachingView.resolve({
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
    super.imageSquareUrl,
    super.playlistUrl,
    super.description,
    super.recordedAt,
    super.publishedAt,
    super.isFullService,
  }) : super.resolve();
}

/// Une **rubrique d'enseignement** de l'accueil, telle qu'un écran l'affiche.
///
/// `teachingTypeId` désigne une ligne de **`teaching_types`**, jamais de
/// `gathering_types` : les deux référentiels sont deux collections, et rien ne
/// garantit que leurs identifiants soient disjoints.
class HomeSectionView extends SectionView {
  const HomeSectionView({
    required super.teachingTypeId,
    required super.label,
    required super.slug,
    required super.color,
    required super.itemCount,
    super.layout,
    super.position,
  });

  HomeSectionView.resolve({
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
