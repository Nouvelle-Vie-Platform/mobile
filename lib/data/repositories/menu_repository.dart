import '../../models/menu_entry_view.dart';

/// Menus — **repository dédié, asynchrone, et le seul chemin des écrans vers les
/// entrées de menu** (#82).
///
/// Hors de `ChurchRepository` comme tous les domaines servis par le back, et
/// adossé au **magasin local** : le réseau ne peint jamais (ADR-0026). C'est ce
/// qui fait qu'un porteur sans compte, hors ligne, trouve sa barre d'onglets
/// dès la première image.
///
/// **Un `Stream`, pas un `Future`** : la synchronisation réécrit sous les pieds
/// des écrans, et un décochage fait au portail doit retirer l'onglet du
/// téléphone au cycle suivant, sans que personne relance l'écran.
///
/// Tout ce qui sort d'ici est **déjà tranché** : destination résolue, fenêtre de
/// publication évaluée, libellé replié, sous-entrées rangées sous leur parent,
/// entrées sans contenu retirées. Un écran qui en reçoit la liste n'a plus
/// aucune règle à appliquer — il choisit un dessin.
abstract interface class MenuRepository {
  /// **Les entrées d'une surface, prêtes à rendre.**
  ///
  /// [now] est l'horloge, injectée : la fenêtre de publication s'évalue **à
  /// chaque émission**, parce qu'une entrée « jusqu'à ce soir » doit disparaître
  /// à la seconde, y compris hors ligne. Ni le serveur ni une requête SQL ne
  /// peuvent le tenir — une requête est évaluée quand la table change, pas quand
  /// l'heure passe. C'est la règle de l'expiration des annonces, mot pour mot.
  ///
  /// La liste peut être **vide**, et c'est un état plein de sens, non une
  /// erreur : « aucun menu reçu », ou « le portail n'a rien allumé sur cette
  /// surface ». Chaque surface en tire sa propre conséquence, et elle est écrite
  /// chez elle.
  Stream<List<MenuEntryView>> menu(
    MenuSurface surface, {
    required String locale,
    required DateTime Function() now,
  });
}

/// Implémentation **en mémoire** — servie quand `AppEnv.useBackend` est faux
/// (mode maquette) et par défaut dans les tests d'écran.
///
/// **Elle rend un menu vide, et ce n'est pas un trou à combler.** `SampleData`
/// ne porte aucune entrée de menu, et en inventer ferait croire à une donnée —
/// c'est le raisonnement de `InMemoryMediathequeRepository.guestNames`, repris
/// tel quel. Le vide est de surcroît **l'état le plus utile à exercer** : c'est
/// celui d'une application fraîchement installée dont le premier cycle n'a rien
/// ramené, et celui d'un serveur en retard d'une version (la collection prend un
/// `404`, le moteur la saute). Les deux surfaces doivent y tenir debout, et
/// c'est précisément ce que ce double vérifie à chaque test d'écran qui ne parle
/// pas de menus.
///
/// [entries] existe pour les rares tests qui veulent poser un menu **déjà
/// résolu** sans monter de magasin. Les règles de lecture, elles, se vérifient
/// sur l'implémentation de magasin, contre une base en mémoire : un double qui
/// les rejouerait à la main serait une seconde vérité, libre de diverger.
class InMemoryMenuRepository implements MenuRepository {
  const InMemoryMenuRepository({this.entries = const {}});

  /// Menu par surface, déjà résolu. Une surface absente rend une liste vide.
  final Map<MenuSurface, List<MenuEntryView>> entries;

  @override
  Stream<List<MenuEntryView>> menu(
    MenuSurface surface, {
    required String locale,
    required DateTime Function() now,
  }) =>
      Stream.value(
        List<MenuEntryView>.unmodifiable(entries[surface] ?? const []),
      );
}
