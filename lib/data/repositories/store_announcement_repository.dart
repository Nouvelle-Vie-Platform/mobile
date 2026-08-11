import '../../models/announcement_view.dart';
import '../local/announcement_dao.dart';
import 'announcement_repository.dart';

/// Les annonces **peintes depuis le magasin local**, jamais depuis le réseau.
///
/// Le jumeau de `StoreMediathequeRepository` et de `StoreGatheringRepository` :
/// aucune requête ne part d'ici. La synchronisation écrit dans le magasin et ne
/// rend rien ; les écrans lisent le magasin et n'attendent rien du réseau
/// (ADR-0026).
///
/// Son seul travail est de **traduire des lignes en modèle de lecture** :
/// désérialiser ce que le magasin stocke tel que le serveur l'envoie — trois
/// couleurs en `#RRGGBB`, une encre en chaîne — puis laisser
/// [AnnouncementView.resolve] appliquer les règles de présentation. La frontière
/// est là : ici la **forme** des valeurs, là-bas les **règles**.
class StoreAnnouncementRepository implements AnnouncementRepository {
  const StoreAnnouncementRepository(this._dao);

  final AnnouncementDao _dao;

  @override
  Stream<List<AnnouncementView>> announcements() =>
      _dao.allAnnouncements().watch().map(
            (rows) => List<AnnouncementView>.unmodifiable(rows.map(_view)),
          );

  @override
  Stream<bool> canCompose() => _dao.hasMembership().watchSingle();

  AnnouncementView _view(AnnouncementWithRefs row) {
    final background = row.background;
    return AnnouncementView.resolve(
      id: row.announcement.id,
      publishedAt: row.announcement.publishedAt,
      // Les deux colonnes brutes du compte, séparées : c'est le modèle de
      // lecture qui choisit le nom court, pas le magasin. `null` traverse — le
      // compte n'est peut-être pas encore arrivé, et l'annonce s'affiche quand
      // même, sans en-tête inventé.
      accountName: row.account?.name,
      accountShortName: row.account?.shortName,
      accountAvatarUrl: row.account?.avatarUrl,
      title: row.announcement.title,
      body: row.announcement.body,
      // Les trois arrêts arrivent **dérivés par le serveur** (ADR-0030) : on les
      // lit, on ne les recalcule pas. Un fond absent — pas choisi, ou pas encore
      // synchronisé — rend `null`, et le rendu retombe sur la teinte dérivée du
      // hash de l'identifiant.
      backdrop: background == null
          ? null
          : StatusBackdrop.read(
              baseColor: background.baseColor,
              topColor: background.topColor,
              bottomColor: background.bottomColor,
              ink: background.ink,
            ),
      backgroundImageUrl: row.announcement.backgroundImageUrl,
      // Stocké brut, jamais filtré ici : c'est la lecture qui fait disparaître
      // un statut expiré, à la seconde.
      expiresAt: row.announcement.expiresAt,
      isPinned: row.announcement.isPinned,
      // `audio` et `video` restent nuls : le serveur ne sert aucun média de
      // statut tant que le transcodage n'est pas livré (phase 2).
    );
  }
}
