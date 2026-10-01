/// **Les onglets de la barre du bas, nommés.**
///
/// Rangé dans `widgets/` et non dans `screens/`, à côté de la barre qui les
/// rend : la coquille est un écran, mais la barre et le tiroir sont des widgets,
/// et aucun widget de ce dépôt n'importe un écran.
///
/// L'onglet était jusqu'ici un **numéro nu**, partagé par la coquille
/// ([HomeShell]), la barre ([AppBottomNav]), le tiroir latéral ([AppDrawerMenu])
/// et leurs tests. Trois mouvements de cette barre plus tard, le numéro avait
/// pris le défaut de sa nature : réordonner la barre changeait le sens de chaque
/// index **sans qu'aucun compilateur ne s'en aperçoive**, et l'oubli était muet —
/// le tiroir ouvrait simplement le mauvais écran.
///
/// Le nom supprime cette classe d'erreur. L'index redevient ce qu'il aurait
/// toujours dû être : un **détail de rendu**, calculé à partir de l'ordre
/// déclaré ici (`HomeTab.values`) par les deux seuls objets qui en ont besoin —
/// l'`IndexedStack` de la coquille et la `Row` de la barre.
///
/// **L'ordre de déclaration est l'ordre d'affichage**, et il ne vit qu'ici.
/// Permuter deux entrées de la barre, c'est permuter deux lignes de cet `enum` ;
/// l'écran, le libellé, l'icône et la garde suivent, parce que tout le reste les
/// résout par un `switch` **exhaustif** sur ce type. C'était le but : un
/// quatrième mouvement doit coûter une ligne.
library;

/// Un onglet de la barre du bas.
///
/// ⚠️ **Le nombre d'onglets est pair, et ce n'est pas un hasard** : l'encoche du
/// bouton central est posée entre deux moitiés égales (voir [AppBottomNav]).
/// Ajouter ou retirer une entrée sans préserver la parité rend la barre
/// boiteuse. C'est aussi pourquoi on n'en **masque** aucun : la géométrie ne
/// dépend d'aucun état d'authentification.
enum HomeTab {
  home,
  announcements,
  community,
  profile;

  /// **L'onglet a-t-il besoin d'un compte pour montrer son contenu ?**
  ///
  /// La réponse vit sur l'onglet lui-même, et pas dans un `if` de la coquille,
  /// pour une raison précise : les onglets ne sont **pas** des routes — ils
  /// vivent dans un `IndexedStack` —, donc `memberOnlyRoutes` n'a aucune prise
  /// sur eux. Une garde oubliée ici ne fait rougir personne : elle ouvre
  /// simplement un écran de membre à un invité, et le magasin local survit à la
  /// déconnexion, donc il y verrait des choses.
  ///
  /// Écrite en `switch` exhaustif, elle oblige un onglet **neuf** à trancher la
  /// question au lieu de la laisser passer par défaut.
  ///
  /// ⚠️ **Ce drapeau ne rend pas l'onglet inaccessible, et il ne doit pas.** Il
  /// a voulu dire « l'appui ouvre le parcours de connexion par-dessus la
  /// coquille » (`requireSession()`), et c'était un cul-de-sac sur iPhone : le
  /// premier écran poussé n'avait pas de flèche de retour, et iOS n'a pas de
  /// bouton système pour dépiler. Il veut désormais dire « sans session, cet
  /// onglet montre le formulaire de connexion **à la place** de son écran » —
  /// `HomeShell._screenFor` et `SignInTab`. L'onglet reste sélectionnable, la
  /// barre du bas reste visible, et on sort en touchant un autre onglet.
  bool get requiresSession => switch (this) {
        // L'accueil et les annonces en lecture sont la surface invitée.
        HomeTab.home || HomeTab.announcements => false,
        // Le hub des conversations — décision du client — et le profil, qui
        // n'existe pas sans compte.
        HomeTab.community || HomeTab.profile => true,
      };
}
