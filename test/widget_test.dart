import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maison_du_miracle/app.dart';

void main() {
  testWidgets('L\'application démarre sur le splash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaisonDuMiracleApp()),
    );
    await tester.pump();

    // Le splash affiche le nom et la baseline de l'église.
    expect(find.text('Maison du Miracle'), findsWidgets);
  });
}
