import '../models/banner_item.dart';

String generateGpx(BannerItem banner) {
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="kBannerGuider"')
    ..writeln('    xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <metadata>')
    ..writeln('    <name>${_x(banner.title)}</name>')
    ..writeln('    <link href="${banner.bannerUrl}">')
    ..writeln('      <text>View on Bannergress</text>')
    ..writeln('    </link>')
    ..writeln('  </metadata>');

  // Named waypoints — one per POI, for GPS app navigation pins.
  for (var i = 0; i < banner.missions.length; i++) {
    final mission = banner.missions[i];
    for (final step in mission.steps) {
      final poi = step.poi;
      if (poi == null || poi.latitude == null || poi.longitude == null) continue;
      buf
        ..writeln('  <wpt lat="${poi.latitude}" lon="${poi.longitude}">')
        ..writeln('    <name>${_x(poi.title)}</name>')
        ..writeln(
            '    <desc>${_x('Mission ${i + 1} · ${_objectiveLabel(step.objective)}')}</desc>')
        ..writeln('  </wpt>');
    }
  }

  // One track per mission — route line through its waypoints.
  for (var i = 0; i < banner.missions.length; i++) {
    final mission = banner.missions[i];
    final points = mission.steps
        .where((s) =>
            s.poi != null &&
            s.poi!.latitude != null &&
            s.poi!.longitude != null)
        .toList();
    if (points.isEmpty) continue;

    buf
      ..writeln('  <trk>')
      ..writeln('    <name>${_x('${i + 1}. ${mission.title}')}</name>')
      ..writeln('    <trkseg>');
    for (final step in points) {
      final poi = step.poi!;
      buf
        ..writeln(
            '      <trkpt lat="${poi.latitude}" lon="${poi.longitude}">')
        ..writeln('        <name>${_x(poi.title)}</name>')
        ..writeln(
            '        <desc>${_x(_objectiveLabel(step.objective))}</desc>')
        ..writeln('      </trkpt>');
    }
    buf
      ..writeln('    </trkseg>')
      ..writeln('  </trk>');
  }

  buf.writeln('</gpx>');
  return buf.toString();
}

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _objectiveLabel(String objective) => switch (objective) {
      'hack' => 'Hack',
      'captureOrUpgrade' => 'Capture / Upgrade',
      'createLink' => 'Create Link',
      'createField' => 'Create Field',
      'installMod' => 'Install Mod',
      'takePhoto' => 'Take Photo',
      'viewWaypoint' => 'View Waypoint',
      'enterPassphrase' => 'Enter Passphrase',
      _ => objective,
    };
