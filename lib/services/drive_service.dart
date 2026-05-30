import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveService {
  static const _dataFileName = 'kbannerguider_data.json';
  static const _scopes = [drive.DriveApi.driveFileScope];

  /// Exposes a human-readable log of the last operation for debug display.
  final ValueNotifier<String> debugLog = ValueNotifier('—');

  void _log(String msg) => debugLog.value = msg;

  Future<drive.DriveApi?> _getApi() async {
    try {
      _log('Trying silent authorization for drive.file scope…');
      var authorization = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes(_scopes);

      if (authorization == null) {
        _log('Silent auth returned null — requesting interactive consent…');
        authorization = await GoogleSignIn.instance.authorizationClient
            .authorizeScopes(_scopes);
      }

      _log('Authorization granted, building DriveApi client…');
      return drive.DriveApi(authorization.authClient(scopes: _scopes));
    } catch (e) {
      _log('Auth error: $e');
      return null;
    }
  }

  Future<Map<String, String>> loadListTypes() async {
    _log('loadListTypes: starting…');
    final api = await _getApi();
    if (api == null) return {};

    try {
      _log('Listing files matching "$_dataFileName"…');
      final result = await api.files.list(
        spaces: 'drive',
        q: "name = '$_dataFileName' and trashed = false",
        $fields: 'files(id,name)',
      );

      final files = result.files;
      if (files == null || files.isEmpty) {
        _log('No existing file found — will create on first save.');
        return {};
      }

      final fileId = files.first.id!;
      _log('Found file id=$fileId, downloading…');

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await media.stream.forEach(bytes.addAll);
      final content = utf8.decode(bytes);
      _log('Downloaded ${bytes.length} bytes: $content');

      final json = jsonDecode(content) as Map<String, dynamic>;
      final types = (json['listTypes'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
          {};
      _log('Loaded ${types.length} list-type entries.');
      return types;
    } catch (e) {
      _log('Load error: $e');
      return {};
    }
  }

  Future<void> saveListTypes(Map<String, String> listTypes) async {
    _log('saveListTypes: starting (${listTypes.length} entries)…');
    final api = await _getApi();
    if (api == null) return;

    try {
      final content = jsonEncode({'listTypes': listTypes});
      final bytes = utf8.encode(content);
      _log('Payload: $content');

      drive.Media buildMedia() => drive.Media(
            Stream.value(bytes),
            bytes.length,
            contentType: 'application/json',
          );

      _log('Listing existing files…');
      final result = await api.files.list(
        spaces: 'drive',
        q: "name = '$_dataFileName' and trashed = false",
        $fields: 'files(id)',
      );

      final files = result.files;
      if (files != null && files.isNotEmpty) {
        final fileId = files.first.id!;
        _log('Updating existing file id=$fileId…');
        await api.files.update(
          drive.File(),
          fileId,
          uploadMedia: buildMedia(),
        );
        _log('Update successful.');
      } else {
        _log('No existing file — creating new file…');
        final created = await api.files.create(
          drive.File()
            ..name = _dataFileName
            ..mimeType = 'application/json',
          uploadMedia: buildMedia(),
        );
        _log('Created file id=${created.id}.');
      }
    } catch (e) {
      _log('Save error: $e');
    }
  }
}
