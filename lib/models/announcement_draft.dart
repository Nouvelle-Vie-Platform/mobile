/// **Le modèle d'écriture des annonces** — ce qu'un membre de compte officiel
/// compose, par opposition à `AnnouncementView`, qui est ce qu'un fidèle lit.
///
/// Deux modèles et non un seul, et ce n'est pas de la symétrie décorative : ils
/// ne portent pas les mêmes champs. La lecture porte des valeurs **jointes et
/// résolues** (`accountName`, `backdrop`, URL absolues) ; l'écriture porte les
/// **identifiants bruts** que le serveur attend (`accountId`, `backgroundId`) et
/// les octets d'une image qui n'a pas encore d'URL. Faire voyager un
/// `AnnouncementView` vers `POST /announcements` obligerait à retrouver les
/// identifiants à partir de leurs valeurs affichées — c'est-à-dire à défaire la
/// jointure.
///
/// Ce fichier porte aussi ce que le composeur **propose** ([ComposerOptions]) :
/// mes comptes officiels et les fonds encore actifs. Les deux viennent du
/// magasin local, comme tout le reste de l'onglet ; seul l'envoi passe par le
/// réseau.
library;

import 'package:flutter/foundation.dart';

import 'announcement_view.dart';

/// L'image de fond choisie, **lue en mémoire** et pas seulement désignée par un
/// chemin.
///
/// Les octets plutôt qu'un `File` : le web n'a pas de système de fichiers
/// accessible, et le dépôt garde le web comme cible. Une image de statut se
/// compte en centaines de kilo-octets — la tenir en mémoire le temps d'un envoi
/// ne coûte rien, et l'écriture exige de toute façon le réseau (ADR-0031), donc
/// cette valeur ne survit jamais à l'écran qui l'a produite.
@immutable
class StatusImageUpload {
  const StatusImageUpload({required this.bytes, required this.filename});

  final Uint8List bytes;

  /// Nom de fichier envoyé au serveur — c'est de lui qu'il dérive l'extension,
  /// donc le type. Jamais vide.
  final String filename;
}

/// **Les trois modes de publication**, repliés sur le seul champ
/// `publishedAt`.
///
/// Un seul champ pour trois intentions, parce que le serveur n'en connaît qu'un
/// (PRD `annonces-comptes-officiels.md`, §6) :
///
/// | mode | ce qui part sur le fil |
/// |---|---|
/// | [now] | la clé est **omise** — le serveur pose l'instant courant |
/// | [scheduled] | `publishedAt` = l'instant choisi, dans le futur |
/// | [draft] | `publishedAt` = **`null`** explicite |
///
/// La distinction « omis » / « `null` » n'est pas un détail de sérialisation :
/// c'est elle qui sépare « publie tout de suite » de « garde ça au chaud ». Une
/// carte JSON qui ne saurait pas les distinguer transformerait chaque
/// publication immédiate en brouillon, ou l'inverse.
///
/// [now] laisse volontairement l'horloge au serveur plutôt que d'envoyer
/// `DateTime.now()` : le téléphone d'un fidèle peut avoir plusieurs minutes de
/// dérive, et une annonce publiée « dans deux minutes » n'apparaîtrait pas.
enum PublicationTiming { now, scheduled, draft }

/// Ce qui empêche un brouillon de partir, **avant tout appel réseau**.
///
/// Les mêmes règles seront revérifiées par le serveur ; les vérifier ici n'est
/// pas de la défiance mais de la politesse : faire l'aller-retour pour
/// apprendre qu'on n'a rien écrit gaspille la connexion de quelqu'un qui, par
/// définition, en a une mauvaise.
enum DraftIssue {
  /// **Ni titre, ni corps, ni image, ni média.** Une annonce valide en porte
  /// au moins un (PRD §18) — et une **affiche**, image seule sans texte, est le
  /// cas le plus courant en pratique, pas une exception à tolérer. Un audio ou
  /// une vidéo **seuls** suffisent aussi (décision du 05/10/2026, #130).
  nothingToPublish,

  /// [PublicationTiming.scheduled] sans instant choisi.
  missingSchedule,

  /// Fin de publication antérieure ou égale au début. Le serveur exige
  /// `expiresAt > publishedAt` ; une annonce expirée à sa naissance n'aura
  /// jamais été lue par personne.
  expiryBeforePublication,
}

/// **Une annonce telle qu'on la compose**, prête à partir vers
/// `POST`/`PUT /announcements`.
///
/// Immuable, et sans `id` : l'identifiant est assigné par le serveur, et
/// l'écriture exige le réseau (ADR-0031). Pas d'`id` fabriqué hors-ligne, donc
/// pas de brouillon local à recoller plus tard.
@immutable
class AnnouncementDraft {
  /// Construit un brouillon **depuis la saisie brute**.
  ///
  /// Titre et corps vides après `trim` valent **`null`**, jamais `''` : le
  /// rendu teste `title == null` pour décider s'il centre le bloc de texte
  /// façon WhatsApp, et une chaîne vide passerait pour un titre présent —
  /// laissant une accroche invisible pousser le corps vers le bas.
  AnnouncementDraft({
    required this.accountId,
    String? title,
    String? body,
    this.backgroundId,
    this.timing = PublicationTiming.now,
    this.publishedAt,
    this.expiresAt,
    this.image,
    this.hasBackgroundImage = false,
    this.hasMedia = false,
  })  : title = _blankToNull(title),
        body = _blankToNull(body);

  /// Compte officiel signataire. **Obligatoire** : c'est lui qui porte la voix,
  /// et c'est de lui que le serveur dérive la branche (PRD §19). Le client
  /// n'envoie jamais `branchId`.
  final int accountId;

  final String? title;
  final String? body;

  /// Fond choisi dans `status_backgrounds`, ou `null` (le rendu retombe alors
  /// sur la teinte dérivée du hash de l'identifiant).
  final int? backgroundId;

  final PublicationTiming timing;

  /// Instant de publication, **seulement** pour [PublicationTiming.scheduled].
  /// Ignoré dans les deux autres modes.
  final DateTime? publishedAt;

  /// Fin de publication, facultative — `null` = n'expire jamais, le défaut.
  final DateTime? expiresAt;

  /// Image de fond à déposer, ou `null` (rien à envoyer).
  final StatusImageUpload? image;

  /// **L'annonce en porte déjà une côté serveur.**
  ///
  /// N'existe que pour la modification, et ne sert qu'à la validation : une
  /// affiche qu'on rouvre pour corriger sa date de fin n'a ni titre ni corps, et
  /// serait refusée à tort comme « rien à publier » si on ignorait l'image déjà
  /// déposée.
  final bool hasBackgroundImage;

  /// **L'annonce porte déjà un audio ou une vidéo côté serveur.**
  ///
  /// Même raison que [hasBackgroundImage] : ce client ne dépose pas de média,
  /// mais un statut qui n'est **qu'un** média (sans titre, corps ni image) est
  /// valide, et le rouvrir pour corriger sa date de fin ne doit pas le faire
  /// refuser comme « rien à publier ».
  final bool hasMedia;

  /// L'instant de publication **effectif**, ou `null` quand il n'y en a pas
  /// encore (brouillon) ou qu'il appartient au serveur ([PublicationTiming.now],
  /// où [now] tient lieu d'approximation le temps de la validation).
  DateTime? effectivePublication(DateTime now) => switch (timing) {
        PublicationTiming.now => now,
        PublicationTiming.scheduled => publishedAt,
        PublicationTiming.draft => null,
      };

  /// Ce qui bloque, à l'instant [now]. Vide = le brouillon peut partir.
  Set<DraftIssue> issuesAt(DateTime now) {
    final issues = <DraftIssue>{};
    if (title == null &&
        body == null &&
        image == null &&
        !hasBackgroundImage &&
        !hasMedia) {
      issues.add(DraftIssue.nothingToPublish);
    }
    if (timing == PublicationTiming.scheduled && publishedAt == null) {
      issues.add(DraftIssue.missingSchedule);
    }
    final start = effectivePublication(now);
    final end = expiresAt;
    if (start != null && end != null && !end.isAfter(start)) {
      issues.add(DraftIssue.expiryBeforePublication);
    }
    return issues;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// Un **compte officiel dont je suis membre**, tel que le sélecteur le propose.
///
/// [name] est déjà replié sur `shortName ?? name`, comme l'en-tête du mur : un
/// membre doit reconnaître dans le sélecteur la signature qu'il verra ensuite
/// sur son statut.
@immutable
class ComposerAccount {
  const ComposerAccount({
    required this.id,
    required this.name,
    this.backgroundId,
  });

  final int id;
  final String name;

  /// Fond par défaut du compte, qui **préremplit** le sélecteur de teinte. Il
  /// n'habille aucune annonce par lui-même : une annonce porte toujours le sien.
  final int? backgroundId;
}

/// Un **fond proposable**, avec ses trois arrêts déjà lus.
///
/// Seuls les fonds `isActive` entrent ici, triés par `position`. Ceux qui ont
/// été désactivés au portail **restent peints** sur les annonces qui les
/// portent — les retirer du magasin ferait perdre leur habillage à des statuts
/// parfaitement valides ; ils ne sont simplement plus offerts à la composition.
@immutable
class StatusBackgroundOption {
  const StatusBackgroundOption({
    required this.id,
    required this.label,
    required this.backdrop,
  });

  final int id;

  /// Libellé du fond, **déjà replié** dans la langue de contenu. Le magasin en
  /// porte la carte `{fr, en, ee}` entière — le portail est bilingue et un
  /// administrateur anglophone nomme ses teintes en anglais ; c'est le
  /// repository qui choisit, par `pick`. Ce n'est pas pour autant un texte
  /// d'interface : il ne passe jamais par `context.l10n`.
  final String label;

  /// Les trois arrêts et l'encre, **dérivés par le serveur** (ADR-0030). La
  /// pastille du sélecteur les peint ; elle ne les recalcule pas.
  final StatusBackdrop backdrop;
}

/// **Ce que le composeur propose** : mes comptes, et les fonds encore actifs.
///
/// Les deux viennent du magasin local et voyagent ensemble parce qu'ils sont
/// lus au même moment, par le même écran : les séparer en deux `Stream`
/// donnerait au formulaire deux états de chargement à composer pour un seul
/// écran, et une fenêtre où le sélecteur de compte est prêt mais pas celui des
/// teintes.
///
/// [accounts] peut être **vide alors même que l'affordance d'écriture est
/// offerte** : `canComposeAnnouncementProvider` compte les appartenances, et une
/// appartenance dont le compte n'est pas encore arrivé ne peut pas être nommée.
/// C'est une fenêtre de synchronisation, pas une erreur — l'écran le dit.
@immutable
class ComposerOptions {
  const ComposerOptions({required this.accounts, required this.backgrounds});

  static const ComposerOptions empty =
      ComposerOptions(accounts: [], backgrounds: []);

  final List<ComposerAccount> accounts;
  final List<StatusBackgroundOption> backgrounds;
}
