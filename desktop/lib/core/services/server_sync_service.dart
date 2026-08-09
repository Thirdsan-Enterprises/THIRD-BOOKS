import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'local_backup_service.dart';
import 'local_storage_service.dart';
import '../database/app_database.dart';

class ServerBackupPreview {
  final String? syncedAt;
  final double sizeKb;
  final Map<String, int> counts;

  const ServerBackupPreview({
    required this.syncedAt,
    required this.sizeKb,
    required this.counts,
  });
}

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

  static const _defaultSyncUrl = 'https://magicbet.thirdbooks.digital/sync';
  static const _defaultApiKey  = 'tb-sync-magicbet-2026';

  // Always the hardcoded server — deliberately ignores any value a previous
  // build may have written to secure storage via the old manual-config UI.
  // A stale/incorrect stored value would otherwise silently override this
  // permanently and no one would know why sync kept failing.
  static Future<String> getSyncUrl() async => _defaultSyncUrl;

  static Future<String> getApiKey() async => _defaultApiKey;

  static Future<void> saveConfig(String url, String apiKey) async {
    await _storage.write(key: _urlKey, value: url.trimRight().replaceAll(RegExp(r'/$'), ''));
    await _storage.write(key: _keyKey, value: apiKey.trim());
  }

  /// Removes any stale server URL/API key previously saved via the old
  /// manual-config UI so it can never again silently override the
  /// hardcoded defaults above.
  static Future<void> clearStoredOverrides() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _keyKey);
  }

  // Always configured — defaults are baked in.
  static Future<bool> isConfigured() async => true;

  static Future<String?> getLastSyncedAt() async =>
      _storage.read(key: _lastSyncKey);

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  static Future<void> sendHeartbeat(String userName) async {
    try {
      final url    = await getSyncUrl();
      final apiKey = await getApiKey();
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      await dio.post(
        '$url/heartbeat.php',
        data: {'user': userName},
        options: Options(headers: {
          'X-API-Key':    apiKey,
          'Content-Type': 'application/json',
        }),
      );
    } catch (_) {} // silent — never block the app for a heartbeat failure
  }

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

  // ── Preview what a restore would bring back, before committing ─────────────

  /// Fetches just the record counts of the server's latest backup, without
  /// downloading the full (potentially many-MB) file. Lets the UI show
  /// exactly what a restore would overwrite local data with, so "Restore
  /// from Server" is never a blind, irreversible guess.
  static Future<ServerBackupPreview?> previewLatestBackup() async {
    try {
      final url    = await getSyncUrl();
      final apiKey = await getApiKey();
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get(
        '$url/pull.php',
        queryParameters: {'preview': '1'},
        options: Options(headers: {'X-API-Key': apiKey}),
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return ServerBackupPreview(
        syncedAt: data['synced_at'] as String?,
        sizeKb: (data['size_kb'] as num?)?.toDouble() ?? 0,
        counts: (data['counts'] as Map?)?.cast<String, dynamic>().map(
                (k, v) => MapEntry(k, (v as num).toInt())) ??
            {},
      );
    } catch (_) {
      return null;
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
