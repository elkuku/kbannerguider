library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String formatMeters(int meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '$meters m';
}

Color factionColor(String? faction) => switch ((faction ?? '').toUpperCase()) {
      'ENLIGHTENED' || 'ENL' => Colors.green,
      'RESISTANCE' || 'RES' => Colors.blue,
      _ => Colors.grey,
    };

const missionColors = [
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

Color missionColor(int i) => missionColors[i % missionColors.length];

Future<void> launch(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
