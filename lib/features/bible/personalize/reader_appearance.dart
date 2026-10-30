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

/// **La police des écritures que les autres ne savent pas écrire.**
///
/// Aucune des trois polices de l'application ne porte `ɔ ɖ ɛ ƒ ɣ ŋ ʋ` — mesuré
/// le 30/10/2026. Sur un téléphone le système comble ; **dans un navigateur
/// non**, et le fidèle lisait des carrés vides au milieu de l'Écriture.
/// `assets/fonts/Andika/COMMENT-ELLE-EST-FAITE.md` dit pourquoi celle-ci.
const String kScriptFontFamily = 'Andika';

/// Les langues dont aucune autre police embarquée ne porte les lettres.
///
/// Une liste, pas un `== 'ee'` : le jour où une version ga, kabiyè ou fon
/// paraîtra, c'est **ici** qu'on l'ajoutera, et nulle part ailleurs.
const Set<String> kScriptFontLanguages = {'ee'};

bool needsScriptFont(String language) =>
    kScriptFontLanguages.contains(language);

/// La famille d'un texte **venu d'une Bible** écrite en [language].
///
/// À préférer au fournisseur quand l'écran tient déjà la version dont il
/// montre le texte — la comparaison de versions en montre plusieurs à la fois,
/// et la version active ne dit rien de celles-là.
String bibleTextFontFamily(String language) =>
    needsScriptFont(language) ? kScriptFontFamily : AppTypography.fontFamily;

/// Le nom de famille de [font]. « Système » nomme une famille absente des
/// actifs : Flutter retombe alors sur la police du système (Roboto, SF).
///
/// [language] l'emporte quand ses lettres manquent partout ailleurs : le
/// réglage de police du fidèle ne peut pas rendre lisible ce qu'aucune de ces
/// polices ne sait dessiner.
String bibleFontFamily(BibleReaderFont font, {String language = 'fr'}) =>
    needsScriptFont(language)
        ? kScriptFontFamily
        : switch (font) {
            BibleReaderFont.atkinson => AppTypography.fontFamily,
            BibleReaderFont.literata => 'Literata',
            BibleReaderFont.system => 'sans-serif',
          };

/// **Le rouge brique du lecteur** (#250) : numéros de versets et lettrine. Il
/// suit le sort du sépia — c'est l'encre d'un réglage de lecture, pas une
/// couleur de l'appli, et il n'a donc rien à faire dans [AppPalette]. Sur fond
/// sombre la brique vire à la terre cuite, sans quoi elle disparaissait.
Color bibleRubricColor(BibleReaderTheme theme) => switch (theme) {
      BibleReaderTheme.light => const Color(0xFFAE3B23),
      BibleReaderTheme.sepia => const Color(0xFF9C3A1E),
      BibleReaderTheme.dark => const Color(0xFFE07A5F),
    };

/// Le style d'un verset pour [prefs] sur [palette].
TextStyle bibleVerseTextStyle(
  BiblePrefs prefs,
  AppPalette palette, {
  String language = 'fr',
}) =>
    TextStyle(
      fontFamily: bibleFontFamily(prefs.font, language: language),
      fontSize: prefs.fontSize,
      height: prefs.lineHeight,
      fontWeight: FontWeight.w400,
      color: palette.textPrimary,
    );

/// **Habille le lecteur** : fond, palette (`context.palette` en dessous rend
/// celle du thème choisi) et réglages du texte des versets.
class BibleReaderAppearance extends ConsumerWidget {
  const BibleReaderAppearance({
    super.key,
    required this.child,
    this.prefs,
    this.language = 'fr',
  });

  final Widget child;

  /// Pour l'aperçu : des réglages qui ne sont pas (encore) enregistrés.
  final BiblePrefs? prefs;

  /// La langue de la version lue, **donnée par l'appelant**.
  ///
  /// Et pas lue ici d'un fournisseur : l'aperçu de « Thèmes & polices » et le
  /// studio de partage posent des bouts de lecteur **hors du lecteur**, où
  /// aucune version n'est ouverte. Demander la version active y réveillait la
  /// position de lecture, donc un flux Drift, et deux tests mouraient sur un
  /// minuteur resté en vie.
  final String language;

  /// Les réglages sous ce widget (le défaut s'il n'y en a pas : l'aperçu des
  /// réglages et les tests posent des bouts de lecteur hors du lecteur).
  static BiblePrefs prefsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Scope>()?.prefs ??
      const BiblePrefs();

  /// La langue de la version lue sous ce widget. Le français hors du lecteur :
  /// l'aperçu des réglages ne lit aucune version.
  static String languageOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Scope>()?.language ?? 'fr';

  /// Le style d'un verset sous ce widget (le défaut s'il n'y en a pas).
  ///
  /// **La langue passe par ici et non par les appelants** : le lecteur la
  /// connaît déjà, et un verset dont la police dépendrait du soin de chaque
  /// widget finirait en carrés vides sur celui qu'on aurait oublié.
  static TextStyle verseStyle(BuildContext context) => bibleVerseTextStyle(
        prefsOf(context),
        context.palette,
        language: languageOf(context),
      );

  /// Le rouge brique sous ce widget : numéros de versets, lettrine.
  static Color rubric(BuildContext context) =>
      bibleRubricColor(prefsOf(context).theme);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BiblePrefs saved = ref.watch(biblePrefsProvider);
    final p = prefs ?? saved;
    final palette = bibleReaderPalette(p.theme);
    final theme = Theme.of(context);
    return _Scope(
      prefs: p,
      language: language,
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
  const _Scope({
    required this.prefs,
    required this.language,
    required super.child,
  });

  final BiblePrefs prefs;
  final String language;

  @override
  bool updateShouldNotify(_Scope old) =>
      old.prefs != prefs || old.language != language;
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BibleReaderAppearance.rubric(context),
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
