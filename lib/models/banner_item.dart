import 'mission_item.dart';

class BannerItem {
  final String id;
  final String? uuid;
  final String title;
  final String? description;
  final int width;
  final int? numberOfMissions;
  final int? numberOfSubmittedMissions;
  final int? numberOfDisabledMissions;
  final double? startLatitude;
  final double? startLongitude;
  final String? formattedAddress;
  final int? lengthMeters;
  final String? picture;
  final String? type;
  final String? warning;
  final String? plannedOfflineDate;
  final String? eventStartDate;
  final String? eventEndDate;
  /// Bannergress server-side list type returned when fetching with auth token.
  final String? listType;
  // Ordered by position key; only populated from GET /bnrs/{id}
  final List<MissionItem> missions;

  const BannerItem({
    required this.id,
    required this.title,
    this.uuid,
    this.description,
    this.width = 1,
    this.numberOfMissions,
    this.numberOfSubmittedMissions,
    this.numberOfDisabledMissions,
    this.startLatitude,
    this.startLongitude,
    this.formattedAddress,
    this.lengthMeters,
    this.picture,
    this.type,
    this.warning,
    this.plannedOfflineDate,
    this.eventStartDate,
    this.eventEndDate,
    this.listType,
    this.missions = const [],
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json['id'] as String? ?? '',
        uuid: json['uuid'] as String?,
        title: json['title'] as String? ?? 'Untitled',
        description: json['description'] as String?,
        width: json['width'] as int? ?? 1,
        numberOfMissions: json['numberOfMissions'] as int?,
        numberOfSubmittedMissions:
            json['numberOfSubmittedMissions'] as int?,
        numberOfDisabledMissions:
            json['numberOfDisabledMissions'] as int?,
        startLatitude: (json['startLatitude'] as num?)?.toDouble(),
        startLongitude: (json['startLongitude'] as num?)?.toDouble(),
        formattedAddress: json['formattedAddress'] as String?,
        lengthMeters: json['lengthMeters'] as int?,
        picture: json['picture'] as String?,
        type: json['type'] as String?,
        warning: json['warning'] as String?,
        plannedOfflineDate: json['plannedOfflineDate'] as String?,
        eventStartDate: json['eventStartDate'] as String?,
        eventEndDate: json['eventEndDate'] as String?,
        listType: json['listType'] as String?,
        missions: _parseMissions(json['missions']),
      );

  static List<MissionItem> _parseMissions(dynamic raw) {
    if (raw is! Map<String, dynamic>) return [];
    final entries = raw.entries.toList()
      ..sort((a, b) {
        final ia = int.tryParse(a.key) ?? 0;
        final ib = int.tryParse(b.key) ?? 0;
        return ia.compareTo(ib);
      });
    return entries
        .map((e) => MissionItem.fromJson(e.value as Map<String, dynamic>))
        .toList();
  }

  // Mirrors OpenBanners toAbsoluteImageUrl: handles relative and absolute picture values.
  String get pictureUrl {
    const base = 'https://api.bannergress.com';
    if (picture == null || picture!.isEmpty) {
      return '$base/bnrs/$id/picture';
    }
    if (picture!.startsWith('http://') || picture!.startsWith('https://')) {
      return picture!;
    }
    return '$base/${picture!.replaceAll(RegExp(r'^/+'), '')}';
  }

  String get bannerUrl => 'https://bannergress.com/banner/$id';
}
