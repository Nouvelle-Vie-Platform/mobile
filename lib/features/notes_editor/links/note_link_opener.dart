/// **Ouvrir un lien de note** (N5, #193) — le `onLinkTap` de
/// `RichNoteEditor`.
///
/// | Lien | Ouverture |
/// |---|---|
/// | `nv://note/<id>` | l'éditeur `/notes/:id` ; note inconnue → `SnackBar` |
/// | `nv://teaching/<id>` | le lecteur `/teaching/:id` (qui dit lui-même « retiré ») |
/// | `http(s)://…` | le navigateur du système (`externalLinkLauncherProvider`) |
/// | `nv://bible/…` | l'onglet Bible, `/bible?tab=bible` |
///
/// Tout autre lien (hors schéma, ou navigateur indisponible) → `SnackBar`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/note_view.dart';
import '../../../router/app_router.dart';
import '../../../state/menu_providers.dart';
import '../../../state/notes_providers.dart';
import 'note_link.dart';

abstract final class NoteLinkOpener {
  /// Ouvre [url]. Ne lève jamais ; ce qui ne peut pas s'ouvrir le dit par un
  /// `SnackBar` sur [context].
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    // Lus avant tout `await` : le contexte peut ne pas survivre. La route est
    // poussée par la `GoRouter` du conteneur, jamais par le `BuildContext`
    // (règle des gestes vers une route réservée, `guest_affordances_test`).
    final router = ref.read(routerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    void say(String message) =>
        messenger?.showSnackBar(SnackBar(content: Text(message)));

    switch (NoteLink.parse(url)) {
      case NoteRefLink(:final noteId):
        // Écouté le temps de la lecture : sous Riverpod 3, un provider sans
        // auditeur est en pause et son `.future` ne se résout jamais.
        final sub = ref.listenManual(noteProvider(noteId), (_, __) {});
        final NoteView? note;
        try {
          note = await ref.read(noteProvider(noteId).future);
        } finally {
          sub.close();
        }
        if (note == null) return say(l.noteLinkNoteMissing);
        unawaited(
          router.pushNamed(AppRoute.noteEditor, pathParameters: {'id': noteId}),
        );
      case TeachingLink(:final teachingId):
        unawaited(
          router.pushNamed(
            AppRoute.teachingDetail,
            pathParameters: {'id': teachingId},
          ),
        );
      case WebLink(:final url):
        final opened = await ref.read(externalLinkLauncherProvider).open(url);
        if (!opened) say(l.noteLinkCannotOpen);
      case BibleLink():
        unawaited(
          router.pushNamed(AppRoute.bible, queryParameters: {'tab': 'bible'}),
        );
      case null:
        say(l.noteLinkCannotOpen);
    }
  }
}
