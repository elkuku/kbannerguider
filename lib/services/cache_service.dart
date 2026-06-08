import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/banner_item.dart';

/// Short-lived cache for todo banner details (avoids re-fetching on tab switch).
class CacheService {
  static const _ttl = Duration(hours: 24);
  static const _todoBannersKey = 'cache_todo_banners';

  static String _tsKey(String key) => '${key}_ts';

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

  Future<void> clearTodoBanners() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_todoBannersKey);
    await prefs.remove(_tsKey(_todoBannersKey));
  }

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
        'listType': b.listType,
      };
}
