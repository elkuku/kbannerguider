import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banner_item.dart';
import '../models/mission_item.dart';
import '../services/banner_service.dart';
import '../services/drive_service.dart';

class BannerDetailPage extends StatefulWidget {
  const BannerDetailPage({
    super.key,
    required this.banner,
    required this.bannerService,
    this.driveService,
    this.listTypes = const {},
  });

  final BannerItem banner;
  final BannerService bannerService;
  final DriveService? driveService;
  final Map<String, String> listTypes;

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  late BannerItem _banner;
  bool _loadingDetail = false;
  late Map<String, String> _listTypes;

  @override
  void initState() {
    super.initState();
    _banner = widget.banner;
    _listTypes = Map.of(widget.listTypes);
    _loadDetail();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_banner.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'banner-${_banner.id}',
              child: Image.network(
                _banner.pictureUrl,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 240,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.map, size: 64, color: Colors.grey),
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
                  if (widget.driveService != null) ...[
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
                      value: '${_banner.startLatitude!.toStringAsFixed(5)}, '
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
                  if (_banner.missions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 4),
                    Text(
                      'Missions (${_banner.missions.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          if (_banner.missions.isNotEmpty)
            _MissionList(missions: _banner.missions),
          ],
        ),
      ),
    );
  }

  Future<void> _setListType(String type) async {
    final updated = Map<String, String>.of(_listTypes);
    if (type == 'none') {
      updated.remove(_banner.id);
    } else {
      updated[_banner.id] = type;
    }
    setState(() => _listTypes = updated);
    await widget.driveService?.saveListTypes(updated);
  }

  String _missionsLabel(BannerItem b) {
    final total = b.numberOfMissions!;
    final disabled = b.numberOfDisabledMissions ?? 0;
    final active = total - disabled;
    if (disabled > 0) return '$active active ($disabled disabled)';
    return '$total';
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '$meters m';
  }
}

class _ListTypeSelector extends StatelessWidget {
  const _ListTypeSelector({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  static const _options = [
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
                color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: selected ? color : Colors.grey),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? color : Colors.grey,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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

Future<void> _launch(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ─── Mission list ─────────────────────────────────────────────────────────────

class _MissionList extends StatelessWidget {
  const _MissionList({required this.missions});

  final List<MissionItem> missions;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: missions.length,
      itemBuilder: (_, i) => _MissionTile(index: i, mission: missions[i]),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.index, required this.mission});

  final int index;
  final MissionItem mission;

  @override
  Widget build(BuildContext context) {
    final stepCount = mission.steps.length;
    return ExpansionTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          mission.pictureUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Container(width: 40, height: 40, color: Colors.grey.shade200,
                  child: const Icon(Icons.map, size: 20, color: Colors.grey)),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${index + 1}. ${mission.title}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
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
          if (stepCount > 0) '$stepCount waypoint${stepCount == 1 ? '' : 's'}',
          if (mission.lengthMeters != null)
            mission.lengthMeters! >= 1000
                ? '${(mission.lengthMeters! / 1000).toStringAsFixed(1)} km'
                : '${mission.lengthMeters} m',
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
                (e) => _StepTile(index: e.key, step: e.value),
              ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final MissionStepItem step;

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
    final (icon, color) = _objectiveStyle(step.objective);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: color),
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

// ─────────────────────────────────────────────────────────────────────────────

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
