import 'app_platform.dart';

/// La plateforme, vue du navigateur.
///
/// **Pas de version de système, et exprès.** Ce que le web pourrait dire de
/// lui-même est la chaîne d'agent utilisateur, qui ne nomme pas le système mais
/// le navigateur, qui ment par compatibilité depuis trente ans, et dont la
/// lecture est précisément une empreinte d'appareil — ce que cette tranche
/// s'interdit. `web` tout court est exact et suffit à ce que le serveur en fait.
AppPlatformInfo describePlatform() => const AppPlatformInfo(name: 'web');
