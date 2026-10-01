import 'package:drift/drift.dart';

import '../../models/auth_channels.dart';
import 'app_database.dart';
import 'tables/auth_tables.dart';

part 'auth_channels_dao.g.dart';

/// **Les lectures du magasin, côté canaux de connexion** (#83).
///
/// Une seule question : **par quelles portes l'application propose-t-elle
/// d'entrer ?** La réponse tient en une ligne — `auth_settings` est un singleton
/// côté serveur — et c'est ici, et nulle part ailleurs, que l'absence de cette
/// ligne se traduit en **offre**.
///
/// ## Le repli vit ici, en un seul endroit
///
/// Table vide = « je n'ai pas encore reçu les réglages », et le repli est
/// l'**e-mail seul** ([AuthChannelOffer.emailOnly]) : le canal qui marche
/// aujourd'hui, et celui que l'écran choisissait déjà par défaut. Un repli
/// permissif (« tous les canaux ») remettrait exactement le sélecteur menteur
/// que cette tranche retire ; un repli vide fermerait la porte.
///
/// Écrire cette règle dans l'écran l'aurait dupliquée au premier second écran, et
/// deux replis finissent par ne plus dire la même chose.
@DriftAccessor(tables: [AuthChannels])
class AuthChannelsDao extends DatabaseAccessor<AppDatabase>
    with _$AuthChannelsDaoMixin {
  AuthChannelsDao(super.db);

  /// L'offre, **observée** : le portail peut fermer un canal, et l'écran
  /// d'identifiant doit cesser de le proposer au cycle de synchronisation
  /// suivant — sans qu'on rouvre l'application.
  ///
  /// Un `Stream` et non un `Future`, pour la raison qui vaut partout dans ce
  /// dépôt : une photographie prise au montage figerait la politique jusqu'à la
  /// prochaine navigation.
  Stream<AuthChannelOffer> watchOffer() => _query().watch().map(_offerOf);

  /// La même, **une fois**. Sert aux tests ; l'application, elle, observe.
  Future<AuthChannelOffer> readOffer() async => _offerOf(await _query().get());

  /// La table n'a qu'une ligne (le singleton serveur), mais la lecture ne le
  /// suppose pas : `getSingleOrNull` sur une table qui en porterait deux
  /// lèverait, là où `limit(1)` rend simplement la première. Un magasin local
  /// n'a pas à se fier à un CHECK posé dans une autre base — et un écran de
  /// connexion est le dernier endroit où l'on veut une exception.
  Selectable<AuthChannelsRow> _query() => (select(authChannels)
    ..orderBy([(row) => OrderingTerm.asc(row.id)])
    ..limit(1));

  AuthChannelOffer _offerOf(List<AuthChannelsRow> rows) {
    if (rows.isEmpty) return AuthChannelOffer.emailOnly;
    final row = rows.first;
    // `resolve` et non le constructeur nu : il remet l'état « tous fermés » du
    // côté sûr. Le serveur l'interdit par un CHECK, ce magasin n'a pas à le
    // rejouer — mais il n'a pas non plus à le supposer.
    return AuthChannelOffer.resolve(
      emailOpen: row.emailOpen,
      phoneOpen: row.phoneOpen,
      notice: row.loginNotice,
    );
  }
}
