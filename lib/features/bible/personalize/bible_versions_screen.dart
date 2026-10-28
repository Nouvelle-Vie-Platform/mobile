/// **Versions et hors ligne** (M4, mobile#202, décision 9) : le catalogue
/// fusionné, « Télécharger » (l'archive réelle depuis C4), « Supprimer », et
/// le choix de la version active.
///
/// **L'invitation** (#265) en est une variante, sans en-tête : la coquille du
/// module la montre tant qu'aucune vraie Bible n'est téléchargée — un court
/// message, puis les seules vraies versions, avec la même ligne, le même
/// « Télécharger » et la même progression.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../state/sync_providers.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import '../home/home_view.dart';
import 'bible_catalog.dart';

class BibleVersionsScreen extends ConsumerStatefulWidget {
  const BibleVersionsScreen({super.key, this.invitation = false});

  /// La page d'invitation de la coquille (#265), et non l'écran poussé.
  final bool invitation;

  static const Key invitationKey = Key('bible_invitation');

  static Key rowKey(String code) => Key('bible_version_row_$code');
  static Key downloadKey(String code) => Key('bible_version_download_$code');
  static Key removeKey(String code) => Key('bible_version_remove_$code');
  static Key activeKey(String code) => Key('bible_version_active_$code');

  @override
  ConsumerState<BibleVersionsScreen> createState() =>
      _BibleVersionsScreenState();
}

class _BibleVersionsScreenState extends ConsumerState<BibleVersionsScreen> {
  /// La progression des téléchargements en cours, par code.
  final Map<String, double> _progress = {};

  Future<void> _download(BibleCatalogEntry entry) async {
    final code = entry.version.code;
    setState(() => _progress[code] = 0);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.bibleM4DownloadFailed;
    final db = ref.read(appDatabaseProvider);
    final installer = ref.read(bibleInstallerProvider);
    final ensureIndexed = ref.read(bibleEnsureIndexedProvider);
    try {
      await for (final p
          in installer.install(db, entry, ensureIndexed: ensureIndexed)) {
        if (mounted) setState(() => _progress[code] = p);
      }
    } on Object {
      // Une archive refusée (empreinte, réseau) **n'installe rien** : le
      // fidèle doit savoir que le bouton n'a rien produit, sinon il le
      // regarde redevenir « Télécharger » sans explication.
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _progress.remove(code));
    }
  }

  void _select(String code) {
    ref.read(activeBibleVersionProvider.notifier).select(code);
    final s = ref.read(bibleReadingStateProvider).value;
    final book = s?.book;
    final chapter = s?.chapter;
    // La version devient durable avec la position ; sans position, elle
    // vaut pour la séance.
    if (book != null && chapter != null) {
      unawaited(
        ref.read(bibleDaoProvider).savePosition(
              member: ref.read(bibleIsMemberProvider),
              versionCode: code,
              book: book,
              chapter: chapter,
              verse: s?.verse,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invitation = widget.invitation;
    // Les exemples ne comptent jamais pour l'invitation : ce sont eux qu'elle
    // remplace. Sans autre ligne (premier lancement hors ligne, catalogue
    // pas encore synchronisé), elle invite à se connecter.
    final entries = [
      for (final e in ref.watch(mergedBibleCatalogProvider).entries)
        if (!invitation || !e.builtIn) e,
    ];
    final active = ref.watch(activeBibleVersionProvider);
    // **Seules les versions défilent** : l'en-tête reste en place au-dessus.
    final page = Column(
      key: invitation ? BibleVersionsScreen.invitationKey : null,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenPadding.copyWith(
            top: invitation ? AppSpacing.xl : null,
            bottom: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _header(context, entries.isEmpty),
          ),
        ),
        Expanded(
          child: ListView(
            padding: AppSpacing.screenPadding.copyWith(top: 0),
            children: [for (final e in entries) _row(context, e, active)],
          ),
        ),
      ],
    );
    if (invitation) return page;
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleM4VersionsTitle),
      body: page,
    );
  }

  List<Widget> _header(BuildContext context, bool empty) {
    final l = context.l10n;
    return [
      if (widget.invitation) ...[
        Image.asset(
          'assets/images/bible_invite_book.webp',
          height: 170,
          // Purement décoratif : le titre dit déjà tout.
          excludeFromSemantics: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.bibleInviteTitle,
          textAlign: TextAlign.center,
          style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          empty ? l.bibleInviteOffline : l.bibleInviteDownload,
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge
              .copyWith(color: context.palette.textSecondary),
        ),
        if (!empty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            l.bibleInviteAvailable.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ] else
        Text(l.bibleM4VersionsHint),
    ];
  }

  Widget _row(BuildContext context, BibleCatalogEntry e, String active) {
    final l = context.l10n;
    final v = e.version;
    final progress = _progress[v.code];
    final size = e.sizeBytes;

    /// La langue, la taille et « incluse » — ce qui aide à choisir quoi
    /// télécharger —, puis **la licence sur sa propre ligne** (#258).
    ///
    /// Elle en était partie le 26/10/2026 pour ne vivre qu'au portail. Mais
    /// plusieurs ayants droit exigent la mention **là où le texte est lu** (la
    /// S21 : « Reproduit avec aimable autorisation » ; l'éwé : Bible Society of
    /// Ghana et of Togo), et le portail n'est pas lu par le fidèle. Cet écran
    /// est l'endroit le plus proche du lecteur qui ne s'immisce pas dans le
    /// texte : un geste depuis la lecture, et c'est là que le fidèle choisit
    /// sa traduction.
    final facts = [
      if (size != null) l.bibleM4SizeMb((size / 1e6).toStringAsFixed(1)),
      if (e.builtIn) l.bibleM4VersionBuiltIn,
    ];
    final license = e.license;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (book, ink) = _languageColors(v.language);
    // La nuit, l'encre de la pastille s'éclaircit : le bleu « FR » sur une
    // carte sombre ne se lisait plus.
    final tag = dark ? Color.lerp(ink, Colors.white, 0.45)! : ink;
    final palette = context.palette;
    final Widget trailing;
    if (progress != null) {
      trailing = SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(value: progress),
      );
    } else if (!v.installed) {
      trailing = e.downloadable
          ? IconButton.filled(
              key: BibleVersionsScreen.downloadKey(v.code),
              tooltip: l.bibleM4Download,
              style: IconButton.styleFrom(
                // La couleur de la pastille de la barre, nuit comprise.
                backgroundColor: BibleHomeColors.of(context).button,
                foregroundColor: Colors.white,
                fixedSize: const Size.square(48),
              ),
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _download(e),
            )
          : Text(l.bibleM4VersionSoon);
    } else if (!e.builtIn) {
      trailing = IconButton(
        key: BibleVersionsScreen.removeKey(v.code),
        tooltip: l.bibleM4Remove,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(bibleInstallerProvider).remove(
              ref.read(appDatabaseProvider),
              v.code,
            ),
      );
    } else {
      trailing = const Icon(Icons.offline_pin_outlined);
    }
    return Container(
      key: BibleVersionsScreen.rowKey(v.code),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pas de choix sur l'invitation : rien n'y est installé, et une case
          // cochée d'avance y mentait. La première version descendue devient
          // active d'office (`ActiveBibleVersion` se replie sur elle).
          if (!widget.invitation)
            IconButton(
              key: BibleVersionsScreen.activeKey(v.code),
              tooltip: l.bibleM4ActiveVersion,
              icon: Icon(
                v.code == active
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onPressed: v.installed ? () => _select(v.code) : null,
            ),
          Icon(Icons.book_rounded, size: 52, color: book),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name, style: AppTypography.h4),
                const SizedBox(height: AppSpacing.xs),
                // La pastille : la langue dans sa couleur, puis la taille.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tag.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: v.language.toUpperCase(),
                            style: TextStyle(color: tag),
                          ),
                          for (final f in facts) TextSpan(text: ' · $f'),
                        ],
                      ),
                      style: AppTypography.body
                          .copyWith(color: palette.textSecondary),
                    ),
                  ),
                ),
                if (license != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    license,
                    style: AppTypography.body
                        .copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ),
    );
  }

  /// **La couleur suit la langue** (#265) : le livre d'un côté, la pastille
  /// de l'autre, en couple inversé — deux Bibles françaises se ressemblent,
  /// et l'œil trie d'un coup.
  static (Color book, Color tag) _languageColors(String language) =>
      switch (language.toLowerCase()) {
        'fr' => (const Color(0xFFF59A62), const Color(0xFF3341B0)),
        'ee' => (const Color(0xFF2F47A8), const Color(0xFFD9782F)),
        'en' => (const Color(0xFF3E9B6F), const Color(0xFF2E7D57)),
        _ => (const Color(0xFF143256), const Color(0xFF143256)),
      };
}
