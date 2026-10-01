/// **La connexion à la demande** — `requireSession()`, et l'intention qu'elle
/// met de côté le temps que la personne se connecte.
///
/// C'est la contrepartie de la garde inversée du routeur : puisque l'application
/// n'exige plus de compte à l'entrée, elle doit savoir l'exiger au moment du
/// **geste**, et reprendre ce geste là où il s'était arrêté.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import 'auth_providers.dart';

/// Un geste mis en attente d'une session, et l'endroit d'où il a été demandé.
///
/// **Elle ne se persiste pas, et ce n'est pas une limite d'implémentation.**
/// Deux raisons, et la seconde suffirait :
///
/// 1. un [VoidCallback] n'a pas de forme sérialisable — ce serait un nom de
///    geste à faire correspondre à du code, c'est-à-dire un second routeur ;
/// 2. **un geste rejoué après un redémarrage agirait dans le dos de la
///    personne.** L'intention vaut pour l'instant où elle a été formée : publier
///    une annonce, écrire une demande. La retrouver trois jours plus tard, à
///    l'ouverture, sur un écran qu'on n'a pas devant soi, serait une action non
///    demandée. Une application tuée entre-temps **perd** donc l'intention, et
///    c'est le bon comportement : la personne retrouve l'accueil (ou sa session),
///    et refait son geste — qui aboutit tout seul, puisqu'elle est connectée.
@immutable
class SessionIntent {
  const SessionIntent({required this.origin, this.action});

  /// L'emplacement où la personne était quand elle a demandé le geste. C'est là
  /// qu'on la ramène, et non sur l'accueil : le parcours d'authentification est
  /// **poussé** par-dessus l'écran d'origine.
  final String origin;

  /// Le geste lui-même. Nul est permis — « ramène-moi simplement où j'étais ».
  final VoidCallback? action;
}

/// Le porte-intention : au plus **une** à la fois, en mémoire seule.
///
/// Une seule, parce qu'il n'y a qu'une personne devant l'écran et qu'un second
/// geste demandé par-dessus le premier remplace ce qu'elle voulait. Une file
/// d'intentions rejouerait, après une connexion, des gestes dont elle a changé
/// d'avis.
class SessionGate extends Notifier<SessionIntent?> {
  @override
  SessionIntent? build() {
    // **C'est ici que le geste se rejoue**, et nulle part ailleurs : l'écran du
    // code ne sait rien de tout ceci, il se contente de vérifier un code. La
    // réaction est donc adossée à l'ouverture de session elle-même, quelle que
    // soit la façon dont elle s'est ouverte.
    //
    // ⚠️ Ce `listen` n'existe que tant que **quelqu'un écoute ce provider** :
    // Riverpod 3 met en pause les abonnements d'un provider inactif. C'est
    // `app.dart` qui le tient vivant (`listenManual`), au même titre que le
    // routeur, et sans lui le geste ne se rejouerait jamais.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final pending = state;
      if (pending == null) return;
      if (next.isAuthenticated) {
        // Reprise **avant** d'agir : une intention ne vaut qu'une fois, et un
        // second passage ici (revalidation de fond, mise à jour du profil) ne
        // doit pas rejouer le geste une seconde fois.
        state = null;
        _grant(pending);
        return;
      }
      // Session perdue en cours de route (déconnexion, 401) : l'intention part
      // avec elle. La rejouer à la prochaine connexion serait un geste sans
      // rapport avec ce que la personne fait à ce moment-là.
      if (previous?.isAuthenticated ?? false) state = null;
    });
    return null;
  }

  /// **Exige une session pour [action].**
  ///
  /// Rend `true` quand la session est déjà là : [action] a **déjà** été exécutée,
  /// dans la foulée du geste, sans rien afficher. Rend `false` quand il a fallu
  /// ouvrir la connexion — [action] sera alors rejouée par le succès, et par
  /// personne d'autre. L'appelant n'a donc jamais à traiter les deux cas.
  ///
  /// Le parcours d'authentification est **poussé** plein écran (`push`, pas
  /// `go`) : c'est ce qui laisse l'écran d'origine sous la pile, donc ce qui
  /// permet à un abandon d'être un simple retour en arrière.
  ///
  /// ⚠️ **Et ce qui est poussé est le formulaire**, jamais une page de garde
  /// devant lui. On poussait `AppRoute.authWelcome` — « Bienvenue · Dans la
  /// Maison du Miracle · Commencer » —, un écran qui n'avait plus de rôle depuis
  /// que l'application s'ouvre sur l'accueil, et qui n'offrait aucun retour :
  /// ni `appBar`, ni `BackButton`, ni `PopScope`. Sur Android le bouton système
  /// dépilait ; **sur iPhone il n'y en a pas**, et la personne était enfermée.
  /// La flèche de retour vient désormais de l'`AppBar` du formulaire, que
  /// `push` rend non vide — c'est la même mécanique que l'abandon ci-dessous,
  /// et elle n'exige aucun bouton système.
  ///
  /// ⚠️ **Les onglets ne passent plus par ici**, et c'est délibéré : « Échanges »
  /// et « Profil » affichent le formulaire *dans* l'onglet
  /// (`HomeShell._screenFor`), sans rien pousser. Ce qui reste ici est ce qui a
  /// vraiment un geste à rejouer — publier une annonce, écrire une note, ouvrir
  /// une conversation depuis une notification.
  bool require({required VoidCallback action}) {
    if (ref.read(authProvider).isAuthenticated) {
      action();
      return true;
    }
    final router = ref.read(routerProvider);
    final intent = SessionIntent(
      origin: router.state.matchedLocation,
      action: action,
    );
    state = intent;
    // **L'abandon se lit sur la pile, pas sur un bouton.** Le `Future` d'un
    // `push` se règle quand la route poussée est dépilée : retour Android, flèche
    // de l'en-tête, geste de balayage — les trois façons de renoncer passent par
    // là, et aucun écran d'authentification n'a à connaître cette mécanique.
    final flow = router.pushNamed<void>(AppRoute.authIdentifier);
    flow.whenComplete(() => _abandon(intent));
    return false;
  }

  /// Oublie une intention **restée sans session**.
  ///
  /// Les deux gardes ne sont pas redondantes : la première écarte une intention
  /// déjà reprise (ou remplacée par une autre depuis), la seconde écarte le cas
  /// où la pile s'est vidée **parce que** la connexion a abouti — l'écran du code
  /// navigue vers l'accueil, ce qui dépile aussi le parcours.
  void _abandon(SessionIntent intent) {
    if (!identical(state, intent)) return;
    if (ref.read(authProvider).isAuthenticated) return;
    state = null;
  }

  /// La session est ouverte : ramener à l'origine, puis agir.
  ///
  /// **Après le frame, et c'est tout le sujet.** L'écran du code navigue vers
  /// l'accueil dès que `verifyCode` lui rend la main — c'est-à-dire dans le même
  /// tour de boucle que ce changement d'état. Naviguer ici tout de suite ferait
  /// perdre la course ; on repose donc la destination une image plus tard, en
  /// dernier. Le geste attend encore une image de plus, pour que l'écran
  /// d'origine soit monté avant qu'on agisse dessus — un geste qui pousse une
  /// route ne doit pas la voir remplacée juste après.
  void _grant(SessionIntent intent) {
    final router = ref.read(routerProvider);
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      router.go(intent.origin);
      binding.addPostFrameCallback((_) => intent.action?.call());
    });
  }
}

/// L'intention en attente. Lu par `app.dart`, qui le tient **vivant** ; personne
/// d'autre n'a à l'observer.
final sessionGateProvider = NotifierProvider<SessionGate, SessionIntent?>(
  SessionGate.new,
);

/// **Le helper que les actions appellent** avant un geste qui exige un compte.
///
/// ```dart
/// onTap: () => ref.requireSession(
///   action: () => context.pushNamed(AppRoute.notes),
/// ),
/// ```
///
/// Il n'y a rien d'autre à écrire : membre → le geste part tout de suite ;
/// invité → la connexion s'ouvre plein écran et le geste part tout seul après le
/// succès. La valeur de retour n'existe que pour l'appelant qui veut *aussi*
/// fermer une feuille ou couper un retour visuel.
extension SessionGateRef on WidgetRef {
  bool requireSession({required VoidCallback action}) =>
      read(sessionGateProvider.notifier).require(action: action);
}
