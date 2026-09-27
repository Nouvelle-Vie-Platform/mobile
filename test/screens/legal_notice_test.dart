/// **La mention légale du premier lancement** — non bloquante, une seule fois.
///
/// Ce bandeau existe pour une raison qu'un test doit rappeler : l'application
/// attribue un **identifiant d'appareil** dès la première ouverture, une donnée
/// personnelle posée avant tout compte. La barrière bloquante des membres
/// (`/legal/accept`) est le seul endroit où un accord explicite est recueilli, et
/// un invité ne la voit jamais. Retirer ce bandeau en le prenant pour une
/// décoration referait ce trou-là.
///
/// Quatre règles y sont verrouillées : il paraît au premier lancement, il ne
/// bloque rien, il ne revient pas, et un membre ne le voit pas.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/legal_notice_store.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/legal_acceptance_screen.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/widgets/legal_notice_banner.dart';

import '../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

void main() {
  testWidgets('premier lancement : le bandeau est là, et il n\'enferme rien',
      (tester) async {
    final store = InMemoryLegalNoticeStore();
    final router =
        await pumpGuestApp(tester, guestContainer(legalNotice: store));

    expect(find.byKey(LegalNoticeBanner.bannerKey), findsOneWidget);
    expect(find.text(_fr.legalNoticeBody), findsOneWidget);

    // **Non bloquant, et c'est ce qui le distingue de la barrière.** Pas de
    // route, pas de `PopScope`, pas de barrière modale : l'accueil répond
    // derrière, et la barre d'onglets aussi.
    expect(find.byType(LegalAcceptanceScreen), findsNothing);
    expect(router.state.matchedLocation, '/home');

    await tester.tap(navTab(_fr.navAnnouncements));
    await settle(tester);
    expect(shellTab(tester), 1,
        reason: 'l\'application s\'utilise pendant que le bandeau est affiché');
    // Et il ne disparaît pas parce qu'on a touché autre chose : il ne part que
    // par son propre bouton.
    expect(find.byKey(LegalNoticeBanner.bannerKey), findsOneWidget);
  });

  testWidgets('les deux liens mènent aux documents, ouverts sans compte',
      (tester) async {
    final router = await pumpGuestApp(
      tester,
      guestContainer(legalNotice: InMemoryLegalNoticeStore()),
    );

    await tester.tap(find.byKey(LegalNoticeBanner.termsKey));
    await settle(tester);
    // `/legal/:kind` est hors de `memberOnlyRoutes` : c'est précisément ce qu'on
    // doit pouvoir lire sans compte. Un bandeau dont les liens renverraient sur
    // l'accueil ne vaudrait rien — c'est le cul-de-sac le plus embarrassant qu'il
    // pourrait porter.
    expect(router.state.matchedLocation, '/legal/cgu');

    router.pop();
    await settle(tester);
    await tester.tap(find.byKey(LegalNoticeBanner.privacyKey));
    await settle(tester);
    expect(router.state.matchedLocation, '/legal/privacy');
  });

  testWidgets('il se ferme, et la fermeture s\'écrit', (tester) async {
    final store = InMemoryLegalNoticeStore();
    await pumpGuestApp(tester, guestContainer(legalNotice: store));

    await tester.tap(find.byKey(LegalNoticeBanner.dismissKey));
    await settle(tester);

    expect(find.byKey(LegalNoticeBanner.bannerKey), findsNothing);
    // **L'écriture, pas seulement le masquage.** Sans elle le bandeau
    // reparaîtrait au lancement suivant, et une mention qui revient cesse d'être
    // lue — la fermer deviendrait un réflexe.
    expect(store.remembered, isTrue);
  });

  testWidgets('deuxième lancement : plus rien', (tester) async {
    await pumpGuestApp(
      tester,
      guestContainer(legalNotice: InMemoryLegalNoticeStore(seen: true)),
    );

    expect(find.byKey(LegalNoticeBanner.bannerKey), findsNothing);
  });

  testWidgets('un membre ne le voit pas', (tester) async {
    final container = guestContainer(
      auth: GuestAuthRepository(signedIn: true),
      vault: StartupVault.memberSession,
      legalNotice: InMemoryLegalNoticeStore(),
    );
    await pumpGuestApp(tester, container);
    await untilSignedIn(tester, container);
    await settle(tester);

    // Son accord est explicite, tracé, et donné sur un texte entier : lui
    // superposer une mention implicite dirait moins que ce qu'il a déjà signé.
    // C'est aussi ce qui garde littéralement vraie la contrainte du client —
    // pour un membre, rien ne change.
    expect(find.byKey(LegalNoticeBanner.bannerKey), findsNothing);
  });
}
