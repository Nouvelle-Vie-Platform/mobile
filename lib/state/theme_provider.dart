import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/settings_dao.dart';
import '../models/theme_preferences.dart';
import 'sync_providers.dart';

/// Pas de réessai automatique : une lecture locale qui échoue ne réussira pas
/// mieux à la seconde tentative.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Le DAO des réglages — partagé avec les préférences média.
final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao,
);

/// **Les réglages d'apparence, tels que le fidèle les a posés.**
///
/// À surcharger dans les tests d'écran : lire ce flux ouvre le magasin Drift,
/// et `pumpScreen` le fait déjà pour tout le monde.
final themePreferencesProvider = StreamProvider<ThemePreferences>(
  (ref) => ref.watch(settingsDaoProvider).watchThemePreferences(),
  retry: _noAutomaticRetry,
);

/// **L'horloge**, injectable — sans elle, la règle horaire serait intestable :
/// on ne peut pas demander à un test d'attendre 19 h.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// **Le `ThemeMode` effectivement appliqué**, une fois le choix résolu.
///
/// C'est la seule chose que `MaterialApp` lit. Trois des quatre choix se
/// traduisent directement ; `auto` passe par la règle horaire, et c'est lui qui
/// justifie tout ce fichier.
///
/// **Une minuterie unique, armée sur la prochaine bascule** — jamais un sondage.
/// Elle se réveille une fois par bascule, se réarme, et rien ne tourne entre
/// deux. `CLAUDE.md` proscrit le sondage dans le moteur de synchronisation ; en
/// introduire un ici pour une couleur serait mal venu.
///
/// **Doublée d'une réévaluation au retour au premier plan**, et ce n'est pas une
/// ceinture de plus : un téléphone en veille ne garantit rien à ses minuteries,
/// et le cas visé — l'app ouverte pendant le culte du soir, l'écran éteint puis
/// rallumé — est précisément celui-là.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _observing = false;

  @override
  ThemeMode build() {
    final preferences =
        ref.watch(themePreferencesProvider).value ?? const ThemePreferences();
    final now = ref.watch(nowProvider);

    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    ref.onDispose(() {
      _timer?.cancel();
      if (_observing) WidgetsBinding.instance.removeObserver(this);
    });

    _arm(preferences, now);
    return _resolve(preferences, now);
  }

  ThemeMode _resolve(ThemePreferences preferences, DateTime Function() now) {
    return switch (preferences.choice) {
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
      ThemeChoice.system => ThemeMode.system,
      ThemeChoice.auto => isDarkAt(
          now(),
          darkFrom: preferences.darkFrom,
          lightFrom: preferences.lightFrom,
        )
            ? ThemeMode.dark
            : ThemeMode.light,
    };
  }

  /// Arme la minuterie sur la prochaine bascule, et rien d'autre.
  ///
  /// Hors mode `auto` il n'y a **rien à attendre** : la minuterie est annulée
  /// plutôt que laissée à tourner pour un résultat qui ne changera pas.
  void _arm(ThemePreferences preferences, DateTime Function() now) {
    _timer?.cancel();
    if (preferences.choice != ThemeChoice.auto) return;

    final at = nextThemeSwitch(
      now(),
      darkFrom: preferences.darkFrom,
      lightFrom: preferences.lightFrom,
    );
    if (at == null) return;

    // Une seconde de marge : sans elle, la minuterie peut se réveiller au
    // dernier instant *avant* l'heure, ne rien voir changer, et se réarmer sur
    // un délai nul — donc tourner en boucle serrée jusqu'à la seconde suivante.
    final delay = at.difference(now()) + const Duration(seconds: 1);
    _timer = Timer(delay.isNegative ? Duration.zero : delay, _reevaluate);
  }

  /// Recalcule sans repasser par le magasin : seule l'heure a bougé.
  void _reevaluate() {
    final preferences =
        ref.read(themePreferencesProvider).value ?? const ThemePreferences();
    final now = ref.read(nowProvider);
    _arm(preferences, now);
    final next = _resolve(preferences, now);
    if (state != next) state = next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _reevaluate();
  }
}

/// Indique si le mode sombre est effectivement actif (en tenant compte du
/// réglage système lorsque le mode est [ThemeMode.system]).
bool isDarkModeActive(ThemeMode mode, BuildContext context) {
  if (mode == ThemeMode.system) {
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
  return mode == ThemeMode.dark;
}
