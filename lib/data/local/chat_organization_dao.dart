import 'package:drift/drift.dart';

import 'app_database.dart';
import 'group_dao.dart';
import 'tables/group_tables.dart';

part 'chat_organization_dao.g.dart';

/// **Organiser ses discussions** (#146, tranche M8) — archiver, épingler,
/// rechercher, et retrouver un message dans son fil.
///
/// Un DAO à part de `GroupDao` : il lit les mêmes tables, mais ce qu'il porte
/// est une fonction à part — le rangement et la recherche —, et `GroupDao` est
/// le fichier que toutes les tranches de la messagerie touchent.
///
/// ## Le rangement effectif : l'outbox l'emporte
///
/// Un geste fait sur ce téléphone (`pending_group_arrangements`) l'emporte sur
/// la ligne servie (`group_arrangements`) tant qu'il n'est pas confirmé : la
/// discussion quitte la liste à l'instant du geste, réseau ou pas. La même
/// règle est écrite dans la requête des conversations (`GroupDao`) ; ici, elle
/// sert au geste suivant (bascule du menu, borne des trois épingles).
@DriftAccessor(
  tables: [
    Groups,
    GroupMembers,
    GroupMessages,
    PendingGroupMessages,
    Profiles,
    GroupArrangements,
    PendingGroupArrangements,
    // M2 (#141) : mes « supprimé pour moi » ne reviennent pas par la recherche.
    GroupMessageHides,
  ],
)
class ChatOrganizationDao extends DatabaseAccessor<AppDatabase>
    with _$ChatOrganizationDaoMixin {
  ChatOrganizationDao(super.db);

  // ───────────────────────────────────────────────────────────────────────────
  // Le rangement
  // ───────────────────────────────────────────────────────────────────────────

  /// **Le rangement servi** d'une discussion, ou `null` (jamais rangée).
  Future<GroupArrangementRow?> arrangementOf(String groupId) =>
      (select(groupArrangements)..where((a) => a.groupId.equals(groupId)))
          .getSingleOrNull();

  /// **Le rangement effectif** d'une discussion : le geste local en attente
  /// s'il y en a un, sinon la ligne servie, sinon « ni archivée ni épinglée ».
  Future<({bool archived, bool pinned})> effectiveArrangementOf(
    String groupId,
  ) async {
    final pending = await pendingArrangementOf(groupId);
    if (pending != null) {
      return (archived: pending.archived, pinned: pending.pinned);
    }
    final served = await arrangementOf(groupId);
    return (
      archived: served?.archivedAt != null,
      pinned: served?.pinnedAt != null,
    );
  }

  /// **Le nombre de mes discussions épinglées**, effectif (outbox comprise),
  /// sur mes appartenances **actives** — celles que la liste montre. [except]
  /// écarte une discussion (celle qu'on s'apprête à ranger).
  Future<int> pinnedCount(String userId, {String? except}) {
    return customSelect(
      '''
SELECT COUNT(*) AS n
FROM group_members AS me
LEFT JOIN group_arrangements AS ga ON ga.group_id = me.group_id
LEFT JOIN pending_group_arrangements AS pa ON pa.group_id = me.group_id
WHERE me.user_id = ?1
  AND me.group_id <> ?2
  AND (CASE WHEN pa.group_id IS NOT NULL THEN pa.pinned
            ELSE ga.pinned_at IS NOT NULL END) = 1
''',
      variables: [Variable<String>(userId), Variable<String>(except ?? '')],
      readsFrom: {groupMembers, groupArrangements, pendingGroupArrangements},
    ).map((row) => row.read<int>('n')).getSingle();
  }

  /// **Pose un rangement local**, l'état voulu complet. Remplace le précédent :
  /// c'est le dernier geste qui compte.
  Future<void> rememberArrangement({
    required String groupId,
    required bool archived,
    required bool pinned,
    required DateTime requestedAt,
  }) {
    return into(pendingGroupArrangements).insert(
      PendingGroupArrangementsCompanion.insert(
        groupId: groupId,
        archived: archived,
        pinned: pinned,
        requestedAt: requestedAt,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<PendingGroupArrangementRow?> pendingArrangementOf(String groupId) =>
      (select(pendingGroupArrangements)
            ..where((p) => p.groupId.equals(groupId)))
          .getSingleOrNull();

  /// Les rangements locaux encore à confirmer — ce que le renvoi rejoue.
  Future<List<PendingGroupArrangementRow>> pendingArrangements() =>
      select(pendingGroupArrangements).get();

  /// **Le rangement est confirmé (ou refusé)** : la ligne locale part — mais
  /// seulement si elle demande toujours **cet** état. Un geste différent posé
  /// pendant l'aller-retour reste, et partira à son tour.
  Future<void> forgetArrangement({
    required String groupId,
    required bool archived,
    required bool pinned,
  }) {
    return (delete(pendingGroupArrangements)
          ..where(
            (p) =>
                p.groupId.equals(groupId) &
                p.archived.equals(archived) &
                p.pinned.equals(pinned),
          ))
        .go();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // La recherche locale
  // ───────────────────────────────────────────────────────────────────────────

  /// **Chercher le texte des messages de mes discussions**, dans le magasin —
  /// instantané, hors ligne.
  ///
  /// Bornée à mes appartenances **actives** (la jointure sur `group_members`),
  /// comme le serveur. Ni System Messages, ni médias sans texte. Les jokers de
  /// `LIKE` de la requête sont échappés : chercher « 100% » cherche ces quatre
  /// caractères. ⚠️ Le `LIKE` de SQLite n'ignore la casse que pour l'ASCII :
  /// « école » ne trouve pas « École ». La route serveur (`ILIKE`) le fait.
  ///
  /// Ni un message **supprimé pour tous** (le tombstone gardé), ni un message
  /// **supprimé pour moi** (M2, #141 — `GroupDao.notHiddenForMe`).
  Future<List<MessageSearchRecord>> searchMessages(
    String userId,
    String query, {
    int limit = 50,
  }) {
    return customSelect(
      '''
SELECT
  m.id          AS message_id,
  m.group_id    AS group_id,
  m.body        AS body,
  m.created_at  AS created_at,
  m.author_id   AS author_id,
  author.display_name AS author_name
FROM group_messages AS m
JOIN group_members AS me ON me.group_id = m.group_id AND me.user_id = ?1
LEFT JOIN profiles AS author ON author.id = m.author_id
WHERE m.is_system = 0
  AND m.body IS NOT NULL
  AND m.body LIKE ?2 ESCAPE '\\'
  AND m.deleted_at IS NULL
  AND ${GroupDao.notHiddenForMe('m')}
ORDER BY m.created_at DESC, m.id DESC
LIMIT ?3
''',
      variables: [
        Variable<String>(userId),
        Variable<String>('%${escapeLikePattern(query)}%'),
        Variable<int>(limit),
      ],
      readsFrom: {groupMessages, groupMembers, profiles, groupMessageHides},
    )
        .map(
          (row) => MessageSearchRecord(
            messageId: row.read<String>('message_id'),
            groupId: row.read<String>('group_id'),
            body: row.read<String>('body'),
            createdAt: row.read<DateTime?>('created_at'),
            authorId: row.read<String?>('author_id'),
            authorName: row.read<String?>('author_name'),
          ),
        )
        .get();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Retrouver un message dans son fil
  // ───────────────────────────────────────────────────────────────────────────

  /// **La place d'un message dans son fil, comptée depuis le plus récent** —
  /// la fenêtre que le fil doit ouvrir pour le contenir. `null` si le magasin
  /// ne l'a pas (pas encore chargé, ou supprimé).
  ///
  /// L'ordre est celui de `GroupDao.threadOf` : `(created_at, id)`, et comme
  /// lui sans mes « supprimé pour moi » (M2, #141), qui ne sont pas dans le
  /// fil. Les échos
  /// en attente comptent aussi — ils sont au bas du fil, donc dans la fenêtre.
  Future<int?> positionFromNewest(String groupId, String messageId) async {
    final row = await customSelect(
      '''
SELECT
  EXISTS (SELECT 1 FROM group_messages AS f
    WHERE f.id = ?2 AND f.group_id = ?1 AND ${GroupDao.notHiddenForMe('f')}) AS found,
  (SELECT COUNT(*) FROM group_messages AS m, group_messages AS t
    WHERE t.id = ?2 AND t.group_id = ?1 AND m.group_id = ?1
      AND ${GroupDao.notHiddenForMe('m')}
      AND (m.created_at > t.created_at
           OR (m.created_at = t.created_at AND m.id >= t.id)))
  + (SELECT COUNT(*) FROM pending_group_messages AS p WHERE p.group_id = ?1)
  AS position
''',
      variables: [Variable<String>(groupId), Variable<String>(messageId)],
      readsFrom: {groupMessages, pendingGroupMessages, groupMessageHides},
    ).getSingle();
    if (!row.read<bool>('found')) return null;
    return row.read<int>('position');
  }

  /// **Le plus ancien message du fil en magasin** — le point de départ de la
  /// page d'historique suivante.
  Future<String?> oldestMessageIdOf(String groupId) {
    return (select(groupMessages)
          ..where((m) => m.groupId.equals(groupId))
          ..orderBy([
            (m) => OrderingTerm.asc(m.createdAt),
            (m) => OrderingTerm.asc(m.id),
          ])
          ..limit(1))
        .map((m) => m.id)
        .getSingleOrNull();
  }

  /// **Le plus récent message du fil** — « Marquer comme lu » avance la lecture
  /// jusqu'à lui.
  Future<({String id, DateTime createdAt})?> newestMessageOf(
    String groupId,
  ) async {
    final row = await (select(groupMessages)
          ..where((m) => m.groupId.equals(groupId) & m.createdAt.isNotNull())
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.id),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return (id: row.id, createdAt: row.createdAt!);
  }
}

/// Un message trouvé par la recherche locale.
class MessageSearchRecord {
  const MessageSearchRecord({
    required this.messageId,
    required this.groupId,
    required this.body,
    this.createdAt,
    this.authorId,
    this.authorName,
  });

  final String messageId;
  final String groupId;
  final String body;
  final DateTime? createdAt;
  final String? authorId;
  final String? authorName;
}

/// Échappe les jokers de `LIKE` (`%`, `_`) et le caractère d'échappement : une
/// requête se cherche **littéralement**. La clause porte `ESCAPE '\'`.
String escapeLikePattern(String text) =>
    text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

/// **Une ligne de rangement reçue hors du tirage est-elle à ranger ?** Oui si
/// elle n'est pas **plus ancienne** que la locale (`arrangedAt`).
///
/// La comparaison se fait à la seconde : le magasin range un instant à la
/// seconde, et deux gestes dans la même seconde ne se départagent plus — on
/// range alors l'arrivant, ce que la synchronisation corrigera si besoin. Une
/// ligne sans instant, ou une locale sans instant, se range.
bool arrangementIsNotOlder(
  GroupArrangementRow? local,
  Map<String, Object?> incoming,
) {
  final localAt = local?.arrangedAt;
  if (localAt == null) return true;
  final raw = incoming['arrangedAt'];
  if (raw is! String) return true;
  final incomingAt = DateTime.tryParse(raw);
  if (incomingAt == null) return true;
  final seconds = incomingAt.millisecondsSinceEpoch ~/ 1000;
  return seconds >= localAt.millisecondsSinceEpoch ~/ 1000;
}
