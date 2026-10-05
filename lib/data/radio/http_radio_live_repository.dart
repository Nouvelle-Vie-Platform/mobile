/// **Les routes de la page live, en HTTP** (#135).
///
/// ```
/// GET  /radio/comments                              ['api','device']
/// POST /radio/comments            { body }          ['api','device'] → 201 RadioCommentView
/// PUT  /radio/pseudonym           { pseudonym }     ['api','device'] → 200 { pseudonym }
/// POST /radio/comments/:id/reports                  ['api','device'] → 201
/// POST /radio/reactions           { reaction }      ['api','device'] → 202
/// GET  /radio/moderation/comments                   ['api']          (modérateurs)
/// POST /radio/moderation/comments/:id/{hide|keep|silence|reset-pseudonym}
/// ```
///
/// **L'invité n'a rien de particulier à faire** : le coffre ne tient qu'un
/// jeton, et `ApiClient` pose celui qui s'y trouve — le jeton d'appareil pour
/// un invité. Le serveur admet le garde `device` sur les cinq premières routes,
/// et sur elles seulement. L'enveloppe `data` est déballée par l'intercepteur ;
/// le 401 d'un jeton d'appareil est renouvelé puis rejoué par
/// `UnauthorizedInterceptor`, comme partout.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'radio_live.dart';
import 'radio_live_repository.dart';

/// Les chemins, écrits une seule fois.
const String kRadioCommentsPath = '/radio/comments';
const String kRadioPseudonymPath = '/radio/pseudonym';
const String kRadioReactionsPath = '/radio/reactions';
const String kRadioModerationPath = '/radio/moderation/comments';

class HttpRadioLiveRepository implements RadioLiveRepository {
  HttpRadioLiveRepository({Dio? client})
      : _dio = client ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error) {
      throw classifyRadioLiveError(error);
    }
  }

  @override
  Future<RadioThread> thread() => _guard(() async {
        final res = await _dio.get<dynamic>(kRadioCommentsPath);
        return RadioThread.fromJson(res.data);
      });

  @override
  Future<void> react(RadioReaction reaction) => _guard(() async {
        await _dio.post<dynamic>(
          kRadioReactionsPath,
          data: {'reaction': reaction.wire},
        );
      });

  @override
  Future<RadioComment> postComment(String body) => _guard(() async {
        final res = await _dio.post<dynamic>(
          kRadioCommentsPath,
          data: {'body': body},
        );
        final comment = RadioComment.fromJson(res.data);
        if (comment == null) {
          throw const RadioLiveException(RadioLiveRefusal.unknown);
        }
        return comment;
      });

  @override
  Future<String> savePseudonym(String pseudonym) => _guard(() async {
        final res = await _dio.put<dynamic>(
          kRadioPseudonymPath,
          data: {'pseudonym': pseudonym},
        );
        final data = res.data;
        final saved = data is Map ? data['pseudonym'] : null;
        return saved is String && saved.isNotEmpty ? saved : pseudonym;
      });

  @override
  Future<void> report(String commentId) => _guard(() async {
        await _dio.post<dynamic>(
          '$kRadioCommentsPath/${Uri.encodeComponent(commentId)}/reports',
        );
      });

  @override
  Future<RadioModerationQueue> moderationQueue() => _guard(() async {
        final res = await _dio.get<dynamic>(kRadioModerationPath);
        return RadioModerationQueue.fromJson(res.data);
      });

  Future<void> _moderate(String commentId, String action) => _guard(() async {
        await _dio.post<dynamic>(
          '$kRadioModerationPath/${Uri.encodeComponent(commentId)}/$action',
        );
      });

  @override
  Future<void> hide(String commentId) => _moderate(commentId, 'hide');

  @override
  Future<void> keep(String commentId) => _moderate(commentId, 'keep');

  @override
  Future<void> silence(String commentId) => _moderate(commentId, 'silence');

  @override
  Future<void> resetPseudonym(String commentId) =>
      _moderate(commentId, 'reset-pseudonym');
}
