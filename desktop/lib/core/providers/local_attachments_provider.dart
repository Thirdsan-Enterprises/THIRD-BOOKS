// Local Attachments Provider
// Offline-first attachment system. Files are copied to local app storage
// immediately on pick; server upload is a background concern.
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../services/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class LocalAttachment {
  final String id; // UUID — local primary key
  final String attachableType; // 'bill' | 'invoice' | 'journal-entry' | etc.
  final String localRecordId; // UUID of the parent record (always local)
  final String fileName;
  final String localPath; // absolute path inside app storage
  final String? mimeType;
  final int? fileSize; // bytes
  final String status; // 'local' | 'synced' | 'error'
  final int? serverAttachmentId; // populated after successful server upload
  final String? serverUrl; // populated after successful server upload
  final DateTime createdAt;

  const LocalAttachment({
    required this.id,
    required this.attachableType,
    required this.localRecordId,
    required this.fileName,
    required this.localPath,
    this.mimeType,
    this.fileSize,
    this.status = 'local',
    this.serverAttachmentId,
    this.serverUrl,
    required this.createdAt,
  });

  bool get isLocal => status == 'local';
  bool get isSynced => status == 'synced';

  String get sizeHuman {
    final b = fileSize ?? 0;
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b > 0) return '$b B';
    return '';
  }

  LocalAttachment copyWith({
    String? status,
    int? serverAttachmentId,
    String? serverUrl,
  }) =>
      LocalAttachment(
        id: id,
        attachableType: attachableType,
        localRecordId: localRecordId,
        fileName: fileName,
        localPath: localPath,
        mimeType: mimeType,
        fileSize: fileSize,
        status: status ?? this.status,
        serverAttachmentId: serverAttachmentId ?? this.serverAttachmentId,
        serverUrl: serverUrl ?? this.serverUrl,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'attachableType': attachableType,
        'localRecordId': localRecordId,
        'fileName': fileName,
        'localPath': localPath,
        'mimeType': mimeType,
        'fileSize': fileSize,
        'status': status,
        'serverAttachmentId': serverAttachmentId,
        'serverUrl': serverUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LocalAttachment.fromJson(Map<String, dynamic> j) => LocalAttachment(
        id: j['id'] as String,
        attachableType: j['attachableType'] as String,
        localRecordId: j['localRecordId'] as String,
        fileName: j['fileName'] as String,
        localPath: j['localPath'] as String,
        mimeType: j['mimeType'] as String?,
        fileSize: j['fileSize'] as int?,
        status: j['status'] as String? ?? 'local',
        serverAttachmentId: j['serverAttachmentId'] as int?,
        serverUrl: j['serverUrl'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------
class LocalAttachmentsNotifier extends StateNotifier<List<LocalAttachment>> {
  final LocalStorageService _storage;

  LocalAttachmentsNotifier(this._storage) : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await _storage.loadData('local_attachments', LocalAttachment.fromJson);
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    await _storage.saveData(
        'local_attachments', state, (a) => a.toJson());
  }

  // Returns the directory where attachments for a given type+record are stored.
  static Future<Directory> _attachmentDir(
      String attachableType, String localRecordId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
        '${appDir.path}/thirdbooks_attachments/$attachableType/$localRecordId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copy [sourcePath] into local app storage and register the attachment.
  /// Returns the newly created [LocalAttachment].
  Future<LocalAttachment> addFromPath({
    required String id,
    required String attachableType,
    required String localRecordId,
    required String sourcePath,
    required String fileName,
    String? mimeType,
    int? fileSize,
  }) async {
    final dir = await _attachmentDir(attachableType, localRecordId);
    // Use id-prefixed name to avoid collisions when re-adding same filename.
    final destPath = '${dir.path}/${id}_$fileName';

    try {
      await File(sourcePath).copy(destPath);
    } catch (e) {
      debugPrint('LocalAttachments: copy failed: $e — using source path');
    }

    final att = LocalAttachment(
      id: id,
      attachableType: attachableType,
      localRecordId: localRecordId,
      fileName: fileName,
      localPath: destPath,
      mimeType: mimeType,
      fileSize: fileSize,
      status: 'local',
      createdAt: DateTime.now(),
    );

    state = [att, ...state];
    await _save();
    return att;
  }

  /// Mark an attachment as synced to the server.
  Future<void> markSynced(
      String id, int serverAttachmentId, String serverUrl) async {
    state = state
        .map((a) => a.id == id
            ? a.copyWith(
                status: 'synced',
                serverAttachmentId: serverAttachmentId,
                serverUrl: serverUrl,
              )
            : a)
        .toList();
    await _save();
  }

  /// Mark an attachment as errored (e.g. upload failed permanently).
  Future<void> markError(String id) async {
    state = state
        .map((a) => a.id == id ? a.copyWith(status: 'error') : a)
        .toList();
    await _save();
  }

  /// Delete an attachment from local storage and metadata.
  Future<void> remove(String id) async {
    final att = state.firstWhere((a) => a.id == id, orElse: () => throw StateError('not found'));
    // Delete the local file if it exists
    try {
      final file = File(att.localPath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('LocalAttachments: delete file error: $e');
    }
    state = state.where((a) => a.id != id).toList();
    await _save();
  }

  /// All attachments for a specific record.
  List<LocalAttachment> forRecord(String attachableType, String localRecordId) =>
      state
          .where((a) =>
              a.attachableType == attachableType &&
              a.localRecordId == localRecordId)
          .toList();

  /// Clear all attachments and delete their local files.
  /// Used by the settings "clear cache" action.
  Future<void> clearAll() async {
    for (final att in state) {
      try {
        final file = File(att.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    state = [];
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final localAttachmentsProvider =
    StateNotifierProvider<LocalAttachmentsNotifier, List<LocalAttachment>>(
  (ref) => LocalAttachmentsNotifier(ref.read(localStorageServiceProvider)),
);
