import 'package:flutter/material.dart';

import '../models/banner_item.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.hiddenFilters,
    required this.listTypes,
    required this.banners,
    required this.onChanged,
    required this.isSignedIn,
    required this.minMissions,
    required this.onMinMissionsChanged,
  });

  final Set<String> hiddenFilters;
  final Map<String, String> listTypes;
  final List<BannerItem> banners;
  final ValueChanged<Set<String>> onChanged;
  final bool isSignedIn;
  final int minMissions;
  final ValueChanged<int> onMinMissionsChanged;

  static const _minMissionOptions = [0, 6, 12, 18, 24, 36];

  int _count(String key) {
    if (key == 'unsorted') {
      return banners.where((b) {
        final t = listTypes[b.id];
        return t == null || t == 'none';
      }).length;
    }
    return banners.where((b) => listTypes[b.id] == key).length;
  }

  @override
  Widget build(BuildContext context) {
    const listTypeOptions = [
      ('todo', 'To-do', Icons.bookmark_outline, Colors.blue),
      ('done', 'Done', Icons.check_circle_outline, Colors.green),
      ('blacklist', 'Skip', Icons.block, Colors.red),
      ('unsorted', 'Unsorted', Icons.label_off_outlined, Colors.grey),
    ];

    final active = minMissions > 0;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PopupMenuButton<int>(
                initialValue: minMissions,
                onSelected: onMinMissionsChanged,
                itemBuilder: (_) => _minMissionOptions
                    .map((v) => PopupMenuItem<int>(
                          value: v,
                          child: Text(v == 0 ? 'Any' : '≥ $v'),
                        ))
                    .toList(),
                child: Chip(
                  avatar: Icon(
                    Icons.straighten,
                    size: 15,
                    color: active ? Colors.purple : Colors.grey,
                  ),
                  label: Text(
                    active ? '≥ $minMissions' : 'Any',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: active
                      ? Colors.purple.withValues(alpha: 0.15)
                      : null,
                ),
              ),
            ),
            if (isSignedIn)
              ...listTypeOptions.map((opt) {
                final (key, label, icon, baseColor) = opt;
                final color = baseColor as Color;
                final visible = !hiddenFilters.contains(key);
                final count = _count(key);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: visible,
                    avatar: Icon(icon,
                        size: 15, color: visible ? color : Colors.grey),
                    label: Text('$count',
                        style: const TextStyle(fontSize: 12)),
                    onSelected: (_) {
                      final updated = Set<String>.of(hiddenFilters);
                      if (visible) {
                        updated.add(key);
                      } else {
                        updated.remove(key);
                      }
                      onChanged(updated);
                    },
                    selectedColor: color.withValues(alpha: 0.15),
                    checkmarkColor: color,
                    showCheckmark: false,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
