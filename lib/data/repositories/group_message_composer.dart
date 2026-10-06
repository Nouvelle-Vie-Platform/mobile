import '../local/group_dao.dart';
import 'group_message_sender.dart';

/// **L'envoi d'un message, écho optimiste compris** (#96, décision 2 du cadrage).
///
/// Quatre temps, et l'ordre est tout :
///
/// 1. **frapper la clé d'idempotence** (un UUIDv7) ;
/// 2. **poser l'écho** dans `pending_group_messages` — le message est à l'écran, en
///    « cours d'envoi », avant qu'aucun octet ne soit parti ;
/// 3. **poster** ;
/// 4. succès → **déclencher un cycle de synchronisation** et laisser le flux delta
///    ramener la ligne autoritaire ; échec → **marquer l'écho** « pas parti ».
///
/// ## Pourquoi l'écho est posé avant l'envoi, et non après
///
/// Parce que c'est toute la raison d'être de cette rupture : une conversation ne
/// supporte pas d'attendre le réseau togolais. Poser l'écho après la réponse
/// reviendrait au composeur d'annonces, qui attend — défendable pour une
/// publication, faux pour un « amen ».
///
/// ## Pourquoi on n'écrit **pas** la ligne définitive soi-même
///
/// « Le réseau ne peint jamais » (ADR-0026). Le serveur assigne l'`id` (un UUIDv7
/// qui est aussi le curseur), et lui seul connaît l'instant de référence du fil ;
/// une ligne écrite ici porterait une identité que le cycle suivant viendrait
/// doubler ou contredire. L'écho vit dans **sa** table, locale seule, et disparaît
/// de l'écran dès que la vraie ligne arrive — la réconciliation se fait sur la clé
/// d'idempotence, dans `GroupDao.threadOf`.
///
/// ## Pourquoi un échec ne lève pas
///
/// L'écriture a déjà eu lieu **localement**, et l'écran n'a rien à décider : il
/// montre déjà le message, marqué. Faire lever obligerait chaque appelant à
/// rattraper une exception pour n'en rien faire — exactement ce que le rapporteur
/// de progression (#43) a refusé.
class GroupMessageComposer {
  GroupMessageComposer({
    required GroupDao dao,
    required GroupMessageSender sender,
    required Future<void> Function() resynchronize,
    DateTime Function()? now,
    String Function()? mintId,
  })  : _dao = dao,
        _sender = sender,
        _resynchronize = resynchronize,
        _now = now ?? DateTime.now,
        _mintId = mintId ?? mintClientMessageId;

  final GroupDao _dao;
  final GroupMessageSender _sender;
  final Future<void> Function() _resynchronize;

  /// L'horloge, **injectable** : sans elle l'ordre de l'écho serait intestable.
  final DateTime Function() _now;

  /// La frappe de la clé, injectable pour la même raison : un test doit pouvoir
  /// nommer la clé qu'il va retrouver dans `pending_group_messages` et dans le
  /// corps posté.
  final String Function() _mintId;

  /// **Les clés dont l'envoi est en cours** (#140) : le renvoi automatique ne
  /// reposte pas un message que l'envoi d'origine est encore en train de
  /// poster. Ce ne serait pas un doublon — la clé d'idempotence l'interdit au
  /// serveur —, mais un aller-retour pour rien, et un écho qui clignoterait
  /// entre « en cours » et « pas parti ».
  final Set<String> _inFlight = {};

  /// **Les clés que le serveur a refusées pour de bon** (#145) : le renvoi
  /// automatique les saute. Sans elles, un message refusé (plus membre, groupe
  /// disparu, corps rejeté) repartirait à **chaque** cycle de synchronisation,
  /// pour le même refus. L'écho reste « pas parti », avec réessayer et
  /// supprimer : réessayer à la main retire la clé d'ici et tente sa chance.
  ///
  /// En mémoire, délibérément : la table `pending_group_messages` n'a pas de
  /// colonne pour le dire, et M6 n'ouvre pas de palier de schéma. Une
  /// application relancée fait donc **un** essai de plus par message refusé —
  /// borné, là où le défaut était sans fin.
  final Set<String> _refused = {};

  /// Poste [pending] ; un refus définitif est retenu dans [_refused] et vaut
  /// « pas parti ».
  Future<bool> _post({
    required String clientMessageId,
    required String groupId,
    required String body,
    required DateTime createdAt,
    String? replyToMessageId,
  }) async {
    try {
      return await _sender.send(
        groupId: groupId,
        body: body,
        clientMessageId: clientMessageId,
        clientCreatedAt: createdAt,
        replyToMessageId: replyToMessageId,
      );
    } on GroupMessageRefused {
      _refused.add(clientMessageId);
      return false;
    }
  }

  /// Envoie [body] dans [groupId]. Rend la **clé d'idempotence** du message, ou
  /// `null` si le texte était vide — un bouton d'envoi qui part sur une chaîne
  /// vide ne doit rien poser du tout.
  ///
  /// La clé est rendue plutôt que gardée : c'est elle que « réessayer » et
  /// « abandonner » désignent.
  ///
  /// [replyToMessageId] (M2, #141) : le message auquel celui-ci **répond**. Il
  /// est gardé avec l'écho, et repart à chaque renvoi.
  Future<String?> send({
    required String groupId,
    required String body,
    String? replyToMessageId,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    final clientMessageId = _mintId();
    final createdAt = _now();

    await _dao.rememberPending(
      clientMessageId: clientMessageId,
      groupId: groupId,
      body: trimmed,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
    );

    _inFlight.add(clientMessageId);
    final bool sent;
    try {
      sent = await _post(
        clientMessageId: clientMessageId,
        groupId: groupId,
        body: trimmed,
        createdAt: createdAt,
        replyToMessageId: replyToMessageId,
      );
    } finally {
      _inFlight.remove(clientMessageId);
    }

    if (!sent) {
      await _dao.markPendingFailed(clientMessageId);
      return clientMessageId;
    }

    // Le flux delta ramène la ligne autoritaire ; `threadOf` fait alors
    // disparaître l'écho tout seul. Le nettoyage de la table vient après, et
    // aucun écran n'en dépend.
    await _resynchronize();
    await _dao.purgeReconciled();
    return clientMessageId;
  }

  /// **Réessayer** un envoi qui n'est pas parti, sous la **même** clé.
  ///
  /// La même, et c'est tout l'intérêt : si le premier envoi avait en réalité
  /// abouti — réponse perdue, coupure après le `POST` —, le serveur reconnaît la
  /// clé et renvoie le message existant au lieu d'en créer un second. Frapper une
  /// clé neuve ferait du « réessayer » le doublon que la clé existe pour éviter.
  ///
  /// L'écho repasse « en cours » le temps de l'essai (#140) — un « pas parti »
  /// affiché pendant qu'on réessaie mentirait —, et redevient « pas parti » si
  /// l'essai échoue.
  Future<bool> retry(String clientMessageId) async {
    // Le geste de la personne passe outre un refus définitif retenu : c'est elle
    // qui décide de retenter, et un second refus la remettra de côté.
    _refused.remove(clientMessageId);
    if (!await _resend(clientMessageId)) return false;
    await _resynchronize();
    await _dao.purgeReconciled();
    return true;
  }

  /// **Renvoie tout ce qui n'est pas confirmé** (#140) — le renvoi
  /// automatique, appelé après chaque cycle de synchronisation réussi : au
  /// retour du réseau, au retour au premier plan, à la reconnexion du canal.
  ///
  /// Sous la **même** clé, message par message et dans l'ordre de rédaction :
  /// jamais de doublon (piège 5 du plan). Les échos « en cours » sont rejoués
  /// aussi : une application tuée pendant l'envoi les aurait laissés tels quels
  /// pour toujours. Ceux dont l'envoi d'origine tourne encore sont sautés, et
  /// ceux que le serveur a refusés pour de bon aussi (#145, [_refused]).
  ///
  /// Ne déclenche **pas** de cycle : il est lui-même appelé à la fin d'un cycle,
  /// et la ligne serveur arrive par le canal `users/{id}` — ou au cycle suivant.
  Future<void> resendUnconfirmed() async {
    for (final pending in await _dao.unconfirmedPending()) {
      if (_refused.contains(pending.clientMessageId)) continue;
      await _resend(pending.clientMessageId);
    }
    await _dao.purgeReconciled();
  }

  Future<bool> _resend(String clientMessageId) async {
    if (!_inFlight.add(clientMessageId)) return false;
    try {
      final pending = await _dao.pendingById(clientMessageId);
      if (pending == null) return false;

      await _dao.markPendingSending(clientMessageId);
      final sent = await _post(
        clientMessageId: pending.clientMessageId,
        groupId: pending.groupId,
        body: pending.body,
        createdAt: pending.createdAt,
        replyToMessageId: pending.replyToMessageId,
      );
      if (!sent) await _dao.markPendingFailed(clientMessageId);
      return sent;
    } finally {
      _inFlight.remove(clientMessageId);
    }
  }

  /// **Abandonner** un message qui n'est pas parti : l'écho quitte le fil.
  ///
  /// Rien ne part au serveur — il n'a jamais rien reçu de cette clé, ou bien il a
  /// reçu et le flux delta ramènera la ligne, auquel cas le message n'était pas à
  /// abandonner. Dans les deux cas, retirer l'écho est la seule chose honnête à
  /// faire localement.
  Future<void> discard(String clientMessageId) {
    _refused.remove(clientMessageId);
    return _dao.forgetPending(clientMessageId);
  }
}
