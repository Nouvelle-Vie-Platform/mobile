// **La vidéo d'un statut : son cadrage, et son affiche en attendant** (#130).
//
// Décision 11 du plan « Sparks » : une vidéo verticale occupe le fond, une
// horizontale est gardée **entière**, centrée sur le fond du statut — jamais
// recadrée. Et l'affiche couvre le chargement jusqu'à la première image.
//
// Aucun vrai lecteur ici : un `InertStatusPlayer` peint les états par `emit`,
// et un widget témoin tient lieu de surface vidéo.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/status_player.dart';
import 'package:maison_du_miracle/widgets/status/status_video_layer.dart';

const _surfaceKey = Key('surface-temoin');

/// Monte le calque dans un fond de téléphone (390 × 760), comme la visionneuse.
Future<InertStatusPlayer> _pumpLayer(
  WidgetTester tester, {
  bool isCurrent = true,
  String? posterUrl = 'https://example.org/affiche.jpg',
}) async {
  final player = InertStatusPlayer();
  addTearDown(player.dispose);
  player.surface = const ColoredBox(key: _surfaceKey, color: Colors.red);
  player.load(
    statusId: 'video',
    mediaUrl: 'https://media.example.test/v/master.m3u8',
    mediaKind: StatusMediaKind.video,
    fallbackDuration: StatusDurations.media,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 390,
          height: 760,
          child: StatusVideoLayer(
            statusId: 'video',
            player: player,
            isCurrent: isCurrent,
            posterUrl: posterUrl,
          ),
        ),
      ),
    ),
  );
  return player;
}

/// L'ajustement que le cadre a retenu pour son enfant.
BoxFit _fitOf(WidgetTester tester, Key key) =>
    tester.renderObject<RenderFittedBox>(find.byKey(key)).fit;

void main() {
  group('statusVideoFraming — la règle', () {
    test('une vidéo verticale occupe le fond', () {
      expect(
          statusVideoFraming(const Size(1080, 1920)), StatusVideoFraming.fill);
    });

    test('une vidéo horizontale est gardée entière', () {
      expect(
          statusVideoFraming(const Size(1920, 1080)), StatusVideoFraming.fit);
    });

    test('une vidéo carrée est gardée entière — on ne coupe pas', () {
      expect(
          statusVideoFraming(const Size(1080, 1080)), StatusVideoFraming.fit);
    });

    test('des dimensions inconnues ne coupent rien', () {
      expect(statusVideoFraming(Size.zero), StatusVideoFraming.fit);
    });
  });

  group('StatusFramedMedia — le cadre applique la règle à son enfant', () {
    Future<void> pumpFramed(WidgetTester tester, Size child) =>
        tester.pumpWidget(
          Center(
            child: SizedBox(
              width: 390,
              height: 760,
              child: StatusFramedMedia(
                key: const Key('cadre'),
                child: SizedBox.fromSize(size: child),
              ),
            ),
          ),
        );

    testWidgets('verticale : `cover`, le fond est rempli', (tester) async {
      await pumpFramed(tester, const Size(1080, 1920));

      expect(_fitOf(tester, const Key('cadre')), BoxFit.cover);
    });

    testWidgets('horizontale : `contain`, rien n\'est recadré', (tester) async {
      await pumpFramed(tester, const Size(1920, 1080));

      expect(_fitOf(tester, const Key('cadre')), BoxFit.contain);
      // Le cadre occupe tout le fond : c'est la peinture de l'enfant qui est
      // réduite et centrée, et le fond du statut subsiste autour.
      expect(
          tester.getSize(find.byKey(const Key('cadre'))), const Size(390, 760));
    });
  });

  group('StatusVideoLayer', () {
    testWidgets('montre l\'affiche tant que la vidéo n\'a pas d\'image',
        (tester) async {
      final player = await _pumpLayer(tester);
      player.play();
      // Le lecteur a dit ses dimensions, mais aucune image n'est encore là :
      // l'affiche reste, jamais un carré noir.
      player.emit(player.value.copyWith(videoSize: const Size(1920, 1080)));
      await tester.pump();

      expect(find.byKey(StatusVideoLayer.posterKey), findsOneWidget);
      expect(find.byKey(StatusVideoLayer.videoKey), findsNothing);
      expect(find.byKey(_surfaceKey), findsNothing);
    });

    testWidgets(
        'à la première image, la vidéo remplace l\'affiche — horizontale, '
        'gardée entière', (tester) async {
      final player = await _pumpLayer(tester);
      player.emit(player.value.copyWith(
        isPlaying: true,
        hasVideoFrame: true,
        videoSize: const Size(1920, 1080),
      ));
      await tester.pump();

      expect(find.byKey(_surfaceKey), findsOneWidget);
      expect(find.byKey(StatusVideoLayer.posterKey), findsNothing);
      expect(_fitOf(tester, StatusVideoLayer.videoKey), BoxFit.contain);
    });

    testWidgets('une vidéo verticale occupe le fond', (tester) async {
      final player = await _pumpLayer(tester);
      player.emit(player.value.copyWith(
        hasVideoFrame: true,
        videoSize: const Size(1080, 1920),
      ));
      await tester.pump();

      expect(_fitOf(tester, StatusVideoLayer.videoKey), BoxFit.cover);
    });

    testWidgets('une page voisine ne montre que son affiche', (tester) async {
      // Le pager préconstruit les pages voisines ; le lecteur ne joue que la
      // page courante, et une image d'un autre statut ne doit pas s'y peindre.
      final player = await _pumpLayer(tester, isCurrent: false);
      player.emit(player.value.copyWith(
        hasVideoFrame: true,
        videoSize: const Size(1920, 1080),
      ));
      await tester.pump();

      expect(find.byKey(_surfaceKey), findsNothing);
      expect(find.byKey(StatusVideoLayer.posterKey), findsOneWidget);
    });

    testWidgets('l\'image d\'un autre statut ne s\'y peint pas',
        (tester) async {
      final player = await _pumpLayer(tester);
      player.emit(StatusPlayback(
        statusId: 'un-autre',
        hasVideoFrame: true,
        videoSize: const Size(1920, 1080),
      ));
      await tester.pump();

      expect(find.byKey(_surfaceKey), findsNothing);
    });

    testWidgets('une affiche en échec réseau retombe sans lever',
        (tester) async {
      // Sous `flutter test`, toute requête réseau rend 400 : c'est le chemin
      // `errorBuilder` qui s'exécute, et il doit être couvert.
      await _pumpLayer(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(StatusVideoLayer.posterErrorKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans affiche, rien n\'est peint avant la première image',
        (tester) async {
      await _pumpLayer(tester, posterUrl: null);

      expect(find.byKey(StatusVideoLayer.posterKey), findsNothing);
      expect(find.byKey(StatusVideoLayer.videoKey), findsNothing);
    });
  });
}
