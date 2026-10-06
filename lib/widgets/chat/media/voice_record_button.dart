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
///   l'enregistrement continue, et ce bouton devient « envoyer » ;
/// - un **appui bref** ne fait rien d'autre que dire le geste.
///
/// L'état est dans [VoiceRecordingController] ; ce widget ne porte que le
/// geste. La permission du micro est demandée **au premier appui**.
class VoiceRecordButton extends StatelessWidget {
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

  Future<void> _finish() async {
    final voice = await controller.finish();
    if (voice == null) {
      onTooShort();
    } else {
      onRecorded(voice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final locked = controller.phase == VoiceRecordingPhase.locked;
        final recording = controller.phase == VoiceRecordingPhase.recording;

        return Semantics(
          button: true,
          label: locked ? l.m4VoiceSend : l.m4ChatRecordVoice,
          child: GestureDetector(
            key: const Key('m4_voice_button'),
            onTap: locked ? () => unawaited(_finish()) : onTooShort,
            onLongPressStart: locked
                ? null
                : (_) async {
                    if (!await controller.begin()) onDenied();
                  },
            onLongPressMoveUpdate: locked
                ? null
                : (details) {
                    final offset = details.offsetFromOrigin;
                    if (offset.dx < -kVoiceCancelDistance) {
                      unawaited(controller.cancel());
                    } else if (offset.dy < -kVoiceLockDistance) {
                      controller.lock();
                    }
                  },
            onLongPressEnd: locked
                ? null
                : (_) {
                    // Annulé en route, ou verrouillé : le relâcher n'envoie rien.
                    if (controller.phase == VoiceRecordingPhase.recording) {
                      unawaited(_finish());
                    }
                  },
            child: AnimatedContainer(
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
          ),
        );
      },
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
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
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
