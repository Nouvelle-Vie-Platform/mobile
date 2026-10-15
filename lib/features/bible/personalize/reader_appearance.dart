/// **Thèmes et polices du lecteur** (M4, mobile#202, décision 13) : Clair /
/// Sombre / Sépia, trois polices, taille, interligne — **le lecteur
/// seulement**, le reste de l'appli garde son apparence.
///
/// Le lecteur (M2) l'applique par une seule retouche : [BibleReaderAppearance]
/// autour des pages, et [BibleReaderAppearance.verseStyle] pour le texte d'un
/// verset. L'écran [BibleAppearanceScreen] règle et montre un aperçu en direct.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/brand_app_bar.dart';
import 'bible_prefs.dart';

/// La palette du lecteur pour [theme]. Le sépia est l'habillage d'un réglage,
/// pas une couleur de l'appli : il vit ici, et nulle part ailleurs.
AppPalette bibleReaderPalette(BibleReaderTheme theme) => switch (theme) {
      BibleReaderTheme.light => AppPalette.light,
      BibleReaderTheme.dark => AppPalette.dark,
      BibleReaderTheme.sepia => AppPalette.light.copyWith(
          background: const Color(0xFFF4ECD8),
          surface: const Color(0xFFFBF5E6),
          surfaceAlt: const Color(0xFFEDE2C8),
          textPrimary: const Color(0xFF4A3B2A),
          textSecondary: const Color(0xFF7A6650),
          primary: const Color(0xFF8B5E34),
          border: const Color(0xFFD9C9A8),
          divider: const Color(0xFFE3D5B8),
        ),
    };

/// Le nom de famille de [font]. « Système » nomme une famille absente des
/// actifs : Flutter retombe alors sur la police du système (Roboto, SF).
String bibleFontFamily(BibleReaderFont font) => switch (font) {
      BibleReaderFont.atkinson => AppTypography.fontFamily,
      BibleReaderFont.literata => 'Literata',
      BibleReaderFont.system => 'sans-serif',
    };

/// Le style d'un verset pour [prefs] sur [palette].
TextStyle bibleVerseTextStyle(BiblePrefs prefs, AppPalette palette) =>
    TextStyle(
      fontFamily: bibleFontFamily(prefs.font),
      fontSize: prefs.fontSize,
      height: prefs.lineHeight,
      fontWeight: FontWeight.w400,
      color: palette.textPrimary,
    );

/// **Habille le lecteur** : fond, palette (`context.palette` en dessous rend
/// celle du thème choisi) et réglages du texte des versets.
class BibleReaderAppearance extends ConsumerWidget {
  const BibleReaderAppearance({super.key, required this.child, this.prefs});

  final Widget child;

  /// Pour l'aperçu : des réglages qui ne sont pas (encore) enregistrés.
  final BiblePrefs? prefs;

  /// Le style d'un verset sous ce widget (le défaut s'il n'y en a pas).
  static TextStyle verseStyle(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_Scope>();
    return bibleVerseTextStyle(
      scope?.prefs ?? const BiblePrefs(),
      context.palette,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BiblePrefs saved = ref.watch(biblePrefsProvider);
    final p = prefs ?? saved;
    final palette = bibleReaderPalette(p.theme);
    final theme = Theme.of(context);
    return _Scope(
      prefs: p,
      child: Theme(
        data: theme.copyWith(
          extensions: [...theme.extensions.values, palette],
        ),
        child: ColoredBox(
          color: palette.background,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: palette.textPrimary),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Scope extends InheritedWidget {
  const _Scope({required this.prefs, required super.child});

  final BiblePrefs prefs;

  @override
  bool updateShouldNotify(_Scope old) => old.prefs != prefs;
}

/// **« Thèmes & polices »** : les réglages et un aperçu en direct.
class BibleAppearanceScreen extends ConsumerWidget {
  const BibleAppearanceScreen({super.key});

  static const Key previewKey = Key('bible_appearance_preview');
  static Key themeKey(BibleReaderTheme t) => Key('bible_theme_${t.name}');
  static Key fontKey(BibleReaderFont f) => Key('bible_font_${f.name}');
  static const Key sizeKey = Key('bible_font_size');
  static const Key lineHeightKey = Key('bible_line_height');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final prefs = ref.watch(biblePrefsProvider);
    final notifier = ref.read(biblePrefsProvider.notifier);
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleM4AppearanceTitle),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: BibleReaderAppearance(
              key: previewKey,
              prefs: prefs,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Builder(
                  builder: (context) => Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '16 ',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.palette.primary,
                          ),
                        ),
                        TextSpan(text: l.bibleM4AppearanceSample),
                      ],
                    ),
                    style: BibleReaderAppearance.verseStyle(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.bibleM4Theme, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in BibleReaderTheme.values)
                ChoiceChip(
                  key: themeKey(t),
                  label: Text(_themeLabel(context, t)),
                  selected: prefs.theme == t,
                  onSelected: (_) =>
                      notifier.update((p) => p.copyWith(theme: t)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.bibleM4Font, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final f in BibleReaderFont.values)
                ChoiceChip(
                  key: fontKey(f),
                  label: Text(
                    bibleFontLabel(context, f),
                    style: TextStyle(fontFamily: bibleFontFamily(f)),
                  ),
                  selected: prefs.font == f,
                  onSelected: (_) =>
                      notifier.update((p) => p.copyWith(font: f)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.bibleM4FontSize, style: AppTypography.h5),
          Slider(
            key: sizeKey,
            min: BiblePrefs.minFontSize,
            max: BiblePrefs.maxFontSize,
            divisions:
                (BiblePrefs.maxFontSize - BiblePrefs.minFontSize).round(),
            value: prefs.fontSize,
            label: prefs.fontSize.round().toString(),
            onChanged: (v) => notifier.update((p) => p.copyWith(fontSize: v)),
          ),
          Text(l.bibleM4LineHeight, style: AppTypography.h5),
          Slider(
            key: lineHeightKey,
            min: BiblePrefs.minLineHeight,
            max: BiblePrefs.maxLineHeight,
            divisions: 10,
            value: prefs.lineHeight,
            label: prefs.lineHeight.toStringAsFixed(1),
            onChanged: (v) => notifier.update((p) => p.copyWith(lineHeight: v)),
          ),
        ],
      ),
    );
  }
}

String _themeLabel(BuildContext context, BibleReaderTheme t) {
  final l = context.l10n;
  return switch (t) {
    BibleReaderTheme.light => l.bibleM4ThemeLight,
    BibleReaderTheme.dark => l.bibleM4ThemeDark,
    BibleReaderTheme.sepia => l.bibleM4ThemeSepia,
  };
}

/// Le nom affiché d'une police du lecteur.
String bibleFontLabel(BuildContext context, BibleReaderFont f) {
  final l = context.l10n;
  return switch (f) {
    BibleReaderFont.atkinson => 'Atkinson',
    BibleReaderFont.literata => 'Literata',
    BibleReaderFont.system => l.bibleM4FontSystem,
  };
}
