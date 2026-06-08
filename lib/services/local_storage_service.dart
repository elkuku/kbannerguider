import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local storage for list types and guider progress.
/// Replaces the Google Drive backend — all data lives in SharedPreferences.
class LocalStorageService {
  static const _listTypesKey = 'local_list_types';
  static const _guiderProgressKey = 'local_guider_progress';

  Future<Map<String, String>> loadListTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listTypesKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  Future<void> saveListTypes(Map<String, String> listTypes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listTypesKey, jsonEncode(listTypes));
  }

  Future<({int index, String missionId})?> loadGuiderProgress(
      String bannerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guiderProgressKey);
    if (raw == null) return null;
    final all = jsonDecode(raw) as Map<String, dynamic>;
    final entry = all[bannerId] as Map<String, dynamic>?;
    if (entry == null) return null;
    return (
      index: (entry['index'] as num).toInt(),
      missionId: entry['missionId'] as String,
    );
  }

  Future<void> saveGuiderProgress(
      String bannerId, int index, String missionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guiderProgressKey);
    final all = raw != null
        ? Map<String, dynamic>.of(jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};
    all[bannerId] = {'index': index, 'missionId': missionId};
    await prefs.setString(_guiderProgressKey, jsonEncode(all));
  }

  Future<void> clearGuiderProgress(String bannerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guiderProgressKey);
    if (raw == null) return;
    final all = Map<String, dynamic>.of(jsonDecode(raw) as Map<String, dynamic>);
    all.remove(bannerId);
    await prefs.setString(_guiderProgressKey, jsonEncode(all));
  }
}
