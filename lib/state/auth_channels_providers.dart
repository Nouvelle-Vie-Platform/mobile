/// **Par quelles portes l'application propose d'entrer**, du magasin jusqu'à
/// l'écran d'identifiant (#83).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_channels.dart';
import 'sync_providers.dart';

/// L'offre telle que le **magasin** la connaît, **observée** : un canal fermé au
/// portail cesse d'être proposé au cycle de synchronisation suivant, sans qu'on
/// rouvre l'application.
///
/// **Pas de réessai automatique** — même parti pris que les autres lectures du
/// magasin : il n'y a rien à retenter en boucle sur une base locale.
final authChannelsProvider = StreamProvider<AuthChannelOffer>(
  (ref) => ref.watch(authChannelsDaoProvider).watchOffer(),
  retry: _noAutomaticRetry,
);

Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// **Ce que l'écran propose**, repli compris — et c'est ce que les écrans
/// lisent, jamais [authChannelsProvider] directement.
///
/// En chargement comme en erreur, l'offre est [AuthChannelOffer.emailOnly] :
/// **avant le premier cycle de synchronisation, l'application ne sait rien**, et
/// c'est précisément le moment où quelqu'un ouvre l'application pour la première
/// fois. Attendre la base donnerait un écran de connexion sans champ ; proposer
/// « tous les canaux » remettrait le sélecteur menteur que cette tranche retire.
///
/// Le repli est écrit **ici et dans le DAO**, qui sont le même repli sur deux
/// chemins (pas encore chargé / chargé mais vide) et jamais deux règles : les
/// deux nomment la constante, aucun des deux ne la recopie.
final authChannelOfferProvider = Provider<AuthChannelOffer>(
  (ref) => ref.watch(authChannelsProvider).value ?? AuthChannelOffer.emailOnly,
);
