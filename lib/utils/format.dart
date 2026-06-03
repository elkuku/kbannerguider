/// Formatting utilities shared across the app.
library;

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
