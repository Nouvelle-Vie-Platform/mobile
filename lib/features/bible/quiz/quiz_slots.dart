/// **Les emplacements de la tranche M6 — quiz.**
///
/// Une entrée dans « Plus » et un raccourci de l'accueil (disposé par M7).
/// La carte « Quiz de la semaine » de l'accueil lit `featuredQuizProvider`
/// (`quiz_providers.dart`) et ouvre `QuizListScreen.play` ; voir
/// `../README.md`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../shell/bible_slots.dart';
import 'quiz_screens.dart';

final BibleSlots quizSlots = BibleSlots(
  moreEntries: [
    BibleMoreEntry(
      id: 'quiz',
      order: 20,
      icon: Icons.quiz_outlined,
      label: (context) => context.l10n.bibleQuizTitle,
      onTap: (_, ref) => QuizListScreen.open(ref),
    ),
  ],
  homeShortcuts: [
    BibleHomeShortcut(
      id: 'quiz',
      order: 30,
      icon: Icons.quiz_outlined,
      label: (context) => context.l10n.bibleQuizTitle,
      onTap: (_, ref) => QuizListScreen.open(ref),
    ),
  ],
);
