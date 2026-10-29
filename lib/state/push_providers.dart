/// **Le réveil push, côté providers** (#97) — et un défaut qui est l'inerte.
///
/// Même patron que le lecteur de la médiathèque : le provider rend le **double
/// inerte**, et `main.dart` — seul endroit du dépôt qui sache que Firebase existe —
/// le surcharge quand un transport a réellement démarré. Conséquences, et ce sont
/// elles qui font tout l'intérêt du patron :
///
/// - **aucun test ne touche Firebase.** Rien ici ne l'importe, donc aucun canal de
///   greffon ne lève ;
/// - **l'application démarre et fonctionne sans aucun transport** : le web, macOS,
///   un Android dé-googlé avant la tranche 4, un appareil hors ligne au premier
///   lancement. C'est le comportement, pas un repli d'urgence ;
/// - **la tranche 4 n'a rien à réécrire ici** : elle ajoute une branche au choix de
///   `main.dart`, et le provider continue de ne connaître que [PushTransport].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/push/notification_texts.dart';
import '../data/push/push_enrolment.dart';
import '../data/push/push_registrar.dart';
import '../data/push/push_transport.dart';
import '../data/push/push_wake_handler.dart';
import '../data/push/wake_notifier.dart';
import '../data/sync/sync_scheduler.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';
import 'theme_provider.dart' show settingsDaoProvider;

/// **Le transport**, inerte par défaut. Surchargé par `main.dart`.
final pushTransportProvider = Provider<PushTransport>(
  (ref) => const InertPushTransport(),
);

/// **La permission d'affichage, à demander maintenant** — `null` partout sauf
/// sur le web, où `main.dart` la surcharge (#283).
///
/// `null` et non une fonction inerte, comme `appReloaderProvider` : sur mobile
/// il n'y a rien à demander à ce moment-là (la permission système est demandée
/// au démarrage, une fois pour trois besoins), et un appelant doit pouvoir
/// **ne rien offrir** plutôt qu'appeler quelque chose qui ne fait rien.
///
/// Son unique appelant est `InstallBanner` : sur le web, un refus de
/// notification est quasi définitif, et le seul moment où il vaut la peine de
/// le risquer est celui de l'installation.
final pushPermissionProvider = Provider<PushPermissionRequest?>((ref) => null);

/// `POST /devices/tokens`, sur le `Dio` d'`ApiClient`. Inerte sans backend : il n'y
/// a personne à qui déclarer une cible de réveil, et une requête partirait pour
/// prendre un refus.
final pushRegistrarProvider = Provider<PushRegistrar>(
  (ref) => AppEnv.useBackend ? HttpPushRegistrar() : const InertPushRegistrar(),
);

/// **Le notifieur du premier plan, et il est inerte — ce n'est pas un oubli.**
///
/// Application ouverte, les écrans se repeignent du magasin que le cycle vient de
/// remplir : la liste des conversations se réordonne et le fil s'allonge sous les
/// yeux du fidèle. Une bannière par-dessus l'écran qu'il regarde serait du bruit, et
/// l'immédiateté d'un fil **ouvert** est le sujet du temps réel SSE (#101).
///
/// La notification locale, elle, est dressée par le réveil de l'**application
/// fermée**, dans son isolate (`push_background.dart`), avec un
/// [LocalWakeNotifier] réel. C'est le même [PushWakeHandler] des deux côtés : ce qui
/// change est injecté, jamais décidé par un drapeau.
final wakeNotifierProvider = Provider<WakeNotifier>(
  (ref) => const InertWakeNotifier(),
);

/// **Le tap sur une notification de réveil** — inerte par défaut, surchargé par
/// `main.dart`.
///
/// Un provider distinct de [wakeNotifierProvider] parce que les deux rôles ne
/// vivent pas dans le même isolate : c'est le réveil de l'application fermée qui
/// **affiche**, et l'isolate principal qui **reçoit le tap**, lui seul ayant un
/// routeur. Voir `wake_notifier.dart`.
final wakeTapsProvider = Provider<WakeTaps>((ref) => const InertWakeTaps());

/// **Le handler du premier plan.**
///
/// Sa synchronisation passe par le **planificateur** et non par un moteur neuf :
/// deux cycles concurrents se disputeraient les mêmes curseurs et les mêmes jetons
/// de resync. Le réveil rejoint donc le cycle en vol s'il y en a un — voir
/// `SyncTrigger.pushWake`, qui dit aussi pourquoi c'est un cycle **complet** ici et
/// un cycle ciblé en fond.
final pushWakeHandlerProvider = Provider<PushWakeHandler>((ref) {
  return PushWakeHandler(
    synchronize: (_) async {
      if (!AppEnv.useBackend) return;
      await ref.read(syncSchedulerProvider).trigger(SyncTrigger.pushWake);
    },
    store: StoreWakeStore(
      groups: ref.watch(groupDaoProvider),
      showPreview: () => ref.read(settingsDaoProvider).notificationPreview(),
      userId: () => ref.read(authProvider).user?.id,
    ),
    notifier: ref.watch(wakeNotifierProvider),
    // Inutiles tant que le notifieur du premier plan est inerte ; résolus
    // quand même dans la langue du système, comme au fond — un notifieur réel
    // posé ici un jour n'aurait rien à rebrancher.
    texts: notificationTextsForSystem(),
  );
});

/// **Le notifieur qui efface, au premier plan** (M5) — `null` par défaut,
/// surchargé par `main.dart` avec un [LocalWakeNotifier] quand un transport de
/// réveil a démarré.
///
/// Distinct de [wakeNotifierProvider], qui reste inerte au premier plan : on
/// n'y **affiche** rien (les écrans se repeignent du magasin), mais on y
/// **efface** la notification d'une conversation qu'on vient de lire — ici ou
/// sur un autre appareil (`read.advanced`). Voir `NotificationReconciler`.
///
/// `null` et non un double inerte : sans transport il n'y a aucune
/// notification à effacer, et le réconciliateur ne s'abonne alors même pas au
/// magasin (`notificationReconcilerProvider`).
final wakeDismisserProvider = Provider<WakeNotifier?>((ref) => null);

/// **L'enregistrement de la cible de réveil** — démarré par `app.dart` une fois
/// qu'il y a un porteur, puis entretenu par l'abonnement aux rotations.
///
/// Le provider n'est **pas** `autoDispose`, et ça compte pour deux raisons : il
/// retient la cible que la déconnexion doit désabonner, et son abonnement aux
/// rotations doit vivre aussi longtemps que l'application.
final pushEnrolmentProvider = Provider<PushEnrolment>((ref) {
  final enrolment = PushEnrolment(
    transport: ref.watch(pushTransportProvider),
    registrar: ref.watch(pushRegistrarProvider),
    platform: devicePlatform(),
  );
  ref.onDispose(enrolment.dispose);
  return enrolment;
});

/// **« Afficher le contenu » des notifications de messages** (M5) — un réglage
/// de ce téléphone, rangé dans le magasin pour que le réveil de fond le lise.
/// Défaut : oui.
final notificationPreviewProvider = StreamProvider<bool>(
  (ref) => ref.watch(settingsDaoProvider).watchNotificationPreview(),
);
