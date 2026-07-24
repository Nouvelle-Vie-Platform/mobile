import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/widgets/status/status_segmented_progress.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  );
}

void main() {
  group('statusSegmentWindow', () {
    test('affiche tout quand count tient dans la fenêtre', () {
      expect(
        statusSegmentWindow(count: 4, index: 2, maxVisible: 10),
        (start: 0, length: 4),
      );
      expect(
        statusSegmentWindow(count: 10, index: 9, maxVisible: 10),
        (start: 0, length: 10),
      );
    });

    test('centre à peu près l’index courant au milieu de la liste', () {
      expect(
        statusSegmentWindow(count: 30, index: 15, maxVisible: 10),
        (start: 10, length: 10),
      );
    });

    test('se borne au début', () {
      expect(
        statusSegmentWindow(count: 30, index: 0, maxVisible: 10),
        (start: 0, length: 10),
      );
      expect(
        statusSegmentWindow(count: 30, index: 4, maxVisible: 10),
        (start: 0, length: 10),
      );
    });

    test('se borne à la fin', () {
      expect(
        statusSegmentWindow(count: 30, index: 29, maxVisible: 10),
        (start: 20, length: 10),
      );
    });

    test('garde toujours l’index dans la fenêtre', () {
      for (var i = 0; i < 30; i++) {
        final w = statusSegmentWindow(count: 30, index: i, maxVisible: 10);
        expect(i, greaterThanOrEqualTo(w.start));
        expect(i, lessThan(w.start + w.length));
      }
    });

    test('cas limites : count nul, index hors bornes, maxVisible nul', () {
      expect(statusSegmentWindow(count: 0, index: 0, maxVisible: 10),
          (start: 0, length: 0));
      expect(statusSegmentWindow(count: -3, index: 0, maxVisible: 10),
          (start: 0, length: 0));
      expect(statusSegmentWindow(count: 30, index: -5, maxVisible: 10),
          (start: 0, length: 10));
      expect(statusSegmentWindow(count: 30, index: 99, maxVisible: 10),
          (start: 20, length: 10));
      expect(statusSegmentWindow(count: 5, index: 2, maxVisible: 0),
          (start: 0, length: 5));
    });
  });

  group('StatusSegmentedProgress', () {
    testWidgets('se monte et dessine un segment par élément visible',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusSegmentedProgress(count: 5, index: 2, progress: 0.4),
        ),
      );
      expect(tester.takeException(), isNull);
      // 5 segments + 4 espaceurs.
      expect(
        find.descendant(
          of: find.byType(StatusSegmentedProgress),
          matching: find.byType(ClipRRect),
        ),
        findsNWidgets(5),
      );
    });

    testWidgets('plafonne le nombre de segments à maxVisible', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusSegmentedProgress(count: 30, index: 15, progress: 0.5),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(StatusSegmentedProgress),
          matching: find.byType(ClipRRect),
        ),
        findsNWidgets(10),
      );
    });

    testWidgets('cas limites : count 0, count 1, index et progress hors bornes',
        (tester) async {
      const cases = <StatusSegmentedProgress>[
        StatusSegmentedProgress(count: 0, index: 0, progress: 0),
        StatusSegmentedProgress(count: 1, index: 0, progress: 1),
        StatusSegmentedProgress(count: 3, index: -4, progress: -2),
        StatusSegmentedProgress(count: 3, index: 42, progress: 7),
        StatusSegmentedProgress(count: 3, index: 1, progress: double.nan),
        StatusSegmentedProgress(
            count: 30, index: 29, progress: 1, maxVisible: 1),
      ];
      for (final c in cases) {
        await tester.pumpWidget(_host(c));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('est « settleable » : pumpAndSettle se termine',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusSegmentedProgress(count: 12, index: 3, progress: 0.25),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatusSegmentedProgress), findsOneWidget);
    });
  });
}
