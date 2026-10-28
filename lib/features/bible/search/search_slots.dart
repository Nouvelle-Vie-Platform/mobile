/// **Les emplacements de la tranche M3 — recherche simple, croisée, comparative.**
///
/// Un raccourci « Rechercher » pour l'accueil du module (disposé par M7) ;
/// plus d'entrée dans Mon espace (#265) : la barre de l'accueil et la loupe
/// de l'onglet Bible y mènent déjà. La loupe de l'en-tête de la coquille n'est pas un
/// emplacement : elle s'ajoute à l'assemblage et appelle
/// `BibleSearchScreen.open(ref.read(routerProvider))`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../shell/bible_slots.dart';
import 'bible_search_screen.dart';

void _open(BuildContext context, WidgetRef ref) =>
    BibleSearchScreen.open(ref.read(routerProvider));

final BibleSlots searchSlots = BibleSlots(
  homeShortcuts: [
    BibleHomeShortcut(
      id: 'search',
      order: 0,
      icon: Icons.search,
      label: (context) => context.l10n.bibleSearchTitle,
      onTap: _open,
    ),
  ],
);
