/// **Les emplacements de la tranche M4 — thèmes, audio, partage, versions, Mon espace, Paramètres.**
///
/// Créé vide par M1 (#199). Cette tranche n'édite **que** ce fichier pour se
/// brancher sur la coquille et le lecteur ; voir `../README.md`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../shell/bible_slots.dart';
import 'bible_audio.dart';
import 'personalize_routes.dart';

final BibleSlots personalizeSlots = BibleSlots(
  moreEntries: [
    BibleMoreEntry(
      id: 'my_space',
      order: 40,
      // « Mes badges » (#265) : l'onglet s'appelle désormais Mon espace.
      icon: Icons.military_tech_outlined,
      label: (context) => context.l10n.bibleMyBadges,
      onTap: (_, ref) =>
          openBiblePersonalize(ref, BiblePersonalizePage.mySpace),
    ),
    BibleMoreEntry(
      id: 'offline',
      order: 50,
      icon: Icons.download_for_offline_outlined,
      label: (context) => context.l10n.bibleM4VersionsTitle,
      onTap: (_, ref) =>
          openBiblePersonalize(ref, BiblePersonalizePage.offline),
    ),
    BibleMoreEntry(
      id: 'appearance',
      order: 60,
      icon: Icons.text_fields,
      label: (context) => context.l10n.bibleM4AppearanceTitle,
      onTap: (_, ref) =>
          openBiblePersonalize(ref, BiblePersonalizePage.appearance),
    ),
    BibleMoreEntry(
      id: 'settings',
      order: 90,
      icon: Icons.settings_outlined,
      label: (context) => context.l10n.bibleM4SettingsTitle,
      onTap: (_, ref) =>
          openBiblePersonalize(ref, BiblePersonalizePage.settings),
    ),
  ],
  homeShortcuts: [
    BibleHomeShortcut(
      id: 'offline',
      order: 40,
      icon: Icons.download_for_offline_outlined,
      label: (context) => context.l10n.bibleM4OfflineShortcut,
      onTap: (_, ref) =>
          openBiblePersonalize(ref, BiblePersonalizePage.offline),
    ),
  ],
  verseActions: [
    BibleVerseAction(
      id: 'share_image',
      order: 60,
      icon: Icons.image_outlined,
      label: (context) => context.l10n.bibleM4ShareAsImage,
      // Les mots choisis (#257) ne descendent pas jusqu'à l'image : déclarés
      // pour rester assignable, ignorés.
      run: (_, ref, selection, version, {charFrom, charTo}) =>
          openBibleStudio(ref, selection, version),
    ),
    BibleVerseAction(
      id: 'listen',
      order: 70,
      icon: Icons.headphones_outlined,
      label: (context) => context.l10n.bibleM4ListenFromHere,
      run: (context, ref, selection, version, {charFrom, charTo}) =>
          listenFromHere(context, ref, selection, version),
    ),
  ],
  chapterDecorators: [bibleAudioDecorator],
);
