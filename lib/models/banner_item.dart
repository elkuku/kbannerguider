class BannerItem {
  final String id;
  final String title;
  final int? numberOfMissions;

  const BannerItem({
    required this.id,
    required this.title,
    this.numberOfMissions,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        numberOfMissions: json['numberOfMissions'] as int?,
      );

  String get pictureUrl => 'https://api.bannergress.com/bnrs/$id/picture';
}
