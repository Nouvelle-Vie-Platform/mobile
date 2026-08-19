/// **La lecture d'un flux SSE, sans le DOM** — et rien d'autre.
///
/// Ce fichier ne touche **ni le DOM, ni `dart:js_interop`, ni `package:web`** :
/// c'est délibéré, et c'est la seule chose qui rend le lecteur SSE web
/// vérifiable. `flutter test` tourne sur la VM, jamais dans un navigateur ; si
/// le découpage des trames vivait dans le fichier d'interop
/// (`web_transmit_client.dart`, jamais compilé pour la VM), il ne serait couvert
/// que par un coup d'œil dans Chrome.
///
/// C'est le pendant, pour le temps-réel, de `media_element_playback.dart` face à
/// `hls_content_player.dart` : la **décision** ici (comment recoudre des octets
/// en trames, comment ignorer un ping, comment lire `{ channel, payload }`), les
/// **câbles** là-bas (ouvrir le `fetch`, tirer le `ReadableStream`).
///
/// Rangé dans `lib/data/realtime/` et non sous l'interop parce qu'il est
/// **partageable** : l'implémentation native à venir (`HttpTransmitClient`, flux
/// Dio, D6) recoud exactement les mêmes trames SSE — le seul écart entre les
/// deux mondes est *par où arrivent les octets*, pas *comment on les lit*.
library;

import 'dart:convert';

import 'transmit_client.dart';

/// **Un recoud-trames SSE incrémental**, nourri chunk par chunk.
///
/// Le corps d'un flux SSE arrive en morceaux d'octets qui ne respectent aucune
/// frontière de ligne : un `data:` peut être coupé en deux réseaux, deux trames
/// peuvent tenir dans un même paquet. Cette classe absorbe cette irrégularité —
/// elle retient la ligne partielle en cours ([_pending]) et les lignes `data`
/// d'une trame pas encore terminée ([_dataLines]) — et n'émet une charge utile
/// qu'à la **ligne vide** qui clôt une trame (spécification SSE : `text/event-stream`).
///
/// Ce qu'elle rend est la valeur brute du champ `data` recousue ; le décodage en
/// [TransmitEvent] est l'affaire de [decodeTransmitEvent], gardé à part pour que
/// le format du transport (SSE) et celui du protocole (Transmit) ne se mélangent
/// pas.
class SseFrameParser {
  /// La fin de chunk qui n'a pas encore rencontré son `\n` : une ligne à moitié
  /// arrivée. Recollée au chunk suivant.
  String _pending = '';

  /// Les valeurs des lignes `data:` de la trame **en cours de constitution**,
  /// vidées et jointes par `\n` à la ligne vide qui clôt la trame.
  final List<String> _dataLines = [];

  /// Avale un morceau de texte déjà décodé (UTF-8) et **émet** la charge utile
  /// `data` de chaque trame que ce morceau achève. Peut n'en émettre aucune (le
  /// morceau ne fait qu'allonger une ligne ou une trame incomplète) ou
  /// plusieurs (le morceau contient plusieurs trames).
  Iterable<String> addChunk(String chunk) sync* {
    _pending += chunk;
    // On ne traite que les lignes **complètes** ; la dernière, sans `\n`, reste
    // dans [_pending] pour le prochain chunk.
    while (true) {
      final newline = _pending.indexOf('\n');
      if (newline < 0) break;
      var line = _pending.substring(0, newline);
      _pending = _pending.substring(newline + 1);
      // Fin de ligne `\r\n` : le `\r` n'appartient pas à la donnée.
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      final frame = _consume(line);
      if (frame != null) yield frame;
    }
  }

  /// Applique une ligne SSE et rend la charge utile de la trame si cette ligne
  /// la clôt (ligne vide), sinon `null`.
  String? _consume(String line) {
    // Ligne vide → fin de trame : on livre ce qu'on a accumulé.
    if (line.isEmpty) {
      if (_dataLines.isEmpty) return null;
      final data = _dataLines.join('\n');
      _dataLines.clear();
      return data;
    }
    // Ligne commençant par `:` → **commentaire**. C'est ainsi que Transmit
    // envoie ses pings de maintien en vie ; ils ne portent aucune donnée et se
    // jettent en silence, sans même déclencher de sync.
    if (line.startsWith(':')) return null;
    // Champ SSE `nom:valeur` ; une valeur qui commence par une espace en perd
    // une (spécification). Un nom sans `:` vaut champ à valeur vide.
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    // On ne retient que `data`. `event`, `id` et `retry` ne servent pas à
    // « quelque chose est arrivé sur tel canal » — la seule chose que le
    // consommateur veut (D1).
    if (field == 'data') _dataLines.add(value);
    return null;
  }
}

/// **Décode la charge utile `data` d'une trame Transmit en [TransmitEvent]**, ou
/// `null` si la trame n'en est pas une.
///
/// Le serveur (`@adonisjs/transmit`) diffuse chaque message sous la forme JSON
/// `{ "channel": "groups/{id}", "payload": … }`. On ne lit que le **canal** —
/// c'est lui qui dit « quelque chose est arrivé, va synchroniser » (D1) ; le
/// [TransmitEvent.payload] est porté tel quel pour le diagnostic mais **jamais
/// peint** (le message revient par le flux delta de `/sync`).
///
/// Rend `null` — sans jamais lever — sur tout ce qui n'est pas une trame de
/// message exploitable : JSON mal formé (un ping qui aurait fui, une trame
/// tronquée), objet sans `channel`, `channel` non textuel. Une trame illisible
/// ne doit pas tuer le flux ; au pire elle rate une sync, que la sync de
/// rattrapage à la reconnexion (D4) répare de toute façon.
TransmitEvent? decodeTransmitEvent(String data) {
  try {
    final decoded = jsonDecode(data);
    if (decoded is! Map) return null;
    final channel = decoded['channel'];
    if (channel is! String) return null;
    return TransmitEvent(channel, payload: decoded['payload']);
  } catch (_) {
    return null;
  }
}
