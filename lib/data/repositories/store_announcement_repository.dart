import 'dart:async';

import '../../models/announcement_draft.dart';
import '../../utils/i18n_text.dart';
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

  /// **Mes comptes et les fonds actifs, en une seule émission.**
  ///
  /// Deux requêtes, un seul flux : le formulaire n'a alors qu'un état de
  /// chargement à composer, au lieu d'une fenêtre où le sélecteur de compte est
  /// prêt et celui des teintes encore vide.
  @override
  Stream<ComposerOptions> composerOptions({required String locale}) =>
      _combineLatest(
        _dao.myAccounts().watch(),
        _dao.composableBackgrounds().watch(),
        (accounts, backgrounds) => ComposerOptions(
          accounts: List<ComposerAccount>.unmodifiable(
            accounts.map(
              (row) => ComposerAccount(
                id: row.id,
                // Le même repli que l'en-tête du mur : un membre doit
                // reconnaître dans le sélecteur la signature qu'il verra
                // ensuite sur son statut.
                name: row.shortName ?? row.name,
                backgroundId: row.backgroundId,
              ),
            ),
          ),
          backgrounds: List<StatusBackgroundOption>.unmodifiable(
            backgrounds
                .map(
                  (row) => (
                    row: row,
                    backdrop: StatusBackdrop.read(
                      baseColor: row.baseColor,
                      topColor: row.topColor,
                      bottomColor: row.bottomColor,
                      ink: row.ink,
                    ),
                  ),
                )
                // Un fond dont les trois arrêts ne se lisent pas ne se propose
                // pas : la pastille du sélecteur **est** le dégradé, et il n'y a
                // pas de repli honnête à peindre à sa place — celui du mur est
                // dérivé de l'identifiant de l'annonce, qui n'existe pas encore.
                .where((entry) => entry.backdrop != null)
                .map(
                  (entry) => StatusBackgroundOption(
                    id: entry.row.id,
                    // `pick` et rien d'autre : le magasin porte la carte
                    // entière, l'unique autorité du repli de langue est
                    // `utils/i18n_text.dart` (ADR-0023).
                    label: pick(entry.row.label, locale),
                    backdrop: entry.backdrop!,
                  ),
                ),
          ),
        ),
      );

  /// **Le brouillon d'une annonce existante**, reconstitué depuis la ligne
  /// brute.
  ///
  /// [PublicationTiming.scheduled] pour tout ce que le magasin porte, et jamais
  /// [PublicationTiming.now] : la date de publication existe déjà, et la
  /// réenvoyer en « maintenant » ferait remonter en tête du mur une annonce
  /// qu'on rouvrait seulement pour corriger une faute de frappe. Le mode
  /// [PublicationTiming.draft] ne peut pas se présenter ici — le serveur ne sert
  /// au mobile ni brouillon ni annonce programmée.
  @override
  Stream<AnnouncementDraft?> draftOf(String id) =>
      _dao.announcementById(id).watchSingleOrNull().map(
            (row) => row == null
                ? null
                : AnnouncementDraft(
                    accountId: row.accountId,
                    title: row.title,
                    body: row.body,
                    backgroundId: row.backgroundId,
                    timing: PublicationTiming.scheduled,
                    publishedAt: row.publishedAt,
                    expiresAt: row.expiresAt,
                    // L'image déjà déposée n'est pas rechargée — on n'a que son
                    // URL. Elle compte malgré tout comme contenu : une affiche
                    // qu'on rouvre pour changer sa date de fin n'a ni titre ni
                    // corps, et serait refusée à tort comme « rien à publier ».
                    hasBackgroundImage: row.backgroundImageUrl != null,
                  ),
          );

  AnnouncementView _view(AnnouncementWithRefs row) {
    final background = row.background;
    return AnnouncementView.resolve(
      id: row.announcement.id,
      publishedAt: row.announcement.publishedAt,
      // L'identifiant brut du compte traverse, en plus de son nom : c'est lui
      // qui décide si les actions « modifier » et « supprimer » existent sur ce
      // statut — un compte officiel est un espace éditorial collectif.
      accountId: row.announcement.accountId,
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

/// **Deux flux du magasin, une seule émission** — le peu de `rxdart` dont ce
/// dépôt a besoin, écrit à la main plutôt qu'ajouté en dépendance.
///
/// N'émet qu'une fois les **deux** sources arrivées : un formulaire à moitié
/// peuplé serait pire qu'un formulaire en chargement, parce qu'il a l'air prêt.
/// Ensuite, chaque nouvelle valeur de l'une recompose avec la dernière connue de
/// l'autre — c'est ce qui fait qu'un fond ajouté au portail apparaît dans le
/// sélecteur au cycle de synchronisation suivant, sans rouvrir l'écran.
///
/// Une erreur de l'une des deux sources traverse : la lecture du magasin a
/// échoué, et l'écran doit le dire comme une panne, pas comme un catalogue vide.
Stream<R> _combineLatest<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A, B) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  A? latestFirst;
  B? latestSecond;
  var hasFirst = false;
  var hasSecond = false;

  void emit() {
    if (hasFirst && hasSecond) {
      controller.add(combine(latestFirst as A, latestSecond as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      firstSub = first.listen(
        (value) {
          latestFirst = value;
          hasFirst = true;
          emit();
        },
        onError: controller.addError,
      );
      secondSub = second.listen(
        (value) {
          latestSecond = value;
          hasSecond = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
    },
  );

  return controller.stream;
}
