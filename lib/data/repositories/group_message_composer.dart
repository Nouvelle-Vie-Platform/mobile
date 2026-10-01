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

  /// Envoie [body] dans [groupId]. Rend la **clé d'idempotence** du message, ou
  /// `null` si le texte était vide — un bouton d'envoi qui part sur une chaîne
  /// vide ne doit rien poser du tout.
  ///
  /// La clé est rendue plutôt que gardée : c'est elle que « réessayer » et
  /// « abandonner » désignent.
  Future<String?> send({required String groupId, required String body}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    final clientMessageId = _mintId();
    final createdAt = _now();

    await _dao.rememberPending(
      clientMessageId: clientMessageId,
      groupId: groupId,
      body: trimmed,
      createdAt: createdAt,
    );

    final sent = await _sender.send(
      groupId: groupId,
      body: trimmed,
      clientMessageId: clientMessageId,
      clientCreatedAt: createdAt,
    );

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
  Future<bool> retry(String clientMessageId) async {
    final pending = await _dao.pendingById(clientMessageId);
    if (pending == null) return false;

    final sent = await _sender.send(
      groupId: pending.groupId,
      body: pending.body,
      clientMessageId: pending.clientMessageId,
      clientCreatedAt: pending.createdAt,
    );

    if (!sent) return false;

    await _resynchronize();
    await _dao.purgeReconciled();
    return true;
  }

  /// **Abandonner** un message qui n'est pas parti : l'écho quitte le fil.
  ///
  /// Rien ne part au serveur — il n'a jamais rien reçu de cette clé, ou bien il a
  /// reçu et le flux delta ramènera la ligne, auquel cas le message n'était pas à
  /// abandonner. Dans les deux cas, retirer l'écho est la seule chose honnête à
  /// faire localement.
  Future<void> discard(String clientMessageId) =>
      _dao.forgetPending(clientMessageId);
}
