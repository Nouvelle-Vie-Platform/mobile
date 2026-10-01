/// **Par quelles portes l'application propose d'entrer** (#83, jumelle serveur
/// #468).
///
/// Un **canal** est la voie par laquelle le code à usage unique voyage — le mot
/// d'`IdentifierChannel` et de `docs/auth-contract.md`, jamais « méthode » ni
/// « fournisseur » (SMS, WhatsApp et Telegram sont des *fournisseurs* du canal
/// téléphone, ADR-0019).
///
/// ## Ce n'est pas une préférence, c'est une **offre**
///
/// L'écran d'identifiant n'affiche pas ce que le fidèle aimerait, il affiche ce
/// que le portail ouvre. S'il n'y a qu'un canal, il n'y a rien à sélectionner :
/// on ne grise pas une option, **on ne la propose pas**.
library;

import 'package:flutter/foundation.dart';

import 'models.dart' show IdentifierChannel;

/// Les canaux ouverts, et le message que le portail annonce avec eux.
///
/// Le jeu est **fermé** : deux booléens et non une liste de canaux. Le contrat
/// mobile nomme exactement deux canaux, et une liste laisserait croire au client
/// qu'il peut en découvrir un troisième — qu'il ne saurait de toute façon pas
/// afficher.
@immutable
class AuthChannelOffer {
  const AuthChannelOffer({
    required this.emailOpen,
    required this.phoneOpen,
    this.notice,
  });

  /// **Le repli, et il compte plus qu'il n'en a l'air : l'e-mail seul.**
  ///
  /// C'est ce que l'écran propose avant le premier cycle de synchronisation —
  /// c'est-à-dire au moment précis où quelqu'un ouvre l'application pour la
  /// première fois, et aussi quand le serveur est en retard d'une version (la
  /// collection prend alors un `404` et se saute).
  ///
  /// **Jamais « tous les canaux »** : un repli permissif remettrait exactement
  /// le sélecteur menteur que cette tranche retire — le canal téléphone n'envoie
  /// rien (`OTP_PHONE_DRIVER` vaut `log`). Et jamais « aucun canal » : ce serait
  /// fermer la porte à qui n'a encore rien synchronisé. C'est aussi l'état réel
  /// du serveur à la livraison de la jumelle (`email_channel_open = true`,
  /// `phone_channel_open = false`), et le canal que l'écran choisissait déjà.
  static const AuthChannelOffer emailOnly =
      AuthChannelOffer(emailOpen: true, phoneOpen: false);

  /// Ce que le magasin a reçu, **remis du côté sûr**.
  ///
  /// Un `CHECK` serveur (`auth_settings_at_least_one_channel`) interdit l'état
  /// « tous fermés », et le magasin n'a pas à le rejouer — mais il n'a pas non
  /// plus à le supposer : une base bricolée, une ligne mutilée ou un serveur
  /// d'une version future qui fermerait les deux canaux connus de ce client
  /// afficheraient un écran sans aucun champ, c'est-à-dire **une porte fermée
  /// sans rien pour la rouvrir**. On retombe alors sur [emailOnly], et le refus
  /// éventuel vient du serveur, qui sait le dire en français.
  factory AuthChannelOffer.resolve({
    required bool emailOpen,
    required bool phoneOpen,
    Map<String, String>? notice,
  }) {
    if (!emailOpen && !phoneOpen) {
      return AuthChannelOffer(
        emailOpen: true,
        phoneOpen: false,
        notice: notice,
      );
    }
    return AuthChannelOffer(
      emailOpen: emailOpen,
      phoneOpen: phoneOpen,
      notice: notice,
    );
  }

  /// Le canal e-mail est-il ouvert ? C'est le seul qui envoie réellement un
  /// code aujourd'hui.
  final bool emailOpen;

  /// Le canal téléphone est-il ouvert ?
  final bool phoneOpen;

  /// L'annonce du portail, **carte de traduction entière** et jamais résolue
  /// ici (ADR-0023) : `null` = le libellé du dépôt, pas un message vide.
  ///
  /// Le repli de langue appartient à `pick`, et il se fait à l'affichage — avec
  /// la locale d'**interface**, puisque c'est une phrase de l'application et non
  /// un contenu.
  final Map<String, String>? notice;

  /// **Y a-t-il quelque chose à choisir ?** Le jeu étant fermé à deux canaux,
  /// « plus d'un canal ouvert » et « les deux ouverts » sont la même phrase.
  bool get offersChoice => emailOpen && phoneOpen;

  /// Le canal unique, quand il n'y a rien à choisir — `null` sinon.
  ///
  /// Jamais `null` quand [offersChoice] est faux : [AuthChannelOffer.resolve]
  /// garantit qu'au moins un canal reste ouvert.
  IdentifierChannel? get soleChannel {
    if (offersChoice) return null;
    return emailOpen ? IdentifierChannel.email : IdentifierChannel.phone;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthChannelOffer &&
      other.emailOpen == emailOpen &&
      other.phoneOpen == phoneOpen &&
      mapEquals(other.notice, notice);

  @override
  int get hashCode => Object.hash(
        emailOpen,
        phoneOpen,
        Object.hashAllUnordered(notice?.keys ?? const <String>[]),
      );
}
