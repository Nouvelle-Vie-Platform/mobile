import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/widgets/status/status_waveform.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 300, child: child),
      ),
    ),
  );
}

void main() {
  group('waveformFromSeed', () {
    test('est déterministe : deux appels au même seed donnent la même liste',
        () {
      expect(waveformFromSeed('ann-1'), equals(waveformFromSeed('ann-1')));
      expect(
        waveformFromSeed('ann-1', count: 40),
        equals(waveformFromSeed('ann-1', count: 40)),
      );
    });

    test('deux seeds différents donnent des listes différentes', () {
      expect(
          waveformFromSeed('ann-1'), isNot(equals(waveformFromSeed('ann-2'))));
      expect(waveformFromSeed(''), isNot(equals(waveformFromSeed('a'))));
    });

    test('respecte le nombre demandé et reste dans 0..100', () {
      expect(waveformFromSeed('x').length, kStatusWaveformBarCount);
      expect(waveformFromSeed('x', count: 28).length, 28);
      expect(waveformFromSeed('x', count: 40).length, 40);
      expect(waveformFromSeed('x', count: 0), isEmpty);
      expect(waveformFromSeed('x', count: -5), isEmpty);
      for (final v in waveformFromSeed('x', count: 40)) {
        expect(v, inInclusiveRange(0, 100));
      }
    });

    test('n’est pas une forme plate', () {
      final bars = waveformFromSeed('vocal-du-dimanche');
      expect(bars.toSet().length, greaterThan(4));
    });
  });

  group('resampleWaveform', () {
    test('ramène toujours à la longueur demandée', () {
      expect(resampleWaveform(List<int>.filled(200, 50), 32).length, 32);
      expect(resampleWaveform(<int>[10, 90], 32).length, 32);
      expect(resampleWaveform(<int>[10, 90, 30], 3), equals(<int>[10, 90, 30]));
    });

    test('moyenne à la baisse d’échantillonnage', () {
      // 4 valeurs → 2 barres : moyennes par paires.
      expect(resampleWaveform(<int>[0, 100, 40, 60], 2), equals(<int>[50, 50]));
    });

    test('cas limites : liste vide ou count nul', () {
      expect(resampleWaveform(const <int>[], 32), isEmpty);
      expect(resampleWaveform(<int>[1, 2, 3], 0), isEmpty);
      expect(resampleWaveform(<int>[1, 2, 3], -1), isEmpty);
    });
  });

  group('StatusWaveform', () {
    testWidgets('se monte avec des barres fournies par le back',
        (tester) async {
      await tester.pumpWidget(
        _host(
          StatusWaveform(
            bars: List<int>.generate(120, (i) => i % 101),
            progress: 0.5,
            seed: 'ann-1',
          ),
        ),
      );
      expect(find.byType(StatusWaveform), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se monte avec repli déterministe quand bars est vide',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusWaveform(bars: <int>[], progress: 0, seed: 'ann-2'),
        ),
      );
      final widget = tester.widget<StatusWaveform>(find.byType(StatusWaveform));
      expect(widget.resolveBars(), equals(waveformFromSeed('ann-2')));
    });

    test('resolveBars ré-échantillonne les données du back', () {
      const w = StatusWaveform(
        bars: <int>[10, 20, 30],
        progress: 0.3,
        seed: 's',
        barCount: 16,
      );
      expect(w.resolveBars().length, 16);

      const empty = StatusWaveform(
        bars: <int>[10, 20, 30],
        progress: 0,
        seed: 's',
        barCount: 0,
      );
      expect(empty.resolveBars(), isEmpty);
    });

    testWidgets('supporte les progressions hors bornes sans exception',
        (tester) async {
      for (final p in <double>[-1, 0, 0.5, 1, 2, double.nan]) {
        await tester.pumpWidget(
          _host(StatusWaveform(bars: const <int>[], progress: p, seed: 'x')),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('supporte une hauteur minuscule et des barres à zéro',
        (tester) async {
      await tester.pumpWidget(
        _host(
          StatusWaveform(
            bars: List<int>.filled(32, 0),
            progress: 0.5,
            seed: 'x',
            height: 2,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('est « settleable » : pumpAndSettle se termine',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusWaveform(bars: <int>[], progress: 0.42, seed: 'ann-3'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatusWaveform), findsOneWidget);
    });
  });
}
