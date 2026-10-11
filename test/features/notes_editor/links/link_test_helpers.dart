import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/note_view.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

NoteView fakeNote(String id, {String? title, String body = ''}) => NoteView(
      id: id,
      title: title,
      body: body,
      content: null,
      categoryId: null,
      pinned: false,
      teachingId: null,
      updatedAt: null,
      isLocal: false,
    );

TeachingView fakeTeaching(String id, String title) =>
    TeachingView(id: id, title: title, color: 0xFF336699);

/// Un routeur réduit aux trois routes qu'un lien ouvre, chacune peinte par
/// son adresse ; [home] est la page de départ.
GoRouter linkTestRouter(Widget home) => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => Scaffold(body: home)),
        GoRoute(
          name: AppRoute.noteEditor,
          path: '/notes/:id',
          builder: (_, s) => Text('note ${s.pathParameters['id']}'),
        ),
        GoRoute(
          name: AppRoute.teachingDetail,
          path: '/teaching/:id',
          builder: (_, s) => Text('teaching ${s.pathParameters['id']}'),
        ),
        GoRoute(
          name: AppRoute.bible,
          path: '/bible',
          builder: (_, s) => Text('bible ${s.uri.queryParameters['tab']}'),
        ),
      ],
    );

Widget linkTestApp(GoRouter router, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        routerConfig: router,
      ),
    );
