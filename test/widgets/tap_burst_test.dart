import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/widgets/home/tap_burst.dart';

/// Le compteur de rafale, seul. Ce qu'il garantit — et qu'aucun test d'écran ne
/// peut montrer, parce que deux `tap` y tombent toujours à quelques
/// microsecondes — c'est qu'une rafale **se referme**.
void main() {
  final t0 = DateTime.utc(2026, 10, 1, 9);

  test('le premier appui vaut un, et il n\'attend rien', () {
    // L'absence d'attente est toute la raison d'être de cette classe : le rang est
    // rendu **par l'appel**, il n'y a pas de minuterie à laisser expirer avant de
    // savoir que c'était un simple appui.
    expect(TapBurst().register(t0), 1);
  });

  test('deux appuis rapprochés sont la même rafale', () {
    final burst = TapBurst();
    expect(burst.register(t0), 1);
    expect(burst.register(t0.add(const Duration(milliseconds: 120))), 2);
  });

  test('le compte continue au-delà de deux', () {
    // C'est ce qui permet au bouton de distinguer « le second appui navigue » de
    // « le troisième ne fait rien ».
    final burst = TapBurst();
    final ranks = [
      for (var i = 0; i < 5; i++)
        burst.register(t0.add(Duration(milliseconds: 100 * i))),
    ];
    expect(ranks, [1, 2, 3, 4, 5]);
  });

  test('un appui au-delà de la fenêtre ouvre une rafale neuve', () {
    final burst = TapBurst(window: const Duration(milliseconds: 300));
    expect(burst.register(t0), 1);
    expect(burst.register(t0.add(const Duration(milliseconds: 301))), 1);
  });

  test('la borne de la fenêtre est incluse', () {
    final burst = TapBurst(window: const Duration(milliseconds: 300));
    expect(burst.register(t0), 1);
    expect(burst.register(t0.add(const Duration(milliseconds: 300))), 2);
  });

  test('la fenêtre se compte depuis le dernier appui, pas depuis le premier',
      () {
    // Sans cela, cinq appuis lents sortiraient de la rafale au troisième, et le
    // quatrième relancerait l'antenne que le troisième venait d'ignorer.
    final burst = TapBurst(window: const Duration(milliseconds: 300));
    expect(burst.register(t0), 1);
    expect(burst.register(t0.add(const Duration(milliseconds: 250))), 2);
    expect(burst.register(t0.add(const Duration(milliseconds: 500))), 3);
  });

  test('la fenêtre par défaut est celle du système', () {
    // Reprise plutôt qu'inventée : la paire de contacts qu'un auditeur produit
    // « en double » est reconnue ici comme le détecteur du framework l'aurait
    // reconnue — sans en payer l'attente.
    expect(TapBurst().window, kTapBurstWindow);
  });
}
