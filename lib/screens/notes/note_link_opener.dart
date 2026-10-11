/// **L'ouverture d'un lien d'une note** (#191) — ce que `RichNoteEditor.onLinkTap`
/// reçoit quand l'utilisateur choisit « ouvrir » dans le menu d'un lien.
///
/// Les quatre formes du contrat serveur (plan §4), et rien d'autre :
/// `https?://` part au navigateur du système par [ExternalLinkLauncher] ;
/// `nv://note/<id>` ouvre l'éditeur ; `nv://teaching/<id>` le lecteur ;
/// `nv://bible/...` l'onglet Bible — qui, aujourd'hui, ne sait pas encore
/// montrer la référence. Un schéma inconnu ne fait **rien** : un `javascript:`
/// n'entre pas côté serveur, et n'ouvrirait rien ici non plus.
///
/// La route est poussée par la `GoRouter` reçue, jamais par un `BuildContext`
/// (règle des gestes vers une route réservée, `guest_affordances_test`). N5
/// ajoute les sélecteurs d'insertion ; ce fichier n'ouvre que ce qui existe.
library;

import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../data/external_link_launcher.dart';
import '../../router/app_router.dart';

class NoteLinkOpener {
  const NoteLinkOpener({required this.router, required this.external});

  final GoRouter router;
  final ExternalLinkLauncher external;

  Future<void> open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    switch (uri.scheme) {
      case 'http' || 'https':
        await external.open(url.trim());
      case 'nv':
        final segments = uri.pathSegments;
        final id = segments.length == 1 && segments.single.isNotEmpty
            ? segments.single
            : null;
        switch (uri.host) {
          case 'note' when id != null:
            unawaited(router.pushNamed(
              AppRoute.noteEditor,
              pathParameters: {'id': id},
            ));
          case 'teaching' when id != null:
            unawaited(router.pushNamed(
              AppRoute.teachingDetail,
              pathParameters: {'id': id},
            ));
          case 'bible':
            unawaited(router.push('/bible?tab=bible'));
        }
    }
  }
}
