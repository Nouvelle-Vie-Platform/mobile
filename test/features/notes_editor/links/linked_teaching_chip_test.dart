import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/links/linked_teaching_chip.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';

import 'link_test_helpers.dart';

const _present = '0192a5b4-0000-7000-8000-0000000000aa';
const _gone = '0192a5b4-0000-7000-8000-0000000000bb';

void main() {
  Future<void> pumpChip(WidgetTester tester, String? teachingId) async {
    await tester.pumpWidget(linkTestApp(
      linkTestRouter(LinkedTeachingChip(teachingId: teachingId)),
      [
        teachingByIdProvider.overrideWith(
          (ref, id) => Stream.value(
            id == _present ? fakeTeaching(_present, 'La foi') : null,
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche le titre et ouvre le lecteur', (tester) async {
    await pumpChip(tester, _present);
    expect(find.text('La foi'), findsOneWidget);
    await tester.tap(find.byKey(LinkedTeachingChip.chipKey));
    await tester.pumpAndSettle();
    expect(find.text('teaching $_present'), findsOneWidget);
  });

  testWidgets('enseignement absent du magasin : rien', (tester) async {
    await pumpChip(tester, _gone);
    expect(find.byKey(LinkedTeachingChip.chipKey), findsNothing);
  });

  testWidgets('note sans enseignement : rien', (tester) async {
    await pumpChip(tester, null);
    expect(find.byKey(LinkedTeachingChip.chipKey), findsNothing);
  });
}
