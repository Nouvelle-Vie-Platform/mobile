import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/note_colors.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';

/// La palette fermée : ce que le serveur accepte, et rien d'autre.
void main() {
  final hex = RegExp(r'^#[0-9a-f]{6}$');

  test('huit couleurs de texte distinctes, en hexadécimal minuscule', () {
    expect(noteTextColors, hasLength(8));
    expect(noteTextColors.toSet(), hasLength(8));
    for (final c in noteTextColors) {
      expect(c, matches(hex), reason: '$c doit s\'écrire #rrggbb');
    }
  });

  test('le surlignage est le jaune d\'accent de la marque', () {
    expect(noteHighlight, matches(hex));
    final accent = AppColors.accent.toARGB32() & 0xFFFFFF;
    expect(int.parse(noteHighlight.substring(1), radix: 16), accent);
  });

  test('isNoteTextColor ne reconnaît que la palette, quelle que soit la casse',
      () {
    expect(isNoteTextColor('#223B8C'), isTrue);
    expect(isNoteTextColor('#223b8c'), isTrue);
    expect(isNoteTextColor('#000000'), isFalse);
    expect(isNoteTextColor('#ffffff'), isFalse);
    expect(isNoteTextColor(null), isFalse);
    expect(isNoteTextColor('red'), isFalse);
  });

  test('isNoteHighlight n\'accepte qu\'une valeur', () {
    expect(isNoteHighlight('#F8D05E'), isTrue);
    expect(isNoteHighlight('#ffff00'), isFalse);
    expect(isNoteHighlight(null), isFalse);
  });
}
