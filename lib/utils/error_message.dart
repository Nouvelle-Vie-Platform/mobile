/// **Ce qu'un écran dit d'un échec de chargement — une seule règle, un seul
/// endroit.**
///
/// La règle, et elle ne se renégocie pas : **une réponse reçue n'est jamais une
/// panne de réseau.** Seule l'*absence* de réponse — délai dépassé, DNS, coupure,
/// TLS — mérite « vérifiez votre connexion internet ». Un 401, un 403, un 404,
/// un 5xx ont tous répondu : le téléphone a parlé au serveur, et le serveur a
/// parlé au téléphone.
///
/// **Le défaut était mesuré, pas supposé.** Sur l'accueil, la section « À venir »
/// affichait *« Impossible de charger le contenu. Vérifiez votre connexion
/// internet, puis réessayez. »* alors que le téléphone était connecté — le serveur
/// refusait simplement le jeton d'invité sur `GET /events`, en 401.
/// `mapCalendarError` rangeait pourtant ce 401 en
/// [CalendarErrorCode.unauthorized] ; c'est **l'écran** qui l'écrasait, parce
/// qu'il ne nommait que le cas `server` et rabattait tout le reste sur le message
/// réseau.
///
/// Dire « vérifiez votre connexion » à quelqu'un dont la connexion fonctionne est
/// la pire phrase possible : elle envoie vers un geste inutile, et elle apprend à
/// ne plus croire les messages de l'application. C'est la même faute que celle que
/// `radio_failure.dart` corrige sur le bouton d'antenne, et les deux fichiers
/// portent la même règle — l'un pour un bouton, l'autre pour un état d'écran.
///
/// ## Pourquoi une fonction, et non une méthode d'`AppErrorState`
///
/// `AppErrorState` n'a **aucune notion métier dans son API** : des textes et un
/// rappel, c'est écrit dans son en-tête. Lui faire lire une `CalendarException`
/// ou une `DioException` lui donnerait une connaissance du domaine dont il n'a
/// pas besoin pour dessiner une carte. La traduction se fait donc avant lui, et
/// **une fois pour tous les écrans** : trois d'entre eux la faisaient chacun à sa
/// façon, et deux s'étaient arrêtés à mi-chemin.
///
/// ## Ce que cette fonction ne fait pas
///
/// Elle ne distingue pas un **404** d'un **5xx**. `CalendarException` ne porte
/// pas le code de statut — `mapCalendarError` range les deux en
/// [CalendarErrorCode.server] —, donc un 404 se dit « le serveur ne répond pas
/// pour l'instant », ce qui est imprécis. C'est une imprécision **connue et
/// laissée** : elle n'envoie personne vérifier son wifi, et la corriger demande
/// d'élargir le modèle d'erreur de l'agenda, ce qui est un autre sujet.
library;

import 'package:dio/dio.dart';

import '../data/repositories/calendar_repository.dart';
import '../l10n/app_localizations.dart';

/// La phrase à montrer pour [error], en langage humain.
///
/// Trois sorties, et chacune affirme exactement ce qu'on sait :
///
/// | ce qui s'est passé | la phrase |
/// | --- | --- |
/// | personne n'a répondu (réseau, DNS, délai, TLS) | `stateErrorMessage` |
/// | le serveur a répondu en échouant (5xx, 404, 422) | `stateErrorServerMessage` |
/// | le serveur a répondu en refusant (401, 403) | `stateErrorRefusedMessage` |
///
/// ⚠️ **Une erreur d'une autre nature retombe sur `stateErrorMessage`**, et ce
/// n'est pas une contradiction avec la règle : la règle est à sens unique — *une
/// réponse reçue n'est pas une panne de réseau*. Une erreur dont on ne sait rien
/// n'est **pas** une réponse reçue, et le message réseau reste alors le plus utile
/// (il propose un geste). Ce que la règle interdit est de le montrer devant une
/// réponse, et c'est précisément ce que les deux premières branches ferment.
String errorStateMessage(Object? error, AppLocalizations l10n) {
  if (error is CalendarException) {
    return switch (error.code) {
      // Le serveur a dit non. Ni le wifi ni les données mobiles n'y changeront
      // quoi que ce soit, et sous mode invité ce 401 est un refus de jeton, pas
      // une session expirée — l'intercepteur n'a éjecté personne.
      CalendarErrorCode.unauthorized => l10n.stateErrorRefusedMessage,
      CalendarErrorCode.server => l10n.stateErrorServerMessage,
      // `network` dit déjà « personne n'a répondu » ; `unknown` est une requête
      // annulée ou un cas non prévu, donc sans réponse non plus.
      CalendarErrorCode.network ||
      CalendarErrorCode.unknown =>
        l10n.stateErrorMessage,
    };
  }

  // Les erreurs **non traduites** en code de domaine : la route d'antenne lève
  // sa `DioException` telle quelle (`http_radio_repository.dart`), et c'est elle
  // qui alimente l'état d'erreur de l'écran d'antenne.
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == null) return l10n.stateErrorMessage;
    return status == 401 || status == 403
        ? l10n.stateErrorRefusedMessage
        : l10n.stateErrorServerMessage;
  }

  return l10n.stateErrorMessage;
}
