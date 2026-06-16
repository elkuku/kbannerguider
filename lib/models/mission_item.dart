import '../utils/format.dart';

class AgentItem {
  const AgentItem({required this.name, required this.faction});

  final String name;
  final String faction;

  factory AgentItem.fromJson(Map<String, dynamic> json) => AgentItem(
        name: json['name'] as String? ?? '',
        faction: json['faction'] as String? ?? '',
      );
}

class PoiItem {
  const PoiItem({
    required this.id,
    required this.title,
    this.latitude,
    this.longitude,
    this.picture,
    required this.type,
  });

  final String id;
  final String title;
  final double? latitude;
  final double? longitude;
  final String? picture;
  final String type; // portal | fieldTripWaypoint | unavailable

  factory PoiItem.fromJson(Map<String, dynamic> json) => PoiItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        picture: json['picture'] as String?,
        type: json['type'] as String? ?? 'portal',
      );

  /// geo: URI — Android shows a chooser (Maps, OsmAnd, etc.).
  String? get geoUrl => latitude != null && longitude != null
      ? 'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(title)})'
      : null;
}

class MissionStepItem {
  const MissionStepItem({this.poi, required this.objective});

  final PoiItem? poi;
  final String objective;

  factory MissionStepItem.fromJson(Map<String, dynamic> json) =>
      MissionStepItem(
        poi: json['poi'] != null
            ? PoiItem.fromJson(json['poi'] as Map<String, dynamic>)
            : null,
        objective: json['objective'] as String? ?? '',
      );
}

class MissionItem {
  const MissionItem({
    required this.id,
    required this.title,
    this.picture,
    this.description,
    this.type,
    this.status,
    this.author,
    this.lengthMeters,
    this.averageDurationMilliseconds,
    this.steps = const [],
  });

  final String id;
  final String title;
  final String? picture;
  final String? description;
  final String? type;   // sequential | anyOrder | hidden
  final String? status; // submitted | published | disabled
  final AgentItem? author;
  final int? lengthMeters;
  final int? averageDurationMilliseconds;
  final List<MissionStepItem> steps;

  factory MissionItem.fromJson(Map<String, dynamic> json) => MissionItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        picture: json['picture'] as String?,
        description: json['description'] as String?,
        type: json['type'] as String?,
        status: json['status'] as String?,
        author: json['author'] != null
            ? AgentItem.fromJson(json['author'] as Map<String, dynamic>)
            : null,
        lengthMeters: json['lengthMeters'] as int?,
        averageDurationMilliseconds:
            json['averageDurationMilliseconds'] as int?,
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) =>
                    MissionStepItem.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get pictureUrl => resolvePictureUrl(picture, 'missions/$id/picture');

  /// Deep link that opens the mission directly in the Ingress app (or Intel map).
  String get ingressUrl {
    final intelUrl = Uri.encodeComponent(
        'https://intel.ingress.com/mission/$id');
    final appStoreUrl = Uri.encodeComponent(
        'https://apps.apple.com/app/ingress/id576505181');
    return 'https://link.ingress.com/'
        '?link=$intelUrl'
        '&apn=com.nianticproject.ingress'
        '&isi=576505181'
        '&ibi=com.google.ingress'
        '&ifl=$appStoreUrl'
        '&ofl=$intelUrl';
  }
}
