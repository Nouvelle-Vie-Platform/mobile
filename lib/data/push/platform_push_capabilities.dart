/// **La détection de plateforme, derrière une abstraction** — les trois faits
/// dont dépend le choix du transport (décision **D4** du PRD
/// `notifications-push.md`), et rien de plus.
///
/// Ce fichier isole *ce que la plateforme peut faire* de *ce qu'on décide d'en
/// faire* : la **règle** de sélection vit dans `transport_selector.dart`, pure et
/// testable ; ici ne vivent que les **capteurs**. Séparer les deux, c'est
/// pouvoir éprouver la règle sur la VM avec un double figé ([FixedPushCapabilities]),
/// sans jamais toucher un canal de plugin.
///
/// **La vraie implémentation n'est PAS ici — c'est un seam documenté.** Elle
/// s'appuierait sur `google_api_availability` (présence de Google Play Services)
/// et `unifiedpush` (présence d'un distributeur), deux **dépendances natives**
/// que `CLAUDE.md` interdit d'ajouter à ce stade : iOS est **SPM-only** et un
/// plugin sans `Package.swift` **ressusciterait CocoaPods** ; et Firebase n'est
/// pas configuré. Le câblage réel de ces plugins est un maillon **séparé** que le
/// main loop posera plus tard, Firebase debout. Voir le seam décrit plus bas.
library;

/// **Les trois faits de plateforme qui décident du transport** (décision **D4**).
///
/// Aucun de ces trois membres ne peint ni ne s'enregistre : ce sont des
/// **questions**, dont `transport_selector.dart` tire une **réponse**. Les tenir
/// derrière ce contrat, c'est ce qui rend la règle de sélection testable sans
/// plateforme.
abstract interface class PlatformPushCapabilities {
  /// `true` sur iOS.
  ///
  /// iOS reste **toujours** sur FCM (décisions **D1/D4**) : un ntfy self-host ne
  /// peut pas réveiller une app iOS en arrière-plan (le réveil iOS passe
  /// obligatoirement par APNs). C'est donc le premier fait qu'interroge le
  /// sélecteur, et il court-circuite les deux autres.
  bool get isIos;

  /// `true` quand **Google Play Services** est disponible sur cet Android.
  ///
  /// C'est ce fait qui départage l'Android googlé (→ FCM) de l'Android dé-googlé
  /// (F-Droid, GrapheneOS, Huawei → UnifiedPush), décision **D1/D2**. La vraie
  /// impl délègue à `google_api_availability`
  /// (`isGooglePlayServicesAvailable`). **Sans objet sur iOS** : le sélecteur ne
  /// l'interroge jamais quand [isIos] est vrai.
  ///
  /// Asynchrone : la disponibilité GMS est une requête au système, pas une
  /// constante de compilation.
  Future<bool> hasPlayServices();

  /// `true` quand une **app distributrice UnifiedPush** (ntfy) est installée et
  /// prête à tenir la socket de réveil (décision **D2**).
  ///
  /// C'est la condition sans laquelle l'Android dé-googlé n'a **aucun** transport
  /// (dégradé propre → `null`, décision **D4**) : notre app ne tient **jamais**
  /// elle-même une socket ntfy — Android la tuerait en fond. La vraie impl
  /// délègue à `unifiedpush` (présence d'un distributeur enregistré).
  ///
  /// Asynchrone : interroger les distributeurs disponibles est un appel au
  /// système.
  Future<bool> hasUnifiedPushDistributor();
}

/// Capacités **figées**, pour les tests et le double de maquette.
///
/// Aucun canal de plugin, aucune plateforme réelle : c'est ce qui permet de
/// vérifier chaque branche de la règle **D4** sur la VM Dart — iOS, Android+GMS,
/// Android dé-googlé avec distributeur, Android dé-googlé sans distributeur — en
/// posant simplement les trois faits.
///
/// C'est le pendant de `FixedNetworkTransport` / `FixedNetworkStatus`
/// (`network_transport.dart`) : le double figé vit **à côté** du contrat, dans le
/// même fichier, parce qu'il fait partie de la même décision de testabilité.
class FixedPushCapabilities implements PlatformPushCapabilities {
  const FixedPushCapabilities({
    this.isIos = false,
    bool playServices = false,
    bool unifiedPushDistributor = false,
  })  : _playServices = playServices,
        _unifiedPushDistributor = unifiedPushDistributor;

  @override
  final bool isIos;

  final bool _playServices;
  final bool _unifiedPushDistributor;

  @override
  Future<bool> hasPlayServices() async => _playServices;

  @override
  Future<bool> hasUnifiedPushDistributor() async => _unifiedPushDistributor;
}

// ---------------------------------------------------------------------------
// SEAM natif (NON construit ici) — à la charge du main loop, Firebase debout.
// ---------------------------------------------------------------------------
//
// L'implémentation réelle de [PlatformPushCapabilities] est **volontairement
// absente** de ce fichier, parce qu'elle exige des **dépendances natives** que
// `CLAUDE.md` interdit d'ajouter maintenant (iOS SPM-only → un plugin sans
// `Package.swift` ressuscite CocoaPods ; Firebase pas encore configuré). Elle
// sera le pendant de `ConnectivityNetworkTransport` : le **seul** endroit du
// dépôt à importer `google_api_availability` et `unifiedpush`.
//
// Forme attendue, pour l'agent qui la posera (aucun autre fichier ne change) :
//
//   import 'dart:io' show Platform;
//   import 'package:google_api_availability/google_api_availability.dart';
//   import 'package:unifiedpush/unifiedpush.dart';
//
//   class RuntimePushCapabilities implements PlatformPushCapabilities {
//     const RuntimePushCapabilities();
//
//     @override
//     bool get isIos => Platform.isIOS; // pas de branche web : le web est FCM,
//                                       // et `Platform` n'y existe pas — garder
//                                       // ce getter derrière `kIsWeb` en amont.
//
//     @override
//     Future<bool> hasPlayServices() async {
//       final status = await GoogleApiAvailability.instance
//           .checkGooglePlayServicesAvailability();
//       return status == GooglePlayServicesAvailability.success;
//     }
//
//     @override
//     Future<bool> hasUnifiedPushDistributor() async {
//       // `unifiedpush` : un distributeur enregistré/disponible existe-t-il ?
//       final distributors = await UnifiedPush.getDistributors();
//       return distributors.isNotEmpty;
//     }
//   }
//
// Règle du dégradé (comme `NetworkTransport` : le doute penche vers le cas sûr) :
// toute panne de canal de plugin dans les deux `Future` doit se rendre en
// `false`. Un faux `false` sur GMS/distributeur route vers « pas de push »
// (dégradé assumé, D4) ; un faux `true` prétendrait joignable un appareil qui ne
// l'est pas — le pire des deux. Voir la même précaution dans
// `ConnectivityNetworkTransport.isOnCellular`.
