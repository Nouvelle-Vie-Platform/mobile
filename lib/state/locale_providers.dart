import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/i18n_text.dart';

/// **La langue dans laquelle le contenu servi par le back doit être replié.**
///
/// À ne pas confondre avec la langue de l'interface : celle-là est résolue par
/// `MaterialApp` et se lit avec `context.l10n`. Celle-ci existe parce que le
/// **repli de contenu se fait hors de l'arbre de widgets** — dans les
/// repositories, qui construisent des modèles de lecture déjà repliés (voir
/// `MediathequeRepository`) et n'ont aucun `BuildContext`.
///
/// Une seule source, alimentée par l'application elle-même
/// (`MaisonDuMiracleApp`) à partir de la locale que `MaterialApp` a
/// **réellement** résolue. Re-dériver la locale depuis `PlatformDispatcher`
/// serait une seconde résolution, qui divergerait de la première le jour où
/// l'app gagnera un sélecteur de langue ou une locale régionale.
///
/// **Elle sert aussi l'en-tête `Accept-Language`** (#131) : `app.dart` la
/// branche comme lecteur d'`ApiClient.interfaceLanguage`. Sa *valeur* est bien
/// la langue de l'interface — c'est sa copie —, seul son *usage* ici diffère du
/// repli de contenu. Une seconde copie pour le réseau serait une seconde
/// vérité, libre de diverger.
///
/// La valeur par défaut est [kContentFallbackLocale] — le français, seule
/// langue dont on est certain qu'elle est toujours remplie côté contenu. Une
/// première image rendue avant la synchronisation de la locale se replie donc
/// exactement comme `pick` le ferait.
class ContentLocale extends Notifier<String> {
  @override
  String build() => kContentFallbackLocale;

  /// Retient la **sous-étiquette de langue** ([locale] peut valoir `fr_FR`) :
  /// le back ne régionalise pas ses contenus, et une valeur régionalisée
  /// multiplierait inutilement les recalculs de providers.
  void set(String locale) {
    final next = locale.split(RegExp('[_-]')).first.toLowerCase();
    if (next.isEmpty || next == state) return;
    state = next;
  }
}

final contentLocaleProvider = NotifierProvider<ContentLocale, String>(
  ContentLocale.new,
);
