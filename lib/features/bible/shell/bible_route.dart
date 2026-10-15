/// **La route d'un écran poussé par le module Bible**, hors des routes
/// nommées (quiz, plans, défis, recherche, comparaison).
///
/// Le thème de l'appli rend le fond des `Scaffold` **transparent** : chaque
/// route nommée peint le dégradé de l'appli derrière (`AppBackground`). Un
/// écran poussé directement sur le `Navigator`, sans ce fond, s'affiche sur
/// du **noir** — texte sombre illisible. Toute poussée du module passe donc
/// par ici (garde : `bible_architecture_test`).
library;

import 'package:flutter/material.dart';

import '../../../widgets/app_background.dart';

MaterialPageRoute<T> bibleRoute<T>(Widget screen) =>
    MaterialPageRoute<T>(builder: (_) => AppBackground(child: screen));
