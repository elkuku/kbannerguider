import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/banner_item.dart';

class BannerService {
  final http.Client _client;

  BannerService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<BannerItem>> fetchNearby({
    required double latitude,
    required double longitude,
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      'https://api.bannergress.com/bnrs'
      '?orderBy=proximityStartPoint'
      '&orderDirection=ASC'
      '&online=true'
      '&proximityLatitude=$latitude'
      '&proximityLongitude=$longitude'
      '&limit=$limit',
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(BannerItem.fromJson)
        .toList();
  }

  Future<BannerItem> fetchById(String id) async {
    final uri = Uri.parse(
      'https://api.bannergress.com/bnrs/${Uri.encodeComponent(id)}',
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    return BannerItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
