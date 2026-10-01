import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/core/network/app_version_header.dart';
import 'package:maison_du_miracle/data/radio/radio_failure.dart';
import 'package:maison_du_miracle/data/radio/radio_handshake.dart';

import '../helpers/fake_api.dart';

/// **La poignée de main par cookie de MediaMTX** (#108) — les deux sauts, le bocal
/// gardé entre eux, et les deux phrases d'échec de #104.
///
/// ⚠️ **Ce que ces tests ne prouvent pas, et qu'il ne faut pas leur faire dire** :
/// qu'un cookie traverse jusqu'à ExoPlayer ou AVFoundation. Ils s'arrêtent à
/// l'en-tête que ce fichier rend ; ce que les moteurs natifs en font demande un
/// appareil réel.
void main() {
  const antenna = 'https://stream.test/antenne/index.m3u8';
  const resolved = 'https://stream.test/antenne/stream.m3u8';

  late FakeAdapter adapter;
  late HttpRadioHandshakeResolver resolver;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    final dio = Dio();
    dio.httpClientAdapter = adapter;
    resolver = HttpRadioHandshakeResolver(client: dio);
  }

  /// Un saut de MediaMTX : un 302 absolu à la racine, qui pose `cookieCheck`.
  ResponseBody redirect(String location, {String? cookie}) =>
      ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [location],
          if (cookie != null) 'set-cookie': [cookie],
        },
      );

  /// La playlist, et le cookie de session qui vient avec.
  ResponseBody playlist({String? cookie}) => ResponseBody.fromString(
        '#EXTM3U\n',
        200,
        headers: {
          if (cookie != null) 'set-cookie': [cookie],
        },
      );

  /// Ce que l'antenne répond à qui n'a pas de session.
  ResponseBody sessionNotFound() => ResponseBody.fromString(
        '{"status":"error","error":"session not found"}',
        401,
      );

  group('Les deux temps, et le bocal gardé entre eux', () {
    test('le cookie du 302 repart au second saut, et les deux sont rendus',
        () async {
      // La séquence mesurée le 2026-10-01 : un 302 qui pose `cookieCheck`, puis un
      // 200 qui pose `hlsSession`. **C'est le cœur de la tranche** — sans le
      // premier cookie renvoyé au second saut, MediaMTX ne pose jamais le second,
      // et tout ce qui suit rend 401.
      serve((options) {
        if (options.uri.toString() == antenna) {
          return redirect(resolved, cookie: 'cookieCheck=1; Path=/; HttpOnly');
        }
        return playlist(
          cookie: 'hlsSession=abc; Path=/antenne/; Secure; SameSite=None',
        );
      });

      final handshake = await resolver.resolve(antenna);

      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.headers.containsKey('Cookie'),
        isFalse,
        reason: 'au premier saut, le bocal est vide',
      );
      expect(
        adapter.requests.last.headers['Cookie'],
        'cookieCheck=1',
        reason: 'le second saut rend ce que le premier a posé — '
            'sans ça, pas de session',
      );
      // L'URL **finale**, pas celle de départ : rouvrir l'adresse de départ
      // referait la négociation sans le bocal.
      expect(handshake.url, resolved);
      expect(handshake.headers, {'Cookie': 'cookieCheck=1; hlsSession=abc'});
    });

    test('aucun nom de cookie n\'est écrit en dur dans le client', () async {
      // Filtrer sur `cookieCheck` / `hlsSession` ferait de la configuration de
      // MediaMTX une constante du binaire : une version du serveur qui renomme
      // l'un des deux rendrait l'antenne muette **sans qu'aucun test rougisse**.
      serve((options) => options.uri.toString() == antenna
          ? redirect(resolved, cookie: 'mtxCheck=1')
          : playlist(cookie: 'mtxSession=zzz'));

      final handshake = await resolver.resolve(antenna);

      expect(adapter.requests.last.headers['Cookie'], 'mtxCheck=1');
      expect(handshake.headers, {'Cookie': 'mtxCheck=1; mtxSession=zzz'});
    });

    test('un cookie reposé au second saut remplace le premier', () async {
      // Ce que fait un navigateur, et ce qu'il faut ici : MediaMTX peut reposer
      // `cookieCheck` en route.
      serve((options) => options.uri.toString() == antenna
          ? redirect(resolved, cookie: 'cookieCheck=1')
          : playlist(cookie: 'cookieCheck=2'));

      final handshake = await resolver.resolve(antenna);

      expect(handshake.headers, {'Cookie': 'cookieCheck=2'});
    });

    test('un `Location` relatif se résout sur l\'adresse courante', () async {
      // La mesure n'a montré qu'un `Location` absolu ; s'en tenir à celui-là
      // rendrait la radio muette le jour où MediaMTX en écrit un autre.
      serve((options) => options.uri.path == '/antenne/index.m3u8'
          ? redirect('stream.m3u8', cookie: 'cookieCheck=1')
          : playlist(cookie: 'hlsSession=abc'));

      final handshake = await resolver.resolve(antenna);

      expect(handshake.url, resolved);
    });

    test('un 200 sans cookie rend l\'adresse et aucun en-tête', () async {
      // Vide n'est pas un échec : un MediaMTX configuré sans session jouerait sans
      // cookie, et inventer un en-tête pour que la carte soit pleine ne prouverait
      // rien.
      serve((_) => playlist());

      final handshake = await resolver.resolve(antenna);

      expect(adapter.requests, hasLength(1));
      expect(handshake.url, antenna);
      expect(handshake.headers, isEmpty);
    });
  });

  group('Les deux phrases restent celles de #104', () {
    test('un 401 « session not found » → « antenne indisponible »', () async {
      serve((_) => sessionNotFound());

      Object? caught;
      try {
        await resolver.resolve(antenna);
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<DioException>());
      // La réponse **attachée** est ce qui range l'échec du bon côté :
      // `classifyRadioFailure` partage sur son existence, et rien d'autre.
      expect((caught as DioException).response?.statusCode, 401);
      expect(classifyRadioFailure(caught), RadioFailureKind.antenna);
    });

    test('personne ne répond → « vérifiez votre connexion »', () async {
      // La panne de transport remonte telle quelle : pas de réponse, donc pas de
      // serveur qui a parlé.
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'Failed host lookup',
            error: const SocketException('Failed host lookup'),
          ));

      Object? caught;
      try {
        await resolver.resolve(antenna);
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<DioException>());
      expect((caught as DioException).response, isNull);
      expect(classifyRadioFailure(caught), RadioFailureKind.connection);
    });

    test('une redirection sans destination → « antenne indisponible »',
        () async {
      // Le serveur a parlé, et sa réponse est cassée : ce n'est pas le réseau de
      // l'auditeur qui manque.
      serve((_) => ResponseBody.fromString('', 302));

      Object? caught;
      try {
        await resolver.resolve(antenna);
      } catch (error) {
        caught = error;
      }

      expect(classifyRadioFailure(caught!), RadioFailureKind.antenna);
    });

    test('une boucle de redirections s\'arrête, et dit « antenne »', () async {
      // Un cycle sur le chemin de l'écoute est une panne, pas une patience à
      // avoir : le bouton doit s'en remettre à la reprise, pas tourner sans fin.
      serve((options) => redirect(options.uri.toString()));

      Object? caught;
      try {
        await resolver.resolve(antenna);
      } catch (error) {
        caught = error;
      }

      expect(classifyRadioFailure(caught!), RadioFailureKind.antenna);
      expect(
        adapter.requests.length,
        kRadioHandshakeMaxHops + 1,
        reason: 'la borne de sauts est ce qui arrête la boucle',
      );
    });
  });

  group('Le pré-vol a ses propres bornes', () {
    test('sa borne de temps est la sienne, et elle est courte', () {
      // Elle est prise sur la fenêtre de rattrapage de 40 s de l'antenne : la
      // valeur est écrite ici en clair, jamais relue depuis la constante — c'est
      // la constante qu'on éprouve.
      expect(kRadioHandshakeTimeout, const Duration(seconds: 5));
    });

    test(
        'le pré-vol ne passe pas par le client global — son 401 ne '
        'déconnecterait personne', () {
      // L'arbitrage le plus important de cette tranche. Sur le `Dio` d'`ApiClient`,
      // le 401 de MediaMTX purgerait le jeton et éjecterait vers `/auth` : une
      // antenne mal configurée **déconnecterait l'auditeur**. Et le porteur Bearer
      // partirait vers un autre hôte que l'API.
      final own = HttpRadioHandshakeResolver();

      expect(own.client.interceptors.whereType<UnauthorizedInterceptor>(),
          isEmpty);
      expect(
        own.client.interceptors.whereType<AppVersionHeaderInterceptor>(),
        isEmpty,
      );
      expect(own.client.options.baseUrl, isEmpty);
      expect(own.client.options.headers.containsKey('Authorization'), isFalse);
    });
  });

  test(
      'la doctrine tient : un seul fichier de `lib/` importe connectivity_plus',
      () {
    // Garde-fou de **source**, sur le modèle de celui de `just_audio`
    // (`content_player_test.dart`). La tentation de cette tranche est précise :
    // un pré-vol sur le chemin critique de l'écoute donne envie de demander
    // d'abord « y a-t-il du réseau ». Le paquet répond « connecté » derrière un
    // portail captif — exactement quand sa réponse compterait —, et un second
    // importeur ne casserait aucun test de comportement.
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    expect(sources, isNotEmpty);
    final coupables = <String>[];
    for (final source in sources) {
      // Les commentaires de documentation **parlent** du paquet — ils en disent
      // même beaucoup de mal — sans l'importer.
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');
      if (code.contains('package:connectivity_plus/')) {
        coupables.add(source.path);
      }
    }

    expect(
      coupables,
      ['lib/data/network/network_transport.dart'],
      reason: 'seul le lecteur du type de transport connaît ce paquet ; '
          'la panne d\'écoute se déduit de l\'échec lui-même',
    );
  });
}
