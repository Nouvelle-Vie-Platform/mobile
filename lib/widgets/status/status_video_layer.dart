import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/players/status_player.dart';

/// Comment une image ou une vidéo de statut se pose sur le fond.
enum StatusVideoFraming {
  /// **Occupe le fond** (`BoxFit.cover`) — une vidéo verticale, filmée au
  /// téléphone pour un écran de téléphone.
  fill,

  /// **Gardée entière, centrée sur le fond du statut** (`BoxFit.contain`) — une
  /// vidéo horizontale. Le dégradé du statut subsiste autour d'elle.
  fit,
}

/// **La règle de cadrage** (décision 11 du plan « Sparks ») : une vidéo
/// verticale occupe le fond ; toute autre — horizontale, carrée — est gardée
/// entière, **jamais recadrée**.
///
/// La raison tient en une phrase du cadrage : *on ne coupe jamais ce que
/// quelqu'un a cadré* — un recadrage automatique décapite les gens, toujours
/// sur la vidéo qui comptait. Une vidéo verticale, elle, a été cadrée pour cet
/// écran : la remplir ne lui retire presque rien.
///
/// Des dimensions inconnues ou vides se lisent [StatusVideoFraming.fit] : dans
/// le doute, on ne coupe pas.
StatusVideoFraming statusVideoFraming(Size size) {
  if (size.isEmpty) return StatusVideoFraming.fit;
  return size.height > size.width
      ? StatusVideoFraming.fill
      : StatusVideoFraming.fit;
}

/// **Pose son enfant selon [statusVideoFraming], d'après ses propres
/// dimensions.**
///
/// Un `FittedBox` dont l'ajustement se décide **après** la mise en page de
/// l'enfant : c'est la seule façon d'appliquer la même règle à l'affiche (une
/// image réseau, dont on ne connaît la taille qu'une fois décodée) et à la
/// vidéo (dont la taille vient du lecteur). L'enfant doit avoir une taille
/// intrinsèque : une `Image` sans contrainte, ou une vidéo dans un `SizedBox`
/// à ses dimensions natives.
///
/// Tant que l'enfant est vide — image pas encore décodée, ou en échec —, rien
/// n'est peint, et le dégradé du statut reste visible dessous.
class StatusFramedMedia extends SingleChildRenderObjectWidget {
  const StatusFramedMedia({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStatusFrame();
}

class _RenderStatusFrame extends RenderFittedBox {
  _RenderStatusFrame() : super(clipBehavior: Clip.hardEdge);

  @override
  void performLayout() {
    super.performLayout();
    final child = this.child;
    if (child == null) return;
    final wanted = statusVideoFraming(child.size) == StatusVideoFraming.fill
        ? BoxFit.cover
        : BoxFit.contain;
    // `cover` et `contain` dimensionnent ce cadre de la même façon (contraintes
    // serrées du fond) : seul l'ajustement de la peinture change, et le poser
    // ici, après la mise en page de l'enfant, ne la refait pas.
    if (fit != wanted) fit = wanted;
  }
}

/// **La vidéo d'un statut, ou son affiche en attendant.**
///
/// Posée par l'écran dans le fond du statut (`StatusBackground.media`), à la
/// place de l'image de fond. Trois états, dans l'ordre où ils se succèdent :
///
/// 1. **l'affiche**, cadrée par la règle commune, tant que la vidéo n'a pas
///    d'image à montrer — sur les pages voisines, préconstruites par le pager,
///    c'est le seul état ;
/// 2. **la vidéo**, dès sa première image ([StatusPlayback.hasVideoFrame]) et
///    ses dimensions connues ([StatusPlayback.videoSize]) — l'affiche
///    s'efface alors, pour ne pas dépasser d'une vidéo d'un autre format ;
/// 3. le **dégradé seul**, quand il n'y a pas d'affiche et pas encore d'image.
///
/// Elle ne s'abonne au lecteur que pour ces trois bascules : la position émet
/// plusieurs fois par seconde, et reconstruire l'affiche à ce rythme ferait
/// clignoter son fondu.
class StatusVideoLayer extends StatefulWidget {
  const StatusVideoLayer({
    super.key,
    required this.statusId,
    required this.player,
    required this.isCurrent,
    this.posterUrl,
  });

  final String statusId;
  final StatusPlayer player;

  /// Seule la page courante suit le lecteur : il ne joue qu'elle.
  final bool isCurrent;

  /// Affiche, **URL absolue**, ou `null`.
  final String? posterUrl;

  /// Clé de l'affiche, pour les tests.
  @visibleForTesting
  static const Key posterKey = Key('status-video-poster');

  /// Clé du cadre de la vidéo, pour les tests.
  @visibleForTesting
  static const Key videoKey = Key('status-video-surface');

  /// Clé du repli quand l'affiche échoue (hors ligne, et toujours en test).
  @visibleForTesting
  static const Key posterErrorKey = Key('status-video-poster-error');

  @override
  State<StatusVideoLayer> createState() => _StatusVideoLayerState();
}

class _StatusVideoLayerState extends State<StatusVideoLayer> {
  /// Les dimensions de la vidéo **quand elle a une image à montrer**, `null`
  /// sinon. C'est la seule chose que cet état retient du lecteur.
  Size? _shown;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onPlayback);
    _shown = _visibleSize();
  }

  @override
  void didUpdateWidget(StatusVideoLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.player, widget.player)) {
      oldWidget.player.removeListener(_onPlayback);
      widget.player.addListener(_onPlayback);
    }
    _shown = _visibleSize();
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayback);
    super.dispose();
  }

  Size? _visibleSize() {
    if (!widget.isCurrent) return null;
    final playback = widget.player.value;
    if (playback.statusId != widget.statusId) return null;
    if (!playback.hasVideoFrame) return null;
    final size = playback.videoSize;
    if (size == null || size.isEmpty) return null;
    return size;
  }

  void _onPlayback() {
    final next = _visibleSize();
    if (next != _shown) setState(() => _shown = next);
  }

  @override
  Widget build(BuildContext context) {
    final size = _shown;
    final surface = size == null ? null : widget.player.videoSurface();
    if (size != null && surface != null) {
      return StatusFramedMedia(
        key: StatusVideoLayer.videoKey,
        child: SizedBox.fromSize(size: size, child: surface),
      );
    }

    final poster = widget.posterUrl;
    if (poster == null) return const SizedBox.shrink();
    return StatusFramedMedia(
      key: StatusVideoLayer.posterKey,
      child: Image.network(
        poster,
        // Règle impérative du CLAUDE.md : sans `errorBuilder`, l'écran casse
        // hors ligne *et* en test. Le repli est le dégradé déjà peint dessous.
        errorBuilder: (_, __, ___) =>
            const SizedBox.shrink(key: StatusVideoLayer.posterErrorKey),
      ),
    );
  }
}
