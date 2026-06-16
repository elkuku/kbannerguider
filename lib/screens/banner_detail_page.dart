import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/banner_item.dart';
import '../services/banner_service.dart';
import '../utils/format.dart';
import '../utils/gpx.dart';
import '../widgets/banner_map.dart';
import '../widgets/full_image_dialog.dart';
import '../widgets/list_type_selector.dart';
import '../widgets/mission_tile.dart';

class BannerDetailPage extends StatefulWidget {
  const BannerDetailPage({
    super.key,
    required this.banner,
    required this.bannerService,
    this.listTypes = const {},
    this.getToken,
  });

  final BannerItem banner;
  final BannerService bannerService;
  final Map<String, String> listTypes;
  final Future<String?> Function()? getToken;

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage>
    with SingleTickerProviderStateMixin {
  late BannerItem _banner;
  bool _loadingDetail = false;
  late Map<String, String> _listTypes;
  late final TabController _tabController;

  // 0 = ready to start first mission; missions.length = all done.
  int _currentMissionIndex = 0;

  @override
  void initState() {
    super.initState();
    _banner = widget.banner;
    _listTypes = Map.of(widget.listTypes);
    _tabController = TabController(length: 2, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final token = await widget.getToken?.call();
      final full =
          await widget.bannerService.fetchById(_banner.id, accessToken: token);
      if (mounted) setState(() => _banner = full);
    } catch (_) {
      // keep the list data already shown
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  void _setGuiderIndex(int index) {
    setState(
        () => _currentMissionIndex = index.clamp(0, _banner.missions.length));
  }

  Future<void> _launchCurrentMission() async {
    if (_currentMissionIndex >= _banner.missions.length) return;
    final mission = _banner.missions[_currentMissionIndex];
    await launch(mission.ingressUrl);
    _setGuiderIndex(_currentMissionIndex + 1);
  }

  Future<void> _exportGpx() async {
    final hasCoords = _banner.missions.any((m) =>
        m.steps.any((s) => s.poi?.latitude != null && s.poi?.longitude != null));
    if (!hasCoords) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No waypoint coordinates available.')),
        );
      }
      return;
    }
    final gpx = generateGpx(_banner);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_banner.id}.gpx');
    await file.writeAsString(gpx);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: _banner.title,
      ),
    );
  }

  Future<void> _setListType(String type) async {
    final old = _listTypes[_banner.id] ?? 'none';
    if (old == type) return;

    final updated = Map<String, String>.of(_listTypes);
    if (type == 'none') {
      updated.remove(_banner.id);
    } else {
      updated[_banner.id] = type;
    }
    setState(() => _listTypes = updated);

    final token = await widget.getToken?.call();
    if (token != null) {
      await widget.bannerService.setListType(_banner.id, type, token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _listTypes);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_banner.title),
          leading: BackButton(
            onPressed: () => Navigator.pop(context, _listTypes),
          ),
          actions: [
            if (_loadingDetail)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.list_outlined), text: 'Missions'),
                Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(),
                  BannerMap(
                    missions: _banner.missions,
                    loading: _loadingDetail,
                    bannerStartLat: _banner.startLatitude,
                    bannerStartLng: _banner.startLongitude,
                    bannerTitle: _banner.title,
                    bannerAddress: _banner.formattedAddress,
                    currentMissionIndex: _currentMissionIndex,
                    onMissionIndexChanged: _setGuiderIndex,
                    onLaunchMission: _launchCurrentMission,
                    onMarkDone: () async {
                      await _setListType('done');
                      // ignore: use_build_context_synchronously
                      if (mounted) Navigator.pop(context, _listTypes);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'banner-${_banner.id}',
                child: GestureDetector(
                  onTap: () => showFullImage(context, _banner.pictureUrl),
                  child: CachedNetworkImage(
                    imageUrl: _banner.pictureUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child:
                          const Icon(Icons.map, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (_banner.warning != null)
                Container(
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_banner.warning!,
                            style:
                                const TextStyle(color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
              if (_banner.missions.any(
                    (m) =>
                        m.steps.any((s) => s.objective == 'enterPassphrase'),
                  ))
                Container(
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: const Row(
                    children: [
                      Icon(Icons.key_outlined, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'One or more missions require a passphrase.',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_banner.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if (_banner.description != null &&
                        _banner.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_banner.description!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (widget.getToken != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 4),
                      ListTypeSelector(
                        current: _listTypes[_banner.id] ?? 'none',
                        onChanged: _setListType,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (_banner.type != null)
                      InfoRow(
                        icon: Icons.format_list_numbered,
                        label: 'Type',
                        value: _banner.type == 'sequential'
                            ? 'Sequential'
                            : 'Any order',
                      ),
                    if (_banner.numberOfMissions != null)
                      InfoRow(
                        icon: Icons.flag,
                        label: 'Missions',
                        value: _missionsLabel(_banner),
                      ),
                    if (_banner.lengthMeters != null)
                      InfoRow(
                        icon: Icons.straighten,
                        label: 'Route length',
                        value: formatMeters(_banner.lengthMeters!),
                      ),
                    if (_banner.formattedAddress != null)
                      InfoRow(
                        icon: Icons.location_on,
                        label: 'Start location',
                        value: _banner.formattedAddress!,
                      )
                    else if (_banner.startLatitude != null &&
                        _banner.startLongitude != null)
                      InfoRow(
                        icon: Icons.location_on,
                        label: 'Start point',
                        value:
                            '${_banner.startLatitude!.toStringAsFixed(5)}, '
                            '${_banner.startLongitude!.toStringAsFixed(5)}',
                      ),
                    if (_banner.authorAgent != null)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.person_outline,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(width: 12),
                            const Text('Author: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                _banner.authorAgent!.name,
                                style: TextStyle(
                                    color: factionColor(
                                        _banner.authorAgent!.faction)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_banner.eventStartDate != null)
                      InfoRow(
                        icon: Icons.event,
                        label: 'Event',
                        value: _banner.eventEndDate != null
                            ? '${_banner.eventStartDate} – ${_banner.eventEndDate}'
                            : _banner.eventStartDate!,
                      ),
                    if (_banner.plannedOfflineDate != null)
                      InfoRow(
                        icon: Icons.event_busy,
                        label: 'Planned offline',
                        value: _banner.plannedOfflineDate!,
                      ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launch(_banner.bannerUrl),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(width: 12),
                            Text(
                              'View on Bannergress',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _loadingDetail ? null : _exportGpx,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined,
                                size: 20,
                                color: _loadingDetail
                                    ? Theme.of(context).disabledColor
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary),
                            const SizedBox(width: 12),
                            Text(
                              'Export GPX',
                              style: TextStyle(
                                color: _loadingDetail
                                    ? Theme.of(context).disabledColor
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_banner.missions.isNotEmpty ||
                        _loadingDetail) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 4),
                      if (_banner.missions.isNotEmpty)
                        Text(
                          'Missions (${_banner.missions.length})',
                          style:
                              Theme.of(context).textTheme.titleSmall,
                        ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              if (_loadingDetail && _banner.missions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
        if (_banner.missions.isNotEmpty)
          SliverList.builder(
            itemCount: _banner.missions.length,
            itemBuilder: (_, i) => MissionTile(
              index: i,
              mission: _banner.missions[i],
              color: missionColor(i),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _missionsLabel(BannerItem b) {
    final total = b.numberOfMissions!;
    final disabled = b.numberOfDisabledMissions ?? 0;
    final active = total - disabled;
    if (disabled > 0) return '$active active ($disabled disabled)';
    return '$total';
  }
}
