/// **La règle de sélection du transport push** (décision **D4** du PRD
/// `notifications-push.md`) — pure, et testable sans plateforme.
///
/// C'est le cœur décisionnel du réveil push mobile, et il est écrit **une seule
/// fois** : donne un [PlatformPushCapabilities] (les trois faits de plateforme),
/// il rend le transport à viser — [kPushTransportFcm], [kPushTransportUnifiedPush]
/// ou `null` (**pas de push sur cet appareil**). Aucun canal de plugin, aucune
/// dépendance native : la règle se prouve sur la VM Dart en posant les faits avec
/// [FixedPushCapabilities].
///
/// **Un seul transport par appareil** (décision **D4**). La règle n'empile pas
/// de repli à l'exécution : elle **choisit**, une fois, à l'enregistrement.
library;

import 'platform_push_capabilities.dart';
import 'push_transport.dart';

/// **Décide quel transport viser**, selon la décision **D4**, dans cet ordre :
///
/// 1. **iOS → FCM.** Un ntfy self-host ne peut pas réveiller une app iOS en
///    arrière-plan (le réveil iOS passe par APNs) : iOS est **toujours** FCM
///    (décisions **D1/D4**). Ce fait court-circuite les deux autres — on
///    n'interroge ni GMS ni distributeur sur iOS.
/// 2. **Android **avec** Google Play Services → FCM.** C'est le défaut de la
///    décision **D1** : FCM partout où Google est présent.
/// 3. **Android **sans** GMS **mais** avec un distributeur UnifiedPush → UnifiedPush.**
///    Le but même du lot (décision **D2**) : couvrir l'Android dé-googlé en
///    déléguant la socket de réveil au distributeur ntfy.
/// 4. **Sinon → `null`.** Android dé-googlé **sans** distributeur : **pas de
///    push** (dégradé propre, décision **D4**). L'app reste pleinement
///    utilisable — SSE quand elle est ouverte, sync au retour au premier plan.
///    L'appelant qui reçoit `null` n'enregistre aucune cible.
///
/// Asynchrone parce que deux des trois faits le sont ([PlatformPushCapabilities.hasPlayServices],
/// [PlatformPushCapabilities.hasUnifiedPushDistributor] sont des appels au
/// système). L'ordre des `await` **suit** l'ordre de la règle : sur iOS et sur
/// Android+GMS, on rend FCM **sans jamais** interroger le distributeur — un
/// appel au système épargné, et une règle qui se lit dans l'ordre où elle
/// décide.
Future<String?> selectPushTransport(
  PlatformPushCapabilities capabilities,
) async {
  // 1. iOS est toujours FCM — court-circuite tout le reste (D1/D4).
  if (capabilities.isIos) return kPushTransportFcm;

  // 2. Android googlé → FCM, le défaut (D1). On n'interroge le distributeur
  //    qu'à défaut de GMS.
  if (await capabilities.hasPlayServices()) return kPushTransportFcm;

  // 3. Android dé-googlé + distributeur ntfy → UnifiedPush (D2).
  if (await capabilities.hasUnifiedPushDistributor()) {
    return kPushTransportUnifiedPush;
  }

  // 4. Ni GMS ni distributeur → pas de push, dégradé assumé (D4).
  return null;
}
