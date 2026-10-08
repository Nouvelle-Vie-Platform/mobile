/// **Aucun cul-de-sac** : rien de ce qu'un invité peut toucher ne mène à un
/// écran que la garde refuse.
///
/// C'est la faute la plus silencieuse de tout le mode invité. Un bouton qui
/// pointe vers une route réservée ne plante pas, ne rougit pas, et ne se signale
/// pas : la garde renvoie sur `/home`, l'écran ouvert disparaît sous les doigts,
/// et la personne n'apprend rien — pas même qu'un compte existe. C'est ce que
/// `requireSession()` existe pour remplacer.
///
/// **Un garde-fou de source**, comme le dépôt en a déjà trois (le seul fichier
/// qui importe `just_audio`, l'interdiction de `pick(` dans les fichiers légaux,
/// l'interdiction d'écrire dans `playback_progress`). La raison est la même : ce
/// qu'on veut vérifier est l'absence d'un motif dans **tout** `lib/`, pas le
/// comportement d'un écran — et un test d'écran ne parle que des écrans qu'il
/// monte, donc jamais de celui que quelqu'un ajoutera demain.
///
/// La liste des routes fermées est **dérivée de `memberOnlyRoutes`** et non
/// recopiée : une route qui entre dans la liste du routeur entre d'office dans ce
/// test, et devra être soit gardée par un geste, soit justifiée ci-dessous.
///
/// ## Ce que ce test ne peut pas voir
///
/// Il travaille au fichier, pas au site d'appel : un fichier qui appelle
/// `requireSession()` pour un geste et pousse l'autre à nu lui échappe. C'est
/// pourquoi il ne vient **pas seul** — `guest_gestures_test.dart` exerce chaque
/// geste branché, un par un, en invité et en membre.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/router/app_router.dart';

import '../helpers/guest_app.dart';

/// Les écrans qui n'ont **pas** à garder leurs gestes, et pourquoi.
///
/// Deux natures, et la seconde est celle qu'on oublie :
///
/// - ceux qu'une **route** réservée sert : la garde du routeur les a déjà fermés,
///   et un invité ne les monte jamais ;
/// - ceux qu'un **onglet** fermé sert, ou une condition d'affichage qui suppose
///   une session. Il n'y a pas de route à interroger pour eux — d'où cette liste,
///   et d'où les justifications.
const _screensBehindTheGuard = <String, String>{
  'lib/screens/profile_screen.dart': '/profile est réservé',
  'lib/screens/prayer_requests_screen.dart': '/prayers est réservé',
  'lib/screens/requests_screen.dart': '/requests est réservé',
  'lib/screens/group_chat_screen.dart': '/group-chat est réservé',
  'lib/screens/group_info_screen.dart': '/group-info est réservé',
  'lib/screens/member_profile_screen.dart': '/member-profile est réservé',
  // Le hub des conversations n'est **pas** une route : c'est l'onglet 2 de la
  // coquille, et sans session la coquille met le formulaire de connexion à sa
  // place (`HomeShell._screenFor`). Un invité ne le monte donc même pas — il le
  // montait jusqu'ici hors de l'écran, un `IndexedStack` construisant tous ses
  // enfants.
  // Le « + » et la loupe du bandeau (nouvelle discussion, nouvelle requête,
  // recherche) : posés pour un membre seulement — un invité n'a pas d'onglets.
  'lib/screens/groups_screen.dart': 'onglet 2, remplacé par le formulaire',
  // L'onglet « Requêtes » de la page Échanges (#148) : monté par
  // `GroupsScreen` pour un membre seulement — la page elle-même ne l'est pas
  // pour un invité — et par `/requests`, route réservée.
  'lib/widgets/community/my_requests_tab.dart':
      'onglet de membre, sous Échanges ou /requests',
  // M8 (#146) : les archives et la recherche sont des routes réservées.
  'lib/screens/archived_chats_screen.dart': '/chats/archived est réservé',
  'lib/screens/chat_search_screen.dart': '/chats/search est réservé',
  // Le bandeau de complétion de profil ne se rend que si `authProvider.user`
  // n'est pas nul (`showBanner` dans `HomeScreen`, et son jumeau dans le Profil).
  // Il vit sur un écran ouvert, mais il n'existe que pour un membre — et un
  // membre à profil incomplet, qui plus est.
  'lib/widgets/profile_completion_banner.dart':
      'ne se rend que pour un utilisateur non nul',
  // #145 (M6) : démarrer une discussion, créer un groupe, administrer.
  'lib/screens/new_conversation_screen.dart': '/new-conversation est réservé',
  'lib/screens/create_group_screen.dart': '/create-group est réservé',
  // Les gestes de la fiche d'un groupe : montés par `/group-info`, réservé.
  'lib/widgets/community/group_admin_section.dart':
      'monté par /group-info, réservé',
  // La ligne « Médias, liens et docs » de la fiche d'un groupe.
  'lib/widgets/chat/media/group_shared_media.dart':
      'monté par /group-info, réservé',
};

/// Les fichiers qui **nomment** les routes sans y naviguer.
const _notNavigation = <String>{
  // La table elle-même, et la garde.
  'lib/router/app_router.dart',
  // Un exemple d'appel dans un commentaire de documentation.
  'lib/state/session_gate.dart',
  // Les routes où le mini-lecteur s'efface (`MiniPlayerHost.hiddenRoutes`) :
  // il compare leur nom à celui du sommet de la pile, il n'y pousse rien.
  'lib/widgets/mini_player_host.dart',
};

/// `member-profile` → `memberProfile` : le nom de route tel que le routeur le
/// déclare, vers le champ d'`AppRoute` tel que le code l'écrit.
String _fieldFor(String routeName) {
  final parts = routeName.split('-');
  return [
    parts.first,
    for (final part in parts.skip(1))
      part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1),
  ].join();
}

/// Une ligne de **commentaire** — à écarter partout dans ce fichier.
///
/// Sans ce filtre, le test se retourne contre sa propre documentation : les
/// commentaires qui expliquent *pourquoi* on ne passe plus par
/// `context.pushNamed` contiennent la chaîne qu'on interdit, et nommer une route
/// réservée dans une phrase suffirait à faire rougir l'écran qui la garde
/// correctement.
bool _isComment(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') || trimmed.startsWith('*');
}

/// Le code d'un fichier, **commentaires de ligne retirés**.
String _codeOf(String path) =>
    File(path).readAsLinesSync().where((line) => !_isComment(line)).join('\n');

/// Tous les `.dart` de `lib/`, chemins relatifs à la racine du paquet.
List<String> _libSources() {
  final root = Directory('lib');
  expect(root.existsSync(), isTrue,
      reason: 'le test doit tourner depuis la racine du paquet');
  return [
    for (final entity in root.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        entity.path.replaceAll(Platform.pathSeparator, '/'),
  ]..sort();
}

void main() {
  late Set<String> closedFields;

  setUp(() {
    final GoRouter router = guestContainer().read(routerProvider);
    final names = <String>[
      for (final route in router.configuration.routes)
        if (route is GoRoute &&
            memberOnlyRoutes.contains(route.path) &&
            route.name != null)
          route.name!,
    ];
    // Le garde-fou du garde-fou : `guest_guard_test.dart` prouve déjà que chaque
    // entrée de `memberOnlyRoutes` désigne une route réelle. Ici on vérifie
    // qu'elles sont toutes **nommées**, sans quoi elles échapperaient au balayage
    // de source sans que rien ne le dise.
    expect(names, hasLength(memberOnlyRoutes.length));
    closedFields = names.map(_fieldFor).toSet();
  });

  test('les champs d\'AppRoute dérivés existent vraiment', () {
    // Une dérivation kebab → camel qui se tromperait rendrait un ensemble de
    // jetons qu'aucun fichier ne porte — et le balayage passerait au vert en ne
    // cherchant rien. On le prouve sur la table elle-même, qui les déclare tous.
    final declarations = File('lib/router/app_router.dart').readAsStringSync();
    for (final field in closedFields) {
      expect(
        declarations,
        contains('static const $field ='),
        reason: '$field doit être un champ d\'AppRoute',
      );
    }
  });

  test('tout écran ouvert qui mène à un geste réservé exige une session', () {
    final offenders = <String>[];
    final gated = <String>[];

    for (final path in _libSources()) {
      if (_notNavigation.contains(path)) continue;
      final source = _codeOf(path);
      final named = closedFields
          .where((field) => RegExp('AppRoute\\.$field\\b').hasMatch(source))
          .toList();
      if (named.isEmpty) continue;
      if (_screensBehindTheGuard.containsKey(path)) continue;
      if (source.contains('requireSession')) {
        gated.add(path);
        continue;
      }
      final routes = named.join(', ');
      offenders.add('$path → $routes');
    }

    // **C'est ici qu'un cul-de-sac apparaît** : un écran ouvert qui pousse une
    // route réservée sans passer par `requireSession()`. Soit le geste demande la
    // connexion, soit le bouton n'est pas là — il n'y a pas de troisième forme.
    expect(offenders, isEmpty);
    // Et le balayage doit avoir trouvé quelque chose : un jour où la regex ne
    // matcherait plus rien, l'assertion ci-dessus passerait pour rien.
    expect(gated, isNotEmpty);
  });

  test('un geste gardé ne navigue pas par le `BuildContext`', () {
    // **La contrepartie de la reprise.** `requireSession()` met le geste de côté
    // et le rejoue après la connexion, qui reconstruit la pile de routes. Un
    // `context.pushNamed` rejoué s'appuierait alors sur un élément dont rien ne
    // garantit qu'il est encore monté ; la `GoRouter`, lue dans le conteneur au
    // moment de l'appui, survit à tout. C'est ce qui rend ces gestes rejouables,
    // et c'est mécaniquement vérifiable.
    final offenders = <String>[];

    for (final path in _libSources()) {
      if (_notNavigation.contains(path)) continue;
      if (_screensBehindTheGuard.containsKey(path)) continue;
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i])) continue;
        final mentionsClosed = closedFields
            .any((field) => RegExp('AppRoute\\.$field\\b').hasMatch(lines[i]));
        if (!mentionsClosed) continue;
        for (var j = (i - 3) < 0 ? 0 : i - 3; j <= i; j++) {
          if (_isComment(lines[j])) continue;
          if (lines[j].contains('context.pushNamed') ||
              lines[j].contains('context.goNamed')) {
            offenders.add('$path:${i + 1}');
          }
        }
      }
    }

    expect(offenders, isEmpty);
  });

  test('chaque écran justifié existe encore', () {
    // Un fichier renommé quitterait la liste en silence, et son écran rentrerait
    // dans le balayage — ou en sortirait — sans que personne ne relise la
    // justification.
    for (final path in _screensBehindTheGuard.keys) {
      expect(File(path).existsSync(), isTrue, reason: '$path a disparu');
    }
  });
}
