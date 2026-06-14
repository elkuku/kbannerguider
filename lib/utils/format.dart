/// Formatting utilities shared across the app.
library;

import 'package:flutter/material.dart';

/// Converts a distance in metres to a human-readable string.
///
/// - Below 1 000 m → `"X m"`
/// - 1 000 m and above  → `"X.X km"`
String formatMeters(int meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '$meters m';
}

/// Returns the faction's canonical color: green for Enlightened, blue for Resistance.
Color factionColor(String? faction) => switch ((faction ?? '').toUpperCase()) {
      'ENLIGHTENED' || 'ENL' => Colors.green,
      'RESISTANCE' || 'RES' => Colors.blue,
      _ => Colors.grey,
    };
