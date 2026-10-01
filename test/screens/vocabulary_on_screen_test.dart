/// **Le mot réglé au portail, sur un écran réel** (#81).
///
/// La page Téléchargements est prise comme témoin parce qu'elle porte deux des
/// clés que le catalogue du portail déclare surchargeables, et qu'elle se monte
/// sans réseau ni canal natif. Ce qui est vérifié ici n'est pas cet écran-là :
/// c'est que `context.words` soit réellement branché entre le magasin et le
/// pixel, et qu'il penche du bon côté quand la surcharge est vide.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/vocabulary.dart';
import 'package:maison_du_miracle/screens/downloads_screen.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';

import '../helpers/pump_screen.dart';

const _id = '019f7000-0000-7000-8000-000000000001';

DownloadRow _completedRow() => DownloadRow(
      contentType: 'teaching',
      contentId: _id,
      quality: 'mid',
      state: DownloadState.complete,
      bytesReceived: 1024 * 1024,
      bytesTotal: 1024 * 1024,
      taskId: 'task-1',
      createdAt: DateTime.utc(2026, 9, 20),
    );

/// Monte la page avec des flux nus — un flux Drift attendu sous l'horloge
/// factice du harnais fige le montage.
Future<void> pumpDownloads(
  WidgetTester tester, {
  List<DownloadRow> rows = const [],
  VocabularyOverrides? vocabulary,
}) {
  final overrides = <Override>[
    downloadsListProvider.overrideWith((ref) => Stream.value(rows)),
    downloadsStorageUsageProvider.overrideWith((ref) => Stream.value(0)),
    teachingByIdProvider
        .overrideWith((ref, id) => Stream.value(null as TeachingView?)),
  ];
  return pumpScreen(
    tester,
    const DownloadsScreen(),
    vocabulary: vocabulary,
    overrides: overrides,
  );
}

void main() {
  testWidgets('sans aucun cycle, l\'écran montre ce qu\'il a compilé',
      (tester) async {
    await pumpDownloads(tester);

    // Le `.arb` n'est pas un repli honteux : c'est l'état de départ légitime,
    // et celui de la toute première ouverture.
    expect(
      find.textContaining('Les messages que vous téléchargez'),
      findsOneWidget,
    );
  });

  testWidgets('le mot réglé au portail recouvre celui du dépôt',
      (tester) async {
    await pumpDownloads(
      tester,
      vocabulary: const VocabularyOverrides(labels: {
        'downloadsEmptyMessage': {
          'fr': 'Vos prêches hors ligne apparaîtront ici.',
        },
      }),
    );

    expect(
      find.text('Vos prêches hors ligne apparaîtront ici.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Les messages que vous téléchargez'),
      findsNothing,
    );
  });

  testWidgets('une surcharge vide ne vide pas l\'écran', (tester) async {
    // Le cas qui ne ferait rougir aucun test s'il n'était pas écrit : la ligne
    // existe côté serveur avec ses cartes à `null`, parce qu'effacer une
    // surcharge n'efface pas la ligne. Un titre blanc ne ressemble pas à un
    // bug — il ressemble à une donnée perdue.
    await pumpDownloads(
      tester,
      rows: [_completedRow()],
      vocabulary: const VocabularyOverrides(labels: {
        'downloadsUnknownTitle': <String, String>{},
      }),
    );

    expect(find.text('Message téléchargé'), findsOneWidget);
  });
}
