/// **Les écrans de M4**, sous une seule route du routeur :
/// `/bible/personalize/:page` (`appearance`, `offline`, `my-space`,
/// `settings`, `studio?ref=John/3/16-18&v=EXA`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../data/canon.dart';
import 'bible_settings_screen.dart';
import 'bible_versions_screen.dart';
import 'my_space_screen.dart';
import 'reader_appearance.dart';
import 'share_studio.dart';

enum BiblePersonalizePage {
  appearance('appearance'),
  offline('offline'),
  mySpace('my-space'),
  settings('settings'),
  studio('studio');

  const BiblePersonalizePage(this.path);
  final String path;
}

/// Ouvre une page de M4, par le routeur (jamais le `BuildContext`).
void openBiblePersonalize(
  WidgetRef ref,
  BiblePersonalizePage page, {
  Map<String, String> query = const {},
}) {
  ref.read(routerProvider).pushNamed(
        AppRoute.biblePersonalize,
        pathParameters: {'page': page.path},
        queryParameters: query,
      );
}

/// Ouvre le studio sur [link] dans [versionCode].
void openBibleStudio(WidgetRef ref, BibleLink link, String versionCode) =>
    openBiblePersonalize(
      ref,
      BiblePersonalizePage.studio,
      query: {
        'ref': link.toUrl().substring('nv://bible/'.length),
        'v': versionCode,
      },
    );

/// L'écran de la route ; une page inconnue rend les Paramètres.
Widget biblePersonalizeScreen(GoRouterState state) {
  final page = BiblePersonalizePage.values
      .where((p) => p.path == state.pathParameters['page'])
      .firstOrNull;
  switch (page) {
    case BiblePersonalizePage.appearance:
      return const BibleAppearanceScreen();
    case BiblePersonalizePage.offline:
      return const BibleVersionsScreen();
    case BiblePersonalizePage.mySpace:
      return const BibleMySpaceScreen();
    case BiblePersonalizePage.studio:
      final link = _parseRef(state.uri.queryParameters['ref']);
      final version = state.uri.queryParameters['v'];
      if (link != null && version != null) {
        return BibleShareStudioScreen(link: link, versionCode: version);
      }
      return const BibleSettingsScreen();
    case BiblePersonalizePage.settings:
    case null:
      return const BibleSettingsScreen();
  }
}

/// `John/3/16-18` → Jean 3:16-18 ; `null` hors du canon.
BibleLink? _parseRef(String? raw) {
  final m = RegExp(r'^([0-9A-Za-z]+)/(\d{1,3})(?:/(\d{1,3})(?:-(\d{1,3}))?)?$')
      .firstMatch(raw ?? '');
  if (m == null) return null;
  final from = m.group(3) == null ? null : int.parse(m.group(3)!);
  final to = m.group(4) == null ? null : int.parse(m.group(4)!);
  final link = BibleLink(
    m.group(1)!,
    int.parse(m.group(2)!),
    from: from,
    to: from == null ? null : to,
  );
  return isValidBibleRef(link) ? link : null;
}
