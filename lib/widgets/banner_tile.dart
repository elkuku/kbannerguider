import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/banner_item.dart';
import '../services/banner_service.dart';
import '../utils/format.dart';
import '../widgets/full_image_dialog.dart';
import '../screens/banner_detail_page.dart';

class BannerTile extends StatelessWidget {
  const BannerTile({
    super.key,
    required this.banner,
    required this.bannerService,
    required this.listTypes,
    this.listType,
    this.distance,
    this.isSignedIn = false,
    this.getToken,
    this.onListTypesUpdated,
  });

  final BannerItem banner;
  final BannerService bannerService;
  final Map<String, String> listTypes;
  /// Pre-computed badge value — null means no badge shown.
  final String? listType;
  /// Pre-computed formatted distance string.
  final String? distance;
  final bool isSignedIn;
  final Future<String?> Function()? getToken;
  final void Function(Map<String, String>)? onListTypesUpdated;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (banner.numberOfMissions != null)
        '${banner.numberOfMissions} mission'
        '${banner.numberOfMissions == 1 ? '' : 's'}',
      ?distance,
    ];

    return ListTile(
      onTap: () async {
        final updated = await Navigator.push<Map<String, String>>(
          context,
          MaterialPageRoute(
            builder: (_) => BannerDetailPage(
              banner: banner,
              bannerService: bannerService,
              listTypes: listTypes,
              getToken: getToken,
            ),
          ),
        );
        if (updated != null) onListTypesUpdated?.call(updated);
      },
      leading: Hero(
        tag: 'banner-${banner.id}',
        child: GestureDetector(
          onTap: () => showFullImage(context, banner.pictureUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: banner.pictureUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const Icon(Icons.map, size: 48),
            ),
          ),
        ),
      ),
      title: Text(banner.title),
      subtitle: (subtitleParts.isNotEmpty ||
              banner.formattedAddress != null ||
              (isSignedIn && banner.authorAgent != null) ||
              banner.warning != null)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitleParts.isNotEmpty)
                  Text(subtitleParts.join('  ·  ')),
                if (banner.formattedAddress != null)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          banner.formattedAddress!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (isSignedIn && banner.authorAgent != null)
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 12,
                          color: factionColor(banner.authorAgent!.faction)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          banner.authorAgent!.name,
                          style: TextStyle(
                              fontSize: 12,
                              color: factionColor(
                                  banner.authorAgent!.faction)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (banner.warning != null)
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          banner.warning!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.amber),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (banner.missions.any(
                (m) => m.steps.any((s) => s.objective == 'enterPassphrase'),
              ))
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.key_outlined, size: 16, color: Colors.amber),
            ),
          if (listType != null && listType != 'none')
            _ListTypeBadge(listType: listType!),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _ListTypeBadge extends StatelessWidget {
  const _ListTypeBadge({required this.listType});
  final String listType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (listType) {
      'todo' => (Icons.bookmark_outline, Colors.blue),
      'done' => (Icons.check_circle_outline, Colors.green),
      'blacklist' => (Icons.block, Colors.red),
      _ => (Icons.label_outline, Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
