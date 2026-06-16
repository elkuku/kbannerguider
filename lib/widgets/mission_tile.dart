import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/mission_item.dart';
import '../utils/format.dart';

class MissionTile extends StatelessWidget {
  const MissionTile({
    super.key,
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
            onPressed: () => launch(mission.ingressUrl),
          ),
        ],
      ),
      subtitle: Text(
        [
          if (mission.type != null)
            mission.type == 'sequential' ? 'Sequential' : 'Any order',
          if (stepCount > 0)
            '$stepCount waypoint${stepCount == 1 ? '' : 's'}',
          if (mission.lengthMeters != null) formatMeters(mission.lengthMeters!),
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

  static String _objectiveLabel(String objective) => switch (objective) {
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
              onPressed: () => launch(poi!.geoUrl!),
            ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
          if (onTap != null)
            Icon(Icons.open_in_new,
                size: 14,
                color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: content,
    );
  }
}
