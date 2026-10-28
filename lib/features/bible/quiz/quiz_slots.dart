/// **Les emplacements de la tranche M6 — quiz.**
///
/// Un raccourci de l'accueil (disposé par M7) ; plus d'entrée dans Mon espace
/// (#265) : la carte de l'accueil y mène déjà.
/// La carte « Quiz de la semaine » de l'accueil lit `featuredQuizProvider`
/// (`quiz_providers.dart`) et ouvre `QuizEntry.play` ; voir
/// `../README.md`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../shell/bible_slots.dart';
import 'quiz_screens.dart';

final BibleSlots quizSlots = BibleSlots(
  homeShortcuts: [
    BibleHomeShortcut(
      id: 'quiz',
      order: 30,
      icon: Icons.quiz_outlined,
      label: (context) => context.l10n.bibleQuizTitle,
      onTap: (_, ref) => QuizEntry.open(ref),
    ),
  ],
);
