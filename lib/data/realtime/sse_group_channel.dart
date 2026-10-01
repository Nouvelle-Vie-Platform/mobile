/// **Le canal d'un groupe, en SSE, sur le `Dio` de l'application** (#101).
///
/// Aucun paquet nouveau, et il n'en faut aucun : SSE est du HTTP en flux, que
/// `dio` lit avec `ResponseType.stream`. Un client Transmit en Dart n'existe pas,
/// et il n'apporterait rien — le protocole tient en trois routes.
///
/// ## Le protocole, relevé dans `@adonisjs/transmit@3`, pas supposé
///
/// ```
/// GET  /__transmit/events?uid=<uid>     → text/event-stream, ouvert tant qu'il tient
/// POST /__transmit/subscribe            { uid, channel }  → 204, ou 400 si refusé
/// POST /__transmit/unsubscribe          { uid, channel }
/// ```
///
/// Quatre points qui se ratent en silence, tous vérifiés sur le source du paquet
/// et sur `server-portal/start/transmit.ts` :
///
/// 1. **L'ordre compte.** `POST /subscribe` cherche le flux par son `uid` : il
///    doit partir **après** que le `GET` a rendu ses en-têtes, sinon le serveur ne
///    connaît pas encore l'`uid` et refuse un abonnement qui aurait été légitime.
/// 2. **`uid` est frappé par le client**, un par connexion. Une reconnexion en
///    frappe un neuf : réutiliser l'ancien ferait vivre deux flux sous la même
///    clé côté serveur, dont un mort.
/// 3. **`receiveTimeout` doit être désarmé.** Le défaut du client est de 15 s
///    (`ApiClient`), et un canal silencieux pendant quinze secondes est le cas
///    **normal** d'une conversation — pas une panne. Sans ce `Duration.zero`, la
///    connexion se ferait tuer en boucle par son propre client (`dio` traite
///    `Duration.zero` comme « aucune limite », `io_adapter.dart`).
/// 4. **Un refus d'abonnement n'est pas une panne** : le canal est réservé aux
///    membres (`CheckGroupMembership`). Il remonte en [GroupChannelRefused], que
///    `OpenThreadChannel` ne réessaie jamais.
///
/// Les routes sont montées derrière `middleware.auth({ guards: ['api', 'web'] })` :
/// le porteur est posé par les intercepteurs d'`ApiClient`, comme sur n'importe
/// quelle autre requête, et il n'y a donc rien de particulier à faire ici.
///
/// ## ⚠️ Ce fichier ne décode aucune charge utile
///
/// Les octets reçus ne traversent que [SseFrameReader], qui compte des frontières
/// d'événements. Le corps diffusé par le serveur — `TransmitGroupBroadcaster` y
/// met l'intégralité du message — est **délibérément ignoré** : c'est le moteur de
/// synchronisation qui écrit, jamais le temps réel (ADR-0006, et l'en-tête de
/// `group_channel.dart`).
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import 'group_channel.dart';
import 'sse_frames.dart';

/// Implémentation réelle de [GroupChannel].
class SseGroupChannel implements GroupChannel {
  SseGroupChannel({Dio? client, String Function()? mintUid})
      : _dio = client ?? ApiClient.instance.dio,
        _mintUid = mintUid ?? _uuidV7;

  /// Un UUIDv7, comme la clé d'idempotence d'un envoi et l'identifiant de
  /// progression : la convention d'identifiant de tout ce dépôt.
  static String _uuidV7() => const Uuid().v7();

  final Dio _dio;
  final String Function() _mintUid;

  @override
  Stream<GroupChannelSignal> watch(String groupId) {
    final channel = groupChannelName(groupId);

    late final StreamController<GroupChannelSignal> out;
    CancelToken? token;
    StreamSubscription<List<int>>? bytes;

    /// Ferme la connexion. **Le `CancelToken` est le seul moyen** de rendre la
    /// socket : annuler l'abonnement au flux de `dio` ne suffit pas quand la
    /// requête est encore en vol (le `GET` n'a pas rendu ses en-têtes).
    Future<void> stop() async {
      token?.cancel();
      token = null;
      final pending = bytes;
      bytes = null;
      await pending?.cancel();
    }

    /// Rapporte une panne **une seule fois** et clôt le flux : un canal tombé est
    /// un canal à rouvrir, pas un canal qui continue de se plaindre.
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
          // Voir le point 3 de l'en-tête : un silence n'est pas une panne.
          receiveTimeout: Duration.zero,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final reader = SseFrameReader();
      bytes = response.data?.stream.listen(
        (chunk) {
          // **Les octets ne sont pas décodés en texte.** `fromCharCodes` suffit
          // parce qu'on ne cherche que des marqueurs ASCII (`data:`, fin de
          // ligne) : un fragment coupé au milieu d'un caractère UTF-8 donnerait
          // du charabia sans jamais fabriquer de fin de ligne — les octets de
          // continuation valent tous ≥ 0x80 —, là où un décodeur UTF-8 lèverait.
          // Et le charabia est sans conséquence : rien de ce corps n'est lu.
          final events = reader.consume(String.fromCharCodes(chunk));
          for (var i = 0; i < events; i++) {
            if (!out.isClosed) out.add(const GroupChannelSignal());
          }
        },
        onError: fail,
        // Le serveur a rendu la main (redéploiement, coupure) : le canal est
        // tombé, et c'est à l'appelant de décider s'il rouvre.
        onDone: out.close,
        cancelOnError: true,
      );

      try {
        await _dio.post<Object?>(
          '/__transmit/subscribe',
          data: {'uid': uid, 'channel': channel},
          cancelToken: cancel,
        );
        // **L'ouverture elle-même est un signal.** Un canal neuf n'a aucune
        // mémoire de ce qui s'est diffusé avant lui — pendant la coupure qu'on
        // vient de rattraper, ou simplement depuis le dernier cycle. Il y a donc
        // exactement la même chose à dire au moteur qu'à l'arrivée d'un message :
        // « va voir ». C'est ce qui fait qu'une reconnexion rattrape son trou, et
        // c'est aussi ce qui rafraîchit le fil qu'on vient d'ouvrir.
        //
        // Posé **après** l'abonnement, jamais avant : une tentative qui échoue ne
        // doit déclencher aucun cycle, sinon la réouverture périodique deviendrait
        // un sondage du moteur — précisément ce qu'ADR-0017 interdit.
        if (!out.isClosed) out.add(const GroupChannelSignal());
      } on DioException catch (error) {
        await stop();
        // Une réponse du serveur = un **refus** (non-membre, canal inconnu) ; pas
        // de réponse = une panne de transport, qui se rattrape.
        fail(
          error.response == null
              ? error
              : GroupChannelRefused(channel, error.response?.statusCode),
        );
      }
    }

    out = StreamController<GroupChannelSignal>(
      // Rien ne part avant qu'on écoute : un canal ouvert que personne ne lit
      // serait du forfait dépensé pour rien.
      onListen: () {
        // `unawaited` par construction : l'ouverture est asynchrone et ses pannes
        // passent par le flux, jamais par un `Future` que personne n'attend.
        open().catchError(fail);
      },
      onCancel: stop,
    );
    return out.stream;
  }
}
