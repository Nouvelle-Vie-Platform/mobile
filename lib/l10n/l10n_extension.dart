import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Accès concis aux traductions : `context.l10n.maCle`.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
