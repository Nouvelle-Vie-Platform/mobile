import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_client.dart';

void main() {
  // Garde-fou de configuration : en release, une URL de backend en HTTP clair
  // fait échouer le démarrage plutôt que d'exposer le token Bearer en clair.
  // Volontairement avant `runApp` : mieux vaut un crash immédiat et lisible
  // qu'une app qui tourne en fuyant les identifiants.
  ApiClient.ensureSecureBaseUrl();

  runApp(const ProviderScope(child: MaisonDuMiracleApp()));
}
