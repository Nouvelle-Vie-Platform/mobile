import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// L'implémentation en service : **le navigateur du système**, par
/// `url_launcher`.
///
/// Le greffon est arrivé avec les médias de la messagerie (M4, #143), qui
/// ouvrent une position dans l'application de cartes et un numéro dans le
/// composeur ; le manifeste Android déclare depuis les `<queries>` `https`,
/// `geo` et `tel`. Il n'y avait donc plus de raison de laisser ce chemin
/// inerte.
///
/// Seule une adresse `http`/`https` bien formée s'ouvre : une entrée `externe`
/// est écrite à la main au portail, et un schéma inattendu (`intent:`,
/// `file:`) ne doit rien lancer. [open] **ne lève jamais**.
class UrlLauncherExternalLinkLauncher implements ExternalLinkLauncher {
  const UrlLauncherExternalLinkLauncher();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// L'implémentation **qui n'ouvre rien** : celle d'avant `url_launcher`,
/// gardée pour un contexte sans greffon (un banc, une plateforme non prise en
/// charge). Elle rend toujours `false`.
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
