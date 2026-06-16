import 'package:flutter_test/flutter_test.dart';

import 'package:kbannerguider/models/banner_item.dart';
import 'package:kbannerguider/models/mission_item.dart';
import 'package:kbannerguider/utils/gpx.dart';

MissionItem _mission(String id, String title, List<MissionStepItem> steps) =>
    MissionItem(id: id, title: title, steps: steps);

MissionStepItem _step(String objective, {double? lat, double? lng}) =>
    MissionStepItem(
      objective: objective,
      poi: (lat != null && lng != null)
          ? PoiItem(
              id: 'poi-$objective',
              title: 'POI $objective',
              latitude: lat,
              longitude: lng,
              type: 'portal',
            )
          : null,
    );

BannerItem _banner({
  String id = 'test-banner',
  String title = 'Test Banner',
  List<MissionItem> missions = const [],
}) =>
    BannerItem(id: id, title: title, missions: missions);

void main() {
  group('generateGpx', () {
    test('produces valid GPX 1.1 header and root element', () {
      final gpx = generateGpx(_banner());

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('xmlns="http://www.topografix.com/GPX/1/1"'));
      expect(gpx, endsWith('</gpx>\n'));
    });

    test('includes banner title and Bannergress link in metadata', () {
      final gpx = generateGpx(_banner(id: 'abc123', title: 'My Banner'));

      expect(gpx, contains('<name>My Banner</name>'));
      expect(gpx,
          contains('<link href="https://bannergress.com/banner/abc123">'));
    });

    test('generates a waypoint for each POI with coordinates', () {
      final banner = _banner(missions: [
        _mission('m1', 'Mission One', [
          _step('hack', lat: 1.0, lng: 2.0),
          _step('captureOrUpgrade', lat: 3.0, lng: 4.0),
        ]),
      ]);
      final gpx = generateGpx(banner);

      expect(gpx, contains('<wpt lat="1.0" lon="2.0">'));
      expect(gpx, contains('<wpt lat="3.0" lon="4.0">'));
    });

    test('skips POIs with missing coordinates', () {
      final banner = _banner(missions: [
        _mission('m1', 'Mission One', [
          _step('hack', lat: 1.0, lng: 2.0),
          _step('viewWaypoint'), // no coords
        ]),
      ]);
      final gpx = generateGpx(banner);

      expect(gpx, contains('<wpt lat="1.0" lon="2.0">'));
      expect(RegExp(r'<wpt').allMatches(gpx).length, 1);
    });

    test('waypoint desc includes mission number and objective label', () {
      final banner = _banner(missions: [
        _mission('m1', 'Mission One', [_step('hack', lat: 1.0, lng: 2.0)]),
        _mission('m2', 'Mission Two',
            [_step('captureOrUpgrade', lat: 3.0, lng: 4.0)]),
      ]);
      final gpx = generateGpx(banner);

      expect(gpx, contains('<desc>Mission 1 · Hack</desc>'));
      expect(gpx, contains('<desc>Mission 2 · Capture / Upgrade</desc>'));
    });

    test('generates one track per mission', () {
      final banner = _banner(missions: [
        _mission('m1', 'Alpha', [_step('hack', lat: 1.0, lng: 2.0)]),
        _mission('m2', 'Beta', [_step('hack', lat: 3.0, lng: 4.0)]),
      ]);
      final gpx = generateGpx(banner);

      expect(RegExp(r'<trk>').allMatches(gpx).length, 2);
      expect(gpx, contains('<name>1. Alpha</name>'));
      expect(gpx, contains('<name>2. Beta</name>'));
    });

    test('track contains trkpt entries for each POI', () {
      final banner = _banner(missions: [
        _mission('m1', 'Mission One', [
          _step('hack', lat: 1.0, lng: 2.0),
          _step('hack', lat: 5.0, lng: 6.0),
        ]),
      ]);
      final gpx = generateGpx(banner);

      expect(gpx, contains('<trkpt lat="1.0" lon="2.0">'));
      expect(gpx, contains('<trkpt lat="5.0" lon="6.0">'));
    });

    test('skips mission track when all steps lack coordinates', () {
      final banner = _banner(missions: [
        _mission('m1', 'No Coords', [_step('viewWaypoint')]),
        _mission('m2', 'Has Coords', [_step('hack', lat: 1.0, lng: 2.0)]),
      ]);
      final gpx = generateGpx(banner);

      expect(RegExp(r'<trk>').allMatches(gpx).length, 1);
      expect(gpx, contains('Has Coords'));
      expect(gpx, isNot(contains('No Coords')));
    });

    test('escapes XML special characters in title and POI names', () {
      final banner = BannerItem(
        id: 'x',
        title: 'A & B <test> "quoted" \'apos\'',
        missions: [
          _mission('m1', 'M & M', [
            MissionStepItem(
              objective: 'hack',
              poi: PoiItem(
                id: 'p1',
                title: 'Café & Bar <Cool>',
                latitude: 1.0,
                longitude: 2.0,
                type: 'portal',
              ),
            ),
          ]),
        ],
      );
      final gpx = generateGpx(banner);

      expect(gpx, contains('A &amp; B &lt;test&gt; &quot;quoted&quot; &apos;apos&apos;'));
      expect(gpx, contains('Café &amp; Bar &lt;Cool&gt;'));
    });

    test('objective label falls back to raw string for unknown values', () {
      final banner = _banner(missions: [
        _mission('m1', 'M', [_step('unknownObjective', lat: 1.0, lng: 2.0)]),
      ]);
      final gpx = generateGpx(banner);

      expect(gpx, contains('<desc>Mission 1 · unknownObjective</desc>'));
    });

    test('all known objective labels are mapped', () {
      final objectives = {
        'hack': 'Hack',
        'captureOrUpgrade': 'Capture / Upgrade',
        'createLink': 'Create Link',
        'createField': 'Create Field',
        'installMod': 'Install Mod',
        'takePhoto': 'Take Photo',
        'viewWaypoint': 'View Waypoint',
        'enterPassphrase': 'Enter Passphrase',
      };

      for (final entry in objectives.entries) {
        final banner = _banner(missions: [
          _mission('m1', 'M', [_step(entry.key, lat: 1.0, lng: 2.0)]),
        ]);
        final gpx = generateGpx(banner);
        expect(gpx, contains(entry.value),
            reason: '${entry.key} should map to ${entry.value}');
      }
    });

    test('produces empty waypoints and tracks for banner with no missions', () {
      final gpx = generateGpx(_banner());

      expect(gpx, isNot(contains('<wpt')));
      expect(gpx, isNot(contains('<trk>')));
    });
  });
}
