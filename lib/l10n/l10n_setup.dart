import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations.dart';

/// L'éwé (`ee`) n'est pas couvert par les localisations Material/Cupertino du
/// framework Flutter. Sans repli, les widgets système (TextField, sélecteurs
/// de date, boutons natifs…) lèvent une erreur sous cette locale.
///
/// Ces délégués interceptent `ee` et réutilisent les chaînes système
/// **françaises** du framework, en attendant un éventuel support natif.
class _FrenchFallbackMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FrenchFallbackMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ee';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('fr'));

  @override
  bool shouldReload(_FrenchFallbackMaterialDelegate old) => false;
}

class _FrenchFallbackCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FrenchFallbackCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ee';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('fr'));

  @override
  bool shouldReload(_FrenchFallbackCupertinoDelegate old) => false;
}

/// Délégués de localisation de l'application.
///
/// Les délégués de repli éwé sont placés **avant** les délégués globaux afin
/// d'être prioritaires pour la locale `ee`.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  _FrenchFallbackMaterialDelegate(),
  _FrenchFallbackCupertinoDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Locales prises en charge par l'application.
const List<Locale> appSupportedLocales = AppLocalizations.supportedLocales;
