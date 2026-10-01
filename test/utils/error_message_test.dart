import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/utils/error_message.dart';

/// **Une réponse reçue n'est jamais une panne de réseau.**
///
/// Le défaut qui a motivé ce fichier était visible et faux : la section « À venir »
/// de l'accueil annonçait « Vérifiez votre connexion internet » sur un téléphone
/// connecté, parce que le serveur refusait le jeton d'invité sur `GET /events` en
/// **401** et que l'écran rabattait tout ce qui n'était pas un 5xx sur le message
/// réseau.
///
/// Les assertions portent sur les **clés**, comparées aux chaînes du `.arb`
/// français, et non sur une égalité d'énoncé choisie à la main : ce qu'on vérifie
/// est *quelle phrase sort*, pas sa rédaction, qui peut être retouchée sans que ce
/// test ait à l'être.
void main() {
  final AppLocalizations l10n = AppLocalizationsFr();
  final options = RequestOptions(path: '/events');

  DioException refused(int status) => DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
        ),
      );

  group('Une réponse reçue n\'est jamais une panne de réseau', () {
    test('un 401 ne dit pas « vérifiez votre connexion »', () {
      final message = errorStateMessage(
        CalendarException(CalendarErrorCode.unauthorized),
        l10n,
      );

      // Les deux assertions comptent, et la seconde plus que la première : c'est
      // elle qui nomme le défaut. Sans elle, remettre le message réseau ici
      // passerait au vert le jour où les deux clés se ressembleraient.
      expect(message, l10n.stateErrorRefusedMessage);
      expect(message, isNot(l10n.stateErrorMessage));

      // ⚠️ La phrase retenue **parle** de la connexion internet — pour dire
      // qu'elle n'est pas en cause. Ce qu'on vérifie n'est donc pas qu'elle se
      // taise sur le sujet, mais qu'elle n'envoie **personne la vérifier** : c'est
      // l'injonction qui était fausse, pas le mot.
      expect(message, isNot(contains('Vérifiez votre connexion')));
    });

    test('un 403 et un 401 nus se disent de la même façon', () {
      // La route d'antenne lève sa `DioException` telle quelle, sans code de
      // domaine : le refus se lit alors sur le statut.
      for (final status in const [401, 403]) {
        expect(
          errorStateMessage(refused(status), l10n),
          l10n.stateErrorRefusedMessage,
          reason: '$status',
        );
      }
    });

    test('un 404 et un 5xx disent que le serveur a répondu', () {
      expect(
        errorStateMessage(CalendarException(CalendarErrorCode.server), l10n),
        l10n.stateErrorServerMessage,
      );
      for (final status in const [404, 422, 500, 503]) {
        expect(
          errorStateMessage(refused(status), l10n),
          l10n.stateErrorServerMessage,
          reason: '$status',
        );
      }
    });
  });

  group('Une absence de réponse le dit toujours', () {
    test('la panne réseau rangée par mapCalendarError', () {
      expect(
        errorStateMessage(CalendarException(CalendarErrorCode.network), l10n),
        l10n.stateErrorMessage,
      );
    });

    test('une DioException sans réponse attachée', () {
      // DNS, socket refusée, TLS, délai dépassé : Dio lève **sans** `response`,
      // et c'est le seul test dont cette fonction ait besoin.
      expect(
        errorStateMessage(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
          l10n,
        ),
        l10n.stateErrorMessage,
      );
    });

    test('un échec d\'une autre nature retombe là aussi', () {
      // La règle est **à sens unique** : une réponse reçue n'est pas une panne de
      // réseau. Une erreur dont on ne sait rien n'est pas une réponse reçue, et le
      // message réseau reste alors le plus utile — il propose un geste. Les trois
      // premiers tests sont ce qui empêche cette branche de tout avaler.
      expect(
        errorStateMessage(StateError('magasin illisible'), l10n),
        l10n.stateErrorMessage,
      );
      expect(errorStateMessage(null, l10n), l10n.stateErrorMessage);
    });
  });
}
