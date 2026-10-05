/// **Le canal `users/{id}`, en SSE, sur le `Dio` de l'application** (#140).
///
/// Le protocole est celui de Transmit, déjà éprouvé par la radio
/// (`lib/data/radio/sse_radio_channel.dart`) — mêmes trois routes, mêmes quatre
/// points :
///
/// 1. **l'ordre** : `POST /__transmit/subscribe` après que `GET
///    /__transmit/events?uid=` a rendu ses en-têtes ;
/// 2. **un `uid` neuf par connexion** — une reconnexion en frappe un autre ;
/// 3. **`receiveTimeout` désarmé** (`Duration.zero`) : un silence est le cas
///    normal, la mort se juge sur l'absence de battement (`MessagingLink`) ;
/// 4. **un refus n'est pas une panne** ([MessagingChannelRefused]), et ne se
///    réessaie pas.
///
/// Le lecteur de trames est celui de la radio ([SseEventReader]) : il rend le
/// texte de chaque événement, sans rien décoder ; [decodeMessagingData] lit.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../radio/sse_radio_channel.dart' show SseEventReader;
import 'messaging_channel.dart';

/// Implémentation réelle de [MessagingChannel].
class SseMessagingChannel implements MessagingChannel {
  SseMessagingChannel({Dio? client, String Function()? mintUid})
      : _dio = client ?? ApiClient.instance.dio,
        _mintUid = mintUid ?? (() => const Uuid().v7());

  final Dio _dio;
  final String Function() _mintUid;

  @override
  Stream<MessagingEvent> watch(String userId) {
    final channel = userChannelName(userId);

    late final StreamController<MessagingEvent> out;
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
            // Décodeur **en flux** : un fragment coupé au milieu d'un caractère
            // (un é, un 🙏 dans un message) se recolle au fragment suivant.
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
          (chunk) {
            for (final data in reader.consume(chunk)) {
              if (out.isClosed) return;
              // Toute trame est un signe de vie, même celle qu'on ne sait pas
              // lire : un serveur plus récent n'est pas un serveur mort.
              out.add(
                decodeMessagingData(data, channel: channel) ??
                    const MessagingHeartbeat(),
              );
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
          data: {'uid': uid, 'channel': channel},
          cancelToken: cancel,
        );
      } on DioException catch (error) {
        await stop();
        fail(
          error.response == null
              ? error
              : MessagingChannelRefused(error.response?.statusCode),
        );
        return;
      }

      // **L'ouverture est elle-même un événement**, posé après l'abonnement :
      // c'est elle qui déclenche le cycle de rattrapage. Une tentative qui
      // échoue n'en déclenche aucun — la réouverture n'est pas un sondage.
      if (!out.isClosed) out.add(const MessagingChannelOpened());
    }

    out = StreamController<MessagingEvent>(
      onListen: () {
        open().catchError(fail);
      },
      onCancel: stop,
    );
    return out.stream;
  }
}
