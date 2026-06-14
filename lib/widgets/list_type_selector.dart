import 'package:flutter/material.dart';

class ListTypeSelector extends StatelessWidget {
  const ListTypeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final String current;
  final ValueChanged<String> onChanged;

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
                  Icon(icon, size: 20, color: selected ? color : Colors.grey),
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
