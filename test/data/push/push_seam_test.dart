import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Les garde-fous de source du réveil push** (#97), sur le modèle de « un seul
/// fichier de `lib/` importe just_audio » et de « jamais de polling ».
///
/// Un `import 'package:firebase_messaging/…'` glissé dans un écran ne casserait
/// aucun test de comportement : il rendrait la suite rouge le jour où quelqu'un
/// toucherait un canal Firebase sous `flutter test`, et il rendrait impossible la
/// tranche 4 (#99) — qui est tout l'intérêt de cette couture. UnifiedPush s'ajoute à
/// côté de `FcmPushTransport` ; il ne s'ajoute pas à côté de vingt sites d'appel.
void main() {
  /// Le code de `lib/`, commentaires de documentation retirés : ils **parlent** de
  /// Firebase, ils ne l'importent pas.
  Map<String, String> sources() {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    return {
      for (final file in files)
        file.path: file
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('///'))
            .join('\n'),
    };
  }

  List<String> importers(String package) {
    final guilty = <String>[];
    sources().forEach((path, code) {
      if (code.contains('package:$package/')) guilty.add(path);
    });
    guilty.sort();
    return guilty;
  }

  test('Firebase ne vit qu\'au bout de la couture', () {
    // `main.dart` est le second, et c'est le même partage que pour le lecteur :
    // c'est lui qui **choisit** le transport (`Firebase.initializeApp`,
    // `onBackgroundMessage`), parce que le choix est une décision de démarrage et non
    // une propriété du transport. Aucun test ne l'importe.
    expect(
      importers('firebase_messaging'),
      ['lib/data/push/fcm_push_transport.dart', 'lib/main.dart'],
      reason:
          'seuls le transport réel et le choix de démarrage connaissent FCM',
    );
    expect(
      importers('firebase_core'),
      [
        'lib/data/push/fcm_push_transport.dart',
        'lib/firebase_options.dart',
        'lib/main.dart',
      ],
      reason: 'les options ne sont lues que par là où Firebase démarre',
    );
  });

  test('le greffon de notification locale ne vit qu\'au bout de la sienne', () {
    expect(
      importers('flutter_local_notifications'),
      [
        'lib/data/push/wake_notifier.dart',
        // Les rappels locaux du module Bible (#202), derrière leur propre
        // couture `BibleReminderScheduler`.
        'lib/features/bible/personalize/bible_reminders.dart',
      ],
      reason: 'tout le reste du dépôt ne connaît que WakeNotifier, WakeTaps '
          'et BibleReminderScheduler',
    );
  });

  test('le handler de réveil ignore Firebase, Drift et le greffon', () {
    // C'est ce qui le rend **entièrement testable** là où le chemin du fond, lui, ne
    // l'est pas : il prend une fonction de synchronisation, une lecture et un
    // notifieur, et rien d'autre.
    final code = sources()['lib/data/push/push_wake_handler.dart'];
    expect(code, isNotNull);
    expect(code, isNot(contains('package:firebase')));
    expect(code, isNot(contains('package:drift/')));
    expect(code, isNot(contains('package:flutter_local_notifications/')));
  });
}
