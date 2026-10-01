/// **Le libellé d'une entrée de menu, et le seul endroit qui le décide** (#82).
///
/// Une entrée porte deux champs **indissociables** : `label`, la surcharge
/// réglée au portail (carte de traduction entière), et `labelKey`, la clé du
/// dépôt. `label = null` ne veut pas dire « pas de libellé » : il veut dire
/// « le libellé du dépôt », porté par la clé.
///
/// ## ⚠️ `labelKey` n'est **pas** une clé `.arb` de ce dépôt
///
/// Le transformer serveur l'annonce comme telle, et c'est une aspiration, pas un
/// fait : les sept entrées reprises de l'ancienne barre portent les clés **de la
/// vitrine** (`public.nav.home`, `public.nav.mediatheque`…), relevées sur
/// `app/vitrine/support/public_nav_catalog.ts`. Ce fichier est la table de
/// traduction, et il est **court exprès** : on ne nomme que les clés dont la
/// destination est rendable ici.
///
/// Les quatre clés absentes de la table — `public.nav.home`,
/// `public.nav.rencontres`, `public.nav.series`, `public.nav.contact` — ne sont
/// pas des oublis : leurs destinations (`page: accueil`, `rencontres`, `themes`,
/// `contact`) n'ont pas d'écran ici, l'entrée disparaît donc **avant** qu'on ait
/// à la nommer. Les lister pour rien ferait croire qu'un libellé suffit à rendre
/// une entrée.
///
/// ## Une entrée sans libellé affichable **ne paraît pas**
///
/// C'est la même doctrine que le reste du dépôt : *l'absence s'affiche comme une
/// absence*, jamais comme un texte inventé. Un onglet nommé « menu 7 » ou
/// « public.nav.dons » ressemble à une fuite de code, pas à un réglage ; et le
/// visiteur n'a aucun moyen de savoir que son application est en retard. [of]
/// rend donc `null`, et c'est l'écran qui saute l'entrée — exactement comme il
/// saute une destination qu'il ne sait pas ouvrir.
library;

import 'package:flutter/widgets.dart';

import '../models/menu_entry_view.dart';
import 'l10n_extension.dart';

/// Le libellé à afficher, ou `null` s'il n'y en a aucun.
///
/// L'ordre n'est pas négociable : **la surcharge du portail d'abord**, le mot du
/// dépôt ensuite. C'est tout l'intérêt du réglage — sans cette précédence, il ne
/// sert à rien. Et une surcharge vide ou blanche se comporte comme une surcharge
/// absente : `MenuEntryView.resolve` l'a déjà réduite à une chaîne vide.
String? menuEntryLabel(BuildContext context, MenuEntryView entry) {
  if (entry.label.isNotEmpty) return entry.label;
  return _deliveredLabel(context, entry.labelKey);
}

String? _deliveredLabel(BuildContext context, String? labelKey) {
  switch (labelKey?.trim()) {
    // L'entrée **indélébile** de la médiathèque (garde-fou 2 du cadrage) : le
    // catalogue entier, sans filtre. « Tout » est le mot que la barre d'onglets
    // employait déjà pour cet onglet-là, du temps où il ne filtrait rien.
    case 'public.nav.mediatheque':
      return context.l10n.filterAll;
    // Le catalogue de la famille enseignement. Passe par `context.words` et non
    // par `context.l10n` : la clé est au catalogue du vocabulaire réglable, et
    // une église qui dit « prédications » doit pouvoir le régler au portail.
    case 'public.nav.teachings':
      return context.words.filterTeachings;
    // Le catalogue de l'autre famille, nommé comme l'accueil le nomme déjà.
    case 'public.nav.gatherings':
      return context.l10n.sectionGatherings;
    default:
      return null;
  }
}
