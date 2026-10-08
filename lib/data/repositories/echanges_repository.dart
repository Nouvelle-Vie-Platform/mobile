import '../../models/echanges_view.dart';
import '../../models/group_management.dart';
import '../../models/message_media.dart';

/// **Le contrat de lecture de la rubrique « Échanges »** (#96).
///
/// Un repository **dédié et asynchrone**, hors de `ChurchRepository` : c'est le
/// motif que suivent déjà l'agenda, la médiathèque, les rassemblements, les
/// annonces et les documents légaux, et la raison n'est pas le confort —
/// `ChurchRepository` est **synchrone**, et passer son interface entière en
/// `Future` pour un seul domaine branché casserait d'un coup tous les autres.
///
/// **Tout se lit en `Stream`, jamais en `Future`**, et ici cette règle a un nom :
/// le **détachement d'auteur** (ADR-0032) arrive sur une ligne déjà stockée, en
/// cours de route. Une bulle affichée doit perdre son auteur **sous les yeux du
/// lecteur**, pas au prochain démarrage. Un `Future` livrerait une photographie
/// prise au moment du clic — et la seule promesse qui compte, « vos messages ne
/// vous sont plus attribués », ne serait tenue qu'à la réouverture de l'écran.
abstract interface class EchangesRepository {
  /// **Mes conversations**, groupes et tête-à-tête mêlés, triées par récence.
  ///
  /// Une seule liste à plat, sans sections : c'est la décision D7 de
  /// `docs/refonte-echanges.md`, et elle n'est pas rouverte ici.
  Stream<List<ConversationView>> conversations();

  /// **Les groupes à rejoindre** — politique ouverte ou sur demande, dont je ne
  /// suis pas membre.
  ///
  /// Sans cette rangée, le groupe de discussion créé au backoffice ne serait
  /// visible de personne : la politique d'adhésion par défaut est `invite_only`,
  /// et un groupe institutionnel naît avec un roster **vide**.
  Stream<List<DiscoverGroupView>> discoverGroups();

  /// **Le fil d'un groupe**, du plus ancien au plus récent, écho optimiste
  /// compris.
  ///
  /// Les messages en attente sont rendus **à la fin**, avec leur
  /// [MessageDelivery] : c'est ce qui fait qu'un « amen » paraît avant que le
  /// réseau ait fini d'y penser, et qu'un envoi perdu le dise au lieu de rester
  /// « en cours » pour toujours.
  ///
  /// [limit] borne le fil à ses **derniers** messages (#140) : l'historique
  /// s'affiche par pages, et l'écran élargit la fenêtre en remontant. `null` =
  /// tout ce que le magasin possède.
  Stream<List<GroupMessageView>> thread(String groupId, {int? limit});

  /// **Les fichiers partagés au fil** — images, vidéos, documents et fichiers
  /// audio, **jamais les vocaux** (comme WhatsApp) —, les plus récents d'abord.
  /// Ni supprimés pour tous, ni pour moi, ni échos.
  Stream<List<GroupMessageView>> sharedFiles(String groupId);

  /// **Les messages dont le texte porte un lien `http(s)`**, les plus récents
  /// d'abord, mêmes exclusions que [sharedFiles].
  Stream<List<GroupMessageView>> sharedLinks(String groupId);

  /// **Le nombre de non-lus** d'une conversation, une fois (#140) — de quoi
  /// ouvrir le fil sur le premier non-lu.
  Future<int> unreadCount(String groupId);

  /// **La fiche d'un groupe**, roster compris. `null` = le magasin ne connaît pas
  /// cet identifiant — ce qui s'affiche comme une absence, jamais comme une
  /// erreur.
  Stream<GroupDetailView?> group(String groupId);

  /// **La fiche d'une personne.** `null` quand `profiles` ne l'a pas livrée.
  Stream<MemberProfileView?> member(String userId);

  /// **Mes contacts de groupe** (#145) : les personnes avec qui je partage un
  /// groupe qui n'est pas un tête-à-tête — le sélecteur de « Nouvelle
  /// discussion » et des membres d'un groupe qu'on crée. Borné comme le
  /// serveur borne : jamais un annuaire.
  Stream<List<ContactView>> contacts();

  /// **Qui a réagi à ce message** (M2, #141), nommé quand le magasin le peut.
  Stream<List<ReactorView>> reactors(String messageId);

  /// **Combien de messages du fil sont plus récents que [messageId]**, ou
  /// `null` si le magasin ne l'a pas (M2, #141) — pour défiler jusqu'au message
  /// cité.
  Future<int?> newerThan(String groupId, String messageId);

  /// **Le plus ancien message du fil en magasin**, ou `null` (M2, #141).
  Future<String?> oldestMessageId(String groupId);
}

/// **Un fichier qui a sa place dans « Médias, liens et docs »** : image,
/// vidéo, document ou fichier audio — un vocal n'en est pas un.
bool isSharedFile(GroupMessageView message) => switch (message.media?.kind) {
      MessageMediaKind.image ||
      MessageMediaKind.video ||
      MessageMediaKind.document ||
      MessageMediaKind.audio =>
        true,
      _ => false,
    };

/// Double **en mémoire** du contrat, servi quand `AppEnv.useBackend` est faux et
/// dans les tests d'écran.
///
/// Ce n'est pas un bouchon de maquette : il applique **les mêmes règles de
/// lecture** que l'implémentation réelle, parce qu'un double qui construirait ses
/// modèles autrement laisserait invisibles, pendant tout le développement, les
/// bugs qui comptent — au premier rang celui de l'origine d'un message. Il reçoit
/// donc des [GroupMessageView] déjà formés, et c'est au test de les construire
/// avec [messageOriginOf] comme le magasin le fait.
///
/// ⚠️ **Il naît vide, et c'est le point de la tranche.** `InMemoryChurchRepository`
/// était le seul double câblé en production sans condition, et il servait quatre
/// groupes, sept conversations et le même fil de cinq messages pour toutes les
/// discussions. Rien de tout cela n'existe plus : une application sans backend
/// montre désormais une rubrique **vide**, ce qui est la vérité.
class InMemoryEchangesRepository implements EchangesRepository {
  InMemoryEchangesRepository({
    List<ConversationView> conversations = const [],
    List<DiscoverGroupView> discoverGroups = const [],
    Map<String, List<GroupMessageView>> threads = const {},
    Map<String, GroupDetailView> groups = const {},
    Map<String, MemberProfileView> members = const {},
    List<ContactView> contacts = const [],
    Map<String, List<ReactorView>> reactors = const {},
  })  : _conversations = conversations,
        _contacts = contacts,
        _discoverGroups = discoverGroups,
        _threads = threads,
        _groups = groups,
        _members = members,
        _reactors = reactors;

  final List<ConversationView> _conversations;
  final List<DiscoverGroupView> _discoverGroups;
  final Map<String, List<GroupMessageView>> _threads;
  final Map<String, GroupDetailView> _groups;
  final Map<String, MemberProfileView> _members;
  final List<ContactView> _contacts;
  final Map<String, List<ReactorView>> _reactors;

  @override
  Stream<List<ConversationView>> conversations() =>
      Stream.value(_conversations);

  @override
  Stream<List<DiscoverGroupView>> discoverGroups() =>
      Stream.value(_discoverGroups);

  @override
  Stream<List<GroupMessageView>> thread(String groupId, {int? limit}) {
    final all = _threads[groupId] ?? const <GroupMessageView>[];
    return Stream.value(
      limit == null || all.length <= limit
          ? all
          : all.sublist(all.length - limit),
    );
  }

  @override
  Stream<List<GroupMessageView>> sharedFiles(String groupId) =>
      Stream.value(_shared(groupId).where(isSharedFile).toList());

  @override
  Stream<List<GroupMessageView>> sharedLinks(String groupId) => Stream.value(
        _shared(groupId)
            .where((m) => m.body?.toLowerCase().contains('http') ?? false)
            .toList(),
      );

  Iterable<GroupMessageView> _shared(String groupId) =>
      (_threads[groupId] ?? const <GroupMessageView>[]).reversed.where(
            (m) => m.delivery == MessageDelivery.sent && !m.deleted,
          );

  @override
  Future<int> unreadCount(String groupId) async =>
      (_threads[groupId] ?? const <GroupMessageView>[])
          .where((m) => m.unread)
          .length;

  @override
  Stream<GroupDetailView?> group(String groupId) =>
      Stream.value(_groups[groupId]);

  @override
  Stream<MemberProfileView?> member(String userId) =>
      Stream.value(_members[userId]);

  @override
  Stream<List<ContactView>> contacts() => Stream.value(_contacts);

  @override
  Stream<List<ReactorView>> reactors(String messageId) =>
      Stream.value(_reactors[messageId] ?? const []);

  @override
  Future<int?> newerThan(String groupId, String messageId) async {
    final all = _threads[groupId] ?? const <GroupMessageView>[];
    final index = all.indexWhere((m) => m.id == messageId);
    return index < 0 ? null : all.length - 1 - index;
  }

  @override
  Future<String?> oldestMessageId(String groupId) async {
    final all = _threads[groupId] ?? const <GroupMessageView>[];
    return all.isEmpty ? null : all.first.id;
  }
}
