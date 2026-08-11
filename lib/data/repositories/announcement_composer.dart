import '../../models/announcement_draft.dart';

/// Nature d'un échec d'écriture d'annonce.
///
/// Ces codes existent pour la même raison que ceux de l'agenda
/// ([CalendarErrorCode]) : **un refus n'est pas une panne, et les deux ne se
/// disent pas de la même façon**. La couche données ne rédige pas de message —
/// elle dit *quoi* a échoué, l'écran choisit le texte. Jamais un code HTTP brut
/// à l'écran, jamais un `toString()` d'exception.
enum AnnouncementWriteErrorCode {
  /// Le serveur n'a **pas répondu** : coupure, DNS, timeout, TLS.
  ///
  /// C'est le cas hors-ligne, et il n'a rien d'exotique ici : l'écriture exige
  /// le réseau (ADR-0031), il n'y a **ni file d'envoi ni brouillon local** pour
  /// l'absorber. L'écran doit donc le **dire** — « il faut du réseau » — et
  /// garder la saisie à l'écran, pas la perdre en même temps que la connexion.
  network,

  /// **401** — la session n'est plus valide. La purge du token et le retour à
  /// `/auth` ont déjà été déclenchés globalement par `UnauthorizedInterceptor` :
  /// l'écran n'a pas à proposer « Réessayer » comme si ça pouvait marcher.
  unauthorized,

  /// **403** — je ne suis (plus) membre de ce compte officiel.
  ///
  /// **Le chemin normal, pas un cas exotique.** La collection d'appartenances
  /// est un confort d'affichage, jamais une autorisation : un membre retiré du
  /// bureau dont le téléphone n'a pas synchronisé voit encore le bouton et
  /// reçoit ce 403. Distinct de [unauthorized] : la session est parfaitement
  /// valide, c'est le droit sur ce compte qui a disparu.
  forbidden,

  /// **422** — le serveur refuse le contenu du brouillon (rien à publier, fin
  /// de publication antérieure au début, champ interdit). Son message est
  /// exploitable ; l'écran garde la saisie et laisse corriger.
  rejected,

  /// **404 / 410** — l'annonce visée n'existe plus. Un autre membre du même
  /// compte l'a supprimée pendant qu'on la modifiait ; ce n'est pas une panne,
  /// et réessayer ne la ressuscitera pas.
  gone,

  /// Le serveur a répondu, mais en erreur (5xx). Il est joignable : ce n'est pas
  /// la connexion de l'auteur qui est en cause.
  server,

  /// Ni l'un ni l'autre (requête annulée, cas non prévu).
  unknown,
}

/// Échec d'écriture d'annonce, tel que le voit l'appelant.
class AnnouncementWriteException implements Exception {
  const AnnouncementWriteException(this.code, [this.message]);

  final AnnouncementWriteErrorCode code;

  /// Message **déjà localisé par le serveur** quand il en a fourni un.
  ///
  /// À n'afficher que pour [AnnouncementWriteErrorCode.rejected], où il dit
  /// précisément quel champ ne va pas ; les autres codes ont leur propre libellé
  /// côté app. Un message serveur n'est pas un texte d'interface.
  final String? message;

  @override
  String toString() => 'AnnouncementWriteException(${code.name}'
      '${message == null ? '' : ': $message'})';
}

/// **L'écriture des annonces** — la seule partie de l'onglet qui parle au
/// réseau.
///
/// Séparé d'`AnnouncementRepository` à dessein, et ce n'est pas une question de
/// taille de fichier : les deux contrats n'ont ni la même source, ni le même
/// régime, ni les mêmes pannes.
///
/// | | `AnnouncementRepository` | `AnnouncementComposer` |
/// |---|---|---|
/// | source | le magasin local | le serveur |
/// | forme | `Stream` (le magasin réécrit sous l'écran) | `Future` (un acte, une réponse) |
/// | hors-ligne | régime **normal** | **impossible**, et ça se dit |
///
/// Les fondre en une seule interface donnerait un objet dont la moitié des
/// méthodes marchent en avion et l'autre pas — la pire des documentations.
///
/// **Aucune de ces méthodes n'écrit dans le magasin local.** Le réseau ne peint
/// jamais (ADR-0026) : après une écriture réussie, c'est un cycle de
/// synchronisation qui ramène l'annonce par le flux delta. Écrire la ligne
/// nous-mêmes fabriquerait une seconde source de vérité, dont l'`id`, la
/// branche dérivée et l'horodatage seraient des devinettes.
abstract interface class AnnouncementComposer {
  /// Publie une nouvelle annonce.
  ///
  /// Lève une [AnnouncementWriteException] : réseau, 403, 422 et panne serveur
  /// se distinguent par [AnnouncementWriteException.code].
  Future<void> create(AnnouncementDraft draft);

  /// Remplace une annonce existante.
  ///
  /// **N'importe laquelle des annonces de mes comptes**, pas seulement les
  /// miennes : un compte officiel est un espace éditorial collectif, le lecteur
  /// tient le comité pour responsable de ce qui est signé de son nom, et un
  /// comité doit pouvoir se corriger. Le serveur tranche, comme toujours.
  Future<void> update({required String id, required AnnouncementDraft draft});

  /// Retire une annonce (soft-delete côté serveur, donc **rétractation** dans
  /// le flux delta — c'est elle qui la fera disparaître du magasin des autres
  /// téléphones, ADR-0025).
  Future<void> remove(String id);
}

/// Composeur du **mode maquette** : il refuse tout, et il le dit.
///
/// Servi quand `AppEnv.useBackend` est faux. Ce n'est pas un bouchon paresseux :
/// c'est exactement le comportement attendu, parce qu'il n'y a rien à quoi
/// bouchonner. L'écriture exige le réseau (ADR-0031) — pas de file d'envoi, pas
/// de brouillon local, pas d'`id` fabriqué hors-ligne. Un double qui
/// « réussirait » en mémoire mentirait deux fois : sur le succès, et sur
/// l'existence d'un chemin hors-ligne.
///
/// [AnnouncementWriteErrorCode.network] et non un code dédié : du point de vue
/// de l'auteur, un serveur absent parce qu'il n'y en a pas et un serveur absent
/// parce que le réseau a coupé donnent le même écran, et c'est le bon.
class UnavailableAnnouncementComposer implements AnnouncementComposer {
  const UnavailableAnnouncementComposer();

  @override
  Future<void> create(AnnouncementDraft draft) => _refuse();

  @override
  Future<void> update({required String id, required AnnouncementDraft draft}) =>
      _refuse();

  @override
  Future<void> remove(String id) => _refuse();

  Future<Never> _refuse() => Future.error(
        const AnnouncementWriteException(AnnouncementWriteErrorCode.network),
      );
}
