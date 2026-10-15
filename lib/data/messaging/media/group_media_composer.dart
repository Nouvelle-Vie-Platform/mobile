/// **L'envoi d'un média, écho optimiste compris** (M4, #143 — reprend #98).
///
/// Le patron de `GroupMessageComposer` (#96, #140), étendu au chemin présigné :
///
/// 1. **frapper la clé d'idempotence** (UUIDv7) ;
/// 2. **poser l'écho** — le vocal, la photo, le document paraissent au fil
///    « en cours d'envoi » **avant** toute dégradation ni montée, avec leur
///    fichier local (recopié dans l'outbox pour survivre à un redémarrage) ;
/// 3. **dégrader** (image : JPEG q80, ≤ 1600 px, EXIF retiré ; vidéo :
///    compressée, métadonnées retirées) ;
/// 4. **le ticket** de dépôt, et ses bornes — **vérifiées avant la montée** :
///    un fichier trop lourd, un vocal ou une vidéo trop longs sont refusés
///    ici, avec leur cause, sans dépenser les données d'un fidèle à monter
///    pour s'entendre refuser ;
/// 5. **monter** droit au magasin, la progression à l'écran ;
/// 6. **poster le message** qui cite la clé, sous la même clé d'idempotence.
///
/// Chaque étape franchie est **écrite dans l'écho** (fichier prêt, clé
/// montée) : un renvoi — manuel, ou automatique au retour du réseau (#140) —
/// reprend où l'on s'était arrêté, sans redégrader ni remonter.
///
/// ## Un échec reste à l'écran, réessayable
///
/// Il ne lève pas : l'écho est marqué « pas parti », avec sa cause quand on la
/// connaît (`media_error`). Une cause **définitive** (trop lourd, trop long,
/// type refusé) n'est pas rejouée par le renvoi automatique — elle referait la
/// même chose ; le geste manuel, lui, essaie quand même.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../../models/message_media.dart';
import '../../local/app_database.dart';
import '../../local/group_dao.dart';
import '../../repositories/group_message_sender.dart' show mintClientMessageId;
import 'group_media_transport.dart';
import 'media_outbox.dart';
import 'media_preparer.dart';
import 'media_upload_progress.dart';
import 'message_media_store.dart';

/// Ce qu'on veut envoyer — une seule des formes est renseignée.
class OutgoingMedia {
  const OutgoingMedia._({
    required this.kind,
    this.sourcePath,
    this.name,
    this.mime,
    this.sizeBytes,
    this.durationSeconds,
    this.waveform = const [],
    this.latitude,
    this.longitude,
    this.label,
    this.contactName,
    this.phones = const [],
    this.caption,
  });

  /// Un vocal enregistré (déjà en AAC mono 32 kbit/s, par l'enregistreur).
  const OutgoingMedia.voice({
    required String path,
    required int durationSeconds,
    List<int> waveform = const [],
  }) : this._(
          kind: MessageMediaKind.voice,
          sourcePath: path,
          mime: 'audio/mp4',
          durationSeconds: durationSeconds,
          waveform: waveform,
        );

  /// Une photo (galerie ou appareil photo), légende facultative.
  const OutgoingMedia.image({required String path, String? caption})
      : this._(
            kind: MessageMediaKind.image, sourcePath: path, caption: caption);

  /// Une vidéo, compressée sur l'appareil avant de partir.
  const OutgoingMedia.video({required String path, String? caption})
      : this._(
            kind: MessageMediaKind.video, sourcePath: path, caption: caption);

  /// Un document, envoyé tel quel (son type est déduit de son nom).
  const OutgoingMedia.document({
    required String path,
    required String name,
    required String mime,
    int? sizeBytes,
  }) : this._(
          kind: MessageMediaKind.document,
          sourcePath: path,
          name: name,
          mime: mime,
          sizeBytes: sizeBytes,
        );

  /// Un fichier audio choisi dans le téléphone (pas un vocal).
  const OutgoingMedia.audioFile({
    required String path,
    required String name,
    required String mime,
    int? sizeBytes,
  }) : this._(
          kind: MessageMediaKind.audio,
          sourcePath: path,
          name: name,
          mime: mime,
          sizeBytes: sizeBytes,
        );

  /// Une position : des coordonnées, un libellé facultatif.
  const OutgoingMedia.location({
    required double latitude,
    required double longitude,
    String? label,
  }) : this._(
          kind: MessageMediaKind.location,
          latitude: latitude,
          longitude: longitude,
          label: label,
        );

  /// **Un** contact : son nom et ses numéros, rien d'autre.
  const OutgoingMedia.contact({
    required String name,
    required List<ContactPhone> phones,
  }) : this._(
          kind: MessageMediaKind.contact,
          contactName: name,
          phones: phones,
        );

  final MessageMediaKind kind;
  final String? sourcePath;
  final String? name;
  final String? mime;
  final int? sizeBytes;
  final int? durationSeconds;
  final List<int> waveform;
  final double? latitude;
  final double? longitude;
  final String? label;
  final String? contactName;
  final List<ContactPhone> phones;
  final String? caption;

  /// La méta envoyée au serveur (`mediaMeta`), selon la forme.
  Map<String, Object?>? get meta => switch (kind) {
        MessageMediaKind.voice => {
            'voice': true,
            if (waveform.isNotEmpty) 'waveform': waveform,
          },
        MessageMediaKind.audio => {'voice': false, 'name': name},
        MessageMediaKind.document => {'name': name},
        MessageMediaKind.location => {
            'latitude': latitude,
            'longitude': longitude,
            if (label != null && label!.trim().isNotEmpty)
              'label': label!.trim(),
          },
        MessageMediaKind.contact => {
            'name': contactName,
            'phones': [for (final phone in phones) phone.toJson()],
          },
        _ => null,
      };
}

class GroupMediaComposer {
  GroupMediaComposer({
    required GroupDao dao,
    required GroupMediaTransport transport,
    required MediaPreparer preparer,
    required MediaOutbox outbox,
    required MessageMediaStore store,
    required MediaUploadProgress progress,
    required Future<void> Function() resynchronize,
    DateTime Function()? now,
    String Function()? mintId,
  })  : _dao = dao,
        _transport = transport,
        _preparer = preparer,
        _outbox = outbox,
        _store = store,
        _progress = progress,
        _resynchronize = resynchronize,
        _now = now ?? DateTime.now,
        _mintId = mintId ?? mintClientMessageId;

  final GroupDao _dao;
  final GroupMediaTransport _transport;
  final MediaPreparer _preparer;
  final MediaOutbox _outbox;
  final MessageMediaStore _store;
  final MediaUploadProgress _progress;
  final Future<void> Function() _resynchronize;
  final DateTime Function() _now;
  final String Function() _mintId;

  /// Les envois en cours : un renvoi automatique ne double pas un envoi qui
  /// tourne encore.
  final Set<String> _inFlight = {};

  /// **Pose l'écho, puis envoie.** Rend la clé d'idempotence — celle que
  /// « réessayer » et « abandonner » désignent.
  ///
  /// L'écho est posé **avant** le premier `await` long : l'appelant peut ne
  /// pas attendre la fin (`unawaited`) et le fil montre déjà le média.
  Future<String> send({
    required String groupId,
    required OutgoingMedia media,
  }) async {
    final id = _mintId();
    final createdAt = _now();

    var path = media.sourcePath;
    if (path != null) {
      try {
        path = await _outbox.adopt(path, '$id-src.${_extensionOf(path)}');
      } on Object {
        // Pas de copie possible : on monte depuis la source, tant qu'elle vit.
      }
    }

    // Le vocal, le document et le fichier audio sont **prêts tels quels** :
    // leur type est connu, et sa présence dit « dégradation faite ». L'image et
    // la vidéo l'obtiendront une fois dégradées.
    final ready = media.kind == MessageMediaKind.voice ||
        media.kind == MessageMediaKind.document ||
        media.kind == MessageMediaKind.audio;

    final meta = media.meta;
    await _dao.rememberPendingMedia(
      clientMessageId: id,
      groupId: groupId,
      createdAt: createdAt,
      mediaKind: media.kind.wire,
      caption: media.caption,
      mediaPath: path,
      mediaMime: ready ? media.mime : null,
      mediaMeta: meta == null ? null : jsonEncode(meta),
      mediaDuration: media.durationSeconds,
      mediaSize: media.sizeBytes,
    );

    await deliver(id, manual: true);
    return id;
  }

  /// **Envoie l'écho [clientMessageId]**, en reprenant où il s'était arrêté.
  /// Rend `true` si le message est parti.
  ///
  /// [manual] faux (le renvoi automatique) : un échec **définitif** n'est pas
  /// rejoué.
  Future<bool> deliver(String clientMessageId, {bool manual = false}) async {
    if (!_inFlight.add(clientMessageId)) return false;
    try {
      var pending = await _dao.pendingById(clientMessageId);
      if (pending == null || pending.mediaKind == null) return false;
      if (!manual &&
          (MediaSendError.parse(pending.mediaError)?.isPermanent ?? false)) {
        return false;
      }

      await _dao.updatePendingMedia(
        clientMessageId,
        const PendingGroupMessagesCompanion(
          failed: Value(false),
          mediaError: Value(null),
        ),
      );

      final kind = pending.mediaKind!;
      if (kind == 'audio' ||
          kind == 'image' ||
          kind == 'video' ||
          kind == 'document') {
        pending = await _prepare(pending);
        pending = await _upload(pending);
      }

      final meta = MessageMedia.decodeMeta(pending.mediaMeta);
      final messageId = await _transport.sendMessage(
        groupId: pending.groupId,
        clientMessageId: pending.clientMessageId,
        clientCreatedAt: pending.createdAt,
        mediaKind: kind,
        body: pending.body.isEmpty ? null : pending.body,
        mediaKey: pending.mediaKey,
        mediaDuration: pending.mediaDuration,
        mediaMeta: meta.isEmpty ? null : meta,
        mediaThumbnailKey: pending.mediaThumbnailKey,
      );
      if (messageId != null) await _keep(messageId, pending, meta);

      _progress.clear(clientMessageId);
      // Le flux delta ramène la ligne autoritaire ; `threadOf` fait alors
      // disparaître l'écho. Le ménage vient après, et aucun écran n'en dépend.
      await _resynchronize();
      await _dao.purgeReconciled();
      await _outbox.sweep(await _dao.pendingMediaFiles());
      return true;
    } on _MediaRefused catch (refusal) {
      await _dao.markPendingMediaFailed(clientMessageId, refusal.error.name);
      return false;
    } on GroupMediaTransportException catch (error) {
      await _onTransportError(clientMessageId, error);
      return false;
    } on MediaPreparationException {
      await _dao.markPendingMediaFailed(
        clientMessageId,
        MediaSendError.unreadable.name,
      );
      return false;
    } on FileSystemException {
      await _dao.markPendingMediaFailed(
        clientMessageId,
        MediaSendError.missingFile.name,
      );
      return false;
    } finally {
      _progress.clear(clientMessageId);
      _inFlight.remove(clientMessageId);
    }
  }

  /// **Le fichier envoyé passe de l'outbox au magasin** (T2, #224).
  ///
  /// Sans ce passage, le fichier qu'on venait d'envoyer était **effacé** par le
  /// balayage dès que l'écho cessait de le citer, puis **retéléchargé** depuis
  /// le serveur pour paraître dans sa propre bulle. On l'avait, on le jetait, on
  /// le reprenait.
  ///
  /// **Un déplacement, pas une copie** : les octets d'une vidéo ne s'écrivent
  /// pas deux fois (`MessageMediaStore.adopt`).
  ///
  /// ## Relier l'écho à l'identité définitive du message
  ///
  /// Le magasin est indexé par l'identité **serveur** du message ; un écho n'a
  /// que sa clé d'idempotence, frappée par le téléphone. Les deux ne se voient
  /// qu'ici : le `201` de `POST /groups/:id/messages` rend le message
  /// autoritaire, et le rend aussi sur un renvoi sous la même clé — un envoi
  /// repris après une coupure apprend donc la même identité, et le passage est
  /// **idempotent** (la source est alors déjà au magasin, `adopt` n'a rien à
  /// faire).
  ///
  /// Attendre la réconciliation aurait été plus fragile : la ligne autoritaire
  /// arrive par le cycle delta **ou** par le canal `users/{id}`, et
  /// `purgeReconciled` efface l'écho — donc le lien — dès qu'elle est là.
  ///
  /// ## Jamais au prix de l'envoi
  ///
  /// Le message **est parti**. Un disque plein, un dossier refusé ne doivent
  /// donc pas marquer l'écho « pas parti » : l'erreur est avalée, et le fichier
  /// reste dans l'outbox — où le balayage finira par le prendre, comme avant
  /// cette tranche. On perd un retéléchargement, pas un message.
  Future<void> _keep(
    String messageId,
    PendingGroupMessageRow pending,
    Map<String, Object?> meta,
  ) async {
    final source = pending.mediaPath;
    if (source == null) return;
    try {
      // Le nom déclaré d'un document est celui que l'ouvreur du système
      // montrera ; l'image et la vidéo gardent le nom de l'outbox.
      final name = meta['name'];
      final path = await _store.adopt(
        messageId: messageId,
        sourcePath: source,
        fileName: name is String && name.trim().isNotEmpty ? name.trim() : null,
      );
      final thumbSource = pending.mediaThumbPath;
      final thumb = thumbSource == null
          ? null
          : await _store.adopt(
              messageId: messageId,
              sourcePath: thumbSource,
              thumbnail: true,
            );
      if (path == null && thumb == null) return;

      await _dao.rememberLocalMedia(messageId, path: path, thumbPath: thumb);
      // L'écho cite désormais le fichier **là où il vit**. Deux raisons : la
      // bulle de l'écho continue de montrer la vignette le temps que la ligne
      // autoritaire arrive, et le balayage ne voit plus un chemin d'outbox
      // qu'il croirait à garder.
      await _dao.updatePendingMedia(
        pending.clientMessageId,
        PendingGroupMessagesCompanion(
          mediaPath: path == null ? const Value.absent() : Value(path),
          mediaThumbPath: thumb == null ? const Value.absent() : Value(thumb),
        ),
      );
    } on Object {
      // Voir ci-dessus : le message est parti, c'est tout ce qui compte.
    }
  }

  /// **Dégrade** une image ou une vidéo, une fois : le type posé dit « prêt ».
  Future<PendingGroupMessageRow> _prepare(
      PendingGroupMessageRow pending) async {
    if (pending.mediaMime != null) return pending;
    final source = pending.mediaPath;
    if (source == null || !File(source).existsSync()) {
      throw const FileSystemException('source absente');
    }
    final id = pending.clientMessageId;
    final meta = MessageMedia.decodeMeta(pending.mediaMeta);

    if (pending.mediaKind == 'image') {
      final prepared = await _preparer.prepareImage(
          source, await _outbox.pathFor('$id.jpg'));
      await _dao.updatePendingMedia(
        id,
        PendingGroupMessagesCompanion(
          mediaPath: Value(prepared.path),
          mediaMime: const Value('image/jpeg'),
          mediaSize: Value(prepared.sizeBytes),
          mediaMeta: Value(
            jsonEncode({
              ...meta,
              'width': prepared.width,
              'height': prepared.height,
            }),
          ),
        ),
      );
    } else if (pending.mediaKind == 'video') {
      // Le plafond de durée est **servi** : on le lit avant de compresser, pour
      // ne pas dépenser la batterie sur une vidéo qu'on refuserait.
      final limits = await _transport.openUpload(
        groupId: pending.groupId,
        kind: 'video',
      );
      final probe = await _preparer.probeVideo(source);
      final max = limits.maxDurationSeconds;
      if (max != null && probe.durationSeconds > max) {
        throw const _MediaRefused(MediaSendError.tooLong);
      }
      final prepared = await _preparer.prepareVideo(
        source,
        // La compression compte pour la première moitié de l'anneau.
        onProgress: (p) => _progress.report(id, p * 0.5),
      );
      final path = await _outbox.adopt(prepared.path, '$id.mp4');
      final thumb = prepared.thumbPath == null
          ? null
          : await _outbox.adopt(prepared.thumbPath!, '$id-thumb.jpg');
      await _dao.updatePendingMedia(
        id,
        PendingGroupMessagesCompanion(
          mediaPath: Value(path),
          mediaThumbPath: Value(thumb),
          mediaMime: const Value('video/mp4'),
          mediaSize: Value(prepared.sizeBytes),
          mediaDuration: Value(prepared.durationSeconds),
          mediaMeta: Value(
            jsonEncode({
              ...meta,
              if (prepared.width != null) 'width': prepared.width,
              if (prepared.height != null) 'height': prepared.height,
            }),
          ),
        ),
      );
    }
    return (await _dao.pendingById(id))!;
  }

  /// **Monte** le fichier (et la vignette d'une vidéo), une fois : la clé
  /// posée dit « monté ».
  Future<PendingGroupMessageRow> _upload(PendingGroupMessageRow pending) async {
    final id = pending.clientMessageId;
    final kind = pending.mediaKind!;
    final video = kind == 'video';

    if (pending.mediaKey == null) {
      final path = pending.mediaPath;
      if (path == null || !File(path).existsSync()) {
        throw const FileSystemException('fichier absent');
      }
      final meta = MessageMedia.decodeMeta(pending.mediaMeta);
      final voice = meta['voice'] != false;
      final ticket = await _transport.openUpload(
        groupId: pending.groupId,
        kind: kind,
        // Le type d'un document ou d'un fichier audio est **déclaré** ; celui
        // d'un vocal, d'une image, d'une vidéo est fixé par le serveur.
        contentType: kind == 'document' || (kind == 'audio' && !voice)
            ? pending.mediaMime
            : null,
        voice: kind == 'audio' && !voice ? false : null,
      );

      // **Les bornes, avant la montée** : refusé ici, avec sa cause.
      final size = pending.mediaSize ?? await File(path).length();
      if (size > ticket.maxBytes) {
        throw const _MediaRefused(MediaSendError.tooLarge);
      }
      final max = ticket.maxDurationSeconds;
      final duration = pending.mediaDuration;
      if (max != null && duration != null && duration > max) {
        throw const _MediaRefused(MediaSendError.tooLong);
      }

      final base = video ? 0.5 : 0.0;
      final span = video ? 0.45 : 1.0;
      _progress.report(id, base);
      await _transport.upload(
        ticket,
        path,
        onProgress: (p) => _progress.report(id, base + p * span),
      );
      await _dao.updatePendingMedia(
        id,
        PendingGroupMessagesCompanion(mediaKey: Value(ticket.key)),
      );
    }

    final thumbPath = pending.mediaThumbPath;
    if (video &&
        thumbPath != null &&
        pending.mediaThumbnailKey == null &&
        File(thumbPath).existsSync()) {
      final ticket = await _transport.openUpload(
        groupId: pending.groupId,
        kind: 'thumbnail',
      );
      if (await File(thumbPath).length() <= ticket.maxBytes) {
        await _transport.upload(ticket, thumbPath);
        await _dao.updatePendingMedia(
          id,
          PendingGroupMessagesCompanion(mediaThumbnailKey: Value(ticket.key)),
        );
      }
      // Une vignette trop lourde est **omise**, pas bloquante : la vidéo part
      // sans elle, la bulle dessine alors un fond neutre.
    }

    return (await _dao.pendingById(id))!;
  }

  Future<void> _onTransportError(
    String clientMessageId,
    GroupMediaTransportException error,
  ) async {
    final cause = switch (error.code) {
      'E_GROUP_MEDIA_TOO_LARGE' => MediaSendError.tooLarge,
      'E_GROUP_MEDIA_TOO_LONG' => MediaSendError.tooLong,
      'E_GROUP_MEDIA_TYPE_NOT_ALLOWED' => MediaSendError.typeNotAllowed,
      'E_GROUP_MEDIA_META_INVALID' ||
      'E_GROUP_MEDIA_SHAPE_INVALID' =>
        MediaSendError.unreadable,
      _ => null,
    };

    // **L'objet n'existe plus au magasin** (lien expiré, purge des orphelins
    // après 24 h) : on oublie les clés, le prochain essai remonte le fichier.
    if (error.code == 'E_GROUP_MEDIA_MISSING') {
      await _dao.updatePendingMedia(
        clientMessageId,
        const PendingGroupMessagesCompanion(
          mediaKey: Value(null),
          mediaThumbnailKey: Value(null),
        ),
      );
    }
    await _dao.markPendingMediaFailed(clientMessageId, cause?.name);
  }

  static String _extensionOf(String path) {
    final slash = path.lastIndexOf('/');
    final name = slash < 0 ? path : path.substring(slash + 1);
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'bin' : name.substring(dot + 1).toLowerCase();
  }
}

/// Un refus **côté téléphone**, avant toute montée.
class _MediaRefused implements Exception {
  const _MediaRefused(this.error);

  final MediaSendError error;
}
