/// **Les types d'un document et d'un fichier audio, déduits de l'extension**
/// (M4, #143).
///
/// Le type est **déclaré** au dépôt (`POST /groups/:id/media-uploads`), signé
/// avec l'URL, puis relu sur l'objet réel : il doit donc être l'un de ceux que
/// le serveur accepte (`GROUP_MESSAGE_DOCUMENT_CONTENT_TYPES`,
/// `GROUP_MESSAGE_AUDIO_FILE_CONTENT_TYPES`). Les deux listes ci-dessous en
/// sont la copie, et le sélecteur ne propose **que** ces extensions : un
/// fichier qu'on ne pourrait pas envoyer ne doit pas pouvoir être choisi.
library;

/// Extension → type, pour un **document**.
const Map<String, String> kDocumentMimeByExtension = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'odt': 'application/vnd.oasis.opendocument.text',
  'ods': 'application/vnd.oasis.opendocument.spreadsheet',
  'odp': 'application/vnd.oasis.opendocument.presentation',
  'rtf': 'application/rtf',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'epub': 'application/epub+zip',
};

/// Extension → type, pour un **fichier audio** (pas un vocal).
const Map<String, String> kAudioFileMimeByExtension = {
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'oga': 'audio/ogg',
  'opus': 'audio/opus',
  'wav': 'audio/wav',
  'flac': 'audio/flac',
  'weba': 'audio/webm',
};

/// L'extension d'un nom de fichier, en minuscules, sans le point — ou `''`.
String fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// Le type d'un document d'après son nom, ou `null` s'il n'est pas accepté.
String? documentMimeOf(String name) =>
    kDocumentMimeByExtension[fileExtension(name)];

/// Le type d'un fichier audio d'après son nom, ou `null` s'il n'est pas
/// accepté.
String? audioFileMimeOf(String name) =>
    kAudioFileMimeByExtension[fileExtension(name)];

/// La famille d'icône d'un document, pour la bulle.
enum DocumentFamily { pdf, text, sheet, slides, other }

DocumentFamily documentFamilyOf({String? mime, String? name}) {
  final ext = name == null ? '' : fileExtension(name);
  final type = mime ?? kDocumentMimeByExtension[ext] ?? '';
  if (type == 'application/pdf') return DocumentFamily.pdf;
  if (type.contains('spreadsheet') ||
      type.contains('ms-excel') ||
      type == 'text/csv') {
    return DocumentFamily.sheet;
  }
  if (type.contains('presentation') || type.contains('powerpoint')) {
    return DocumentFamily.slides;
  }
  if (type.contains('word') ||
      type.contains('opendocument.text') ||
      type == 'text/plain' ||
      type == 'application/rtf') {
    return DocumentFamily.text;
  }
  return DocumentFamily.other;
}
