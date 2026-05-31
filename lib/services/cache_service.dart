import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/banner_item.dart';

/// Simple SharedPreferences-backed cache with per-key TTL.
class CacheService {
  static const _ttl = Duration(hours: 24);

  static String _tsKey(String key) => '${key}_ts';

  // ── List types ────────────────────────────────────────────────────────

  static const _listTypesKey = 'cache_list_types';

  Future<void> saveListTypes(Map<String, String> types) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listTypesKey, jsonEncode(types));
    await prefs.setInt(_tsKey(_listTypesKey), _now());
  }

  Future<Map<String, String>?> loadListTypes() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isExpired(prefs, _listTypesKey)) return null;
    final raw = prefs.getString(_listTypesKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  // ── Todo banners ──────────────────────────────────────────────────────

  static const _todoBannersKey = 'cache_todo_banners';

  Future<void> saveTodoBanners(List<BannerItem> banners) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(banners.map(_bannerToJson).toList());
    await prefs.setString(_todoBannersKey, encoded);
    await prefs.setInt(_tsKey(_todoBannersKey), _now());
  }

  Future<List<BannerItem>?> loadTodoBanners() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isExpired(prefs, _todoBannersKey)) return null;
    final raw = prefs.getString(_todoBannersKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => BannerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Invalidation ──────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_listTypesKey);
    await prefs.remove(_tsKey(_listTypesKey));
    await prefs.remove(_todoBannersKey);
    await prefs.remove(_tsKey(_todoBannersKey));
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  int _now() => DateTime.now().millisecondsSinceEpoch;

  bool _isExpired(SharedPreferences prefs, String key) {
    final ts = prefs.getInt(_tsKey(key));
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ts > _ttl.inMilliseconds;
  }

  static Map<String, dynamic> _bannerToJson(BannerItem b) => {
        'id': b.id,
        'uuid': b.uuid,
        'title': b.title,
        'description': b.description,
        'width': b.width,
        'numberOfMissions': b.numberOfMissions,
        'numberOfSubmittedMissions': b.numberOfSubmittedMissions,
        'numberOfDisabledMissions': b.numberOfDisabledMissions,
        'startLatitude': b.startLatitude,
        'startLongitude': b.startLongitude,
        'formattedAddress': b.formattedAddress,
        'lengthMeters': b.lengthMeters,
        'picture': b.picture,
        'type': b.type,
        'warning': b.warning,
        'plannedOfflineDate': b.plannedOfflineDate,
        'eventStartDate': b.eventStartDate,
        'eventEndDate': b.eventEndDate,
      };
}
