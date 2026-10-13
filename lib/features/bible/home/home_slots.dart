/// **Les emplacements de la tranche M7 — l'accueil du module (sections, raccourcis).**
///
/// Deux sections : l'en-tête du verset du jour (pleine largeur), puis le corps
/// (recherche, raccourcis des autres tranches, « Continuer la lecture »,
/// passage du dimanche, quiz de la semaine — deux colonnes sur tablette). Une
/// tranche qui ajoute sa propre carte prend un `order` au-delà de 10.
library;

import '../shell/bible_slots.dart';
import 'home_view.dart';

final BibleSlots homeSlots = BibleSlots(
  homeSections: [
    BibleHomeSection(
      id: 'verse_of_day',
      order: 0,
      builder: (_) => const BibleHomeHeader(),
    ),
    BibleHomeSection(
      id: 'home_body',
      order: 10,
      builder: (_) => const BibleHomeBody(),
    ),
  ],
);
