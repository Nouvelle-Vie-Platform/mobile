import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` n'est pas exporté par l'entrée principale de
// flutter_riverpod 3 — c'est pourtant le type qui permet de recevoir *un
// provider* plutôt que sa valeur, donc de l'écouter autant que de le lire.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/content_view.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_error_state.dart';
import 'content_absence.dart';

/// Habillage du lecteur quand il n'y a plus de contenu d'où tirer une couleur :
/// le bleu de marque, dernier maillon de la cascade.
const _fallbackBase = Color(kBrandFallbackColor);

/// **Le lecteur plein écran d'un contenu de médiathèque** — le même pour un
/// enseignement et pour un rassemblement.
///
/// Il ne lit **aucun provider** et ne connaît **aucune route** : il reçoit un
/// `AsyncValue<ContentView?>` déjà résolu par l'écran qui l'enveloppe. C'est ce
/// qui permet aux deux familles de partager ce dessin sans que le partage
/// devienne un chemin par lequel un rassemblement pourrait s'ouvrir dans
/// l'écran d'un enseignement : la famille est décidée en amont, par le provider
/// et par la route.
///
/// Quatre situations, et elles sont distinctes :
///
/// - **chargement** — le cadre du lecteur, sans son contenu. Aucun titre
///   d'emprunt, aucune couleur devinée ;
/// - **échec de lecture** — une **panne**, pas une absence : il y a quelque
///   chose à réessayer, et `AppErrorState` est le seul état du dépôt qui porte
///   une action ;
/// - **identifiant qui ne résout plus rien** — l'écran **reste ouvert** et
///   bascule sur [ContentAbsence.retracted] : on n'éjecte pas quelqu'un en
///   pleine lecture, et on ne fige pas une copie qui mentirait ;
/// - **contenu trouvé** — le lecteur.
///
/// Les trois premières partagent le même cadre ([_PlayerScaffold]) : basculer
/// sur un écran d'allure différente reviendrait à déplacer le fidèle sans le lui
/// dire.
///
/// **Une rétractation reçue pendant l'écoute arrête la lecture.** C'est la
/// disparition de la valeur qui le déclenche, jamais un simple retour à l'état
/// « chargement » : un rechargement ne doit pas couper le son.
class ContentPlayerView extends ConsumerStatefulWidget {
  const ContentPlayerView({
    super.key,
    required this.content,
    required this.chromeTitle,
    required this.retractedTitle,
    required this.retractedMessage,
    required this.onRetry,
  });

  /// **Le provider du contenu**, et non sa valeur.
  ///
  /// Il est passé tel quel pour que ce widget puisse l'**écouter** en plus de
  /// le lire : l'arrêt de la lecture doit réagir à chaque valeur du flux, pas
  /// aux seules reconstructions. Une rétractation immédiatement suivie d'une
  /// resynchronisation ne produit qu'une reconstruction — le contenu n'aurait
  /// jamais paru absent, et le son aurait continué sur un contenu retiré.
  ///
  /// Déclaré sur [ContentView] : `ProviderListenable` est covariant, un
  /// `StreamProvider<TeachingView?>` se passe donc ici tel quel.
  final ProviderListenable<AsyncValue<ContentView?>> content;

  /// Surtitre du lecteur — « Enseignement », « Rassemblement ». Déjà localisé.
  final String chromeTitle;

  /// Titre et explication de l'absence, plus précis que ceux de la variante
  /// générique. Déjà localisés.
  final String retractedTitle;
  final String retractedMessage;

  /// Relance la lecture du magasin après un échec.
  final VoidCallback onRetry;

  @override
  ConsumerState<ContentPlayerView> createState() => _ContentPlayerViewState();
}

class _ContentPlayerViewState extends ConsumerState<ContentPlayerView> {
  bool _playing = true;
  bool _liked = false;
  double _progress = 0.35;

  /// Ouvre une demi-feuille native (glissable vers le bas) : description,
  /// rubrique et infos du contenu.
  void _showInfoSheet(BuildContext context, ContentView content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ContentInfoSheet(content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Une rétractation reçue pendant l'écoute doit **arrêter la lecture**, et
    // pas seulement retirer les commandes de l'écran. On écoute la valeur, pas
    // l'`AsyncValue` : un rechargement qui repasse par « chargement » ne doit
    // pas couper le son, seule la disparition le doit.
    ref.listen<AsyncValue<ContentView?>>(widget.content, (_, next) {
      if (next.hasValue && next.value == null && _playing) {
        setState(() => _playing = false);
      }
    });

    return ref.watch(widget.content).when(
          loading: () => _buildLoading(context),
          error: (_, __) => _buildError(context),
          data: (content) => content == null
              ? _buildAbsent(context)
              : _buildPlayer(context, content),
        );
  }

  /// Le cadre du lecteur, sans son contenu : c'est le même écran, il n'est pas
  /// encore rempli.
  Widget _buildLoading(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      child: Column(
        children: [
          _PlayerTopBar(title: widget.chromeTitle),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      child: Column(
        children: [
          _PlayerTopBar(title: widget.chromeTitle),
          Expanded(
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: AppErrorState(
                  message: context.l10n.stateErrorMessage,
                  onRetry: widget.onRetry,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// L'identifiant ne résout plus rien : même chrome (le fidèle n'est pas
  /// déplacé), contenu remplacé par la déclaration d'absence.
  Widget _buildAbsent(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      child: Column(
        children: [
          _PlayerTopBar(title: widget.chromeTitle),
          Expanded(
            child: ContentAbsenceView(
              absence: ContentAbsence.retracted,
              onDark: true,
              title: widget.retractedTitle,
              message: widget.retractedMessage,
              onBack: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(BuildContext context, ContentView content) {
    // Couleur **déjà résolue** par le modèle de lecture : la cascade
    // contenu → rubrique → marque s'est terminée avant d'arriver ici.
    final base = Color(content.color);
    final author = content.authorName;

    return _PlayerScaffold(
      base: base,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerTopBar(
              title: widget.chromeTitle,
              onInfo: () => _showInfoSheet(context, content),
            ),
            Expanded(child: Center(child: _Artwork(content: content))),
            const SizedBox(height: AppSpacing.lg),
            Text(
              content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            // **Pas de ligne d'auteur quand il n'y en a pas.** Un « Auteur
            // inconnu » aurait l'allure d'une donnée, et le fidèle le lirait
            // comme une erreur de saisie de l'église. L'intervenant n'est
            // peut-être qu'en retard d'un cycle de synchronisation.
            if (author != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                author,
                style: AppTypography.h4.copyWith(color: Colors.white),
              ),
            ],
            if (content.typeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.sell_outlined,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    content.typeLabel,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _Controls(
              progress: _progress,
              playing: _playing,
              liked: _liked,
              accent: base,
              onSeek: (v) => setState(() => _progress = v),
              onPlayPause: () => setState(() => _playing = !_playing),
              onLike: () => setState(() => _liked = !_liked),
              onNotes: () => context.pushNamed(AppRoute.notes),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Le cadre du lecteur : dégradé plein écran tiré d'une couleur d'accent.
///
/// Extrait pour que l'**absence** garde exactement le même cadre que la
/// lecture. Basculer sur un écran d'allure différente reviendrait à déplacer le
/// fidèle sans le lui dire.
class _PlayerScaffold extends StatelessWidget {
  const _PlayerScaffold({required this.base, required this.child});

  final Color base;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, Color.lerp(base, Colors.black, 0.55)!],
            stops: const [0.15, 1.0],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

/// Barre supérieure du lecteur (retour, libellé, accès aux détails).
class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.title, this.onInfo});
  final String title;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        Text(
          title.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
          onPressed: onInfo,
        ),
      ],
    );
  }
}

/// Visuel central : image d'habillage si fournie, sinon placeholder coloré.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    // En-tête pleine largeur : le cadrage paysage. Le portrait prend le relais
    // s'il est seul, plutôt que de renoncer à toute image. La résolution des
    // chemins relatifs a déjà eu lieu dans le modèle de lecture.
    final image = _imageProvider(content.landscapeOrPortrait);

    // Pas d'image : grande icône flottant sur le dégradé.
    if (image == null) return _placeholder();

    // Image fondue dans le dégradé : opaque en haut, transparente en bas
    // (et léger fondu en haut) via un masque d'opacité.
    return Hero(
      // Étiquette bâtie sur l'identifiant, et non sur le titre : deux contenus
      // homonymes casseraient l'animation, un titre corrigé la
      // désynchroniserait de la carte d'origine.
      tag: 'content_art_${content.id}',
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.6, 1.0],
        ).createShader(rect),
        // Repli obligatoire (cf. CLAUDE.md) : sans lui, un visuel injoignable
        // — hors ligne, ou `flutter test` qui répond 400 à tout réseau — fait
        // lever le lecteur au lieu de retomber sur le placeholder.
        child: Image(
          image: image,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  /// Les deux cadrages sont servis en **URL relative** par l'API : la
  /// résolution contre la base courante appartient au client (ADR-0005).
  static ImageProvider? _imageProvider(String? source) {
    if (source == null) return null;
    return source.startsWith('http')
        ? NetworkImage(source)
        : AssetImage(source);
  }

  Widget _placeholder() => Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 110,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      );
}

/// Bloc de contrôles : progression, actions et lecture/pause.
///
/// **Pas de compteur de temps.** Il se calculait sur une durée que le serveur ne
/// sert pour aucune des deux familles. La vraie viendra du lecteur média
/// lui-même, qui la lit dans le flux HLS — pas d'un champ de contenu.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.progress,
    required this.playing,
    required this.liked,
    required this.accent,
    required this.onSeek,
    required this.onPlayPause,
    required this.onLike,
    required this.onNotes,
  });

  final double progress;
  final bool playing;
  final bool liked;
  final Color accent;
  final ValueChanged<double> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne de lecture + bouton play centré verticalement dessus.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                ),
                child: Slider(value: progress, onChanged: onSeek),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            _PlayButton(
                playing: playing, accent: accent, onPressed: onPlayPause),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            _GlassCircleButton(
              icon: liked ? Icons.favorite : Icons.favorite_border,
              onPressed: onLike,
            ),
            const SizedBox(width: AppSpacing.md),
            _GlassCircleButton(
              icon: Icons.edit_note_rounded,
              onPressed: onNotes,
            ),
          ],
        ),
      ],
    );
  }
}

/// Gros bouton lecture/pause (cercle blanc, icône à la couleur d'accent).
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.accent,
    required this.onPressed,
  });

  final bool playing;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 36),
        color: accent,
        onPressed: onPressed,
      ),
    );
  }
}

/// Petit bouton circulaire translucide (glassmorphisme).
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

/// Demi-feuille de détails : intervenant, rubrique et description.
class _ContentInfoSheet extends StatelessWidget {
  const _ContentInfoSheet({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    // Deux facultatifs, assemblés sans séparateur orphelin : un contenu sans
    // intervenant **ni** rubrique ne doit pas afficher un « • » seul.
    final subtitle = [content.authorName, content.typeLabel]
        .where((part) => part != null && part.isNotEmpty)
        .join(' • ');
    final description = content.description;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.title, style: AppTypography.h3),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
            ],
            // Section entière absente quand il n'y a rien à décrire : un
            // en-tête « Description » suivi du vide est pire que rien.
            if (description != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l.tabDescription, style: AppTypography.h5),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: AppTypography.bodyLarge
                    .copyWith(color: palette.textSecondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
