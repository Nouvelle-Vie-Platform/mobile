/// **Les emplacements de la tranche M7 — l'accueil du module.**
///
/// Le premier écran (maquette « Splash & Accueil ») est une seule section,
/// **fixe** (#265) ; « Lecture du jour » et « Continuer la lecture » ouvrent ce
/// qui défile dessous, puis
/// « Mon plan en cours » (M5, ordre 40), le passage du dimanche et le quiz de
/// la semaine. Une tranche qui ajoute une carte prend un
/// `order` au-delà de 0.
library;

import '../shell/bible_slots.dart';
import 'home_view.dart';

final BibleSlots homeSlots = BibleSlots(
  homeSections: [
    BibleHomeSection(
      id: 'home_view',
      order: 0,
      builder: (_) => const BibleHomeView(),
    ),
    // Le début de ce qui défile, sous l'en-tête fixe (#265).
    BibleHomeSection(
      id: 'daily_reading',
      order: 5,
      builder: (_) => const BibleDailySection(),
    ),
    BibleHomeSection(
      id: 'continue_reading',
      order: 10,
      builder: (_) => const BibleContinueSection(),
    ),
    BibleHomeSection(
      id: 'sunday_passage',
      order: 50,
      builder: (_) => const BibleSundayPassageSection(),
    ),
    BibleHomeSection(
      id: 'featured_quiz',
      order: 60,
      builder: (_) => const BibleFeaturedQuizSection(),
    ),
  ],
);
