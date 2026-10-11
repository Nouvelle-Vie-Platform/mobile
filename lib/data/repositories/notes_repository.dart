/// **L'écriture des notes** (#190) — les quatre routes du contrat N1, et rien
/// de la lecture : une note se lit dans le magasin, que le delta remplit.
///
/// ```
/// POST   /notes                 upsert (id UUIDv7 client), guard `api`
/// DELETE /notes/:id             tombstone
/// POST   /notes/categories      upsert
/// DELETE /notes/categories/:id  tombstone + `category_id = NULL` sur mes notes
/// ```
///
/// Corps en **`camelCase`**. L'upsert est **owner-scopé idempotent** (ADR-0018)
/// et porte `clientUpdatedAt` : le serveur ignore un rejeu plus ancien que sa
/// ligne courante (plan §4, piège 5), donc une file hors ligne rejouée en
/// retard n'écrase jamais une frappe faite ailleurs.
///
/// **Silencieux sur l'échec**, comme le rapporteur de progression : hors ligne
/// et 5xx sont des régimes normaux d'un brouillon, et l'envoi se retente — 2 s
/// après la frappe suivante, à la sortie de l'écran, et après chaque cycle de
/// synchronisation réussi. La méthode rend *parti* / *pas parti*, et rien de
/// plus : de quoi retenter, jamais de quoi composer une phrase à l'écran.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../models/note_view.dart';

/// Un identifiant de note ou de catégorie, frappé par ce client.
String mintNoteId() => const Uuid().v7();

/// Ce qu'un upsert de note envoie.
@immutable
class NoteUpsert {
  const NoteUpsert({
    required this.id,
    required this.title,
    required this.content,
    required this.body,
    required this.categoryId,
    required this.pinned,
    required this.teachingId,
    required this.clientCreatedAt,
    required this.clientUpdatedAt,
  });

  final String id;
  final String? title;

  /// Le Delta Quill en JSON, déjà encodé.
  final String? content;
  final String body;
  final String? categoryId;
  final bool pinned;
  final String? teachingId;
  final DateTime clientCreatedAt;
  final DateTime clientUpdatedAt;
}

abstract interface class NotesRepository {
  Future<bool> upsertNote(NoteUpsert note);
  Future<bool> deleteNote(String id);
  Future<bool> upsertCategory({
    required String id,
    required String name,
    required NoteColor color,
    required DateTime clientCreatedAt,
  });
  Future<bool> deleteCategory(String id);
}

class HttpNotesRepository implements NotesRepository {
  HttpNotesRepository({ApiClient? client})
      : _dio = (client ?? ApiClient.instance).dio;

  final Dio _dio;

  /// Le dernier échec avalé, pour les tests — aucun écran ne le lit.
  @visibleForTesting
  Object? lastFailure;

  @override
  Future<bool> upsertNote(NoteUpsert note) =>
      _send(() => _dio.post<void>('/notes', data: noteUpsertPayload(note)));

  @override
  Future<bool> deleteNote(String id) =>
      _send(() => _dio.delete<void>('/notes/$id'));

  @override
  Future<bool> upsertCategory({
    required String id,
    required String name,
    required NoteColor color,
    required DateTime clientCreatedAt,
  }) =>
      _send(() => _dio.post<void>('/notes/categories', data: {
            'id': id,
            'name': name,
            'color': color.name,
            'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
          }));

  @override
  Future<bool> deleteCategory(String id) =>
      _send(() => _dio.delete<void>('/notes/categories/$id'));

  Future<bool> _send(Future<void> Function() call) async {
    try {
      await call();
      lastFailure = null;
      return true;
    } on DioException catch (e) {
      // Un 404 sur un DELETE est un succès : la ligne est déjà partie.
      if (e.response?.statusCode == 404 &&
          e.requestOptions.method == 'DELETE') {
        lastFailure = null;
        return true;
      }
      lastFailure = e;
      return false;
    }
  }
}

/// Le corps de `POST /notes`, en `camelCase`. Fonction de bibliothèque pour
/// rester testable sans réseau.
@visibleForTesting
Map<String, Object?> noteUpsertPayload(NoteUpsert note) => {
      'id': note.id,
      'title': note.title,
      'content': note.content == null ? null : jsonDecodeContent(note.content!),
      'body': note.body,
      'categoryId': note.categoryId,
      'pinned': note.pinned,
      'teachingId': note.teachingId,
      'clientCreatedAt': note.clientCreatedAt.toUtc().toIso8601String(),
      'clientUpdatedAt': note.clientUpdatedAt.toUtc().toIso8601String(),
    };

/// Le Delta voyage comme un **objet** JSON, pas comme une chaîne : le serveur
/// le valide `ops` par `ops`.
Object? jsonDecodeContent(String content) {
  try {
    return jsonDecode(content);
  } on FormatException {
    return null;
  }
}

/// Le double **inerte** : sans backend, et dans les tests qui ne parlent pas
/// de réseau. Tout part — il n'y a nulle part où aller.
class InertNotesRepository implements NotesRepository {
  const InertNotesRepository();

  @override
  Future<bool> upsertNote(NoteUpsert note) async => true;

  @override
  Future<bool> deleteNote(String id) async => true;

  @override
  Future<bool> upsertCategory({
    required String id,
    required String name,
    required NoteColor color,
    required DateTime clientCreatedAt,
  }) async =>
      true;

  @override
  Future<bool> deleteCategory(String id) async => true;
}
