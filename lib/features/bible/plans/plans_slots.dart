/// **Les emplacements de la tranche M5 — plans, défis.**
///
/// Cette tranche n'édite **que** ce fichier pour se brancher sur la coquille ;
/// voir `../README.md`. Ordres : raccourcis — Plans 10, Défis 20 (plus
/// d'entrée dans Mon espace depuis #265 : les cartes de l'accueil y mènent) ;
/// section d'accueil « Mon plan en cours » — 40 (après le verset du jour,
/// « Continuer la lecture » et le passage du dimanche de M7).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../shell/bible_slots.dart';
import 'challenges_screen.dart';
import 'plans_screen.dart';
import 'plans_widgets.dart';

void _openPlans(BuildContext _, WidgetRef ref) =>
    pushBiblePlansPage<void>(ref, const BiblePlansScreen());

void _openChallenges(BuildContext _, WidgetRef ref) =>
    pushBiblePlansPage<void>(ref, const BibleChallengesScreen());

final BibleSlots plansSlots = BibleSlots(
  homeShortcuts: [
    BibleHomeShortcut(
      id: 'plans',
      order: 10,
      icon: Icons.event_note_outlined,
      label: (context) => context.l10n.biblePlansShortcut,
      onTap: _openPlans,
    ),
    BibleHomeShortcut(
      id: 'challenges',
      order: 20,
      icon: Icons.emoji_events_outlined,
      label: (context) => context.l10n.biblePlansChallengesTitle,
      onTap: _openChallenges,
    ),
  ],
  homeSections: [
    BibleHomeSection(
      id: 'current-plan',
      order: 40,
      builder: (_) => const BiblePlanHomeCard(onOpen: openBiblePlanDetail),
    ),
  ],
);
