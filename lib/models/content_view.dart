/// **Ce que les deux familles de la médiathèque partagent à la lecture**, et
/// rien de plus.
///
/// Un enseignement et un rassemblement sont **deux types**, alimentés par deux
/// collections, rendus par deux écrans (ADR-0026, décision 1 : la clé de
/// collection est le discriminant, jamais un champ de ligne). Ce qu'ils
/// partagent — la forme de la charge utile, la couleur de repli, les deux
/// cadrages d'image — se partage **par composition**, ici.
///
/// Ce fichier est donc l'endroit où les **quatre règles de présentation**
/// s'appliquent, une fois pour les deux familles :
///
/// 1. la cascade de couleur s'y **termine** (contenu → rubrique → marque) ;
/// 2. le libellé de rubrique s'y replie, par `pick` et lui seul ;
/// 3. les URL d'image s'y résolvent, par `resolveMediaUrl` et lui seul ;
/// 4. **l'absence s'y affiche comme une absence** : pas de nom d'auteur inventé.
///
/// Les recopier une seconde fois pour les rassemblements aurait donné deux
/// mécaniques presque identiques, donc deux occasions de diverger — et une
/// divergence de cascade de couleur ne se voit pas en test, elle se voit sur le
/// téléphone d'un fidèle six mois plus tard.
///
/// Aucun import du magasin ici : le modèle de lecture ne connaît ni Drift ni
/// `SampleData`. Ce sont les repositories qui l'alimentent, chacun depuis sa
/// source, par le même constructeur `resolve`.
library;

import 'package:flutter/foundation.dart';

import '../utils/i18n_text.dart';
import '../utils/media_url.dart';

/// **Dernier maillon de la cascade de couleur** : le bleu de marque
/// (`#223B8C`, `AppColors.primary`).
///
/// Écrit ici et non tiré du thème : la cascade est une règle de **donnée** —
/// « ni le contenu ni sa rubrique n'ont dit de couleur » — et le modèle de
/// lecture ne dépend pas de `lib/theme/`. La valeur est la même des deux côtés,
/// et c'est volontaire : le repli doit être la couleur de l'église, pas un gris
/// technique.
const int kBrandFallbackColor = 0xFF223B8C;

/// Un **contenu de médiathèque tel qu'un écran l'affiche** — la part commune
/// d'un enseignement et d'un rassemblement.
///
/// Abstraite **à dessein** : il n'existe pas de « contenu » en soi dans ce
/// domaine, seulement des enseignements et des rassemblements. Ce type est le
/// vocabulaire des widgets qui n'ont besoin de savoir ni l'un ni l'autre — un
/// visuel, une carte, une ligne de liste —, jamais celui d'un provider ou d'une
/// route : ceux-là désignent toujours une famille.
///
/// Tout y est déjà résolu : la couleur, le libellé de rubrique dans la langue
/// courante, les deux URL absolues. Un widget qui en reçoit un n'a plus aucune
/// règle à appliquer — donc plus aucune occasion d'en appliquer une variante.
///
/// Ce que le modèle **ne porte pas** est aussi délibéré : ni durée (le serveur
/// n'en sert pas), ni référence biblique (idem), ni **famille** (la clé de
/// collection est le discriminant, et le type Dart en est ici le reflet).
@immutable
abstract class ContentView {
  /// Le constructeur des valeurs **déjà résolues** — celui que les sous-classes
  /// exposent pour leurs tests et leurs doubles.
  const ContentView({
    required this.id,
    required this.title,
    required this.color,
    this.authorName,
    this.teachingTypeId,
    this.branchId,
    this.typeLabel = '',
    this.imageLandscapeUrl,
    this.imagePortraitUrl,
    this.imageSquareUrl,
    this.playlistUrl,
    this.description,
    this.recordedAt,
    this.publishedAt,
    this.isFullService = false,
  });

  /// **Les quatre règles de présentation, appliquées une fois.**
  ///
  /// [color] et [typeColor] sont les couleurs **brutes** (ARGB), chacune
  /// éventuellement nulle ; [typeLabel] est la carte de traduction **entière**
  /// de la rubrique ; les deux URL sont **relatives**. [contributorName] est nul
  /// quand l'intervenant n'est pas (encore) dans le magasin — et le reste :
  /// aucun « Auteur inconnu » n'est fabriqué ici.
  ContentView.resolve({
    required this.id,
    required this.title,
    required String locale,
    String? contributorName,
    this.teachingTypeId,
    this.branchId,
    Map<String, String>? typeLabel,
    int? color,
    int? typeColor,
    String? imageLandscapeUrl,
    String? imagePortraitUrl,
    String? imageSquareUrl,
    this.playlistUrl,
    String? description,
    this.recordedAt,
    this.publishedAt,
    this.isFullService = false,
  })  :
        // Règle 1 — la cascade se termine ici, et nulle part ailleurs. Résolue
        // côté serveur, elle laisserait les téléphones sur l'ancienne teinte
        // indéfiniment et en silence : changer la couleur d'une rubrique ne
        // bouscule l'`updated_at` d'aucun contenu, donc aucune ligne ne
        // repasserait par le flux delta pour corriger la valeur figée.
        color = color ?? typeColor ?? kBrandFallbackColor,
        // Règle 4 — l'absence s'affiche comme une absence. `null` traverse.
        authorName = blankToNull(contributorName),
        // Règle 2 — `pick` est l'unique endroit où le repli de langue est écrit.
        typeLabel = typeLabel == null ? '' : pick(typeLabel, locale),
        // Règle 3 — le serveur sert des chemins relatifs, l'hôte change d'un
        // environnement à l'autre.
        imageLandscapeUrl = resolveMediaUrl(imageLandscapeUrl),
        imagePortraitUrl = resolveMediaUrl(imagePortraitUrl),
        imageSquareUrl = resolveMediaUrl(imageSquareUrl),
        description = blankToNull(description);

  /// UUIDv7 servi par le serveur — ce qui circule dans la navigation.
  final String id;

  /// Titre **monolingue** : le serveur sert une chaîne, pas une carte.
  final String title;

  /// Nom de l'intervenant, ou `null`.
  ///
  /// **`null` se dessine en n'affichant rien.** Un « Auteur inconnu » de
  /// remplacement ressemblerait à une donnée et serait pris pour une erreur de
  /// saisie ; le contenu, lui, s'affiche quand même — la ligne d'auteur
  /// paraîtra au cycle de synchronisation suivant.
  final String? authorName;

  /// Rubrique du contenu, `null` s'il n'en porte pas.
  ///
  /// C'est un **entier**, pas une valeur d'enum : la rubrique est une table
  /// éditable depuis le portail. Le champ porte le nom que le protocole emploie
  /// pour les deux familles — c'est la colonne FK de la table partagée côté
  /// serveur —, et il désigne le référentiel de **sa** famille : une ligne de
  /// `teaching_types` pour un enseignement, de `gathering_types` pour un
  /// rassemblement.
  final int? teachingTypeId;

  /// Branche du contenu (SERIAL, comparable à `branches.id`), `null` pour un
  /// contenu **national**. Ne sert qu'à borner une page ou une section de la
  /// médiathèque réglée sur une branche.
  final int? branchId;

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

  /// Visuel carré (1:1), **URL absolue** ou `null` — le troisième cadrage,
  /// celui du rail de vignettes de l'accueil. Additif : le paysage et le portrait
  /// restent servis, `null` = pas de carré (le repli sur la couleur s'applique).
  final String? imageSquareUrl;

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

  /// Visuel à privilégier pour un cadre **carré** (rail, vignette) : le carré
  /// d'abord, puis les deux autres en secours — une image mal cadrée reste plus
  /// informative qu'un aplat.
  String? get squareOrLandscape =>
      imageSquareUrl ?? imageLandscapeUrl ?? imagePortraitUrl;

  /// Une chaîne vide ou blanche **est** une absence, et se dessine comme telle.
  static String? blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// Une **rubrique de l'accueil**, telle qu'un écran l'affiche — la part commune
/// d'une rubrique d'enseignement et d'une rubrique de rassemblement.
///
/// Le magasin a déjà écarté les rubriques masquées et celles dont il ne possède
/// aucun contenu (« pas de contenu, pas de section ») et les a rangées dans
/// l'ordre du serveur. Ce qui reste ici est de la présentation : replier le
/// libellé et terminer la cascade de couleur.
///
/// `layout` est porté **brut** et n'est délibérément pas un enum : le
/// référentiel est administrable, une valeur inconnue se replie à l'affichage
/// (`HomeSectionLayout.of`).
@immutable
abstract class SectionView {
  const SectionView({
    required this.teachingTypeId,
    required this.label,
    required this.slug,
    required this.color,
    required this.itemCount,
    this.layout,
    this.position = 0,
  });

  /// Applique les deux règles de présentation d'une rubrique : le repli de
  /// langue et la fin de la cascade de couleur.
  SectionView.resolve({
    required this.teachingTypeId,
    required Map<String, String> label,
    required this.slug,
    required String locale,
    required this.itemCount,
    int? color,
    this.layout,
    this.position = 0,
  })  : label = pick(label, locale),
        color = color ?? kBrandFallbackColor;

  /// SERIAL côté serveur — la clé que porte `ContentView.teachingTypeId`, dans
  /// le référentiel de **sa** famille.
  final int teachingTypeId;

  /// Libellé **déjà replié** dans la langue courante.
  final String label;

  /// Clé stable qui survit au renommage du libellé.
  final String slug;

  /// Couleur de la rubrique, résolue sur le bleu de marque à défaut.
  final int color;

  /// Toujours strictement positif : une rubrique dont le magasin ne possède
  /// aucun contenu n'est pas une section.
  final int itemCount;

  /// `hero` | `carousel` | `list`, **tel que servi**.
  final String? layout;

  /// Rang voulu par le serveur.
  final int position;
}
