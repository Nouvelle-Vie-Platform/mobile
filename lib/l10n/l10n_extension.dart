import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'app_localizations.dart';

/// Accès concis aux traductions : `context.l10n.maCle`.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
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
