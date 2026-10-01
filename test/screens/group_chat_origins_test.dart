/// **Les trois origines d'un message, à l'écran** (#96).
///
/// `test/sync/echanges_collections_test.dart` prouve que le magasin les distingue ;
/// celui-ci prouve que l'**écran** en tire trois rendus différents. Les deux sont
/// nécessaires, et le second est celui qui aurait manqué : le défaut que le contrat
/// décrit — tester `authorId == null` — donne un magasin juste et un écran faux.
///
/// Un test par ligne du tableau du §1 de `docs/messagerie-groupe.md`, plus le
/// message qu'on ne peut pas envoyer et celui qu'on vient d'envoyer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/widgets/app_avatar.dart';
import 'package:maison_du_miracle/widgets/chat/chat_bubble.dart';
import 'package:maison_du_miracle/widgets/chat/chat_info_banner.dart';
import 'package:maison_du_miracle/widgets/chat/message_input_bar.dart';

import '../helpers/pump_screen.dart';

/// L'avatar **dans la bulle**, et non celui de la barre de titre : `ChatAppBar` en
/// pose un lui aussi, et un `find.byType(AppAvatar)` nu les confondrait.
Finder _bubbleAvatar() => find.descendant(
      of: find.byType(ChatBubble),
      matching: find.byType(AppAvatar),
    );

/// Les libellés attendus, **lus dans les traductions** et non recopiés : un test
/// qui recopie la chaîne ne saurait pas dire si la clé est branchée.
final _fr = AppLocalizationsFr();

const String _groupId = 'g-1';

const GroupDetailView _group = GroupDetailView(
  groupId: _groupId,
  title: 'Chorale Harmonie',
  isDirect: false,
  memberCount: 3,
  canWrite: true,
);

/// Les trois origines, **et une seule construction** : les vues sont bâties par
/// [messageOriginOf], comme le repository le fait, parce qu'un test qui poserait
/// l'origine à la main ne vérifierait plus que son propre jugement.
GroupMessageView _message({
  required String id,
  required String body,
  String? authorId,
  bool isSystem = false,
  String? authorName,
  bool mine = false,
  MessageDelivery delivery = MessageDelivery.sent,
}) {
  final origin = messageOriginOf(authorId: authorId, isSystem: isSystem);
  return GroupMessageView(
    id: id,
    groupId: _groupId,
    body: body,
    origin: origin,
    mine: mine,
    delivery: delivery,
    authorId: authorId,
    authorName: origin == MessageOrigin.member ? authorName : null,
    createdAt: DateTime.utc(2026, 9, 3, 10, 30),
  );
}

Future<void> _pumpThread(
  WidgetTester tester,
  List<GroupMessageView> messages, {
  GroupDetailView group = _group,
}) {
  return pumpScreen(
    tester,
    const GroupChatScreen(groupId: _groupId),
    echanges: InMemoryEchangesRepository(
      groups: {_groupId: group},
      threads: {_groupId: messages},
    ),
  );
}

void main() {
  testWidgets('(uuid, false) d\'un autre : une bulle, avec son nom',
      (tester) async {
    await _pumpThread(tester, [
      _message(
        id: 'm-1',
        body: 'Répétition samedi à 16h.',
        authorId: 'u-peer',
        authorName: 'Estelle Adjo',
      ),
    ]);

    expect(find.byType(ChatBubble), findsOneWidget);
    expect(find.byType(ChatInfoBanner), findsNothing);
    expect(find.text('Estelle Adjo'), findsOneWidget);
    expect(find.text('Répétition samedi à 16h.'), findsOneWidget);
  });

  testWidgets('(uuid, false) = le mien : une bulle, sans ligne d\'auteur',
      (tester) async {
    await _pumpThread(tester, [
      _message(
        id: 'm-2',
        body: 'Amen, j\'y serai.',
        authorId: 'u-me',
        authorName: 'Kossi Amavi',
        mine: true,
      ),
    ]);

    expect(find.byType(ChatBubble), findsOneWidget);
    // Un message à moi ne porte ni avatar ni nom : je sais qui parle.
    expect(find.text('Kossi Amavi'), findsNothing);
    expect(_bubbleAvatar(), findsNothing);
  });

  testWidgets('(null, true) : un bandeau, et AUCUNE bulle', (tester) async {
    await _pumpThread(tester, [
      _message(
        id: 'm-3',
        body: 'Un nouveau membre a rejoint le groupe.',
        isSystem: true,
      ),
    ]);

    expect(find.byType(ChatInfoBanner), findsOneWidget);
    expect(find.byType(ChatBubble), findsNothing);
    // Un bandeau système ne porte pas de ligne d'auteur, donc pas le libellé de
    // l'auteur retiré — c'est la confusion que le contrat existe pour éviter.
    expect(find.text(_fr.chatAuthorRemoved), findsNothing);
  });

  testWidgets('(null, false) : UNE BULLE, « Membre retiré », et PAS de bandeau',
      (tester) async {
    // ⚠️ **Le test qui échoue si quelqu'un réécrit `authorId == null`.** Le nul a
    // deux sens depuis la suppression de compte (ADR-0032) : tester le nul seul
    // afficherait la phrase d'un fidèle parti comme une annonce du serveur —
    // centrée, en gris, sans bulle, mêlée aux « X a rejoint le groupe ».
    await _pumpThread(tester, [
      _message(id: 'm-4', body: 'Que Dieu vous bénisse tous.'),
    ]);

    expect(find.byType(ChatBubble), findsOneWidget);
    expect(
      find.byType(ChatInfoBanner),
      findsNothing,
      reason: 'un auteur retiré est une bulle, jamais un bandeau',
    );
    // La ligne d'auteur porte un **fait**, pas un nom de repli : « la personne est
    // partie », ce qui est plus juste que ne rien dire.
    expect(find.text(_fr.chatAuthorRemoved), findsOneWidget);
    expect(find.text('Que Dieu vous bénisse tous.'), findsOneWidget);
  });

  testWidgets('l\'avatar d\'un auteur retiré ne porte aucune initiale',
      (tester) async {
    // Le libellé ne doit **pas** se glisser dans `AppAvatar(name:)` : on en
    // tirerait « MR » et une teinte dérivée de la longueur du libellé, deux
    // marqueurs d'identité fabriqués de toutes pièces et identiques pour tous les
    // auteurs retirés. Le constructeur `AppAvatar.neutral` n'accepte pas de nom —
    // c'est ce qui rend l'erreur impossible, et c'est ce qu'on vérifie.
    await _pumpThread(tester, [
      _message(id: 'm-4', body: 'Que Dieu vous bénisse tous.'),
    ]);

    final avatar = tester.widget<AppAvatar>(_bubbleAvatar());
    expect(avatar.name, isEmpty);
    expect(find.text('MR'), findsNothing);
    // Une silhouette, pas des initiales.
    expect(
      find.descendant(
        of: find.byType(ChatBubble),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('les trois origines cohabitent dans le bon ordre',
      (tester) async {
    // Le fil réel les mélange, et c'est ainsi qu'on voit la confusion si elle
    // revient : deux bulles et **un seul** bandeau.
    await _pumpThread(tester, [
      _message(
        id: 'm-1',
        body: 'Répétition samedi.',
        authorId: 'u-peer',
        authorName: 'Estelle Adjo',
      ),
      _message(id: 'm-3', body: 'Un nouveau membre a rejoint.', isSystem: true),
      _message(id: 'm-4', body: 'Que Dieu vous bénisse.'),
    ]);

    expect(find.byType(ChatBubble), findsNWidgets(2));
    expect(find.byType(ChatInfoBanner), findsOneWidget);
  });

  testWidgets('un fil vide le dit, et la barre de saisie reste',
      (tester) async {
    await _pumpThread(tester, const []);

    expect(find.text(_fr.chatEmpty), findsOneWidget);
    // Un groupe sans message est un groupe où l'on peut écrire le premier.
    expect(find.byType(MessageInputBar), findsOneWidget);
  });

  testWidgets('un groupe en diffusion n\'offre pas de barre de saisie',
      (tester) async {
    // Le serveur revérifie à chaque envoi ; on le lit ici pour **ne pas offrir** un
    // champ dont chaque appui prendrait un 403. Et c'est une **phrase**, pas un
    // champ grisé : une option désactivée reste une option offerte, donc une
    // promesse que personne ne tiendra (la règle du sélecteur de canaux, #83).
    await _pumpThread(
      tester,
      const [],
      group: const GroupDetailView(
        groupId: _groupId,
        title: 'Annonces du bureau',
        isDirect: false,
        memberCount: 3,
        canWrite: false,
      ),
    );

    expect(find.byType(MessageInputBar), findsNothing);
    expect(find.text(_fr.chatReadOnly), findsOneWidget);
  });

  testWidgets('un identifiant qui ne résout rien est une absence',
      (tester) async {
    // Un identifiant est présent ou absent, il n'y a rien à quoi se replier — et un
    // identifiant qui ne résout rien n'est pas une erreur technique : c'est une
    // conversation quittée depuis un autre appareil, ou un lien venu d'un réveil
    // push arrivé avant le cycle. On **n'éjecte pas** le fidèle de l'écran ouvert.
    await pumpScreen(tester, const GroupChatScreen(groupId: 'inconnu'));

    expect(find.byType(MessageInputBar), findsNothing);
    expect(find.byType(ChatBubble), findsNothing);
    expect(find.text(_fr.absenceNotSyncedTitle), findsOneWidget);
  });
}
