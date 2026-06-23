import 'package:flutter_test/flutter_test.dart';

import 'package:maison_du_miracle/main.dart';

void main() {
  testWidgets('L\'application démarre sur le splash', (tester) async {
    await tester.pumpWidget(const MaisonDuMiracleApp());
    await tester.pump();

    // Le splash affiche le nom et la baseline de l'église.
    expect(find.text('Maison du Miracle'), findsWidgets);
  });
}
