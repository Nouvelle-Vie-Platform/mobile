import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/install/install_prompt.dart';
import 'push_providers.dart';

/// **Ce qui sait proposer l'installation.** Inerte par défaut — donc sur mobile
/// natif, où l'application est déjà installée, et dans tous les tests.
///
/// `main.dart` le surcharge sous `kIsWeb`, exactement comme
/// `contentPlayerProvider` : aucun test ne touche à `dart:js_interop`, et
/// l'application démarre entièrement sans cette pièce.
final installPromptProvider = Provider<InstallPrompt>(
  (ref) => const InertInstallPrompt(),
);

/// L'offre courante, puis ses changements.
///
/// La valeur de départ est émise tout de suite : `beforeinstallprompt` peut
/// avoir été capté par `web/index.html` **avant** que Flutter ne démarre, et
/// s'en remettre au seul flux ferait attendre un événement déjà passé.
final installOfferProvider = StreamProvider<InstallOffer>((ref) async* {
  final prompt = ref.watch(installPromptProvider);
  yield prompt.offer;
  yield* prompt.changes;
});

/// **Installer, puis demander la permission d'afficher les annonces** (#283).
///
/// Écrit **ici** et pas dans un widget, parce qu'il y a **deux** endroits qui
/// ouvrent la boîte d'installation — le bandeau et l'invitation du bouton
/// Télécharger (#273) — et que la permission doit suivre l'un comme l'autre.
/// Le jour où un troisième geste installe, il passe par cette fonction et
/// n'a rien à savoir du push.
///
/// Deux gardes, et elles sont le sujet de la tranche :
///
/// 1. **rien n'est demandé si l'installation n'a pas été acceptée.** Sur le web
///    un refus de notification est quasi définitif et il emporte tout (sans
///    permission, pas de jeton, donc pas même la synchronisation réveillée) :
///    on ne brûle pas cette unique chance sur quelqu'un qui vient de refuser
///    l'installation ;
/// 2. **rien n'est demandé là où il n'y a pas de push à demander** —
///    `pushPermissionProvider` est `null` partout sauf sur le web, et sur
///    mobile la permission système est déjà demandée au démarrage.
///
/// Ne lève jamais : les deux appelants sont des invitations, pas des
/// fonctionnalités.
Future<void> installThenAskForNotifications(WidgetRef ref) async {
  final accepted = await ref.read(installPromptProvider).show();
  if (!accepted) return;
  final askPermission = ref.read(pushPermissionProvider);
  if (askPermission == null) return;
  await askPermission();
}

/// **Le bandeau a-t-il été fermé ?** — pour cette session, et pas au-delà.
///
/// Même choix que [AppUpdateBannerDismissal], et pour la même raison :
/// l'invitation reste valable tant que l'application n'est pas installée, et
/// un drapeau sur le disque la tairait pour toujours. Une session suffit à ne
/// pas harceler quelqu'un qui vient de dire « plus tard ».
class InstallBannerDismissal extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final installBannerDismissedProvider =
    NotifierProvider<InstallBannerDismissal, bool>(
  InstallBannerDismissal.new,
);
