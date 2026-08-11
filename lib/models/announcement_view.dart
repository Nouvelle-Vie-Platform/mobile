/// **Le modèle de lecture des annonces** — ce qu'un écran affiche d'un statut,
/// et rien de plus.
///
/// Il remplace l'ancien `Announcement` du fichier `models.dart`, qui portait des
/// **valeurs résolues** (`author`, `backgroundColor`) là où le serveur sert
/// désormais des **identifiants à joindre** (`accountId`, `backgroundId`). C'est
/// la décision 3 d'ADR-0026 appliquée à un deuxième domaine : *le magasin stocke
/// ce que le serveur envoie ; la présentation se calcule à la lecture*.
///
/// Trois règles s'appliquent ici, une seule fois, pour les deux implémentations
/// du repository (magasin et double en mémoire) :
///
/// 1. **L'en-tête se replie sur `shortName ?? name`** — « Diaconat » plutôt que
///    « Diaconat de la Maison du Miracle — Bè Kpota », sur une ligne où
///    l'ellipse guette.
/// 2. **Les URL se résolvent par `resolveMediaUrl`** — le serveur les sert
///    relatives, l'hôte change d'un environnement à l'autre.
/// 3. **L'absence s'affiche comme une absence** : [accountName] reste `null`
///    quand le compte n'est pas (encore) dans le magasin, et la ligne ne se rend
///    pas. Jamais de « Compte inconnu » — ça ressemble à une donnée et sera pris
///    pour une erreur de saisie.
///
/// Ce que ce modèle **ne porte pas** est aussi délibéré : ni `tag` (le compte
/// occupe déjà l'en-tête), ni durée d'affichage, ni libellé d'action — le
/// serveur ne sert aucun des trois, et un modèle qui porte ce que le back ne
/// sert pas fabrique de la donnée en mode maquette, donc un écran qui marche sur
/// les fixtures et se vide en production.
library;

import 'package:flutter/foundation.dart';

import '../utils/media_url.dart';
import '../utils/server_values.dart';

/// Encre lisible sur un fond de statut, **telle que le serveur l'a décidée**.
///
/// Ce n'est pas une déduction du client : le contraste a été tranché à
/// l'écriture (ADR-0030). Un client qui le recalculerait à partir de la
/// luminance rendrait un jour un texte blanc sur un or pâle, et personne ne s'en
/// apercevrait avant les utilisateurs.
enum StatusInk {
  /// Encre claire — texte blanc sur fond sombre.
  light,

  /// Encre sombre — texte foncé sur fond clair.
  dark;

  /// Lit la valeur servie. Une valeur inconnue se replie sur [light] plutôt que
  /// de lever : le référentiel est administrable, et un fond illisible vaut
  /// mieux qu'un mur de statuts qui ne s'affiche plus.
  static StatusInk parse(String? raw) =>
      raw == 'dark' ? StatusInk.dark : StatusInk.light;
}

/// **Le fond d'un statut, prêt à peindre** : trois arrêts de dégradé et une
/// encre, tous dérivés par le serveur à l'écriture.
///
/// Le client ne recalcule **rien** ici. Dériver ses propres arrêts à partir de
/// [baseColor] rendrait deux dégradés différents pour la même annonce selon la
/// version installée — sur un mur de statuts, ça se voit.
///
/// `null` (aucun fond servi, ou fond pas encore synchronisé) n'est pas une
/// erreur : le rendu retombe alors sur la teinte dérivée du hash de
/// l'identifiant (`lib/theme/status_palette.dart`).
@immutable
class StatusBackdrop {
  const StatusBackdrop({
    required this.baseColor,
    required this.topColor,
    required this.bottomColor,
    required this.ink,
  });

  /// Lit les trois couleurs `#RRGGBB` servies par le référentiel.
  ///
  /// Rend `null` si l'une des trois manque ou ne se lit pas : un dégradé
  /// incomplet ne se complète pas au jugé, il laisse la place au repli.
  static StatusBackdrop? read({
    String? baseColor,
    String? topColor,
    String? bottomColor,
    String? ink,
  }) {
    final base = parseHexColor(baseColor);
    final top = parseHexColor(topColor);
    final bottom = parseHexColor(bottomColor);
    if (base == null || top == null || bottom == null) return null;
    return StatusBackdrop(
      baseColor: base,
      topColor: top,
      bottomColor: bottom,
      ink: StatusInk.parse(ink),
    );
  }

  /// Teinte de référence (ARGB) — le milieu du dégradé.
  final int baseColor;

  /// Arrêt haut du dégradé (ARGB).
  final int topColor;

  /// Arrêt bas du dégradé (ARGB).
  final int bottomColor;

  /// Encre lisible sur ce fond.
  final StatusInk ink;

  @override
  bool operator ==(Object other) =>
      other is StatusBackdrop &&
      other.baseColor == baseColor &&
      other.topColor == topColor &&
      other.bottomColor == bottomColor &&
      other.ink == ink;

  @override
  int get hashCode => Object.hash(baseColor, topColor, bottomColor, ink);
}

/// Forme dominante d'un statut.
///
/// Le type n'est jamais déclaré par le back : il se **déduit** de ce qui est
/// présent (cf. [AnnouncementView.kind]). Il ne sert qu'aux rares cas à valeur
/// unique (icône de vignette) — le rendu, lui, empile ce qui existe plutôt que
/// de faire un `switch`.
enum StatusKind { text, image, audio, video }

/// Piste audio d'un statut (message vocal).
///
/// **Hors périmètre tant que le transcodage n'est pas livré** : le serveur ne
/// sert aujourd'hui aucun média de statut. Le type survit pour la maquette et
/// pour la phase 2 ; le magasin, lui, ne le peuple jamais.
@immutable
class StatusAudio {
  const StatusAudio({
    required this.url,
    this.durationMs,
    this.waveform = const [],
  });

  final String url;

  /// Durée annoncée par le back, en millisecondes (`null` = inconnue).
  final int? durationMs;

  /// Hauteurs de barres précalculées (0–100).
  ///
  /// Peut être vide : l'UI replie alors sur une forme déterministe dérivée de
  /// l'identifiant du statut (jamais de `Random()`).
  final List<int> waveform;
}

/// Piste vidéo d'un statut. **Hors périmètre**, comme [StatusAudio].
@immutable
class StatusVideo {
  const StatusVideo({
    required this.url,
    required this.poster,
    this.durationMs,
  });

  final String url;

  /// Image d'aperçu — **requise** : elle porte tout l'affichage en phase 1 et
  /// couvre le temps de chargement en phase 2.
  final String poster;

  /// Durée annoncée par le back, en millisecondes (`null` = inconnue).
  final int? durationMs;
}

/// Une **annonce telle qu'un écran l'affiche** : un statut, signé par un compte
/// officiel d'église.
@immutable
class AnnouncementView {
  /// Le constructeur des valeurs **déjà résolues** — celui des tests et des
  /// doubles. Déclaré `const` (tous les champs sont finaux) mais non invocable
  /// en `const` : [DateTime] n'est pas constructible en constante.
  const AnnouncementView({
    required this.id,
    required this.publishedAt,
    this.accountId,
    this.accountName,
    this.accountAvatarUrl,
    this.title,
    this.body,
    this.backdrop,
    this.backgroundImageUrl,
    this.expiresAt,
    this.isPinned = false,
    this.audio,
    this.video,
  });

  /// **Les trois règles de présentation, appliquées une fois.**
  ///
  /// [accountName] et [accountShortName] sont les deux colonnes brutes du compte
  /// joint ; les URL sont **relatives** ; [backdrop] a déjà été lu par
  /// [StatusBackdrop.read].
  AnnouncementView.resolve({
    required this.id,
    required this.publishedAt,
    this.accountId,
    String? accountName,
    String? accountShortName,
    String? accountAvatarUrl,
    String? title,
    String? body,
    this.backdrop,
    String? backgroundImageUrl,
    this.expiresAt,
    this.isPinned = false,
    this.audio,
    this.video,
  })  :
        // Règle 1 — le nom court d'abord, le nom complet à défaut, `null` si le
        // compte n'est pas là. Règle 3 : `null` traverse jusqu'à l'écran, où il
        // se dessine en n'affichant rien.
        accountName =
            _blankToNull(accountShortName) ?? _blankToNull(accountName),
        title = _blankToNull(title),
        body = _blankToNull(body),
        // Règle 2 — le serveur sert des chemins relatifs, l'hôte change d'un
        // environnement à l'autre.
        accountAvatarUrl = resolveMediaUrl(accountAvatarUrl),
        backgroundImageUrl = resolveMediaUrl(backgroundImageUrl);

  /// Identifiant stable : repli de waveform, teinte de repli, clés de pager.
  final String id;

  /// Mise à disposition, en UTC. **Formatée côté client**, jamais par le back.
  final DateTime publishedAt;

  /// **Le compte signataire, en identifiant brut** — le seul champ de ce modèle
  /// qui ne se destine pas à l'affichage.
  ///
  /// Il n'y est pas par symétrie avec le magasin, mais parce qu'une seule
  /// question a besoin de lui : *cette annonce est-elle de l'un de mes
  /// comptes ?*, celle qui décide si les actions « modifier » et « supprimer »
  /// existent sur le statut affiché. Un compte officiel est un espace éditorial
  /// **collectif** : un membre peut corriger toute annonce de ses comptes, pas
  /// seulement celles qu'il a écrites — le lecteur tient le comité pour
  /// responsable de ce qui est signé de son nom.
  ///
  /// Comparer [accountName] à la place serait un faux ami : deux comptes de
  /// branches différentes peuvent porter le même nom court, et l'écran offrirait
  /// de modifier l'annonce d'un autre bureau — que le serveur refuserait ensuite
  /// en 403, après la saisie.
  ///
  /// `null` quand la source ne le porte pas (double en mémoire, fixtures de
  /// test) : l'affordance n'apparaît alors pas, ce qui est le bon défaut.
  final int? accountId;

  /// En-tête du statut — `shortName ?? name` du compte officiel.
  ///
  /// `null` = le compte n'est pas (encore) dans le magasin. La ligne ne se rend
  /// pas ; elle paraîtra au cycle de synchronisation suivant.
  final String? accountName;

  /// Avatar du compte, **URL absolue** ou `null`.
  final String? accountAvatarUrl;

  /// Absent ⇒ bloc de texte centré façon WhatsApp.
  final String? title;
  final String? body;

  /// Fond servi, `null` ⇒ teinte dérivée du hash de l'[id].
  final StatusBackdrop? backdrop;

  /// Image de fond, **URL absolue** ou `null`.
  final String? backgroundImageUrl;

  /// `null` = n'expire jamais (le défaut).
  ///
  /// **Le filtre appartient à la lecture** : le serveur ne retire jamais une
  /// annonce expirée du flux delta, parce qu'un statut « valable jusqu'à ce
  /// soir » doit disparaître à la seconde, y compris hors-ligne. Voir
  /// `announcementsProvider`.
  final DateTime? expiresAt;

  /// Épinglé en tête du mur.
  final bool isPinned;

  /// **Hors périmètre** : le serveur ne sert aucun média de statut (phase 2,
  /// transcodage). Toujours nuls quand la source est le magasin.
  final StatusAudio? audio;
  final StatusVideo? video;

  /// Forme dominante déduite de la composition.
  ///
  /// Priorité : vidéo, puis audio, puis image de fond **sans texte**, sinon
  /// texte.
  StatusKind get kind {
    if (video != null) return StatusKind.video;
    if (audio != null) return StatusKind.audio;
    final hasBody = body != null && body!.isNotEmpty;
    if (backgroundImageUrl != null && !hasBody && title == null) {
      return StatusKind.image;
    }
    return StatusKind.text;
  }

  /// Une chaîne vide ou blanche **est** une absence, et se dessine comme telle.
  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
