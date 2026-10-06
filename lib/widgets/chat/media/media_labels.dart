import '../../../l10n/app_localizations.dart';
import '../../../models/message_media.dart';

/// **L'aperçu d'un média dans la liste des conversations** (M4, #143) —
/// « 🎤 Message vocal », « 📍 Position »… `null` pour une forme inconnue :
/// la tuile retombe alors sur sa mention générique.
String? mediaPreviewLabel(AppLocalizations l, MessageMediaKind? kind) =>
    switch (kind) {
      MessageMediaKind.voice => l.m4PreviewVoice,
      MessageMediaKind.audio => l.m4PreviewAudio,
      MessageMediaKind.image => l.m4PreviewImage,
      MessageMediaKind.video => l.m4PreviewVideo,
      MessageMediaKind.document => l.m4PreviewDocument,
      MessageMediaKind.location => l.m4PreviewLocation,
      MessageMediaKind.contact => l.m4PreviewContact,
      MessageMediaKind.unknown || null => null,
    };

/// **La cause d'un envoi de média en échec**, dite au fidèle.
String mediaErrorLabel(AppLocalizations l, MediaSendError error) =>
    switch (error) {
      MediaSendError.tooLarge => l.m4MediaErrorTooLarge,
      MediaSendError.tooLong => l.m4MediaErrorTooLong,
      MediaSendError.typeNotAllowed => l.m4MediaErrorType,
      MediaSendError.missingFile => l.m4MediaErrorMissing,
      MediaSendError.unreadable => l.m4MediaErrorUnreadable,
    };

/// « 1× », « 1,5× », « 2× » — la vitesse de lecture d'un vocal.
String speedLabel(double speed, String localeName) {
  final text = speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toStringAsFixed(1);
  return '${localeName.startsWith('fr') ? text.replaceAll('.', ',') : text}×';
}
