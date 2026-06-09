import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../models/banner_item.dart';
import '../models/mission_item.dart';
import '../services/banner_service.dart';
import '../utils/format.dart';
import '../widgets/full_image_dialog.dart';

// Distinct colors assigned per mission index
const _missionColors = [
  Color(0xFF2196F3), // blue
  Color(0xFFF44336), // red
  Color(0xFF4CAF50), // green
  Color(0xFFFF9800), // orange
  Color(0xFF9C27B0), // purple
  Color(0xFF00BCD4), // cyan
  Color(0xFFE91E63), // pink
  Color(0xFF009688), // teal
  Color(0xFFFFEB3B), // yellow
  Color(0xFF3F51B5), // indigo
];

Color _missionColor(int i) => _missionColors[i % _missionColors.length];

Future<void> _launch(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ─── Page ────────────────────────────────────────────────────────────────────

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

  // ── Guider state ──────────────────────────────────────────────────────────
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
      final full = await widget.bannerService.fetchById(_banner.id);
      if (mounted) setState(() => _banner = full);
    } catch (_) {
      // keep the list data already shown
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  void _setGuiderIndex(int index) {
    setState(() => _currentMissionIndex = index.clamp(0, _banner.missions.length));
  }

  Future<void> _launchCurrentMission() async {
    if (_currentMissionIndex >= _banner.missions.length) return;
    final mission = _banner.missions[_currentMissionIndex];
    await _launch(mission.ingressUrl);
    _setGuiderIndex(_currentMissionIndex + 1);
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
    // PopScope ensures _listTypes is returned even on the system back-gesture.
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
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.list_outlined), text: 'Missions'),
              Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            _BannerMap(
              missions: _banner.missions,
              loading: _loadingDetail,
              bannerStartLat: _banner.startLatitude,
              bannerStartLng: _banner.startLongitude,
              bannerTitle: _banner.title,
              bannerAddress: _banner.formattedAddress,
              currentMissionIndex: _currentMissionIndex,
              onMissionIndexChanged: _setGuiderIndex,
              onLaunchMission: _launchCurrentMission,
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
                      child: const Icon(Icons.map, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (_banner.warning != null)
                Container(
                  color: Colors.amber.shade100,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_banner.warning!)),
                    ],
                  ),
                ),
              if (_banner.missions.any(
                    (m) => m.steps.any((s) => s.objective == 'enterPassphrase'),
                  ))
                Container(
                  color: Colors.amber.shade100,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(
                    children: [
                      Icon(Icons.key_outlined, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'One or more missions require a passphrase.',
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
                    Text(
                      _banner.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_banner.description != null &&
                        _banner.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _banner.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (widget.getToken != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 4),
                      _ListTypeSelector(
                        current: _listTypes[_banner.id] ?? 'none',
                        onChanged: _setListType,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (_banner.type != null)
                      _InfoRow(
                        icon: Icons.format_list_numbered,
                        label: 'Type',
                        value: _banner.type == 'sequential'
                            ? 'Sequential'
                            : 'Any order',
                      ),
                    if (_banner.numberOfMissions != null)
                      _InfoRow(
                        icon: Icons.flag,
                        label: 'Missions',
                        value: _missionsLabel(_banner),
                      ),
                    if (_banner.lengthMeters != null)
                      _InfoRow(
                        icon: Icons.straighten,
                        label: 'Route length',
                        value: _formatDistance(_banner.lengthMeters!),
                      ),
                    if (_banner.formattedAddress != null)
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'Start location',
                        value: _banner.formattedAddress!,
                      )
                    else if (_banner.startLatitude != null &&
                        _banner.startLongitude != null)
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'Start point',
                        value:
                            '${_banner.startLatitude!.toStringAsFixed(5)}, '
                            '${_banner.startLongitude!.toStringAsFixed(5)}',
                      ),
                    if (_banner.eventStartDate != null)
                      _InfoRow(
                        icon: Icons.event,
                        label: 'Event',
                        value: _banner.eventEndDate != null
                            ? '${_banner.eventStartDate} – ${_banner.eventEndDate}'
                            : _banner.eventStartDate!,
                      ),
                    if (_banner.plannedOfflineDate != null)
                      _InfoRow(
                        icon: Icons.event_busy,
                        label: 'Planned offline',
                        value: _banner.plannedOfflineDate!,
                      ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _launch(_banner.bannerUrl),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'View on Bannergress',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_banner.missions.isNotEmpty || _loadingDetail) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 4),
                      if (_banner.missions.isNotEmpty)
                        Text(
                          'Missions (${_banner.missions.length})',
                          style: Theme.of(context).textTheme.titleSmall,
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
        // Missions are rendered lazily so a banner with 300 missions doesn't
        // force all tiles to be built at once (avoids the shrinkWrap penalty).
        if (_banner.missions.isNotEmpty)
          SliverList.builder(
            itemCount: _banner.missions.length,
            itemBuilder: (_, i) => _MissionTile(
              index: i,
              mission: _banner.missions[i],
              color: _missionColor(i),
            ),
          ),
        // Bottom padding so the last tile isn't flush with the screen edge.
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

  String _formatDistance(int meters) => formatMeters(meters);
}

// ─── Map tab ─────────────────────────────────────────────────────────────────

class _BannerMap extends StatefulWidget {
  const _BannerMap({
    required this.missions,
    required this.loading,
    this.bannerStartLat,
    this.bannerStartLng,
    this.bannerTitle,
    this.bannerAddress,
    this.currentMissionIndex,
    this.onMissionIndexChanged,
    this.onLaunchMission,
  });

  final List<MissionItem> missions;
  final bool loading;
  final double? bannerStartLat;
  final double? bannerStartLng;
  final String? bannerTitle;
  final String? bannerAddress;
  final int? currentMissionIndex;
  final void Function(int)? onMissionIndexChanged;
  final Future<void> Function()? onLaunchMission;

  @override
  State<_BannerMap> createState() => _BannerMapState();
}

class _BannerMapState extends State<_BannerMap> {
  final _mapController = MapController();
  bool _showLocation = false;
  bool _loadingLocation = false;
  LatLng? _currentLocation;
  Timer? _locationTimer;
  bool _userInteracting = false;
  Timer? _interactionDebounce;

  static List<LatLng> _missionPoints(MissionItem m) => m.steps
      .map((s) => s.poi)
      .whereType<PoiItem>()
      .where((p) => p.latitude != null && p.longitude != null)
      .map((p) => LatLng(p.latitude!, p.longitude!))
      .toList();

  void _focusOnMission(int index) {
    final points = _missionPoints(widget.missions[index]);
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _interactionDebounce?.cancel();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event.source == MapEventSource.mapController ||
        event.source == MapEventSource.nonRotatedSizeChange ||
        event.source == MapEventSource.interactiveFlagsChanged ||
        event.source == MapEventSource.fitCamera) {
      return;
    }
    _interactionDebounce?.cancel();
    _userInteracting = true;
    _interactionDebounce = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _userInteracting = false);
    });
  }

  Future<void> _refreshLocation({bool moveCamera = false}) async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLocation = loc;
        _loadingLocation = false;
      });
      if (moveCamera || !_userInteracting) {
        _mapController.move(loc, _mapController.camera.zoom);
      }
    } catch (_) {
      if (mounted) setState(() { _showLocation = false; _loadingLocation = false; });
      _locationTimer?.cancel();
      _locationTimer = null;
    }
  }

  Future<void> _toggleLocation() async {
    if (_showLocation) {
      _locationTimer?.cancel();
      _locationTimer = null;
      setState(() => _showLocation = false);
      return;
    }

    setState(() { _showLocation = true; _loadingLocation = true; });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() { _showLocation = false; _loadingLocation = false; });
        return;
      }
      await _refreshLocation(moveCamera: true);
      _locationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _refreshLocation(),
      );
    } catch (_) {
      if (mounted) setState(() { _showLocation = false; _loadingLocation = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.missions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final allPoints = widget.missions.expand(_missionPoints).toList();

    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allPoints.isEmpty) {
      return const Center(child: Text('No waypoint coordinates available.'));
    }

    final cameraFit = CameraFit.coordinates(
      coordinates: allPoints,
      padding: const EdgeInsets.all(40),
    );

    final polylines = <Polyline>[];
    final waypointMarkers = <Marker>[];
    final startMarkers = <Marker>[];

    for (var i = 0; i < widget.missions.length; i++) {
      final mission = widget.missions[i];
      final color = _missionColor(i);
      final points = _missionPoints(mission);

      if (points.length >= 2) {
        polylines.add(Polyline(points: points, color: color, strokeWidth: 3));
      }

      bool firstWaypoint = true;
      for (final step in mission.steps) {
        final poi = step.poi;
        if (poi == null || poi.latitude == null || poi.longitude == null) {
          continue;
        }
        final point = LatLng(poi.latitude!, poi.longitude!);
        void onTap() => _showWaypointSheet(context,
            mission: mission, poi: poi, color: color);

        if (firstWaypoint) {
          startMarkers.add(Marker(
            point: point,
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ));
          firstWaypoint = false;
        } else {
          waypointMarkers.add(Marker(
            point: point,
            width: 26,
            height: 26,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 3),
                  ],
                ),
              ),
            ),
          ));
        }
      }
    }

    final flagMarkers = <Marker>[];
    if (widget.bannerStartLat != null && widget.bannerStartLng != null) {
      final startPoint = LatLng(widget.bannerStartLat!, widget.bannerStartLng!);
      final geoUrl = 'geo:${widget.bannerStartLat},${widget.bannerStartLng}'
          '?q=${widget.bannerStartLat},${widget.bannerStartLng}'
          '(${Uri.encodeComponent(widget.bannerTitle ?? 'Banner start')})';

      flagMarkers.add(Marker(
        point: startPoint,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showStartSheet(
            context,
            title: widget.bannerTitle,
            address: widget.bannerAddress,
            lat: widget.bannerStartLat!,
            lng: widget.bannerStartLng!,
            geoUrl: geoUrl,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4),
              ],
            ),
            child: const Icon(Icons.flag, color: Colors.red, size: 20),
          ),
        ),
      ));
    }

    final locationMarkers = <Marker>[];
    if (_showLocation && _currentLocation != null) {
      locationMarkers.add(Marker(
        point: _currentLocation!,
        width: 22,
        height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ));
    }

    final theme = Theme.of(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: cameraFit,
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.elkuku.kbannerguider',
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            if (waypointMarkers.isNotEmpty)
              MarkerLayer(markers: waypointMarkers),
            if (startMarkers.isNotEmpty) MarkerLayer(markers: startMarkers),
            if (flagMarkers.isNotEmpty) MarkerLayer(markers: flagMarkers),
            if (locationMarkers.isNotEmpty)
              MarkerLayer(markers: locationMarkers),
            _MapLegend(missions: widget.missions, onFocus: _focusOnMission),
          ],
        ),
        // Guider controls bar
        if (widget.currentMissionIndex != null &&
            widget.missions.isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: _GuiderBar(
              currentIndex: widget.currentMissionIndex!,
              total: widget.missions.length,
              onDecrement: widget.currentMissionIndex! > 0
                  ? () => widget
                      .onMissionIndexChanged!(widget.currentMissionIndex! - 1)
                  : null,
              onIncrement:
                  widget.currentMissionIndex! < widget.missions.length
                      ? () => widget.onMissionIndexChanged!(
                          widget.currentMissionIndex! + 1)
                      : null,
              onLaunch: widget.currentMissionIndex! < widget.missions.length
                  ? widget.onLaunchMission
                  : null,
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: _showLocation
                ? theme.colorScheme.primary
                : Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleLocation,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _loadingLocation
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.my_location,
                        size: 22,
                        color: _showLocation
                            ? Colors.white
                            : Colors.black54,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Guider bar ──────────────────────────────────────────────────────────────

class _GuiderBar extends StatefulWidget {
  const _GuiderBar({
    required this.currentIndex,
    required this.total,
    required this.onDecrement,
    required this.onIncrement,
    required this.onLaunch,
  });

  final int currentIndex;
  final int total;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final Future<void> Function()? onLaunch;

  @override
  State<_GuiderBar> createState() => _GuiderBarState();
}

class _GuiderBarState extends State<_GuiderBar> {
  bool _launching = false;

  String get _buttonLabel {
    if (widget.currentIndex == 0) return 'Start';
    if (widget.currentIndex >= widget.total) return 'Done';
    return 'Next';
  }

  IconData get _buttonIcon {
    if (widget.currentIndex >= widget.total) return Icons.check_circle_outline;
    return Icons.rocket_launch_outlined;
  }

  Future<void> _handleLaunch() async {
    if (_launching || widget.onLaunch == null) return;
    setState(() => _launching = true);
    await widget.onLaunch!();
    if (mounted) setState(() => _launching = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayIndex = widget.currentIndex.clamp(1, widget.total);

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Decrement
          IconButton(
            icon: const Icon(Icons.remove),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: widget.onDecrement,
          ),
          // Counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$displayIndex / ${widget.total}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          // Increment
          IconButton(
            icon: const Icon(Icons.add),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: widget.onIncrement,
          ),
          const Spacer(),
          // Launch button
          FilledButton.icon(
            onPressed:
                widget.onLaunch == null || _launching ? null : _handleLaunch,
            icon: _launching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_buttonIcon, size: 18),
            label: Text(_buttonLabel),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

void _showStartSheet(
  BuildContext context, {
  required String? title,
  required String? address,
  required double lat,
  required double lng,
  required String geoUrl,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'Banner start',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (title != null)
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          Text(
            address ?? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontFamily: address == null ? 'monospace' : null),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share_location_outlined),
              label: const Text('Open location'),
              onPressed: () {
                Navigator.pop(ctx);
                _launch(geoUrl);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

void _showWaypointSheet(
  BuildContext context, {
  required MissionItem mission,
  required PoiItem poi,
  required Color color,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            poi.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (poi.latitude != null && poi.longitude != null) ...[
            const SizedBox(height: 4),
            Text(
              '${poi.latitude!.toStringAsFixed(5)}, '
              '${poi.longitude!.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                  fontFamily: 'monospace'),
            ),
          ],
          const SizedBox(height: 16),
          if (poi.geoUrl != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_location_outlined),
                label: const Text('Open location'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _launch(poi.geoUrl!);
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class _MapLegend extends StatefulWidget {
  const _MapLegend({required this.missions, required this.onFocus});

  final List<MissionItem> missions;
  final void Function(int index) onFocus;

  @override
  State<_MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<_MapLegend> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.missions.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.grey[900]!.withValues(alpha: 0.93)
        : Colors.white.withValues(alpha: 0.93);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with collapse toggle
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'Missions',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: iconColor,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.missions.asMap().entries.map((e) {
                      final color = _missionColor(e.key);
                      return InkWell(
                        onTap: () => widget.onFocus(e.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Row(
                            children: [
                              Container(width: 16, height: 3, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${e.key + 1}. ${e.value.title}',
                                  style: TextStyle(fontSize: 11, color: textColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.center_focus_weak,
                                  size: 13, color: iconColor),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── List type selector ───────────────────────────────────────────────────────

class _ListTypeSelector extends StatelessWidget {
  const _ListTypeSelector({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  // Explicit Color type removes the need for `as Color` casts at every use site.
  static const List<(String, IconData, String, Color)> _options = [
    ('none', Icons.label_off_outlined, 'None', Colors.grey),
    ('todo', Icons.bookmark_outline, 'To-do', Colors.blue),
    ('done', Icons.check_circle_outline, 'Done', Colors.green),
    ('blacklist', Icons.block, 'Skip', Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (value, icon, label, color) = opt;
        final selected = current == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20,
                      color: selected ? color : Colors.grey),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? color : Colors.grey,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Mission list ─────────────────────────────────────────────────────────────

// _MissionList removed — missions are now rendered directly as a
// SliverList.builder inside _buildInfoTab for lazy layout.

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.index,
    required this.mission,
    required this.color,
  });

  final int index;
  final MissionItem mission;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final stepCount = mission.steps.length;
    return ExpansionTile(
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: mission.pictureUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                width: 40,
                height: 40,
                color: Colors.grey.shade200,
                child: const Icon(Icons.map, size: 20, color: Colors.grey),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(height: 3, color: color),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${index + 1}. ${mission.title}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          if (mission.steps.any((s) => s.objective == 'enterPassphrase'))
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.key_outlined, size: 16, color: Colors.amber),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            tooltip: 'Open in Ingress',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _launch(mission.ingressUrl),
          ),
        ],
      ),
      subtitle: Text(
        [
          if (mission.type != null)
            mission.type == 'sequential' ? 'Sequential' : 'Any order',
          if (stepCount > 0)
            '$stepCount waypoint${stepCount == 1 ? '' : 's'}',
          if (mission.lengthMeters != null)
            formatMeters(mission.lengthMeters!),
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        if (mission.steps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No waypoint data available.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          ...mission.steps.asMap().entries.map(
                (e) => _StepTile(index: e.key, step: e.value, color: color),
              ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.color,
  });

  final int index;
  final MissionStepItem step;
  final Color color;

  static (IconData, Color) _objectiveStyle(String objective) =>
      switch (objective) {
        'hack' => (Icons.sensors, Colors.deepOrange),
        'captureOrUpgrade' => (Icons.flag_outlined, Colors.blue),
        'createLink' => (Icons.link, Colors.indigo),
        'createField' => (Icons.change_history, Colors.purple),
        'installMod' => (Icons.build_outlined, Colors.teal),
        'takePhoto' => (Icons.camera_alt_outlined, Colors.pink),
        'viewWaypoint' => (Icons.visibility_outlined, Colors.green),
        'enterPassphrase' => (Icons.key_outlined, Colors.amber),
        _ => (Icons.place_outlined, Colors.grey),
      };

  static String _objectiveLabel(String objective) =>
      switch (objective) {
        'hack' => 'Hack',
        'captureOrUpgrade' => 'Capture/Upgrade',
        'createLink' => 'Create Link',
        'createField' => 'Create Field',
        'installMod' => 'Install Mod',
        'takePhoto' => 'Take Photo',
        'viewWaypoint' => 'View Waypoint',
        'enterPassphrase' => 'Enter Passphrase',
        _ => objective,
      };

  @override
  Widget build(BuildContext context) {
    final poi = step.poi;
    final (icon, objColor) = _objectiveStyle(step.objective);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}.',
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: objColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poi?.title ?? '(hidden waypoint)',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  _objectiveLabel(step.objective),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (poi?.geoUrl != null)
            IconButton(
              icon: const Icon(Icons.share_location_outlined, size: 18),
              tooltip: 'Share location',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _launch(poi!.geoUrl!),
            ),
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
