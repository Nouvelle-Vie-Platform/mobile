import '../../models/announcement_view.dart';
import '../sample_data.dart';

/// Annonces — **repository dédié, asynchrone, et le seul chemin des écrans vers
/// les statuts**.
///
/// Hors de `ChurchRepository` à dessein (CLAUDE.md, « Brancher un vrai
/// backend ») : ce contrat-là est **synchrone** et ne couvre plus que des
/// domaines fictifs. Les annonces en sortent comme l'agenda, la médiathèque et
/// les rassemblements avant elles ; `ChurchRepository` rétrécit d'autant, et
/// c'est voulu — il finira par disparaître.
///
/// **Des `Stream`, pas des `Future`** : la source est un magasin local que la
/// synchronisation réécrit sous les pieds des écrans. Une rétractation reçue
/// pendant qu'un fidèle regarde le mur doit retirer le statut de l'écran ouvert,
/// et un `Future` livrerait une photographie prise au moment du clic.
///
/// **Aucun `locale` en paramètre**, à la différence de la médiathèque : une
/// annonce est monolingue — son auteur l'écrit dans la langue de son assemblée,
/// et le serveur ne sert aucune carte de traduction. Il n'y a donc rien à
/// replier.
abstract interface class AnnouncementRepository {
  /// Toutes les annonces du magasin, **sans plafond et sans filtre**.
  ///
  /// Ni l'expiration ni le tri ne sont appliqués ici : les deux appartiennent à
  /// `announcementsProvider`, qui les fait au plus près du rendu. Une requête
  /// est évaluée quand la table change, pas quand l'heure passe.
  Stream<List<AnnouncementView>> announcements();

  /// **Suis-je membre d'au moins un compte officiel ?**
  ///
  /// C'est ce qui décide de l'affordance d'écriture — pour une poignée de
  /// personnes ; pour tous les autres, l'onglet reste une visionneuse, sans
  /// aucune affordance d'écriture.
  ///
  /// **Un confort d'affichage, jamais une autorisation** : le serveur revérifie
  /// à chaque écriture, et un membre retiré du bureau dont le téléphone n'a pas
  /// synchronisé verra encore le bouton et recevra un 403. L'écran doit traiter
  /// ce cas, pas s'y fier.
  Stream<bool> canCompose();
}

/// Implémentation **en mémoire**, servie quand `AppEnv.useBackend` est faux
/// (mode maquette) et dans les tests d'écran.
///
/// Comme les doubles de la médiathèque et des rassemblements, elle passe par le
/// **même constructeur `resolve`** que l'implémentation sur le magasin : le mode
/// maquette doit exercer les mêmes règles de lecture, sans quoi un bug de repli
/// d'en-tête ou d'URL resterait invisible jusqu'à la production.
class InMemoryAnnouncementRepository implements AnnouncementRepository {
  InMemoryAnnouncementRepository({
    List<AnnouncementView>? announcements,
    this.member = false,
  }) : _announcements = announcements ?? SampleData.announcements;

  final List<AnnouncementView> _announcements;

  /// En maquette, personne n'est membre d'un compte officiel : c'est le cas de
  /// l'immense majorité des fidèles, et donc l'état par défaut de l'onglet.
  final bool member;

  @override
  Stream<List<AnnouncementView>> announcements() =>
      Stream.value(List<AnnouncementView>.unmodifiable(_announcements));

  @override
  Stream<bool> canCompose() => Stream.value(member);
}
