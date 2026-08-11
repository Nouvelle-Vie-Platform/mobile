import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/pickers/status_image_picker.dart';
import '../data/repositories/announcement_composer.dart';
import '../data/repositories/announcement_repository.dart';
import '../data/repositories/http_announcement_composer.dart';
import '../data/repositories/store_announcement_repository.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_view.dart';
import 'sync_providers.dart';

/// Politique de réessai des providers d'annonce : **aucun réessai
/// automatique**, mêmes raisons que la médiathèque, les rassemblements et
/// l'agenda. Sur une lecture de magasin local, un échec n'est pas une
/// intermittence de réseau qu'attendre pourrait résoudre : c'est une base
/// illisible, et insister ne ferait que retarder l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Fournit l'implémentation courante de [AnnouncementRepository].
///
/// Avec backend : le **magasin local**, que la synchronisation alimente. Sans
/// backend : le double en mémoire, qui applique **les mêmes règles de lecture**.
final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AppEnv.useBackend
      ? StoreAnnouncementRepository(ref.watch(announcementDaoProvider))
      : InMemoryAnnouncementRepository(),
);

/// **Les annonces prêtes à l'affichage** — et les deux responsabilités que le
/// serveur ne prendra pas.
///
/// 1. **L'expiration se filtre ici, et nulle part ailleurs.** Le serveur sert
///    `expiresAt` brut et ne retire jamais une annonce expirée du flux delta :
///    un statut « valable jusqu'à ce soir » doit disparaître **à la seconde**, y
///    compris hors-ligne, et un filtrage serveur le laisserait affiché jusqu'à
///    la synchronisation suivante. Le magasin ne le fait pas davantage — une
///    requête SQL est évaluée quand la table change, pas quand l'heure passe.
/// 2. **Le tri est écrit ici, une seule fois** : épinglés d'abord, puis
///    `publishedAt` décroissant, puis l'identifiant en départage. `List.sort`
///    n'est pas stable en Dart : sans ce dernier maillon, deux statuts publiés à
///    la même seconde changeraient d'ordre d'un tri à l'autre, donc d'un `build`
///    à l'autre — le pager sauterait sous le doigt.
///
/// Ce provider ne filtre en revanche **jamais** sur `publishedAt` : le serveur
/// ne sert au mobile ni brouillon ni annonce programmée, tout ce qui arrive est
/// publiable. Re-tester la visibilité ici reviendrait à réimplémenter une règle
/// serveur, avec une horloge d'appareil pour arbitre.
final announcementsProvider = StreamProvider<List<AnnouncementView>>(
  (ref) => ref.watch(announcementRepositoryProvider).announcements().map(
        (all) => _visibleAndSorted(all, DateTime.now().toUtc()),
      ),
  retry: _noAutomaticRetry,
);

/// **L'affordance d'écriture existe-t-elle pour cet utilisateur ?**
///
/// Vrai pour la poignée de personnes qui appartiennent à un compte officiel ;
/// pour tous les autres, l'onglet reste une **visionneuse**, sans bouton de
/// composition ni menu caché.
///
/// La collection d'appartenances est un **confort d'affichage, jamais une
/// autorisation** : le serveur revérifie à chaque écriture. Un membre retiré du
/// bureau dont le téléphone n'a pas synchronisé verra encore le bouton et
/// recevra un 403 — l'écran doit le traiter proprement, pas s'appuyer sur ce
/// drapeau comme sur un droit acquis.
final canComposeAnnouncementProvider = StreamProvider<bool>(
  (ref) => ref.watch(announcementRepositoryProvider).canCompose(),
  retry: _noAutomaticRetry,
);

/// **L'écriture** — le seul provider de cet onglet qui parle au réseau.
///
/// Sans backend, [UnavailableAnnouncementComposer] refuse tout en disant qu'il
/// faut du réseau. Ce n'est pas un bouchon paresseux : l'écriture exige le
/// réseau (ADR-0031), il n'y a **pas** de chemin hors-ligne à simuler, et un
/// double qui « réussirait » en mémoire mentirait sur l'existence d'un tel
/// chemin.
final announcementComposerProvider = Provider<AnnouncementComposer>(
  (ref) => AppEnv.useBackend
      ? HttpAnnouncementComposer()
      : const UnavailableAnnouncementComposer(),
);

/// **Ce que le composeur propose** : mes comptes officiels et les fonds actifs.
///
/// Une lecture de **magasin**, comme le reste de l'onglet — seul l'envoi passe
/// par le réseau. Ouvrir le formulaire sur un appel REST le rendrait dépendant
/// du réseau *à l'ouverture*, et ferait attendre un sélecteur de teintes qui est
/// déjà dans la poche.
final composerOptionsProvider = StreamProvider<ComposerOptions>(
  (ref) => ref.watch(announcementRepositoryProvider).composerOptions(),
  retry: _noAutomaticRetry,
);

/// **L'annonce que l'on modifie**, en valeurs brutes.
///
/// Une `family` sur l'identifiant, comme `teachingByIdProvider` : la route porte
/// l'identifiant, l'écran résout depuis le magasin à chaque `build`. Une valeur
/// `null` n'est pas une erreur — c'est une annonce retirée pendant qu'on la
/// modifiait, et l'écran le dit.
final announcementDraftProvider =
    StreamProvider.family<AnnouncementDraft?, String>(
  (ref, id) => ref.watch(announcementRepositoryProvider).draftOf(id),
  retry: _noAutomaticRetry,
);

/// **Le choix d'une image de fond**, derrière une abstraction.
///
/// À surcharger par [InertStatusImagePicker] dans les tests d'écran : sans ça,
/// monter le composeur toucherait la photothèque de la machine — ou lèverait une
/// `MissingPluginException` que personne ne relierait au formulaire.
final statusImagePickerProvider = Provider<StatusImagePicker>(
  (ref) => GalleryStatusImagePicker(),
);

List<AnnouncementView> _visibleAndSorted(
  List<AnnouncementView> all,
  DateTime now,
) {
  final visible = all
      .where((a) => a.expiresAt == null || a.expiresAt!.isAfter(now))
      .toList()
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final byDate = b.publishedAt.compareTo(a.publishedAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
  return List<AnnouncementView>.unmodifiable(visible);
}
