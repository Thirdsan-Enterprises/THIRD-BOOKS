import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'local_backup_service.dart';
import 'local_storage_service.dart';
import '../database/app_database.dart';

class ServerSyncResult {
  final bool success;
  final String? error;
  final String? syncedAt;
  final Map<String, int> counts;

  const ServerSyncResult({
    required this.success,
    this.error,
    this.syncedAt,
    this.counts = const {},
  });
}

class ServerSyncService {
  static const _storage = FlutterSecureStorage();
  static const _urlKey     = 'server_sync_url';
  static const _keyKey     = 'server_sync_api_key';
  static const _lastSyncKey = 'server_last_synced_at';

  // ── Configuration ──────────────────────────────────────────────────────────

  static Future<String> getSyncUrl() async =>
      await _storage.read(key: _urlKey) ?? '';

  static Future<String> getApiKey() async =>
      await _storage.read(key: _keyKey) ?? '';

  static Future<void> saveConfig(String url, String apiKey) async {
    await _storage.write(key: _urlKey, value: url.trimRight().replaceAll(RegExp(r'/$'), ''));
    await _storage.write(key: _keyKey, value: apiKey.trim());
  }

  static Future<bool> isConfigured() async {
    final url = await getSyncUrl();
    final key = await getApiKey();
    return url.isNotEmpty && key.isNotEmpty;
  }

  static Future<String?> getLastSyncedAt() async =>
      _storage.read(key: _lastSyncKey);

  // ── Push backup to server ──────────────────────────────────────────────────

  static Future<ServerSyncResult> pushBackup(AppDatabase db) async {
    if (!await isConfigured()) {
      return const ServerSyncResult(success: false, error: 'Server sync not configured');
    }

    try {
      final url    = await getSyncUrl();
      final apiKey = await getApiKey();
      final ls     = LocalStorageService.instance;
      await ls.initialize();

      final svc = LocalBackupService(ls, db);
      final json = await svc.exportAsJson();

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout:    const Duration(seconds: 60),
      ));

      final response = await dio.post(
        '$url/push.php',
        data: json,
        options: Options(headers: {
          'X-API-Key':     apiKey,
          'Content-Type':  'application/json',
        }),
      );

      if (response.statusCode == 200) {
        final now = DateTime.now().toIso8601String();
        await _storage.write(key: _lastSyncKey, value: now);
        final counts = (response.data['records'] as Map?)
            ?.cast<String, int>() ?? {};
        return ServerSyncResult(success: true, syncedAt: now, counts: counts);
      }

      return ServerSyncResult(
        success: false,
        error: 'Server returned ${response.statusCode}',
      );
    } on DioException catch (e) {
      return ServerSyncResult(
        success: false,
        error: e.response?.data?['error'] ?? e.message ?? 'Network error',
      );
    } catch (e) {
      return ServerSyncResult(success: false, error: e.toString());
    }
  }

  // ── Pull and restore from server ───────────────────────────────────────────

  static Future<ServerSyncResult> pullAndRestore(AppDatabase db) async {
    if (!await isConfigured()) {
      return const ServerSyncResult(success: false, error: 'Server sync not configured');
    }

    try {
      final url    = await getSyncUrl();
      final apiKey = await getApiKey();

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ));

      final response = await dio.get<String>(
        '$url/pull.php',
        options: Options(
          headers: {'X-API-Key': apiKey},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return ServerSyncResult(
          success: false,
          error: 'Server returned ${response.statusCode}',
        );
      }

      // Write to a temp file then restore via existing LocalBackupService
      final tmpFile = File(
        '${Directory.systemTemp.path}/thirdbooks_server_restore.json',
      );
      await tmpFile.writeAsString(response.data!);

      final ls  = LocalStorageService.instance;
      await ls.initialize();
      final svc = LocalBackupService(ls, db);
      final result = await svc.restoreFromFile(tmpFile.path);
      await tmpFile.delete();

      return ServerSyncResult(
        success: true,
        counts: result.counts.cast<String, int>(),
        syncedAt: response.headers.value('x-backup-date'),
      );
    } on DioException catch (e) {
      return ServerSyncResult(
        success: false,
        error: e.response?.data ?? e.message ?? 'Network error',
      );
    } catch (e) {
      return ServerSyncResult(success: false, error: e.toString());
    }
  }
}
