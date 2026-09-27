import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'play_reporter.dart';

/// Implémentation HTTP de [PlayReporter].
///
/// ```
/// POST /teachings/:teachingId/plays
/// (aucun corps)
/// ```
///
/// **Aucun corps, et c'est le point à ne pas « améliorer ».** Le contenu
/// voyage dans le chemin ; le porteur — membre **ou** appareil anonyme —
/// voyage dans le `Authorization`, posé par `ApiClient` ; la date, c'est celle
/// à laquelle le serveur reçoit l'appel. Il n'y a rien d'autre à dire, et tout
/// champ qu'on ajouterait ici serait une chose que le client prétend savoir
/// mieux que le serveur. En particulier **pas d'horodatage** : le serveur ne
/// l'accepte pas, et le lui envoyer donnerait au client la main sur le jour
/// auquel une écoute est imputée, donc sur la déduplication.
///
/// La route est portée par le jeton de **membre** comme par le jeton
/// d'**appareil** : un invité compte dans l'audience, et c'est tout l'intérêt
/// du porteur anonyme. Rien n'est à faire ici pour ça — `ApiClient` pose le
/// jeton qu'il a, quel qu'il soit.
///
/// ## Le silence
///
/// **Aucun échec ne sort d'ici** : ni exception, ni bandeau, ni relance
/// visible. Hors ligne, 401, 404, 5xx sont des régimes normaux d'une route
/// appelée pendant qu'un prêche joue, souvent en 3G, souvent écran éteint.
///
/// Le `false` rendu n'est **pas** un message : c'est le signal qui décide si
/// l'événement part en file d'attente (`PlaySpool`). Voir `play_reporter.dart`
/// pour le pourquoi.
///
/// [lastFailure] existe pour le diagnostic et pour les tests — c'est le seul
/// endroit où l'échec est visible, et aucun écran ne le lit. Sans lui, un
/// rapporteur qui n'enverrait plus **rien du tout** passerait pour un
/// rapporteur discret.
class HttpPlayReporter implements PlayReporter {
  HttpPlayReporter({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  /// Le dernier échec avalé, `null` si la dernière remontée est passée.
  @visibleForTesting
  Object? lastFailure;

  @override
  Future<bool> report(String contentId) async {
    try {
      await _client.post<void>(playPath(contentId));
      lastFailure = null;
      return true;
    } on DioException catch (error) {
      // Avalé, délibérément : voir l'en-tête de cette classe. Une unité perdue
      // dans un compteur d'audience ne vaut pas une ligne à l'écran.
      lastFailure = error;
      return false;
    } catch (error) {
      // Seconde ceinture : une erreur de programmation — sérialisation, état
      // incohérent — ne doit pas plus interrompre un prêche qu'une coupure
      // réseau. La télémétrie n'a le droit de casser **rien**.
      lastFailure = error;
      return false;
    }
  }
}

/// Le chemin de la route, écrit **une fois**.
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester
/// vérifiable sans réseau : `flutter test` répond 400 à tout accès réel.
///
/// `plays` et non `progress` : les deux routes se ressemblent à une lettre
/// près, et se tromper donnerait une reprise de lecture écrite par la mesure
/// d'audience — exactement la confusion que toute cette tranche écarte.
@visibleForTesting
String playPath(String contentId) => '/teachings/$contentId/plays';
