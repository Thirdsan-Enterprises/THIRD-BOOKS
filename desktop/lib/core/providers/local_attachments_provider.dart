// Local Attachments Provider — Web Edition
// Tracks attachment metadata in-memory and persists via SharedPreferences.
// File bytes are NOT stored locally; uploads go directly to the server API.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class LocalAttachment {
  final String id;
  final String attachableType;
  final String localRecordId;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final String status; // 'pending' | 'synced' | 'error'
  final int? serverAttachmentId;
  final String? serverUrl;
  final DateTime createdAt;

  const LocalAttachment({
    required this.id,
    required this.attachableType,
    required this.localRecordId,
    required this.fileName,
    this.mimeType,
    this.fileSize,
    this.status = 'pending',
    this.serverAttachmentId,
    this.serverUrl,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
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
        mimeType: j['mimeType'] as String?,
        fileSize: j['fileSize'] as int?,
        status: j['status'] as String? ?? 'pending',
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
      final list = await _storage.loadData(
          'local_attachments', LocalAttachment.fromJson);
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    await _storage.saveData(
        'local_attachments', state, (a) => a.toJson());
  }

  /// Register an attachment (metadata only — the caller handles the upload).
  Future<LocalAttachment> add({
    required String id,
    required String attachableType,
    required String localRecordId,
    required String fileName,
    String? mimeType,
    int? fileSize,
  }) async {
    final att = LocalAttachment(
      id: id,
      attachableType: attachableType,
      localRecordId: localRecordId,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    state = [att, ...state];
    await _save();
    return att;
  }

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

  Future<void> markError(String id) async {
    state = state
        .map((a) => a.id == id ? a.copyWith(status: 'error') : a)
        .toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _save();
  }

  List<LocalAttachment> forRecord(
          String attachableType, String localRecordId) =>
      state
          .where((a) =>
              a.attachableType == attachableType &&
              a.localRecordId == localRecordId)
          .toList();

  Future<void> clearAll() async {
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
