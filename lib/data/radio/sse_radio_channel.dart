/// **Le canal radio, en SSE, sur le `Dio` de l'application** (#135).
///
/// Le protocole est **celui des groupes**, relevé dans `@adonisjs/transmit@3` et
/// déjà éprouvé par `lib/data/realtime/sse_group_channel.dart` — ses quatre
/// points valent ici à l'identique :
///
/// 1. **l'ordre** : `POST /__transmit/subscribe` après que `GET
///    /__transmit/events?uid=` a rendu ses en-têtes ;
/// 2. **un `uid` neuf par connexion** ;
/// 3. **`receiveTimeout` désarmé** (`Duration.zero`) : une antenne sans
///    réaction pendant quinze secondes est le cas normal, pas une panne ;
/// 4. **un refus n'est pas une panne** ([RadioChannelRefused]), et ne se
///    réessaie pas.
///
/// Ce qui change, et qui interdit de passer par `SseGroupChannel` : **on lit la
/// charge**. Le lecteur de trames des groupes compte des frontières sans rien
/// lire après `data:` ; celui-ci ([SseEventReader]) rend le texte de chaque
/// événement, que [decodeRadioChannelData] décode.
///
/// ## L'invité ouvre ce canal avec son jeton d'appareil
///
/// Le porteur est posé par `ApiClient`, comme sur toute requête : le coffre ne
/// tient qu'**un** jeton, membre ou appareil, et c'est lui qui part. Le serveur
/// admet le garde `device` sur `/__transmit/*` **pour le seul canal `radio`**
/// (`server-portal/start/transmit.ts`, `guestOnlyOnRadio`) — l'abonnement à
/// `radio/moderation` n'est donc demandé que pour un modérateur, qui est
/// forcément un membre.
///
/// ## Le canal de modération partage la connexion
///
/// Une seule socket, deux abonnements sous le même `uid` : Transmit range chaque
/// trame sous son nom de canal. Un refus de `radio/moderation` (rôle retiré
/// entre deux lectures) **ne coupe pas** le canal public : l'auditeur garde ses
/// réactions et son fil, il perd seulement la file des signalements.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import 'radio_channel.dart';

/// **Lit `text/event-stream` et rend le texte de chaque événement.**
///
/// Une ligne vide termine un événement ; ses lignes `data:` se joignent par un
/// saut de ligne (spécification SSE). Les commentaires (`:ok` à l'ouverture) et
/// les autres champs (`id:`, `event:`) sont ignorés. L'état est retenu entre
/// deux fragments : une socket rend des morceaux, pas des lignes.
///
/// Il prend du **texte déjà décodé** : le découpage UTF-8 d'un fragment coupé au
/// milieu d'un caractère (un é, un 🙏) appartient au décodeur en flux, en amont.
class SseEventReader {
  String _carry = '';
  final List<String> _data = [];

  /// Avale un fragment et rend les événements qu'il achève.
  List<String> consume(String chunk) {
    final events = <String>[];
    _carry += chunk;
    while (true) {
      final cut = _carry.indexOf('\n');
      if (cut < 0) break;
      final line = _carry.substring(0, cut).replaceAll('\r', '');
      _carry = _carry.substring(cut + 1);

      if (line.isEmpty) {
        if (_data.isNotEmpty) events.add(_data.join('\n'));
        _data.clear();
        continue;
      }
      if (line.startsWith('data:')) {
        final value = line.substring(5);
        _data.add(value.startsWith(' ') ? value.substring(1) : value);
      }
    }
    return events;
  }
}

/// Implémentation réelle de [RadioChannel].
class SseRadioChannel implements RadioChannel {
  SseRadioChannel({Dio? client, String Function()? mintUid})
      : _dio = client ?? ApiClient.instance.dio,
        _mintUid = mintUid ?? (() => const Uuid().v7());

  final Dio _dio;
  final String Function() _mintUid;

  @override
  Stream<RadioChannelEvent> watch({required bool moderation}) {
    late final StreamController<RadioChannelEvent> out;
    CancelToken? token;
    StreamSubscription<String>? text;

    Future<void> stop() async {
      token?.cancel();
      token = null;
      final pending = text;
      text = null;
      await pending?.cancel();
    }

    void fail(Object error, [StackTrace? trace]) {
      if (out.isClosed) return;
      out.addError(error, trace);
      out.close();
    }

    Future<void> open() async {
      final uid = _mintUid();
      final cancel = CancelToken();
      token = cancel;

      final response = await _dio.get<ResponseBody>(
        '/__transmit/events',
        queryParameters: {'uid': uid},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final reader = SseEventReader();
      final bytes = response.data?.stream;
      if (bytes != null) {
        text = bytes
            .cast<List<int>>()
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
          (chunk) {
            for (final data in reader.consume(chunk)) {
              final event = decodeRadioChannelData(data);
              if (event != null && !out.isClosed) out.add(event);
            }
          },
          onError: fail,
          onDone: out.close,
          cancelOnError: true,
        );
      }

      try {
        await _dio.post<Object?>(
          '/__transmit/subscribe',
          data: {'uid': uid, 'channel': kRadioChannel},
          cancelToken: cancel,
        );
      } on DioException catch (error) {
        await stop();
        fail(
          error.response == null
              ? error
              : RadioChannelRefused(error.response?.statusCode),
        );
        return;
      }

      var moderated = false;
      if (moderation) {
        try {
          await _dio.post<Object?>(
            '/__transmit/subscribe',
            data: {'uid': uid, 'channel': kRadioModerationChannel},
            cancelToken: cancel,
          );
          moderated = true;
        } on DioException catch (error) {
          // Une coupure franche ici est une coupure du canal entier.
          if (error.response == null) {
            await stop();
            fail(error);
            return;
          }
          traceRadioChannel(
            'abonnement à la modération refusé '
            '(${error.response?.statusCode}) — le canal public reste ouvert',
          );
        }
      }

      // **L'ouverture est elle-même un événement**, posé après l'abonnement :
      // c'est elle qui déclenche la relecture qui comble la coupure.
      if (!out.isClosed) out.add(RadioChannelOpened(moderation: moderated));
    }

    out = StreamController<RadioChannelEvent>(
      onListen: () {
        open().catchError(fail);
      },
      onCancel: stop,
    );
    return out.stream;
  }
}
