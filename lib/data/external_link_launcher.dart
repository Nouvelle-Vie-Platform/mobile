import 'package:flutter/foundation.dart';

/// **Ouvrir une adresse dans le navigateur du système**, derrière une
/// abstraction (#82).
///
/// Le seul type de destination dont l'adresse est écrite à la main au portail —
/// un fournisseur de dons, une chaîne vidéo —, et le seul dont le dépôt ne peut
/// rien promettre. Il s'ouvre **pour les invités comme pour les membres** :
/// aucune garde de session ne le protège, parce qu'il ne mène à rien de l'église.
///
/// Même motif que `StoreLauncher`, `DiskSpace`, `AppVersionReader` et
/// `StatusImagePicker` : l'écran ne connaît que ce contrat, et un test prouve que
/// le geste l'appelle sans qu'aucune application tierce s'ouvre sur la machine de
/// test.
///
/// [open] rend `true` si le navigateur s'est ouvert. Il **ne lève jamais** : un
/// menu n'est pas un formulaire, et un écran rouge posé par un onglet serait la
/// pire façon de rater un lien.
abstract interface class ExternalLinkLauncher {
  Future<bool> open(String url);
}

/// L'implémentation en service aujourd'hui — **elle n'ouvre rien**, et c'est
/// assumé, pour exactement la raison d'`UnavailableStoreLauncher`.
///
/// **Le dépôt n'a pas `url_launcher`.** L'ajouter est un greffon natif de plus,
/// qui exige une déclaration `<queries>` dans le manifeste Android et une entrée
/// `LSApplicationQueriesSchemes` côté iOS — pour un geste qu'aucun fidèle ne peut
/// atteindre aujourd'hui : la graine de la médiathèque mobile ne contient
/// **aucune** entrée `externe` (`menu_seed.ts` n'en sème qu'une, le catalogue
/// entier), et il faut qu'un administrateur en crée une au portail pour que le
/// chemin existe.
///
/// Il se câble donc **le jour où le portail en publiera une**, et c'est le même
/// arbitrage qu'`UnavailableStoreLauncher` : le chemin complet est écrit et
/// testé, seule la dernière ligne attend. Ce qui n'attend pas, en revanche, c'est
/// la décision — une entrée `externe` est une destination **résolue**, elle
/// paraît dans la barre, et elle ne se replie sur aucune autre.
class UnavailableExternalLinkLauncher implements ExternalLinkLauncher {
  const UnavailableExternalLinkLauncher();

  @override
  Future<bool> open(String url) async => false;
}

/// Lanceur **qui retient ce qu'on lui a demandé d'ouvrir** : le double des
/// tests.
///
/// Exposé en production plutôt que défini dans `test/`, pour la raison de
/// `RecordingStoreLauncher` et de `FixedAppVersionReader` — un double qui vit à
/// côté de son contrat se met à jour avec lui.
@visibleForTesting
class RecordingExternalLinkLauncher implements ExternalLinkLauncher {
  RecordingExternalLinkLauncher({this.succeeds = true});

  /// Ce que [open] rend. Le contrat le promet, et un double qui mentirait sur ce
  /// point ne vaudrait rien.
  final bool succeeds;

  /// Les adresses demandées, dans l'ordre.
  final List<String> opened = [];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return succeeds;
  }
}
