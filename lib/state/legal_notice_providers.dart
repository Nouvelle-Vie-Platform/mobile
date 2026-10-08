import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/legal_notice_store.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

/// Politique de réessai : **aucun réessai automatique**.
///
/// Riverpod 3 réessaie tout seul un provider en échec, dix fois, avec une
/// attente qui double. Une lecture locale qui échoue ne réussira pas mieux à la
/// seconde tentative, et insister laisserait des minuteries derrière soi — y
/// compris sous `flutter test`. Même règle que `themePreferencesProvider` et
/// `appVersionProvider`.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// La mémoire de la mention légale en service. Le magasin local en production,
/// un double en mémoire dans les tests d'écran.
final legalNoticeStoreProvider = Provider<LegalNoticeStore>(
  (ref) => SettingsLegalNoticeStore(ref.watch(appDatabaseProvider)),
);

/// **Le bandeau a-t-il déjà été fermé ?**
///
/// Un `FutureProvider` et non un `StreamProvider`, et ce n'est pas un raccourci :
/// ce drapeau ne change qu'une fois dans la vie de l'installation, et par un
/// geste de la personne qui regarde l'écran. Un flux Drift coûterait une
/// souscription permanente pour une valeur qui ne bouge plus — et, sous
/// l'horloge factice du harnais de test, un flux Drift attendu fige le montage
/// (voir l'en-tête de `pump_screen.dart`).
///
/// **Le chargement et l'échec valent « déjà vu »**, donc « pas de bandeau ». Le
/// défaut penche de ce côté-là exprès : afficher pendant qu'on ne sait pas
/// encore ferait clignoter la mention sur tous les lancements suivants, et un
/// clignotement se lit comme un bug, pas comme une information.
final legalNoticeSeenProvider = FutureProvider<bool>(
  (ref) => ref.watch(legalNoticeStoreProvider).seen(),
  retry: _noAutomaticRetry,
);

/// **La fermeture de la session en cours**, immédiate à l'écran : l'écriture
/// dans le magasin suit (`LegalNoticeStore.markSeen`), sans la faire attendre.
class LegalNoticeDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final legalNoticeDismissedProvider =
    NotifierProvider<LegalNoticeDismissed, bool>(LegalNoticeDismissed.new);

/// **Le consentement du premier lancement est-il en attente ?** Un invité,
/// jamais vu, pas fermé dans cette session. Tant qu'il l'est, l'application est
/// **bloquée** derrière le popup (la coquille pose une barrière sur tout) : seuls
/// « J'ai compris » et les deux liens de lecture répondent.
///
/// Chargement et échec du magasin valent « déjà vu » (`?? true`), comme avant :
/// on ne bloque jamais l'application sur une incertitude.
final legalNoticePendingProvider = Provider<bool>((ref) {
  if (!ref.watch(authProvider.select((s) => s.isGuest))) return false;
  if (ref.watch(legalNoticeDismissedProvider)) return false;
  return !(ref.watch(legalNoticeSeenProvider).value ?? true);
});
