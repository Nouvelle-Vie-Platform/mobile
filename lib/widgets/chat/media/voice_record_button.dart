import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/messaging/media/voice_recording_controller.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/message_media.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';

/// Le glissement vers la gauche qui **annule** un vocal, en pixels.
const double kVoiceCancelDistance = 110;

/// Le glissement vers le haut qui **verrouille** l'enregistrement (mains
/// libres), en pixels.
const double kVoiceLockDistance = 80;

/// **Le micro de la barre de saisie** (M4, #143 — reprend #98), comme
/// WhatsApp :
///
/// - **appui maintenu** : on enregistre ; **relâcher** envoie ;
/// - **glisser à gauche** : on annule, rien ne part ;
/// - **glisser vers le haut** : on verrouille — le doigt se lève,
///   l'enregistrement continue, et ce bouton devient « envoyer » (une pastille
///   cadenas, au-dessus du micro, montre le geste pendant l'enregistrement) ;
/// - un **appui bref** ne fait rien d'autre que dire le geste.
///
/// L'état est dans [VoiceRecordingController] ; ce widget ne porte que le
/// geste. La permission du micro est demandée **au premier appui**.
///
/// ## Le geste est retenu pendant le démarrage
///
/// `begin()` attend la permission puis le micro, ce qui prend plusieurs
/// centaines de millisecondes — et, au premier appui, une fenêtre système qui
/// **interrompt** le geste. Un relâchement ou un glissement survenus dans cet
/// intervalle étaient ignorés (l'enregistrement n'était pas encore « en
/// cours »), alors que le micro démarrait quand même : l'enregistrement restait
/// **orphelin**, et seul un second appui long le terminait (relevé sur iPad).
/// Le geste est donc retenu, et appliqué dès que le micro tourne.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.controller,
    required this.onRecorded,
    required this.onDenied,
    required this.onTooShort,
  });

  final VoiceRecordingController controller;
  final ValueChanged<RecordedVoice> onRecorded;
  final VoidCallback onDenied;
  final VoidCallback onTooShort;

  static const Key lockHintKey = Key('m4_voice_lock_hint');

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  VoiceRecordingController get _controller => widget.controller;

  /// Le doigt est-il encore posé ? Faux dès le relâchement ou l'interruption,
  /// y compris pendant le démarrage du micro.
  bool _held = false;

  /// Ce que le doigt a demandé pendant le démarrage.
  bool _wantsLock = false;
  bool _wantsCancel = false;

  Future<void> _finish() async {
    final voice = await _controller.finish();
    if (voice == null) {
      widget.onTooShort();
    } else {
      widget.onRecorded(voice);
    }
  }

  Future<void> _start() async {
    _held = true;
    _wantsLock = false;
    _wantsCancel = false;
    if (!await _controller.begin()) {
      widget.onDenied();
      return;
    }
    if (!mounted) return;
    // Le micro tourne : on applique ce que le doigt a fait entre-temps.
    if (_wantsCancel) {
      unawaited(_controller.cancel());
    } else if (_wantsLock) {
      _controller.lock();
    } else if (!_held) {
      // Relâché avant que le micro ne démarre : rien de valable n'a été dit.
      // Annulé, jamais laissé tourner sans personne pour le finir.
      unawaited(_controller.cancel());
      widget.onTooShort();
    }
  }

  void _move(LongPressMoveUpdateDetails details) {
    final offset = details.offsetFromOrigin;
    if (offset.dx < -kVoiceCancelDistance) {
      _wantsCancel = true;
      unawaited(_controller.cancel());
    } else if (offset.dy < -kVoiceLockDistance) {
      _wantsLock = true;
      _controller.lock();
    }
  }

  /// Relâché — ou interrompu par le système (une fenêtre, un appel) : un
  /// enregistrement en cours est **envoyé**, jamais laissé orphelin.
  void _release() {
    _held = false;
    if (_controller.phase == VoiceRecordingPhase.recording) {
      unawaited(_finish());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final locked = _controller.phase == VoiceRecordingPhase.locked;
        final recording = _controller.phase == VoiceRecordingPhase.recording;

        return Semantics(
          button: true,
          label: locked ? l.m4VoiceSend : l.m4ChatRecordVoice,
          child: GestureDetector(
            key: const Key('m4_voice_button'),
            onTap: locked ? () => unawaited(_finish()) : widget.onTooShort,
            onLongPressStart: locked ? null : (_) => unawaited(_start()),
            onLongPressMoveUpdate: locked ? null : _move,
            onLongPressEnd: locked ? null : (_) => _release(),
            onLongPressCancel: locked ? null : _release,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: recording ? 64 : 48,
                  height: recording ? 64 : 48,
                  decoration: BoxDecoration(
                    gradient: recording ? null : AppColors.gradientSecondary,
                    color: recording ? AppColors.danger : null,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    locked ? Icons.send : Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                // **Le cadenas, au-dessus du micro** : glisser jusqu'à lui
                // verrouille l'enregistrement, mains libres.
                if (recording) const Positioned(bottom: 76, child: _LockHint()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockHint extends StatelessWidget {
  const _LockHint();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: VoiceRecordButton.lockHintKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 20, color: palette.textSecondary),
          const SizedBox(height: AppSpacing.xs),
          Icon(Icons.keyboard_arrow_up, size: 20, color: palette.textSecondary),
        ],
      ),
    );
  }
}

/// **Ce qui remplace le champ pendant l'enregistrement** : le point rouge, la
/// durée, la forme d'onde en direct — et la consigne (« glisser pour
/// annuler ») ou, verrouillé, la corbeille.
class VoiceRecordingStrip extends StatelessWidget {
  const VoiceRecordingStrip({super.key, required this.controller});

  final VoiceRecordingController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final locked = controller.phase == VoiceRecordingPhase.locked;
        return Container(
          key: const Key('m4_voice_strip'),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              if (locked)
                IconButton(
                  key: const Key('m4_voice_discard'),
                  tooltip: l.m4VoiceCancel,
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => unawaited(controller.cancel()),
                )
              else
                const Icon(Icons.fiber_manual_record,
                    color: AppColors.danger, size: 14),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatMediaDuration(controller.elapsed),
                key: const Key('m4_voice_elapsed'),
                style: AppTypography.bodyStrong
                    .copyWith(color: palette.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: locked
                    ? _LiveWaveform(levels: controller.recentLevels)
                    : Text(
                        l.m4VoiceSlideToCancel,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary),
                      ),
              ),
              if (!locked)
                Icon(Icons.lock_outline,
                    size: 16, color: palette.textSecondary),
            ],
          ),
        );
      },
    );
  }
}

class _LiveWaveform extends StatelessWidget {
  const _LiveWaveform({required this.levels});

  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 32),
      painter: _LivePainter(levels, context.palette.textSecondary),
    );
  }
}

/// Les derniers niveaux, **depuis la droite** : le plus récent contre la
/// durée, comme une bande qui défile. Peint plutôt que posé en `Row` : une
/// rangée de barres déborderait d'un champ étroit.
class _LivePainter extends CustomPainter {
  _LivePainter(this.levels, this.color);

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const step = 4.0;
    final mid = size.height / 2;
    var x = size.width - 2;
    for (final level in levels.reversed) {
      if (x < 0) break;
      final half = 2 + level * (size.height / 2 - 2);
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
      x -= step;
    }
  }

  @override
  bool shouldRepaint(covariant _LivePainter old) =>
      old.levels != levels || old.color != color;
}
