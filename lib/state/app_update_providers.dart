import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_version.dart';
import '../data/store_launcher.dart';
import 'app_version_providers.dart';

/// **Le seuil de version sous lequel l'application invite à monter** — la plus
/// basse version encore recommandée, telle que `1.4.0`. `null` veut dire
/// « aucun seuil réglé », donc **aucun bandeau**.
///
/// ## Le repli reste ouvert, et la tranche 3 ne pouvait pas le refermer
///
/// Le seuil se règle depuis le portail (écran *Appareils*) et devait descendre
/// par la **synchronisation**, avec les réglages de la tranche 3 (#81). Il
/// n'est pas descendu, et ce n'est pas un oubli : **le serveur ne le sert à
/// aucune collection**.
///
/// Ce qui a été vérifié dans `server-portal` au moment d'écrire ceci :
///
/// - le seuil vit dans `device_settings.update_banner_min_version`, une table
///   d'une seule ligne posée par #465 — et cette table **n'a pas de descripteur
///   de synchronisation** : `app/sync/descriptors/registry.ts` en compte
///   vingt-six, aucune ne la touche. Elle ne se lit que par l'écran
///   d'administration, derrière le RBAC ;
/// - `presentation_vocabulary`, la collection de la tranche 3, ne pouvait pas le
///   porter : `SaveVocabulary` **ignore en silence** toute clé que
///   `vocabulary_catalog.ts` ne nomme pas, et le catalogue ne porte que des
///   termes et des clés de dictionnaire. Une ligne `update_banner_min_version`
///   n'y naîtrait jamais.
///
/// Y faire descendre le seuil demande donc une décision **côté serveur** —
/// enregistrer un descripteur pour `device_settings`, ou nommer une clé de
/// catalogue qui n'est pas un mot —, et ni l'une ni l'autre n'est au périmètre
/// d'une tranche mobile. Le repli reste donc **explicite et assumé** : pas de
/// seuil, pas de bandeau. Tout le reste du chemin — la comparaison de versions,
/// la fermeture, le renvoi au magasin, la place dans la coquille — est écrit et
/// testé ; il ne manque que la source, et la seule ligne à changer est celle-ci.
///
/// ## Et c'est aussi le bon comportement aujourd'hui
///
/// L'application n'a **jamais été publiée**. Un bandeau « mettez à jour » sur la
/// toute première version, sans fiche de magasin à ouvrir, serait le plus
/// mauvais premier contact possible. Même le jour où la source existera, un
/// serveur qui ne sert pas le réglage (version antérieure, 404 de collection)
/// doit se lire comme « aucun seuil », jamais comme « seuil à zéro ».
final appUpdateThresholdProvider = Provider<String?>((ref) => null);

/// **Faut-il inviter à monter ?**
///
/// Trois raisons de répondre non, et elles penchent toutes du même côté — celui
/// qui n'affiche rien :
///
/// 1. aucun seuil réglé (le cas d'aujourd'hui, voir
///    [appUpdateThresholdProvider]) ;
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
