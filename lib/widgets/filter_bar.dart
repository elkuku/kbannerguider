import 'package:flutter/material.dart';

import '../models/banner_item.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.hiddenFilters,
    required this.listTypes,
    required this.banners,
    required this.onChanged,
  });

  final Set<String> hiddenFilters;
  final Map<String, String> listTypes;
  final List<BannerItem> banners;
  final ValueChanged<Set<String>> onChanged;

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
    const options = [
      ('todo', 'To-do', Icons.bookmark_outline, Colors.blue),
      ('done', 'Done', Icons.check_circle_outline, Colors.green),
      ('blacklist', 'Skip', Icons.block, Colors.red),
      ('unsorted', 'Unsorted', Icons.label_off_outlined, Colors.grey),
    ];

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: options.map((opt) {
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
                label: Text('$label  $count',
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
          }).toList(),
        ),
      ),
    );
  }
}
