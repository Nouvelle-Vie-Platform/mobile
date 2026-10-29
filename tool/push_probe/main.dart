/// **La sonde du push web** (#283) — le seul moyen de prouver que le SDK JS de
/// Firebase se charge **depuis notre origine**.
///
/// `flutter test` tourne sur la VM : il ne compile même pas
/// `web_push_transport.dart`. Et `flutter build web` ne prouve rien non plus —
/// ça compile, ça ne charge rien. Ce qui se mesure ici, et nulle part ailleurs :
///
/// 1. `importModule` descend `web/firebase/firebase-app.js` et
///    `firebase-messaging.js` **depuis le serveur de la sonde** (son journal de
///    requêtes le dit) ;
/// 2. `Firebase.initializeApp()` **n'injecte rien** : la porte de sortie de
///    `firebase_core_web` (le test sur `window.firebase_core`) tient ;
/// 3. tout cela **sous la CSP de production** (`script-src 'self'
///    'wasm-unsafe-eval'`) et **avec le réseau extérieur coupé** — Chrome est
///    lancé avec une règle de résolution qui ne connaît que `127.0.0.1`, donc
///    `gstatic.com` est injoignable. Que l'initialisation réussisse quand même
///    **est** la preuve.
///
/// Ce n'est **pas** un test : il exige Chrome, ne tourne pas en CI, et il
/// s'arrête là où un navigateur ne peut plus rien dire sans la clé VAPID — voir
/// la fin du rapport qu'il imprime.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core/firebase_core.dart';
import 'package:maison_du_miracle/data/push/web_push_transport.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  final observed = <String>[];

  try {
    final push = await createWebPush();
    observed.add(
      'createWebPush()          : ${push == null ? 'null — RIEN N\'A DÉMARRÉ' : 'transport « ${push.transport.transport} »'}',
    );

    // Lu **sur le module que nous avons posé** : s'il venait de `gstatic.com`,
    // la CSP et la règle de résolution l'auraient empêché d'arriver.
    final core = globalContext.getProperty<JSObject?>('firebase_core'.toJS);
    final sdkVersion = core?.getProperty<JSString?>('SDK_VERSION'.toJS)?.toDart;
    observed
        .add('window.firebase_core     : ${core == null ? 'ABSENT' : 'posé'}');
    observed.add('SDK_VERSION lu           : ${sdkVersion ?? 'illisible'}');
    observed.add(
      'window.firebase_messaging: '
      '${globalContext.getProperty<JSObject?>('firebase_messaging'.toJS) == null ? 'ABSENT' : 'posé'}',
    );
    observed.add(
      'applications Firebase    : ${Firebase.apps.map((app) => app.name).join(', ')}',
    );
    observed.add(
      'projet                   : ${Firebase.apps.isEmpty ? '—' : Firebase.app().options.projectId}',
    );

    observed.add(
      'clé VAPID                : ${kWebPushVapidKey.isEmpty ? 'ABSENTE — aucun jeton ne sera demandé' : '${kWebPushVapidKey.length} caractères'}',
    );
    observed.add(
      'Notification.permission  : ${web.Notification.permission}',
    );

    // Sans clé VAPID **et** sans permission, `target()` doit rendre `null` sans
    // lever et sans rien demander : c'est le comportement attendu aujourd'hui.
    // Bornée **ici aussi** : sans cela, la sonde elle-même ne rend jamais son
    // verdict quand Google est injoignable — ce qui est son régime normal.
    final target = await push?.transport
        .target()
        .timeout(const Duration(seconds: 20), onTimeout: () => null);
    observed.add('target()                 : ${target ?? 'null'}');

    final registrations =
        await web.window.navigator.serviceWorker.getRegistrations().toDart;
    final scopes = registrations.toDart
        .map((registration) => registration.scope)
        .join('\n                           ');
    observed
        .add('workers enregistrés      : ${scopes.isEmpty ? 'aucun' : scopes}');
  } on Object catch (error, stackTrace) {
    observed.add('✗ LEVÉE : $error\n$stackTrace');
  }

  await _report(observed.join('\n'));
}

/// Renvoie le relevé au serveur de la sonde, qui l'imprime au terminal.
Future<void> _report(String body) async {
  try {
    await web.window
        .fetch(
          '/sonde'.toJS,
          web.RequestInit(method: 'POST', body: body.toJS),
        )
        .toDart;
  } on Object catch (error) {
    web.console.error('la sonde n\'a pas pu rendre son relevé : $error'.toJS);
  }
}
