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

/// **Les mots choisis, découpés du texte** (#257) : avant, en exergue, après.
///
/// [charFrom] comprise, [charTo] **exclue**. Bornes nulles, vides ou hors du
/// texte — une traduction a changé sous les décalages — : tout revient en
/// « avant » et rien n'est mis en exergue, le verset reste lisible.
/// ⚠️ `charFrom == 0` est légitime, c'est le premier caractère du verset :
/// comparer à `null`, **jamais** à la vérité d'un entier.
(String before, String chosen, String after) bibleEmphasis(
  String text,
  int? charFrom,
  int? charTo,
) {
  if (charFrom == null || charTo == null) return (text, '', '');
  final from = charFrom.clamp(0, text.length);
  final to = charTo.clamp(from, text.length);
  if (from == to) return (text, '', '');
  return (
    text.substring(0, from),
    text.substring(from, to),
    text.substring(to),
  );
}

/// « texte » — Jean 3:16 (EXA) : ce que Copier et Partager emportent.
///
/// Le verset **entier** — tronquer la citation la rendrait illisible, et la
/// référence annonce un verset — mais les mots choisis (#257) encadrés
/// d'astérisques : le verset est déjà entre guillemets français, l'astérisque
/// n'y collisionne avec rien et survit à tout presse-papiers.
Future<String> bibleQuotation(
  WidgetRef ref,
  BibleLink link,
  String version, {
  int? charFrom,
  int? charTo,
}) async {
  // Les deux lectures de `ref` se font **avant** le premier `await` : après
  // lui, l'écran qui porte ce `ref` peut avoir disparu.
  final catalog = ref.read(bibleCatalogProvider);
  final langue = ref.read(bibleBookLanguageProvider);
  final text = await bibleVerseText(catalog, link, version);
  final (before, chosen, after) = bibleEmphasis(text, charFrom, charTo);
  final quoted = chosen.isEmpty ? before : '$before*$chosen*$after';
  return '« $quoted »\n— ${link.labelIn(langue)} ($version)';
}

Future<void> copyVerses(
  BuildContext context,
  WidgetRef ref,
  BibleLink link,
  String version, {
  int? charFrom,
  int? charTo,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = context.l10n.bibleM2Copied;
  await Clipboard.setData(
    ClipboardData(
      text: await bibleQuotation(
        ref,
        link,
        version,
        charFrom: charFrom,
        charTo: charTo,
      ),
    ),
  );
  messenger?.showSnackBar(SnackBar(content: Text(copied)));
}

Future<void> shareVerses(
  BuildContext context,
  WidgetRef ref,
  BibleLink link,
  String version, {
  int? charFrom,
  int? charTo,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  await SharePlus.instance.share(
    ShareParams(
      text: await bibleQuotation(
        ref,
        link,
        version,
        charFrom: charFrom,
        charTo: charTo,
      ),
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
///
/// Les mots choisis (#257) y sont en exergue **pour de vrai** : l'`insert` du
/// texte se coupe en trois, celui du milieu en `bold`. ⚠️ Le serveur valide
/// le Delta contre une liste close (`upsert_spiritual_note_controller`) :
/// `bold` y est, et **aucun autre attribut** ne doit s'inviter ici, sous
/// peine de 422 `E_NOTE_CONTENT_INVALID`. Un `insert` vide n'est pas un
/// Delta valide non plus : les morceaux vides sont omis, et c'est ce qui
/// arrive quand les mots choisis commencent le verset (`charFrom == 0`).
String bibleNoteContent(
  BibleLink link,
  String text, {
  int? charFrom,
  int? charTo,
  // La note garde la référence **telle qu'elle était affichée** au moment où
  // le fidèle l'a insérée. C'est du texte qu'il écrit, pas un libellé que
  // l'application recalcule : il ne doit pas changer de langue tout seul le
  // jour où une autre version devient active.
  String language = 'fr',
}) {
  final (before, chosen, after) = bibleEmphasis(text, charFrom, charTo);
  return jsonEncode({
    'ops': [
      {
        'insert': link.labelIn(language),
        'attributes': {'link': link.toUrl()},
      },
      {'insert': '\n'},
      if (chosen.isEmpty)
        {'insert': text}
      else ...[
        if (before.isNotEmpty) {'insert': before},
        {
          'insert': chosen,
          'attributes': {'bold': true},
        },
        if (after.isNotEmpty) {'insert': after},
      ],
      {
        'insert': '\n',
        'attributes': {'blockquote': true},
      },
      {'insert': '\n'},
    ],
  });
}

/// **Note sur un verset** — réservée aux membres. Rouvre la note qui commence
/// déjà par ce lien, sinon en crée une : lien `nv://bible/...` en tête, texte
/// cité en citation.
void noteOnVerses(
  BuildContext context,
  WidgetRef ref,
  BibleLink link,
  String version, {
  int? charFrom,
  int? charTo,
}) {
  // Lus maintenant : le geste peut être rejoué après la connexion.
  final router = ref.read(routerProvider);
  final dao = ref.read(notesDaoProvider);
  final repository = ref.read(notesRepositoryProvider);
  final catalog = ref.read(bibleCatalogProvider);
  // **Lue ici aussi, et c'est la raison de tout le bloc** : après la connexion,
  // ce `ref` appartient à une feuille déjà démontée, et le lire là rendait la
  // note impossible à créer — le lecteur restait à l'écran, sans rien dire.
  final langue = ref.read(bibleBookLanguageProvider);
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
                charFrom: charFrom,
                charTo: charTo,
                language: langue,
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
