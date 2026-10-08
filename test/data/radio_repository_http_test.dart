/// **La route d'antenne et le battement, en HTTP** (M2 du plan radio
/// adaptative) : `ecoStreamUrl` lu à travers l'enveloppe, et le corps exact du
/// battement.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/radio/http_radio_repository.dart';

/// Un serveur qui répond ce qu'on lui dit, enveloppe `data` comprise.
class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int status = 200;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({HttpRadioRepository repo, _FakeServer server}) _setUp() {
  final server = _FakeServer();
  final dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
    ..httpClientAdapter = server
    ..interceptors.add(unwrapEnvelopeInterceptor);
  return (repo: HttpRadioRepository(client: dio), server: server);
}

void main() {
  test('GET /radio/antenna lit ecoStreamUrl', () async {
    final (:repo, :server) = _setUp();
    server.body = {
      'data': {
        'streamUrl': 'https://s.example/antenne-hls/master.m3u8',
        'ecoStreamUrl': 'https://s.example/antenne-hls/a32/index.m3u8',
        'onAir': true,
        'live': null,
      },
    };

    final antenna = await repo.antenna();

    expect(server.requests.single.path, kRadioAntennaPath);
    expect(
        antenna.ecoStreamUrl, 'https://s.example/antenne-hls/a32/index.m3u8');
  });

  test('GET /radio/antenna : ecoStreamUrl null reste null', () async {
    final (:repo, :server) = _setUp();
    server.body = {
      'data': {
        'streamUrl': 'https://s.example/antenne-hls/master.m3u8',
        'ecoStreamUrl': null,
        'onAir': true,
      },
    };

    expect((await repo.antenna()).ecoStreamUrl, isNull);
  });

  test('POST /radio/listening porte { listenId }', () async {
    final (:repo, :server) = _setUp();
    server.status = 204;

    await repo.reportListening('7c0e6a3e-1f2b-4c3d-9e8f-0a1b2c3d4e5f');

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, kRadioListeningPath);
    expect(request.data, {'listenId': '7c0e6a3e-1f2b-4c3d-9e8f-0a1b2c3d4e5f'});
  });

  test('un 429 lève — c\'est le battement qui le tait', () async {
    final (:repo, :server) = _setUp();
    server.status = 429;

    await expectLater(
      repo.reportListening('7c0e6a3e-1f2b-4c3d-9e8f-0a1b2c3d4e5f'),
      throwsA(isA<DioException>()),
    );
  });
}
