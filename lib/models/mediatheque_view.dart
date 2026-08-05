/// **Le modèle de lecture de la médiathèque** — ce qu'un écran affiche, et
/// rien de plus.
///
/// Décision 3 d'ADR-0026 : *le magasin stocke ce que le serveur envoie ; la
/// présentation se calcule à la lecture*. Les lignes répliquées portent donc
/// une carte de traduction entière, une couleur **brute** (`null` = « hérite de
/// ma rubrique »), des URL **relatives** et des références qui peuvent manquer.
/// Rien de tout cela n'est affichable tel quel, et rien de tout cela ne doit
/// être résolu à l'écriture : une couleur de rubrique modifiée ne touche aucune
/// ligne `teachings`, un enseignement dont l'intervenant n'est pas encore
/// arrivé le recevra au cycle suivant.
///
/// Ce fichier est l'endroit où ces quatre règles s'appliquent, **une fois** :
///
/// 1. la cascade de couleur s'y **termine** (enseignement → rubrique → marque) ;
/// 2. le libellé de rubrique s'y replie, par `pick` et lui seul ;
/// 3. les URL d'image s'y résolvent, par `resolveMediaUrl` et lui seul ;
/// 4. **l'absence s'y affiche comme une absence** : pas de nom d'auteur inventé.
///
/// Aucun import du magasin ici : le modèle de lecture ne connaît ni Drift ni
/// `SampleData`. Ce sont les deux implémentations de `MediathequeRepository`
/// qui l'alimentent, chacune depuis sa source, par le même constructeur
/// [TeachingView.resolve] — c'est ce qui garantit que le mode maquette et le
/// mode magasin appliquent exactement les mêmes règles.
library;

import 'package:flutter/foundation.dart';

import '../utils/i18n_text.dart';
import '../utils/media_url.dart';

/// **Dernier maillon de la cascade de couleur** : le bleu de marque
/// (`#223B8C`, `AppColors.primary`).
///
/// Écrit ici et non tiré du thème : la cascade est une règle de **donnée** —
/// « ni l'enseignement ni sa rubrique n'ont dit de couleur » — et le modèle de
/// lecture ne dépend pas de `lib/theme/`. La valeur est la même des deux côtés,
/// et c'est volontaire : le repli doit être la couleur de l'église, pas un gris
/// technique.
const int kBrandFallbackColor = 0xFF223B8C;

/// Un enseignement **tel qu'un écran l'affiche**.
///
/// Tout y est déjà résolu : la couleur, le libellé de rubrique dans la langue
/// courante, les deux URL absolues. Un widget qui reçoit un [TeachingView] n'a
/// plus aucune règle à appliquer — et n'a donc plus aucune occasion d'en
/// appliquer une variante.
///
/// Ce que le modèle **ne porte pas** est aussi délibéré : ni durée (le serveur
/// n'en sert pas), ni référence biblique (idem), ni graine de vignette. Un
/// champ que le back ne sert pas n'a pas à traverser la couche de lecture.
@immutable
class TeachingView {
  const TeachingView({
    required this.id,
    required this.title,
    required this.color,
    this.authorName,
    this.teachingTypeId,
    this.typeLabel = '',
    this.imageLandscapeUrl,
    this.imagePortraitUrl,
    this.playlistUrl,
    this.description,
    this.recordedAt,
    this.publishedAt,
    this.isFullService = false,
  });

  /// Applique les quatre règles de lecture à une ligne et à ce que le magasin
  /// possède de ses références.
  ///
  /// [color] et [typeColor] sont les couleurs **brutes** (ARGB), chacune
  /// éventuellement nulle ; [typeLabel] est la carte de traduction **entière**
  /// de la rubrique ; les deux URL sont **relatives**. [contributorName] est
  /// nul quand l'intervenant n'est pas (encore) dans le magasin — et le reste :
  /// aucun « Auteur inconnu » n'est fabriqué ici.
  factory TeachingView.resolve({
    required String id,
    required String title,
    required String locale,
    String? contributorName,
    int? teachingTypeId,
    Map<String, String>? typeLabel,
    int? color,
    int? typeColor,
    String? imageLandscapeUrl,
    String? imagePortraitUrl,
    String? playlistUrl,
    String? description,
    DateTime? recordedAt,
    DateTime? publishedAt,
    bool isFullService = false,
  }) {
    return TeachingView(
      id: id,
      title: title,
      // Règle 1 — la cascade se termine ici, et nulle part ailleurs. Résolue
      // côté serveur, elle laisserait les téléphones sur l'ancienne teinte
      // indéfiniment et en silence : changer la couleur d'une rubrique ne
      // bouscule l'`updated_at` d'aucun enseignement, donc aucune ligne ne
      // repasserait par le flux delta pour corriger la valeur figée.
      color: color ?? typeColor ?? kBrandFallbackColor,
      // Règle 4 — l'absence s'affiche comme une absence. `null` traverse.
      authorName: _blankToNull(contributorName),
      teachingTypeId: teachingTypeId,
      // Règle 2 — `pick` est l'unique endroit où le repli de langue est écrit.
      typeLabel: typeLabel == null ? '' : pick(typeLabel, locale),
      // Règle 3 — le serveur sert des chemins relatifs, l'hôte change d'un
      // environnement à l'autre.
      imageLandscapeUrl: resolveMediaUrl(imageLandscapeUrl),
      imagePortraitUrl: resolveMediaUrl(imagePortraitUrl),
      playlistUrl: playlistUrl,
      description: _blankToNull(description),
      recordedAt: recordedAt,
      publishedAt: publishedAt,
      isFullService: isFullService,
    );
  }

  /// UUIDv7 servi par le serveur — ce qui circule dans la navigation.
  final String id;

  /// Titre **monolingue** : le serveur sert une chaîne, pas une carte.
  final String title;

  /// Nom de l'intervenant, ou `null`.
  ///
  /// **`null` se dessine en n'affichant rien.** Un « Auteur inconnu » de
  /// remplacement ressemblerait à une donnée et serait pris pour une erreur de
  /// saisie ; l'enseignement, lui, s'affiche quand même — la ligne d'auteur
  /// paraîtra au cycle de synchronisation suivant.
  final String? authorName;

  /// Rubrique de l'enseignement, `null` s'il n'en porte pas.
  ///
  /// C'est un **entier**, pas une valeur d'enum : la rubrique est une table
  /// éditable depuis le portail, et la première rubrique créée par un
  /// administrateur n'aurait aucune valeur d'enum où aller.
  final int? teachingTypeId;

  /// Libellé de la rubrique, **déjà replié** dans la langue courante. Chaîne
  /// vide quand la rubrique manque, ou qu'aucune de ses traductions n'est
  /// remplie — un trou de contenu, pas une erreur à gérer dans chaque widget.
  final String typeLabel;

  /// Couleur d'habillage **résolue** (ARGB). Jamais nulle : la cascade se
  /// termine sur le bleu de marque.
  ///
  /// Elle n'est pas décorative — c'est ce que voient les membres en
  /// connectivité limitée, chaque fois qu'une image manque ou tarde.
  final int color;

  /// Visuel paysage (1,7:1), **URL absolue** ou `null`.
  final String? imageLandscapeUrl;

  /// Visuel portrait (0,6:1), **URL absolue** ou `null`.
  final String? imagePortraitUrl;

  /// URL HLS publique. `null` = le contenu existe, son média pas encore :
  /// c'est une absence à dessiner (`ContentAbsence.noMedia`), pas un cas
  /// impossible.
  final String? playlistUrl;

  /// Description longue, `null` si vide.
  final String? description;

  /// **Jour** de l'enregistrement, ancré à minuit UTC — pas un instant.
  final DateTime? recordedAt;

  /// Instant de mise à disposition, en UTC.
  final DateTime? publishedAt;

  /// Le contenu porte le **culte entier** et non un extrait de prédication.
  /// C'est un marqueur, pas une rubrique : les deux axes sont indépendants.
  final bool isFullService;

  /// Visuel à privilégier pour un cadre large, l'autre en secours : une image
  /// mal cadrée reste plus informative qu'un aplat.
  String? get landscapeOrPortrait => imageLandscapeUrl ?? imagePortraitUrl;

  /// Visuel à privilégier pour un cadre haut, l'autre en secours.
  String? get portraitOrLandscape => imagePortraitUrl ?? imageLandscapeUrl;

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// Une **rubrique de l'accueil**, telle qu'un écran l'affiche.
///
/// Le magasin a déjà écarté les rubriques masquées et celles dont il ne possède
/// aucun enseignement (« pas d'enseignement, pas de section ») et les a rangées
/// dans l'ordre du serveur. Ce qui reste à faire ici est de la présentation :
/// replier le libellé et terminer la cascade de couleur.
///
/// [layout] et [position] sont portés **bruts** : c'est le ticket suivant qui
/// compose l'accueil avec. `layout` n'est délibérément pas un enum — le
/// référentiel est administrable, une valeur inconnue se replie à l'affichage.
@immutable
class HomeSectionView {
  const HomeSectionView({
    required this.teachingTypeId,
    required this.label,
    required this.slug,
    required this.color,
    required this.teachingCount,
    this.layout,
    this.position = 0,
  });

  factory HomeSectionView.resolve({
    required int teachingTypeId,
    required Map<String, String> label,
    required String slug,
    required String locale,
    required int teachingCount,
    int? color,
    String? layout,
    int position = 0,
  }) {
    return HomeSectionView(
      teachingTypeId: teachingTypeId,
      label: pick(label, locale),
      slug: slug,
      color: color ?? kBrandFallbackColor,
      teachingCount: teachingCount,
      layout: layout,
      position: position,
    );
  }

  /// SERIAL côté serveur — la clé que porte `TeachingView.teachingTypeId`.
  final int teachingTypeId;

  /// Libellé **déjà replié** dans la langue courante.
  final String label;

  /// Clé stable qui survit au renommage du libellé.
  final String slug;

  /// Couleur de la rubrique, résolue sur le bleu de marque à défaut.
  final int color;

  /// Toujours strictement positif : une rubrique sans enseignement local n'est
  /// pas une section.
  final int teachingCount;

  /// `hero` | `carousel` | `list`, **tel que servi**. Ticket #32.
  final String? layout;

  /// Rang voulu par le serveur. Ticket #32.
  final int position;
}
