import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_version.dart';
import '../data/store_launcher.dart';
import '../data/update/app_reloader.dart';
import 'app_version_providers.dart';
import 'device_settings_providers.dart';

/// **Le seuil de version sous lequel l'application invite à monter** — la plus
/// basse version encore recommandée, telle que `1.4.0`. `null` veut dire
/// « aucun seuil réglé », donc **aucun bandeau**.
///
/// ## Le repli était ouvert, et #91 l'a refermé par la source
///
/// Le seuil se règle depuis le portail (écran *Appareils*) et devait descendre
/// par la **synchronisation**. Il ne descendait pas, et ce n'était pas un
/// oubli : `device_settings.update_banner_min_version` — la table d'une seule
/// ligne posée par le serveur en #465 — n'avait **aucun descripteur de
/// synchronisation**, et ne se lisait que par l'écran d'administration, derrière
/// le RBAC. Le portail réglait donc un seuil que l'application ne verrait
/// jamais, et le bandeau était écrit, testé, et ne s'affichait pour personne.
///
/// `server-portal#475` a enregistré le descripteur ; ce provider lit désormais
/// la collection répliquée `device_settings`, et c'est tout ce qui manquait.
///
/// ## `null` reste la réponse par défaut, et c'est une décision
///
/// [updateBannerMinVersionProvider] rend `null` en chargement, et
/// `DeviceSettingsDao` rend `null` sur une table vide comme sur une colonne
/// nulle. Trois chemins, une seule réponse : **pas de seuil, pas de bandeau**.
///
/// Les trois se produisent pour de vrai :
///
/// - **avant le premier cycle** — le moment exact où quelqu'un ouvre
///   l'application pour la première fois ;
/// - **sur un serveur en retard d'une version** — la collection prend un `404`,
///   le moteur la saute, le cycle continue, et le magasin reste sans seuil ;
/// - **quand le portail n'a rien réglé** — la valeur livrée, et la seule
///   honnête tant que l'application n'a jamais été publiée.
///
/// Jamais l'inverse : un bandeau « mettez à jour » apparu par défaut sur la
/// toute première version serait le plus mauvais premier contact possible, et
/// il n'y aurait même pas de fiche de magasin où aller. C'est la décision
/// explicite de #80, et deux tests la verrouillent.
final appUpdateThresholdProvider = Provider<String?>(
  (ref) => ref.watch(updateBannerMinVersionProvider).value,
);

/// **Faut-il inviter à monter ?**
///
/// Trois raisons de répondre non, et elles penchent toutes du même côté — celui
/// qui n'affiche rien :
///
/// 1. aucun seuil réglé — rien n'est encore arrivé du portail, ou le portail
///    n'a rien réglé (voir [appUpdateThresholdProvider]) ;
/// 2. version locale inconnaissable — `appVersionProvider` rend `null` en
///    chargement, en échec, et sur un hôte sans canal de plugin. On n'invite pas
///    à quitter une version qu'on ne sait pas nommer ;
/// 3. seuil illisible — un `1.0.0-rc1` recopié de travers dans le portail ne
///    décide de rien ([compareAppVersions] rend `null`).
///
/// Le défaut penche de ce côté parce que l'erreur y est gratuite : un bandeau
/// manqué coûte une mise à jour tardive, un bandeau de trop coûte la confiance.
final appUpdateAvailableProvider = Provider<bool>((ref) {
  final threshold = ref.watch(appUpdateThresholdProvider);
  if (threshold == null) return false;

  final installed = ref.watch(appVersionProvider).value;
  if (installed == null) return false;

  final order = compareAppVersions(installed.version, threshold);
  return order != null && order < 0;
});

/// **Le bandeau a-t-il été fermé ?** — pour cette session, et pas au-delà.
///
/// Rien n'est écrit sur le disque, et c'est une décision, pas une facilité. Un
/// drapeau persistant ferait taire le bandeau **pour toujours**, y compris
/// quand le seuil remontera ; or l'invitation est répétable par nature — elle
/// porte sur une version qui change. Une session suffit à ce qu'on lui demande :
/// ne pas harceler quelqu'un qui vient de dire « plus tard ».
///
/// C'est la différence exacte avec la mention légale du premier lancement, qui
/// elle se retient **définitivement** (`LegalNoticeStore`) : celle-là annonce un
/// fait qui ne se répète pas.
class AppUpdateBannerDismissal extends Notifier<bool> {
  @override
  bool build() => false;

  /// « Plus tard ». Sans retour en arrière — rien ne rouvre le bandeau dans la
  /// même session, pas même un changement de seuil.
  void dismiss() => state = true;
}

final appUpdateBannerDismissedProvider =
    NotifierProvider<AppUpdateBannerDismissal, bool>(
  AppUpdateBannerDismissal.new,
);

/// Ce qui sait renvoyer au magasin. Inerte en production tant qu'il n'y a pas de
/// fiche à ouvrir — voir [UnavailableStoreLauncher].
final storeLauncherProvider = Provider<StoreLauncher>(
  (ref) => const UnavailableStoreLauncher(),
);

/// **Ce qui sait recharger l'application — `null` partout sauf sur le web.**
///
/// `null` n'est pas un repli, c'est la question : « y a-t-il autre chose qu'un
/// magasin au bout de ce bouton ? ». La réponse est oui dans un navigateur et
/// non ailleurs, et c'est le bandeau qui en tire son libellé *et* son action.
///
/// Le choix ne peut pas se faire sur `kIsWeb` dans le widget : c'est une
/// constante de compilation, donc un test ne pourrait jamais monter le cas du
/// web. `main.dart` surcharge ce provider sous `kIsWeb`, exactement comme
/// `installPromptProvider` et `contentPlayerProvider` — et pour la raison de
/// plus que `browser_app_reloader.dart` importe `dart:js_interop`.
final appReloaderProvider = Provider<AppReloader?>((ref) => null);
