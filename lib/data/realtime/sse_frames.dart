/// **Lire `text/event-stream` sans rien en comprendre** (#101).
///
/// Le format est trivial : des lignes, et une ligne **vide** termine un
/// événement. Les lignes qui comptent commencent par `data:` ; celles qui
/// commencent par `:` sont des commentaires (Transmit en envoie un, `:ok`, dès
/// l'ouverture, parce que Safari ne déclenche `onopen` qu'à la première trame).
///
/// ## Ce que ce lecteur ne fait pas, et pourquoi c'est tout l'intérêt
///
/// Il **ne décode aucun JSON**. Il compte des frontières d'événements, et c'est
/// tout ce dont l'application a besoin : le corps du message n'est pas une donnée
/// à lire, c'est le moteur de synchronisation qui ira le chercher (ADR-0006, et
/// l'en-tête de `group_channel.dart`). Si quelqu'un se surprend à ajouter ici un
/// `jsonDecode`, c'est que le mauvais chemin a été pris.
///
/// Il n'y a donc **rien à filtrer par canal** non plus : un flux porte l'`uid`
/// d'une seule connexion, et cette connexion n'est abonnée qu'à un canal — celui
/// du fil ouvert. Le ping périodique de Transmit est désactivé côté serveur
/// (`config/transmit.ts`, `pingInterval: false`), et serait de toute façon sans
/// dommage : il déclencherait un cycle de plus, jamais une écriture fausse.
///
/// ## Le découpage en paquets n'est pas celui des lignes
///
/// Une socket rend des fragments d'octets, pas des lignes : un événement peut
/// arriver en trois morceaux, et trois événements dans un seul. D'où l'état
/// retenu entre deux appels ([consume]) — un lecteur sans mémoire perdrait un
/// événement sur deux dès que le réseau hoquette, ce qui est le régime normal
/// d'une connexion mobile.
library;

/// Compte les événements complets d'un flux `text/event-stream`.
class SseFrameReader {
  /// Le reste du dernier fragment, en attente de sa fin de ligne.
  String _carry = '';

  /// Le bloc courant portait-il au moins une ligne `data:` ?
  ///
  /// Sans cette question, deux lignes vides consécutives — ou le `:ok`
  /// d'ouverture suivi de sa ligne vide — compteraient pour des événements.
  bool _hasData = false;

  /// Avale un fragment et rend le **nombre d'événements** qu'il achève.
  int consume(String chunk) {
    var events = 0;
    _carry += chunk;

    while (true) {
      final cut = _carry.indexOf('\n');
      if (cut < 0) break;

      // `\r\n` comme `\n` : la spécification SSE accepte les deux, et un proxy
      // peut réécrire l'un en l'autre.
      final line = _carry.substring(0, cut).replaceAll('\r', '');
      _carry = _carry.substring(cut + 1);

      if (line.isEmpty) {
        if (_hasData) events++;
        _hasData = false;
        continue;
      }
      // `data:` avec ou sans espace, et **rien n'est lu après les deux points**.
      if (line.startsWith('data:')) _hasData = true;
    }

    return events;
  }
}
