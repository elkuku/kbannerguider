import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Structure of the data file on Drive:
/// ```json
/// {
///   "listTypes":      { "bannerId": "todo|done|blacklist" },
///   "guiderProgress": { "bannerId": { "index": 2, "missionId": "abc" } }
/// }
/// ```
class DriveService {
  static const _dataFileName = 'kbannerguider_data.json';
  static const _scopes = [drive.DriveApi.driveFileScope];

  final ValueNotifier<String> debugLog = ValueNotifier('—');

  // Cache the Drive file ID to avoid repeated list queries.
  String? _fileId;

  // In-memory cache of the Drive JSON payload — avoids a download before
  // every write (which would otherwise double the network round-trips).
  Map<String, dynamic>? _cachedData;

  // Cached DriveApi instance — re-used across calls until invalidated.
  drive.DriveApi? _cachedApi;

  void _log(String msg) => debugLog.value = msg;

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<drive.DriveApi?> _getApi() async {
    if (_cachedApi != null) return _cachedApi;
    try {
      _log('Trying silent authorization for drive.file scope…');
      var authorization = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes(_scopes);

      if (authorization == null) {
        _log('Silent auth returned null — requesting interactive consent…');
        authorization = await GoogleSignIn.instance.authorizationClient
            .authorizeScopes(_scopes);
      }

      _log('Authorization granted.');
      _cachedApi = drive.DriveApi(authorization.authClient(scopes: _scopes));
      return _cachedApi;
    } catch (e) {
      _log('Auth error: $e');
      return null;
    }
  }

  /// Clears all cached state (API client, data, file ID).
  /// Call this when the user signs out.
  void invalidate() {
    _cachedApi = null;
    _cachedData = null;
    _fileId = null;
  }

  // ── Low-level file helpers ────────────────────────────────────────────────

  Future<String?> _resolveFileId(drive.DriveApi api) async {
    if (_fileId != null) return _fileId;
    final result = await api.files.list(
      spaces: 'drive',
      q: "name = '$_dataFileName' and trashed = false",
      $fields: 'files(id)',
    );
    _fileId = result.files?.firstOrNull?.id;
    return _fileId;
  }

  Future<Map<String, dynamic>> _loadData() async {
    // Return in-memory cache when available.
    if (_cachedData != null) return _cachedData!;

    final api = await _getApi();
    if (api == null) return {};

    try {
      final fileId = await _resolveFileId(api);
      if (fileId == null) {
        _log('No data file found on Drive.');
        _cachedData = {};
        return _cachedData!;
      }

      _log('Downloading data file id=$fileId…');
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await media.stream.forEach(bytes.addAll);
      final content = utf8.decode(bytes);
      _log('Downloaded ${bytes.length} bytes.');
      _cachedData = jsonDecode(content) as Map<String, dynamic>;
      return _cachedData!;
    } catch (e) {
      _log('Load error: $e');
      _cachedData = {};
      return _cachedData!;
    }
  }

  Future<void> _saveData(Map<String, dynamic> data) async {
    // Keep in-memory cache in sync immediately (optimistic update).
    _cachedData = data;

    final api = await _getApi();
    if (api == null) return;

    try {
      final bytes = utf8.encode(jsonEncode(data));
      drive.Media buildMedia() => drive.Media(
            Stream.value(bytes),
            bytes.length,
            contentType: 'application/json',
          );

      final existingId = await _resolveFileId(api);
      if (existingId != null) {
        _log('Updating file id=$existingId…');
        await api.files.update(drive.File(), existingId,
            uploadMedia: buildMedia());
        _log('Update successful.');
      } else {
        _log('Creating new data file…');
        final created = await api.files.create(
          drive.File()
            ..name = _dataFileName
            ..mimeType = 'application/json',
          uploadMedia: buildMedia(),
        );
        _fileId = created.id;
        _log('Created file id=${created.id}.');
      }
    } catch (e) {
      _log('Save error: $e');
    }
  }

  // ── List types ─────────────────────────────────────────────────────────────

  Future<Map<String, String>> loadListTypes() async {
    _log('loadListTypes: starting…');
    final data = await _loadData();
    final types =
        (data['listTypes'] as Map<String, dynamic>?)?.cast<String, String>() ??
            {};
    _log('Loaded ${types.length} list-type entries.');
    return types;
  }

  Future<void> saveListTypes(Map<String, String> listTypes) async {
    _log('saveListTypes: ${listTypes.length} entries…');
    // Use cached data — no extra download needed.
    final data = Map<String, dynamic>.of(await _loadData());
    data['listTypes'] = listTypes;
    await _saveData(data);
  }

  // ── Guider progress ────────────────────────────────────────────────────────

  /// Returns `{index, missionId}` for the given banner, or null if none saved.
  Future<({int index, String missionId})?> loadGuiderProgress(
      String bannerId) async {
    _log('loadGuiderProgress: $bannerId');
    final data = await _loadData();
    final raw = (data['guiderProgress'] as Map<String, dynamic>?)?[bannerId]
        as Map<String, dynamic>?;
    if (raw == null) return null;
    return (
      index: (raw['index'] as num).toInt(),
      missionId: raw['missionId'] as String,
    );
  }

  Future<void> saveGuiderProgress(
      String bannerId, int index, String missionId) async {
    _log('saveGuiderProgress: $bannerId index=$index missionId=$missionId');
    final data = Map<String, dynamic>.of(await _loadData());
    final progress =
        Map<String, dynamic>.of((data['guiderProgress'] as Map<String, dynamic>?) ?? {});
    progress[bannerId] = {'index': index, 'missionId': missionId};
    data['guiderProgress'] = progress;
    await _saveData(data);
  }

  Future<void> clearGuiderProgress(String bannerId) async {
    _log('clearGuiderProgress: $bannerId');
    final data = Map<String, dynamic>.of(await _loadData());
    final progress =
        Map<String, dynamic>.of((data['guiderProgress'] as Map<String, dynamic>?) ?? {});
    progress.remove(bannerId);
    data['guiderProgress'] = progress;
    await _saveData(data);
  }
}
