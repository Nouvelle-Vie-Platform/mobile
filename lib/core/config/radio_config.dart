/// **Ce que l'application sait de New Life Radio sans demander à personne** — et
/// la liste est courte, exprès.
///
/// Il n'y a **plus d'URL ici**, et c'est tout l'objet de #104. Ce fichier portait
/// `defaultStreamUrl = 'https://radio.rtbf.be/jam/mp3-160/me'` — la RTBF belge,
/// bouchon assumé dans son propre commentaire. Une adresse de flux compilée dans
/// le binaire ne se corrige que par une livraison sur les magasins, et les
/// téléphones en retard gardent l'ancienne **pour toujours** : l'URL vient
/// désormais d'une route publique (`RadioRepository`), appelée au lancement et au
/// retour à l'écran.
///
/// Le titre annoncé au système n'y est pas davantage : c'est un texte destiné à
/// l'auditeur, il vit dans les `.arb` (`radioTitle`), et le chemin qui le porte
/// jusqu'au lecteur passe par l'écran — seul endroit où `context.l10n` existe.
library;

class RadioConfig {
  RadioConfig._();

  /// **L'identifiant du flux d'antenne dans le lecteur**, et le seul reste de
  /// l'ancien fichier.
  ///
  /// Il ne désigne aucune ligne de magasin : c'est la clé par laquelle l'accueil,
  /// l'écran d'antenne et le contrôleur d'écoute reconnaissent que **c'est la
  /// radio** que le lecteur unique tient en main, et non un enseignement.
  ///
  /// Il valait `live_stream` quand ce bouton jouait un culte imaginaire. Le
  /// renommer est sans conséquence : rien ne le persiste côté serveur, et la
  /// seule trace locale qu'il laisse est une position de lecture dont un direct
  /// n'a que faire.
  static const String contentId = 'radio_antenna';
}
