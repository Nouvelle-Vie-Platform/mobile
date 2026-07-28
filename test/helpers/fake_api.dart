import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptateur Dio factice : note ce qui part sur le fil et rend la réponse
/// décidée par le test.
///
/// Indispensable — `flutter test` répond **400 à tout accès réseau réel**.
/// Aucune socket n'est ouverte : la requête traverse bien tous les
/// intercepteurs d'`ApiClient` (Bearer, enveloppe `data`, 401), mais s'arrête
/// à cet adaptateur.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);

  /// Réponse à rendre, ou exception à lever pour simuler une panne.
  final ResponseBody Function(RequestOptions options) reply;

  /// Requêtes vues, dans l'ordre — pour vérifier chemin, verbe et corps.
  final List<RequestOptions> requests = [];

  RequestOptions get lastRequest => requests.last;

  Map<String, dynamic> get lastBody =>
      (lastRequest.data as Map).cast<String, dynamic>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Réponse JSON du serveur, enveloppe `data` comprise (elle est déballée par
/// l'intercepteur d'`ApiClient`, comme en production).
ResponseBody jsonReply(int status, Object? data) => ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Réponse d'erreur du serveur : `{ code, message }`, **hors** enveloppe.
ResponseBody errorReply(int status, String code, [String? message]) =>
    ResponseBody.fromString(
      jsonEncode({'code': code, if (message != null) 'message': message}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Charge utile d'un `User` telle que la sérialise le serveur.
const Map<String, dynamic> userPayload = {
  'id': 'b6f0a1c2-0000-4000-8000-000000000001',
  'phone': '+22890123456',
  'email': null,
  'title': 'brother',
  'firstName': 'Jean',
  'lastName': 'Kossi',
  'branchId': 3,
  'status': 'affiliated',
  'avatarUrl': null,
  'profileComplete': true,
};
