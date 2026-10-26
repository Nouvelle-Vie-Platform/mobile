import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'app_localizations.dart';
import 'vocabulary.dart';

/// Accès concis aux traductions : `context.l10n.maCle`.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// **Les mêmes mots, surcharge du portail comprise** : `context.words.maCle`
  /// (#81).
  ///
  /// Le réglage fait au portail l'emporte sur le `.arb` compilé — c'est tout
  /// l'intérêt du réglage, sans quoi il ne sert à rien. Mais le `.arb` reste
  /// l'état de départ légitime, et la vérité de toute clé que le portail ne
  /// surcharge pas.
  ///
  /// Il est **à côté** de [l10n] et non à sa place : le catalogue des clés
  /// surchargeables est curé (une poignée de mots métier), et ouvrir les
  /// centaines de clés du dictionnaire ferait de l'écran de réglages un métier.
  /// Choisir entre les deux accesseurs, c'est nommer une clé — pas décider
  /// d'une précédence : celle-là est écrite une seule fois, dans [AppWords].
  AppWords get words => AppWords(
        AppLocalizations.of(this),
        VocabularyScope.of(this),
        Localizations.localeOf(this).languageCode,
      );
}

/// **La locale à donner à `intl`, qui n'est pas celle de l'application.**
///
/// `package:intl` ne connaît pas l'éwé : `DateFormat.Hm('ee')` lève
/// `Invalid argument(s): Invalid locale "ee"`, et l'écran affiche un bloc
/// rouge à la place de sa date. Mesuré le 26/10/2026 sur l'émulateur, locale
/// forcée à `ee` : l'accueil perdait sa section « À venir » entière.
///
/// Ce n'est **pas** un cas d'école. `Locale('ee')` est dans
/// `AppLocalizations.supportedLocales`, donc le sélecteur de langue par
/// application d'Android 13+ propose l'éwé, et le choisir suffit.
///
/// La décision est celle **déjà prise** pour les widgets du framework
/// (`l10n_setup.dart`, qui charge les chaînes Material françaises sous `ee`) :
/// à défaut de données éwé, on formate les dates à la française. Une date au
/// format français reste lisible ; un bloc rouge ne l'est pas.
///
/// ⚠️ Tout appel à `DateFormat` doit passer par ici et **jamais** par
/// `localeName`. Un test de source le vérifie
/// (`test/l10n/intl_locale_test.dart`) — sans quoi la règle se perdrait au
/// premier écran ajouté.
extension IntlLocale on AppLocalizations {
  String get intlLocale => localeName == 'ee' ? 'fr' : localeName;
}

/// Rendu localisé des clés de donnée du domaine.
///
/// Les enums de `models.dart` portent des **clés** (`brother`, `sister`), pas
/// des libellés : la traduction se fait ici, jamais dans le modèle.
extension DomainLabels on AppLocalizations {
  /// Libellé de civilité, `null` si [title] est `null` (profil non complété).
  String? userTitleLabel(UserTitle? title) => switch (title) {
        UserTitle.brother => titleBrother,
        UserTitle.sister => titleSister,
        null => null,
      };
}
