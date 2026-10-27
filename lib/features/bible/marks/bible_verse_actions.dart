/// **Les gestes de la pilule d'un verset** (M2, #200) : note, signet, partage,
/// copie, favori — et le surlignage, que la pilule offre par sa palette.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/local/notes_dao.dart';
import '../../../data/repositories/note_draft_saver.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../state/notes_providers.dart';
import '../../../state/session_gate.dart';
import '../../notes_editor/note_content.dart';
import '../data/bible_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import 'bible_marks_store.dart';

/// Le texte de [link] dans [version], versets joints par une espace.
Future<String> bibleVerseText(
  BibleCatalog catalog,
  BibleLink link,
  String version,
) async {
  final source = catalog.sourceFor(version);
  if (source == null) return '';
  final verses = await source.chapter(link.book, link.chapter);
  final from = link.from ?? 1;
  final to = link.to ?? link.from ?? verses.length;
  return [
    for (final v in verses)
      if (v.number >= from && v.number <= to) v.text,
  ].join(' ');
}

/// « texte » — Jean 3:16 (EXA) : ce que Copier et Partager emportent.
Future<String> bibleQuotation(
  WidgetRef ref,
  BibleLink link,
  String version,
) async =>
    '« ${await bibleVerseText(ref.read(bibleCatalogProvider), link, version)} »\n'
    '— ${link.labelFr} ($version)';

Future<void> copyVerses(
  BuildContext context,
  WidgetRef ref,
  BibleLink link,
  String version,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = context.l10n.bibleM2Copied;
  await Clipboard.setData(
    ClipboardData(text: await bibleQuotation(ref, link, version)),
  );
  messenger?.showSnackBar(SnackBar(content: Text(copied)));
}

Future<void> shareVerses(
  BuildContext context,
  WidgetRef ref,
  BibleLink link,
  String version,
) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  await SharePlus.instance.share(
    ShareParams(
      text: await bibleQuotation(ref, link, version),
      sharePositionOrigin: origin,
    ),
  );
}

/// **Le signet du chapitre** où se trouve [link] — le même que celui de
/// l'en-tête du lecteur : notre marque-page est chapitré (décision 13), la
/// pilule ne lui invente pas une portée au verset.
void toggleChapterBookmark(WidgetRef ref, BibleLink link) => unawaited(
      ref.read(bibleMarksStoreProvider).toggleBookmark(
            member: ref.read(bibleIsMemberProvider),
            book: link.book,
            chapter: link.chapter,
          ),
    );

void toggleFavorite(WidgetRef ref, BibleLink link) => unawaited(
      ref
          .read(bibleMarksStoreProvider)
          .toggleFavorite(member: ref.read(bibleIsMemberProvider), link: link),
    );

/// Surligne la sélection. **Au mot** (#252) : [charFrom] comprise, [charTo]
/// exclue, et [versionCode] obligatoire — sans quoi le serveur refuse (422
/// `E_BIBLE_PAYLOAD_INVALID`). Sans bornes, la marque reste au verset et
/// suit toutes les traductions, comme avant.
void highlightVerses(
  WidgetRef ref,
  BibleLink link,
  String? color, {
  String? versionCode,
  int? charFrom,
  int? charTo,
}) =>
    unawaited(
      ref.read(bibleMarksStoreProvider).highlight(
            member: ref.read(bibleIsMemberProvider),
            link: link,
            color: color,
            versionCode: versionCode,
            charFrom: charFrom,
            charTo: charTo,
          ),
    );

/// Le contenu d'une note sur [link] : le lien, puis le texte cité.
String bibleNoteContent(BibleLink link, String text) => jsonEncode({
      'ops': [
        {
          'insert': link.labelFr,
          'attributes': {'link': link.toUrl()},
        },
        {'insert': '\n'},
        {'insert': text},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
        {'insert': '\n'},
      ],
    });

/// **Note sur un verset** — réservée aux membres. Rouvre la note qui commence
/// déjà par ce lien, sinon en crée une : lien `nv://bible/...` en tête, texte
/// cité en citation.
void noteOnVerses(
  BuildContext context,
  WidgetRef ref,
  BibleLink link,
  String version,
) {
  // Lus maintenant : le geste peut être rejoué après la connexion.
  final router = ref.read(routerProvider);
  final dao = ref.read(notesDaoProvider);
  final repository = ref.read(notesRepositoryProvider);
  final catalog = ref.read(bibleCatalogProvider);
  ref.requireSession(
    action: () {
      unawaited(() async {
        final id = await _noteFor(dao, link) ??
            await _createNote(
              dao,
              repository,
              bibleNoteContent(
                link,
                await bibleVerseText(catalog, link, version),
              ),
            );
        await router.pushNamed(AppRoute.noteEditor, pathParameters: {'id': id});
      }());
    },
  );
}

Future<String?> _noteFor(NotesDao dao, BibleLink link) async {
  final needle = '"link":"${link.toUrl()}"';
  final notes = await dao.watchNotes().first;
  for (final n in notes) {
    if (n.content?.contains(needle) ?? false) return n.id;
  }
  return null;
}

Future<String> _createNote(
  NotesDao dao,
  NotesRepository repository,
  String content,
) async {
  final id = mintNoteId();
  final saver = NoteDraftSaver(dao: dao, repository: repository);
  await saver.update(
    NoteDraft(
      id: id,
      content: content,
      body: deltaToPlainText(content),
      clientCreatedAt: DateTime.now().toUtc(),
    ),
  );
  // L'éditeur prend le relais de l'envoi ; à défaut, le cycle suivant.
  saver.cancel();
  return id;
}
