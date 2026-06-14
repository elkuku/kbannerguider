import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/banner_item.dart';

class BannerService {
  static const int pageSize = 25;

  // Default list attributes + missions + warning, so the list endpoint
  // returns mission author data and warning text alongside the normal fields.
  static const _listAttributes = [
    'id', 'title', 'numberOfMissions', 'numberOfSubmittedMissions',
    'numberOfDisabledMissions', 'lengthMeters', 'startLatitude',
    'startLongitude', 'picture', 'width', 'startPlaceId', 'formattedAddress',
    'listType', 'missions', 'warning',
  ];

  final http.Client _client;

  BannerService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<BannerItem>> fetchNearby({
    required double latitude,
    required double longitude,
    int offset = 0,
    String? accessToken,
  }) async {
    final query = [
      'orderBy=proximityStartPoint',
      'orderDirection=ASC',
      'online=true',
      'proximityLatitude=$latitude',
      'proximityLongitude=$longitude',
      'offset=$offset',
      'limit=$pageSize',
      if (accessToken != null) ..._listAttributes.map((a) => 'attributes=$a'),
    ].join('&');
    final uri = Uri.parse('https://api.bannergress.com/bnrs?$query');

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

  Future<BannerItem> fetchById(String id, {String? accessToken}) async {
    final uri = Uri.parse(
      'https://api.bannergress.com/bnrs/${Uri.encodeComponent(id)}',
    );

    final headers = accessToken != null
        ? {'Authorization': 'Bearer $accessToken'}
        : <String, String>{};

    final response = await _client.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    return BannerItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Sets the list type for a banner on Bannergress.
  Future<void> setListType(
      String bannerId, String listType, String accessToken) async {
    final uri = Uri.parse(
      'https://api.bannergress.com/bnrs/${Uri.encodeComponent(bannerId)}/settings',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: '{"listType":"$listType"}',
    );
    if (response.statusCode == 401) throw SessionExpiredException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Server returned ${response.statusCode}');
    }
  }

  /// Fetches the authenticated user's banners for a given list type.
  /// Throws [SessionExpiredException] if the token is no longer valid.
  Future<List<BannerItem>> fetchByListType({
    required String listType,
    required String accessToken,
    int offset = 0,
    int limit = 100,
  }) async {
    final query = [
      'listTypes=$listType',
      'orderBy=listAdded',
      'orderDirection=DESC',
      'offset=$offset',
      'limit=$limit',
      ..._listAttributes.map((a) => 'attributes=$a'),
    ].join('&');
    final uri = Uri.parse('https://api.bannergress.com/bnrs?$query');

    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode == 401) throw SessionExpiredException();
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
