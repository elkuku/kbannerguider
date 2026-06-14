import 'package:flutter/material.dart';

class GuiderBar extends StatefulWidget {
  const GuiderBar({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.onDecrement,
    required this.onIncrement,
    required this.onLaunch,
    this.onMarkDone,
  });

  final int currentIndex;
  final int total;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final Future<void> Function()? onLaunch;
  final Future<void> Function()? onMarkDone;

  @override
  State<GuiderBar> createState() => _GuiderBarState();
}

class _GuiderBarState extends State<GuiderBar> {
  bool _launching = false;

  String get _buttonLabel {
    if (widget.currentIndex == 0) return 'Start';
    if (widget.currentIndex >= widget.total) return 'Mark as done';
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

  Future<void> _handleMarkDone() async {
    if (_launching || widget.onMarkDone == null) return;
    setState(() => _launching = true);
    await widget.onMarkDone!();
    if (mounted) setState(() => _launching = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayIndex = widget.currentIndex.clamp(0, widget.total);
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
          IconButton(
            icon: const Icon(Icons.remove),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: widget.onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$displayIndex / ${widget.total}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: widget.onIncrement,
          ),
          const Spacer(),
          FilledButton.icon(
            style: (widget.currentIndex == 0 ||
                    widget.currentIndex >= widget.total)
                ? FilledButton.styleFrom(backgroundColor: Colors.green)
                : null,
            onPressed: _launching
                ? null
                : widget.currentIndex >= widget.total
                    ? (widget.onMarkDone == null ? null : _handleMarkDone)
                    : (widget.onLaunch == null ? null : _handleLaunch),
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
