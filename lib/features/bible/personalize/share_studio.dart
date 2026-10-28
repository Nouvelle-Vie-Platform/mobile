/// **Le studio de partage** (M4, mobile#202, décision 12) : un verset mis en
/// image — fond (fonds des annonces `status_backgrounds`, dégradés de la
/// marque, photo de la galerie), police, couleur et taille du texte,
/// référence — rendu sur l'appareil (`RepaintBoundary`), puis partagé
/// (`share_plus`) ou enregistré dans la galerie (`gal`).
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/announcement_view.dart';
import '../../../state/announcement_providers.dart';
import '../../../state/sync_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import 'bible_prefs.dart';
import 'reader_appearance.dart';

/// Où part l'image : la feuille de partage, la galerie. Surchargé en test.
class BibleImageSink {
  const BibleImageSink();

  Future<void> share(BuildContext context, Uint8List png, String name) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, name: name, mimeType: 'image/png')],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
  }

  /// `false` : refusé ou impossible (web, permission).
  Future<bool> save(Uint8List png) async {
    if (kIsWeb) return false;
    try {
      await Gal.putImageBytes(png, name: 'verset');
      return true;
    } on Object {
      return false;
    }
  }
}

final bibleImageSinkProvider = Provider<BibleImageSink>(
  (ref) => const BibleImageSink(),
);

/// Les fonds actifs des annonces, dans l'ordre du portail.
final bibleStudioBackdropsProvider = StreamProvider<List<StatusBackdrop>>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    return db.announcementDao.composableBackgrounds().watch().map(
          (rows) => [
            for (final r in rows)
              if (StatusBackdrop.read(
                baseColor: r.baseColor,
                topColor: r.topColor,
                bottomColor: r.bottomColor,
                ink: r.ink,
              )
                  case final b?)
                b,
          ],
        );
  },
);

/// Les dégradés de la marque, toujours offerts.
const List<LinearGradient> kBrandGradients = [
  AppColors.gradientPrimary,
  AppColors.gradientHomeHeader,
  AppColors.gradientSecondary,
];

/// Les couleurs de texte proposées.
const List<Color> kStudioInks = [
  Colors.white,
  Color(0xFF1A1A1A),
  Color(0xFFF8D05E),
];

/// Rend [boundary] en PNG.
Future<Uint8List> renderStudioPng(
  RenderRepaintBoundary boundary, {
  double pixelRatio = 3,
}) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class BibleShareStudioScreen extends ConsumerStatefulWidget {
  const BibleShareStudioScreen({
    super.key,
    required this.link,
    required this.versionCode,
  });

  final BibleLink link;
  final String versionCode;

  static const Key canvasKey = Key('bible_studio_canvas');
  static const Key shareKey = Key('bible_studio_share');
  static const Key saveKey = Key('bible_studio_save');
  static const Key photoKey = Key('bible_studio_photo');
  static const Key referenceKey = Key('bible_studio_reference');
  static const Key sizeKey = Key('bible_studio_size');

  @override
  ConsumerState<BibleShareStudioScreen> createState() => _StudioState();
}

class _StudioState extends ConsumerState<BibleShareStudioScreen> {
  final _canvas = GlobalKey();

  /// Un seul fond à la fois : dégradé, ou photo.
  Gradient _gradient = kBrandGradients.first;
  Uint8List? _photo;
  BibleReaderFont _font = BibleReaderFont.literata;
  Color _ink = kStudioInks.first;
  double _size = 24;
  bool _showReference = true;
  bool _busy = false;

  Future<String> _text() async {
    final link = widget.link;
    final source = ref.read(bibleCatalogProvider).sourceFor(widget.versionCode);
    final verses = source == null
        ? const []
        : await source.chapter(link.book, link.chapter);
    final from = link.from ?? 1;
    final to = link.to ?? from;
    return [
      for (final v in verses)
        if (v.number >= from && v.number <= to) v.text,
    ].join(' ');
  }

  late final Future<String> _verse = _text();

  Future<Uint8List?> _render() async {
    final boundary =
        _canvas.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return renderStudioPng(boundary);
  }

  Future<void> _export(bool save) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final png = await _render();
      if (png == null || !mounted) return;
      final sink = ref.read(bibleImageSinkProvider);
      if (save) {
        final ok = await sink.save(png);
        messenger.showSnackBar(
          SnackBar(
              content:
                  Text(ok ? l.bibleM4StudioSaved : l.bibleM4StudioSaveFailed)),
        );
      } else {
        await sink.share(context, png, 'verset.png');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ref.read(statusImagePickerProvider).pick();
    if (picked != null && mounted) setState(() => _photo = picked.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final backdrops = ref.watch(bibleStudioBackdropsProvider).value ?? const [];
    final gradients = <Gradient>[
      for (final b in backdrops)
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(b.topColor), Color(b.bottomColor)],
        ),
      ...kBrandGradients,
    ];
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleM4StudioTitle),
      body: ListView(
        padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: RepaintBoundary(
              key: _canvas,
              child: _Canvas(
                key: BibleShareStudioScreen.canvasKey,
                gradient: _gradient,
                photo: _photo,
                verse: _verse,
                reference: _showReference ? widget.link.labelFr : null,
                style: TextStyle(
                  fontFamily: bibleFontFamily(_font),
                  fontSize: _size,
                  height: 1.35,
                  color: _ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.bibleM4StudioBackground, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Swatch(
                  key: BibleShareStudioScreen.photoKey,
                  selected: _photo != null,
                  onTap: _pickPhoto,
                  child: const Icon(Icons.photo_library_outlined),
                ),
                for (final (i, g) in gradients.indexed)
                  _Swatch(
                    key: Key('bible_studio_bg_$i'),
                    selected: _photo == null && g == _gradient,
                    gradient: g,
                    onTap: () => setState(() {
                      _photo = null;
                      _gradient = g;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.bibleM4Font, style: AppTypography.h5),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final f in BibleReaderFont.values)
                ChoiceChip(
                  label: Text(
                    bibleFontLabel(context, f),
                    style: TextStyle(fontFamily: bibleFontFamily(f)),
                  ),
                  selected: _font == f,
                  onSelected: (_) => setState(() => _font = f),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.bibleM4StudioInk, style: AppTypography.h5),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final c in kStudioInks)
                _Swatch(
                  selected: c == _ink,
                  color: c,
                  onTap: () => setState(() => _ink = c),
                ),
            ],
          ),
          Text(l.bibleM4FontSize, style: AppTypography.h5),
          Slider(
            key: BibleShareStudioScreen.sizeKey,
            min: 16,
            max: 40,
            value: _size,
            onChanged: (v) => setState(() => _size = v),
          ),
          SwitchListTile(
            key: BibleShareStudioScreen.referenceKey,
            contentPadding: EdgeInsets.zero,
            title: Text(l.bibleM4StudioShowReference),
            value: _showReference,
            onChanged: (v) => setState(() => _showReference = v),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: BibleShareStudioScreen.saveKey,
                  onPressed: _busy || kIsWeb ? null : () => _export(true),
                  icon: const Icon(Icons.download),
                  label: Text(l.bibleM4StudioSave),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  key: BibleShareStudioScreen.shareKey,
                  onPressed: _busy ? null : () => _export(false),
                  icon: const Icon(Icons.share),
                  label: Text(l.bibleM4StudioShare),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({
    super.key,
    required this.gradient,
    required this.photo,
    required this.verse,
    required this.reference,
    required this.style,
  });

  final Gradient gradient;
  final Uint8List? photo;
  final Future<String> verse;
  final String? reference;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: photo == null ? gradient : null,
        color: photo == null ? null : Colors.black,
        image: photo == null
            ? null
            : DecorationImage(
                image: MemoryImage(photo),
                fit: BoxFit.cover,
                // Un voile pour que le texte reste lisible sur une photo.
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.35),
                  BlendMode.darken,
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: FutureBuilder<String>(
          future: verse,
          builder: (context, snap) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      snap.data ?? '',
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ),
              ),
              if (reference case final r?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  r,
                  style: style.copyWith(
                    fontSize: style.fontSize! * 0.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.selected,
    required this.onTap,
    this.gradient,
    this.color,
    this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            color: color,
            border: Border.all(
              color: selected ? AppColors.primary : Colors.black12,
              width: selected ? 3 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
