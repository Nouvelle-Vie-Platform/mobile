/// **Le média porté par un message** (tranche M4, #143 — reprend #98), tel
/// qu'une bulle le peint.
///
/// Le magasin stocke les colonnes telles que le serveur les envoie
/// (`group_messages.media_*`, dont la méta en JSON) ; la **lecture** en fait un
/// objet typé, ici, une fois (ADR-0026, décision 3). Une bulle qui reçoit un
/// [MessageMedia] n'a plus rien à décoder, donc plus rien à décoder de travers.
///
/// ## Tout est toléré
///
/// Une forme inconnue (d'une version future du serveur) devient
/// [MessageMediaKind.unknown] — la bulle dit « non pris en charge » —, une méta
/// illisible donne un média sans détail. Rien ne lève : une exception ici
/// ferait échouer la requête qui peint tout le fil.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Les formes qu'une bulle sait peindre.
///
/// `voice` et `audio` partagent la forme serveur `audio` : c'est
/// `mediaMeta.voice` qui les distingue (vrai ou absent = un vocal).
enum MessageMediaKind {
  voice,
  audio,
  image,
  video,
  document,
  location,
  contact,

  /// Une forme que cette version ne connaît pas.
  unknown;

  /// La forme **serveur** (`mediaKind`) — `voice` et `audio` y sont `audio`.
  String get wire => switch (this) {
        MessageMediaKind.voice || MessageMediaKind.audio => 'audio',
        MessageMediaKind.unknown => 'unknown',
        _ => name,
      };

  /// Les formes qui déposent un **fichier** au magasin.
  bool get hasFile => switch (this) {
        MessageMediaKind.location ||
        MessageMediaKind.contact ||
        MessageMediaKind.unknown =>
          false,
        _ => true,
      };
}

/// Un numéro d'un contact partagé.
@immutable
class ContactPhone {
  const ContactPhone({required this.number, this.label});

  final String number;
  final String? label;

  Map<String, Object?> toJson() =>
      {'number': number, if (label != null) 'label': label};

  @override
  bool operator ==(Object other) =>
      other is ContactPhone && other.number == number && other.label == label;

  @override
  int get hashCode => Object.hash(number, label);
}

/// **Pourquoi un envoi de média a échoué**, quand on le sait — l'écran dit
/// alors la cause au lieu du seul « pas parti ».
enum MediaSendError {
  /// Le fichier dépasse la borne servie par le serveur.
  tooLarge,

  /// Le vocal ou la vidéo dépasse le plafond de durée.
  tooLong,

  /// Le type n'est pas accepté (un document exotique).
  typeNotAllowed,

  /// Le fichier local a disparu (cache vidé, application réinstallée).
  missingFile,

  /// La dégradation a échoué (image illisible, vidéo que le compresseur refuse).
  unreadable;

  static MediaSendError? parse(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  /// Un échec **définitif** : réessayer referait la même chose. Le réseau, lui,
  /// n'a pas de cause ici (`null`) et se réessaie.
  bool get isPermanent => this != MediaSendError.missingFile;
}

/// Le média d'un message — confirmé (colonnes serveur) ou en cours d'envoi
/// (l'écho, avec son fichier local).
@immutable
class MessageMedia {
  const MessageMedia({
    required this.kind,
    this.key,
    this.thumbnailKey,
    this.durationSeconds,
    this.sizeBytes,
    this.mime,
    this.waveform = const [],
    this.name,
    this.width,
    this.height,
    this.latitude,
    this.longitude,
    this.label,
    this.contactName,
    this.phones = const [],
    this.localPath,
    this.localThumbPath,
  });

  final MessageMediaKind kind;

  /// La clé au magasin — `null` pour un écho pas encore monté, une position,
  /// un contact.
  final String? key;
  final String? thumbnailKey;
  final int? durationSeconds;
  final int? sizeBytes;
  final String? mime;

  /// Hauteurs `0..100` d'un vocal, relevées à l'enregistrement.
  final List<int> waveform;

  /// Le nom d'un document ou d'un fichier audio.
  final String? name;
  final int? width;
  final int? height;
  final double? latitude;
  final double? longitude;

  /// Le libellé d'une position.
  final String? label;
  final String? contactName;
  final List<ContactPhone> phones;

  /// Le fichier **local** d'un écho : on le peint tant que le serveur n'a pas
  /// confirmé — l'image qu'on vient de prendre s'affiche sans aller-retour.
  final String? localPath;
  final String? localThumbPath;

  /// Largeur / hauteur, quand on les connaît — pour réserver la place de la
  /// bulle avant le téléchargement (pas de saut du fil).
  double? get aspectRatio {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  /// **Lit les colonnes** d'une ligne (serveur ou écho). `null` quand il n'y a
  /// pas de média.
  static MessageMedia? fromColumns({
    required String? kind,
    String? key,
    String? thumbnailKey,
    int? duration,
    String? metaJson,
    int? size,
    String? mime,
    String? localPath,
    String? localThumbPath,
  }) {
    if (kind == null) return null;
    final meta = decodeMeta(metaJson);

    final resolved = switch (kind) {
      'audio' => meta['voice'] == false
          ? MessageMediaKind.audio
          : MessageMediaKind.voice,
      'image' => MessageMediaKind.image,
      'video' => MessageMediaKind.video,
      'document' => MessageMediaKind.document,
      'location' => MessageMediaKind.location,
      'contact' => MessageMediaKind.contact,
      _ => MessageMediaKind.unknown,
    };

    final location = resolved == MessageMediaKind.location;
    final contact = resolved == MessageMediaKind.contact;

    return MessageMedia(
      kind: resolved,
      key: key,
      thumbnailKey: thumbnailKey,
      durationSeconds: duration,
      sizeBytes: size,
      mime: mime,
      waveform: _waveform(meta['waveform']),
      name: contact ? null : _text(meta['name']),
      width: _positiveInt(meta['width']),
      height: _positiveInt(meta['height']),
      latitude: location ? _number(meta['latitude']) : null,
      longitude: location ? _number(meta['longitude']) : null,
      label: _text(meta['label']),
      contactName: contact ? _text(meta['name']) : null,
      phones: contact ? _phones(meta['phones']) : const [],
      localPath: localPath,
      localThumbPath: localThumbPath,
    );
  }

  /// La méta décodée, ou un objet vide — jamais d'exception.
  static Map<String, Object?> decodeMeta(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } on FormatException {
      // Illisible : un média sans détail.
    }
    return const {};
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _number(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return null;
  }

  static int? _positiveInt(Object? value) {
    if (value is num && value.isFinite && value > 0) return value.round();
    return null;
  }

  static List<int> _waveform(Object? value) {
    if (value is! List) return const [];
    return List<int>.unmodifiable([
      for (final bar in value)
        if (bar is num && bar.isFinite) bar.round().clamp(0, 100),
    ]);
  }

  static List<ContactPhone> _phones(Object? value) {
    if (value is! List) return const [];
    return List<ContactPhone>.unmodifiable([
      for (final phone in value)
        if (phone is Map && _text(phone['number']) != null)
          ContactPhone(
            number: _text(phone['number'])!,
            label: _text(phone['label']),
          ),
    ]);
  }
}

/// « 2,3 Mo », « 840 ko » — la taille d'un document, en unités décimales
/// (celles que le serveur emploie pour ses bornes).
String formatByteSize(int bytes, String localeName) {
  final fr = localeName.startsWith('fr');
  String number(double value) {
    final text = value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return fr ? text.replaceAll('.', ',') : text;
  }

  if (bytes >= 1000000) return '${number(bytes / 1000000)} ${fr ? 'Mo' : 'MB'}';
  if (bytes >= 1000) return '${number(bytes / 1000)} ${fr ? 'ko' : 'kB'}';
  return '$bytes ${fr ? 'o' : 'B'}';
}

/// « 0:42 », « 12:05 » — la durée d'un vocal ou d'une vidéo.
String formatMediaDuration(Duration duration) {
  final total = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
