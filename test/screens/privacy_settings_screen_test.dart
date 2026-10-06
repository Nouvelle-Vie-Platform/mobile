/// **L'écran Confidentialité** (#142, tranche M3) : il lit les deux réglages
/// sur le serveur, les bascule, dit la réciprocité, et revient en place sur un
/// refus.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/messaging_signals_api.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/privacy_settings_screen.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

final _fr = AppLocalizationsFr();

class _FakePrivacyApi extends InertMessagingSignalsApi {
  _FakePrivacyApi({
    this.current = MessagingPrivacy.defaults,
    this.failOnUpdate = false,
  });

  MessagingPrivacy current;
  final bool failOnUpdate;
  final List<Map<String, bool?>> updates = [];

  @override
  Future<MessagingPrivacy> readPrivacy() async => current;

  @override
  Future<MessagingPrivacy> updatePrivacy({
    bool? readReceipts,
    bool? presence,
  }) async {
    updates.add({'readReceipts': readReceipts, 'presence': presence});
    if (failOnUpdate) throw Exception('réseau');
    return current = current.copyWith(
      readReceipts: readReceipts,
      presence: presence,
    );
  }
}

bool _switchValue(WidgetTester tester, Key key) =>
    tester.widget<SwitchListTile>(find.byKey(key)).value;

Future<void> _pump(WidgetTester tester, _FakePrivacyApi api) async {
  await pumpScreen(
    tester,
    const PrivacySettingsScreen(),
    auth: SignedInAuthRepository(),
    signals: api,
  );
  await tester.pump();
}

void main() {
  testWidgets('les deux réglages, lus sur le serveur, et la réciprocité dite',
      (tester) async {
    await _pump(
      tester,
      _FakePrivacyApi(
        current: const MessagingPrivacy(readReceipts: false, presence: true),
      ),
    );

    expect(find.text(_fr.privacyTitle), findsOneWidget);
    expect(
        _switchValue(tester, PrivacySettingsScreen.readReceiptsKey), isFalse);
    expect(_switchValue(tester, PrivacySettingsScreen.presenceKey), isTrue);
    expect(find.text(_fr.privacyReadReceiptsHint), findsOneWidget);
    expect(find.text(_fr.privacyPresenceHint), findsOneWidget);
  });

  testWidgets('couper les accusés de lecture l\'écrit sur le serveur',
      (tester) async {
    final api = _FakePrivacyApi();
    await _pump(tester, api);

    await tester.tap(find.byKey(PrivacySettingsScreen.readReceiptsKey));
    await tester.pump();
    await tester.pump();

    expect(api.updates, [
      {'readReceipts': false, 'presence': null},
    ]);
    expect(
        _switchValue(tester, PrivacySettingsScreen.readReceiptsKey), isFalse);
    expect(_switchValue(tester, PrivacySettingsScreen.presenceKey), isTrue);
  });

  testWidgets('couper « vu à et en ligne »', (tester) async {
    final api = _FakePrivacyApi();
    await _pump(tester, api);

    await tester.tap(find.byKey(PrivacySettingsScreen.presenceKey));
    await tester.pump();
    await tester.pump();

    expect(api.updates.single['presence'], isFalse);
    expect(_switchValue(tester, PrivacySettingsScreen.presenceKey), isFalse);
  });

  testWidgets('un refus remet l\'interrupteur en place et le dit',
      (tester) async {
    final api = _FakePrivacyApi(failOnUpdate: true);
    await _pump(tester, api);

    await tester.tap(find.byKey(PrivacySettingsScreen.readReceiptsKey));
    await tester.pump();
    await tester.pump();

    expect(_switchValue(tester, PrivacySettingsScreen.readReceiptsKey), isTrue);
    expect(find.text(_fr.privacySaveError), findsOneWidget);
    // La barre d'information se retire seule : on la laisse partir.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
