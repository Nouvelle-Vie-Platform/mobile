/// **Un onglet réservé, pour qui n'a pas de compte** : le formulaire de
/// connexion **à la place** du contenu de l'onglet.
///
/// ## Le cul-de-sac que ceci remplace
///
/// L'appui sur « Échanges » ou « Profil » poussait, par `requireSession()`, le
/// parcours d'authentification **plein écran** par-dessus la coquille. Sur
/// Android, renoncer était un appui sur le bouton système ; **sur iPhone il n'y
/// en a pas**, et l'écran poussé — l'écran de bienvenue, qui n'avait ni `appBar`,
/// ni `BackButton`, ni `PopScope` — enfermait la personne. Le bouton manquant
/// n'était que le symptôme : la faute était d'avoir fait une **navigation** de
/// ce qui est un **état d'onglet**.
///
/// Ici, rien n'est poussé. La barre du bas reste là, l'onglet reste sélectionné,
/// et on sort du formulaire en touchant un autre onglet. Il n'y a donc aucun
/// retour à inventer, et aucun bouton système à espérer.
///
/// Trois conséquences qui valent d'être écrites :
///
/// 1. **Le contexte est donné par l'endroit.** Quelqu'un qui touche « Échanges »
///    voit le formulaire *dans* Échanges, et [signInReasonFor] le lui dit en une
///    phrase. Aucun appelant n'a à transporter ce contexte : c'est l'onglet qui
///    le porte, et un `switch` exhaustif qui le résout.
/// 2. **La connexion aboutit ⇒ l'onglet se repeint**, sans que personne n'y
///    retouche. La coquille lit l'état d'authentification et rend l'écran de
///    l'onglet à sa place ; il n'y a pas de geste à rejouer, donc pas d'intention
///    à mettre de côté. `requireSession()` garde ce rôle pour les gestes qui ne
///    sont **pas** des onglets — publier une annonce, écrire une note, ouvrir une
///    conversation depuis une notification.
/// 3. **L'écran réservé n'est jamais monté** pour un invité. Il l'était jusqu'ici
///    (un `IndexedStack` construit tous ses enfants, même ceux qu'il ne peint
///    pas) ; il ne l'est plus, puisque la coquille met ce formulaire à sa place.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/home_tab.dart';
import '../../widgets/mini_player_host.dart';
import 'identifier_screen.dart';

/// **Pourquoi on demande un compte sur cet onglet-ci**, en une phrase.
///
/// Fonction de dessus de table et non méthode de [HomeTab] : l'`enum` vit dans
/// `widgets/` et ne connaît pas les traductions. Le `switch` est **exhaustif**,
/// comme `HomeTab.requiresSession` et `AppBottomNav.itemFor`, pour la même
/// raison : un onglet neuf doit répondre à la question au lieu de la laisser
/// passer par défaut.
///
/// Les deux onglets ouverts rendent `null` — ils n'arrivent jamais ici, et c'est
/// `requiresSession` qui le garantit. Le lien entre les deux est **vérifié** et
/// non supposé : `test/screens/guest_sign_in_tab_test.dart` exige une phrase pour
/// chaque onglet qui exige une session.
String? signInReasonFor(HomeTab tab, AppLocalizations l) => switch (tab) {
      HomeTab.home || HomeTab.announcements => null,
      HomeTab.community => l.authReasonCommunity,
      HomeTab.profile => l.authReasonProfile,
    };

/// Le contenu d'un onglet réservé, en l'absence de session.
class SignInTab extends StatelessWidget {
  const SignInTab({super.key, required this.tab});

  /// L'onglet dont ce formulaire prend la place. Il ne sert qu'à **nommer la
  /// raison** : le formulaire, lui, est le même partout.
  final HomeTab tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        // La coquille garde `extendBody: true` : le bas du corps passe derrière
        // la barre givrée. Sans la marge basse, « Continuer » finirait dessous.
        bottom: false,
        child: IdentifierForm(
          reason: signInReasonFor(tab, context.l10n),
          padding: AppSpacing.screenPadding.copyWith(
            top: AppSpacing.xxl,
            // La place du mini-lecteur (#117) s'y ajoute : ce formulaire pose
            // sa marge en dur, sans lire `MediaQuery.padding`.
            bottom: AppSpacing.xxl +
                AppBottomNav.barHeight +
                MiniPlayerHost.insetOf(context),
          ),
        ),
      ),
    );
  }
}
