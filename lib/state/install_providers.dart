import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/install/install_prompt.dart';

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
