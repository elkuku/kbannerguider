import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/banner_item.dart';

class BannerService {
  static const int pageSize = 25;

  final http.Client _client;

  BannerService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<BannerItem>> fetchNearby({
    required double latitude,
    required double longitude,
    int offset = 0,
    String? accessToken,
  }) async {
    final uri = Uri.parse(
      'https://api.bannergress.com/bnrs'
      '?orderBy=proximityStartPoint'
      '&orderDirection=ASC'
      '&online=true'
      '&proximityLatitude=$latitude'
      '&proximityLongitude=$longitude'
      '&offset=$offset'
      '&limit=$pageSize',
    );

    final headers = accessToken != null
        ? {'Authorization': 'Bearer $accessToken'}
        : <String, String>{};

    final response = await _client.get(uri, headers: headers);

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

  /// Fetches the authenticated user's todo list from Bannergress.
  /// Throws [SessionExpiredException] if the token is no longer valid.
  Future<List<BannerItem>> fetchTodos({
    required String accessToken,
    int offset = 0,
    int limit = 100,
  }) async {
    final uri =
        Uri.parse('https://api.bannergress.com/bnrs').replace(queryParameters: {
      'listTypes': 'todo',
      'orderBy': 'listAdded',
      'orderDirection': 'DESC',
      'offset': offset.toString(),
      'limit': limit.toString(),
    });

    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode == 401) {
      throw SessionExpiredException();
    }

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> items =
        data is List ? data : ((data as Map<String, dynamic>)['banners'] ?? []);
    return items.cast<Map<String, dynamic>>().map(BannerItem.fromJson).toList();
  }
}

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired — please sign in again.';
}
