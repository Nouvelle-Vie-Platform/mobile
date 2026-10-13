/// **Les gardes d'architecture du module Bible** (#199) : les emplacements
/// d'une tranche ne vivent que dans son fichier, le module ne lit aucun
/// lecteur média, et la fusion des emplacements est ordonnée et stable.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_slots.dart';

const _tranches = {
  'marks': 'marksSlots',
  'search': 'searchSlots',
  'personalize': 'personalizeSlots',
  'plans': 'plansSlots',
  'quiz': 'quizSlots',
  'home': 'homeSlots',
};

BibleMoreEntry _entry(String id, int order) => BibleMoreEntry(
      id: id,
      order: order,
      icon: Icons.circle,
      label: (_) => id,
      onTap: (_, __) {},
    );

void main() {
  test('chaque tranche a son fichier d\'emplacements, et il est fusionné', () {
    final hub =
        File('lib/features/bible/shell/bible_slots.dart').readAsStringSync();
    _tranches.forEach((dir, symbol) {
      final file = File('lib/features/bible/$dir/${dir}_slots.dart');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.readAsStringSync(), contains('BibleSlots $symbol'));
      expect(hub, contains("import '../$dir/${dir}_slots.dart';"));
      expect(hub, contains('    $symbol,'));
    });
  });

  test('le module n\'importe aucun lecteur média', () {
    final offenders = [
      for (final f in Directory('lib/features/bible').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(r"package:(just_audio|video_player|audio_service)/")
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('le module ne navigue jamais par le BuildContext', () {
    final offenders = [
      for (final f in Directory('lib/features/bible').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(r'context\.(push|go|pushNamed|goNamed)\(')
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('la fusion trie par ordre, et départage par le rang des tranches', () {
    final merged = BibleSlots.merge([
      BibleSlots(moreEntries: [_entry('b', 20), _entry('a1', 10)]),
      BibleSlots(moreEntries: [_entry('a2', 10), _entry('c', 0)]),
    ]);
    expect(merged.moreEntries.map((e) => e.id), ['c', 'a1', 'a2', 'b']);
    expect(const BibleSlots().homeSections, isEmpty);
  });
}
