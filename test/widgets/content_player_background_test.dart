/// **La cascade du fond des lecteurs.**
///
/// Le fond de la saison gagne ; l'image du dépôt ferme la cascade, comme sur le
/// site public. Ce que ces tests surveillent n'est pas l'esthétique — c'est
/// qu'un lecteur ne se retrouve **jamais** sans décor parce qu'une case est
/// vide au portail, et qu'un décor absent n'empêche **jamais** l'écran de se
/// peindre.
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/season_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';

import '../helpers/playback_doubles.dart';

const _view = TeachingView(
  id: '019f7000-0000-7000-8000-000000000001',
  title: 'La foi qui déplace',
  color: 0xFF223B8C,
  playlistUrl: 'https://exemple.test/enseignement/master.m3u8',
);

/// Un fond de saison reconnaissable : un pixel, mais **identifiable**.
final _saison = MemoryImage(Uint8List.fromList(const [1, 2, 3, 4]));

class _ContentNotifier extends Notifier<AsyncValue<ContentView?>> {
  @override
  AsyncValue<ContentView?> build() => const AsyncValue.loading();

  void set(AsyncValue<ContentView?> value) => state = value;
}

final _contentProvider =
    NotifierProvider<_ContentNotifier, AsyncValue<ContentView?>>(
  _ContentNotifier.new,
);

Future<void> _pump(
  WidgetTester tester, {
  ImageProvider? season,
  String? fallbackAsset,
}) async {
  final player = InertContentPlayer();
  addTearDown(player.dispose);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  final container = ProviderContainer.test(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      contentPlayerProvider.overrideWithValue(player),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      seasonBackgroundProvider.overrideWith((ref) async => season),
    ],
  );
  container.read(_contentProvider.notifier).set(const AsyncData(_view));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: ContentPlayerView(
          content: _contentProvider,
          chromeTitle: 'ENSEIGNEMENT',
          retractedTitle: 'Indisponible',
          retractedMessage: 'Retiré du catalogue.',
          onRetry: () {},
          fallbackBackgroundAsset: fallbackAsset,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Les fonds réellement posés par le cadre, dans l'ordre de peinture.
///
/// On lit l'`ImageProvider` et non un chemin : c'est ce que le cadre reçoit, et
/// c'est la seule chose dont dépend ce qui s'affiche.
List<ImageProvider> _backgrounds(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => image.image)
    .toList();

void main() {
  testWidgets('le fond de la saison est posé', (tester) async {
    await _pump(tester, season: _saison);

    expect(_backgrounds(tester), contains(_saison));
  });

  testWidgets('sans saison, l\'image du dépôt ferme la cascade',
      (tester) async {
    await _pump(tester, fallbackAsset: 'assets/images/live_bg.png');

    final assets = _backgrounds(tester).whereType<AssetImage>();
    expect(
        assets.map((a) => a.assetName), contains('assets/images/live_bg.png'));
  });

  testWidgets('la saison gagne sur l\'image du dépôt', (tester) async {
    await _pump(
      tester,
      season: _saison,
      fallbackAsset: 'assets/images/live_bg.png',
    );

    final posed = _backgrounds(tester);
    expect(posed, contains(_saison));
    // Et le plancher n'est **pas** peint par-dessus : deux fonds empilés
    // donneraient, selon l'ordre, le mauvais des deux — et le bon la moitié du
    // temps, ce qui est la pire façon de découvrir le bug.
    expect(posed.whereType<AssetImage>(), isEmpty);
  });

  testWidgets('sans rien du tout, l\'écran se peint quand même',
      (tester) async {
    await _pump(tester);

    // Aucun fond, et pourtant le lecteur est là : le titre, les commandes et
    // l'aplat de couleur du contenu. Un décor manquant n'est pas une panne.
    expect(find.text('La foi qui déplace'), findsOneWidget);
    expect(_backgrounds(tester), isEmpty);
  });
}
