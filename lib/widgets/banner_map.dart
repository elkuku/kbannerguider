import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/mission_item.dart';
import '../utils/format.dart';
import 'guider_bar.dart';

class BannerMap extends StatefulWidget {
  const BannerMap({
    super.key,
    required this.missions,
    required this.loading,
    this.bannerStartLat,
    this.bannerStartLng,
    this.bannerTitle,
    this.bannerAddress,
    this.currentMissionIndex,
    this.onMissionIndexChanged,
    this.onLaunchMission,
    this.onMarkDone,
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
  final Future<void> Function()? onMarkDone;

  @override
  State<BannerMap> createState() => _BannerMapState();
}

class _BannerMapState extends State<BannerMap> {
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

  void _focusOnMission(int index) => _focusOnMissions([index]);

  void _focusOnMissions(List<int> indices) {
    final points = indices
        .where((i) => i >= 0 && i < widget.missions.length)
        .expand((i) => _missionPoints(widget.missions[i]))
        .toList();
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  @override
  void didUpdateWidget(BannerMap old) {
    super.didUpdateWidget(old);
    final ci = widget.currentMissionIndex ?? 0;
    if (ci != (old.currentMissionIndex ?? 0) && ci > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusOnMissions([ci - 1, ci]);
      });
    }
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
      if (mounted) {
        setState(() {
          _showLocation = false;
          _loadingLocation = false;
        });
      }
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

    setState(() {
      _showLocation = true;
      _loadingLocation = true;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _showLocation = false;
            _loadingLocation = false;
          });
        }
        return;
      }
      await _refreshLocation(moveCamera: true);
      _locationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _refreshLocation(),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _showLocation = false;
          _loadingLocation = false;
        });
      }
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

    final ci = widget.currentMissionIndex ?? 0;
    final isGuiding = ci > 0;
    final visibleIndices = isGuiding
        ? [
            if (ci - 1 < widget.missions.length) ci - 1,
            if (ci < widget.missions.length) ci,
          ]
        : List.generate(widget.missions.length, (i) => i);

    final polylines = <Polyline>[];
    final waypointMarkers = <Marker>[];
    final startMarkers = <Marker>[];

    for (final i in visibleIndices) {
      final mission = widget.missions[i];
      final color = missionColor(i);
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
        void onTap() =>
            _showWaypointSheet(context, mission: mission, poi: poi, color: color);

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
      final startPoint =
          LatLng(widget.bannerStartLat!, widget.bannerStartLng!);
      final geoUrl =
          'geo:${widget.bannerStartLat},${widget.bannerStartLng}'
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
            if (flagMarkers.isNotEmpty && !isGuiding)
              MarkerLayer(markers: flagMarkers),
            if (locationMarkers.isNotEmpty)
              MarkerLayer(markers: locationMarkers),
            if (!isGuiding)
              _MapLegend(missions: widget.missions, onFocus: _focusOnMission),
          ],
        ),
        if (widget.currentMissionIndex != null && widget.missions.isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: GuiderBar(
              currentIndex: widget.currentMissionIndex!,
              total: widget.missions.length,
              onDecrement: widget.currentMissionIndex! > 0
                  ? () => widget
                      .onMissionIndexChanged!(widget.currentMissionIndex! - 1)
                  : null,
              onIncrement: widget.currentMissionIndex! < widget.missions.length
                  ? () => widget
                      .onMissionIndexChanged!(widget.currentMissionIndex! + 1)
                  : null,
              onLaunch: widget.currentMissionIndex! < widget.missions.length
                  ? widget.onLaunchMission
                  : null,
              onMarkDone: widget.onMarkDone,
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: _showLocation ? theme.colorScheme.primary : Colors.white,
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
                        color: _showLocation ? Colors.white : Colors.black54,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bottom sheets ─────────────────────────────────────────────────────────────

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
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
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
                launch(geoUrl);
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
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.title,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            poi.title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (poi.latitude != null && poi.longitude != null) ...[
            const SizedBox(height: 4),
            Text(
              '${poi.latitude!.toStringAsFixed(5)}, '
              '${poi.longitude!.toStringAsFixed(5)}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
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
                  launch(poi.geoUrl!);
                },
              ),
            ),
        ],
      ),
    ),
  );
}

// ── Map legend ────────────────────────────────────────────────────────────────

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
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'Missions',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: labelColor),
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
                      final color = missionColor(e.key);
                      return InkWell(
                        onTap: () => widget.onFocus(e.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                  width: 16, height: 3, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${e.key + 1}. ${e.value.title}',
                                  style: TextStyle(
                                      fontSize: 11, color: textColor),
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
