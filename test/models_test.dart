import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kbannerguider/models/banner_item.dart';
import 'package:kbannerguider/models/mission_item.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

List<dynamic> _fixtureList(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as List<dynamic>;

void main() {
  // ── AgentItem ─────────────────────────────────────────────────────────────

  group('AgentItem', () {
    test('fromJson parses name and faction', () {
      final agent = AgentItem.fromJson({'name': 'Shaper', 'faction': 'enlightened'});
      expect(agent.name, 'Shaper');
      expect(agent.faction, 'enlightened');
    });

    test('fromJson defaults to empty strings when fields are missing', () {
      final agent = AgentItem.fromJson({});
      expect(agent.name, '');
      expect(agent.faction, '');
    });
  });

  // ── PoiItem ───────────────────────────────────────────────────────────────

  group('PoiItem', () {
    test('fromJson parses full portal', () {
      final poi = PoiItem.fromJson({
        'id': 'ae1c2371daa340ccb8682986c9507e2c.16',
        'latitude': -0.241489,
        'longitude': -78.519962,
        'picture': 'https://lh3.googleusercontent.com/abc',
        'title': 'Entrada Principal Parque Santa Ana',
        'type': 'portal',
      });

      expect(poi.id, 'ae1c2371daa340ccb8682986c9507e2c.16');
      expect(poi.title, 'Entrada Principal Parque Santa Ana');
      expect(poi.latitude, closeTo(-0.241489, 1e-6));
      expect(poi.longitude, closeTo(-78.519962, 1e-6));
      expect(poi.type, 'portal');
      expect(poi.picture, 'https://lh3.googleusercontent.com/abc');
    });

    test('fromJson parses unavailable POI with no coordinates', () {
      final poi = PoiItem.fromJson({
        'id': 'e33a179468ff4b8390d85871485ca05f.16',
        'type': 'unavailable',
      });

      expect(poi.type, 'unavailable');
      expect(poi.latitude, isNull);
      expect(poi.longitude, isNull);
    });

    test('geoUrl is populated for portal with coordinates', () {
      final poi = PoiItem.fromJson({
        'id': 'abc',
        'title': 'Test Portal',
        'latitude': -0.241489,
        'longitude': -78.519962,
        'type': 'portal',
      });

      expect(poi.geoUrl, startsWith('geo:-0.241489,-78.519962'));
      expect(poi.geoUrl, contains('Test%20Portal'));
    });

    test('geoUrl is null for unavailable POI', () {
      final poi = PoiItem.fromJson({'id': 'x', 'type': 'unavailable'});
      expect(poi.geoUrl, isNull);
    });
  });

  // ── MissionStepItem ───────────────────────────────────────────────────────

  group('MissionStepItem', () {
    test('fromJson parses hack step with portal', () {
      final step = MissionStepItem.fromJson({
        'objective': 'hack',
        'poi': {
          'id': 'abc',
          'title': 'Test',
          'latitude': 1.0,
          'longitude': 2.0,
          'type': 'portal',
        },
      });

      expect(step.objective, 'hack');
      expect(step.poi, isNotNull);
      expect(step.poi!.title, 'Test');
    });

    test('fromJson parses enterPassphrase step', () {
      final step = MissionStepItem.fromJson({
        'objective': 'enterPassphrase',
        'poi': {'id': 'x', 'title': 'HQ', 'latitude': 1.0, 'longitude': 2.0, 'type': 'portal'},
      });
      expect(step.objective, 'enterPassphrase');
    });

    test('fromJson handles step with unavailable poi', () {
      final step = MissionStepItem.fromJson({
        'objective': 'hack',
        'poi': {'id': 'y', 'type': 'unavailable'},
      });
      expect(step.poi?.type, 'unavailable');
      expect(step.poi?.latitude, isNull);
    });

    test('fromJson handles missing poi', () {
      final step = MissionStepItem.fromJson({'objective': 'hack'});
      expect(step.poi, isNull);
      expect(step.objective, 'hack');
    });
  });

  // ── MissionItem ───────────────────────────────────────────────────────────

  group('MissionItem', () {
    test('fromJson parses all fields', () {
      final mission = MissionItem.fromJson({
        'id': '3d06acb8975a427ab3fb358dea52fda5.1c',
        'title': 'PARQUE SANTA ANA 1/18',
        'picture': 'https://lh3.googleusercontent.com/algI',
        'description': 'Recorre el Parque',
        'type': 'anyOrder',
        'status': 'published',
        'lengthMeters': 181,
        'averageDurationMilliseconds': 438103,
        'steps': [
          {
            'objective': 'hack',
            'poi': {'id': 'p1', 'title': 'Portal', 'latitude': 1.0, 'longitude': 2.0, 'type': 'portal'},
          },
        ],
      });

      expect(mission.id, '3d06acb8975a427ab3fb358dea52fda5.1c');
      expect(mission.title, 'PARQUE SANTA ANA 1/18');
      expect(mission.type, 'anyOrder');
      expect(mission.status, 'published');
      expect(mission.lengthMeters, 181);
      expect(mission.averageDurationMilliseconds, 438103);
      expect(mission.steps, hasLength(1));
      expect(mission.author, isNull);
    });

    test('fromJson parses author when present', () {
      final mission = MissionItem.fromJson({
        'id': 'x',
        'title': 'T',
        'author': {'name': 'TestAgent', 'faction': 'enlightened'},
        'steps': [],
      });

      expect(mission.author, isNotNull);
      expect(mission.author!.name, 'TestAgent');
      expect(mission.author!.faction, 'enlightened');
    });

    test('pictureUrl resolves absolute picture as-is', () {
      final mission = MissionItem.fromJson({
        'id': 'abc',
        'title': 'T',
        'picture': 'https://lh3.googleusercontent.com/xyz',
        'steps': [],
      });
      expect(mission.pictureUrl, 'https://lh3.googleusercontent.com/xyz');
    });

    test('pictureUrl falls back to missions/{id}/picture when null', () {
      final mission = MissionItem.fromJson({'id': 'abc123', 'title': 'T', 'steps': []});
      expect(mission.pictureUrl, 'https://api.bannergress.com/missions/abc123/picture');
    });

    test('ingressUrl contains mission id', () {
      final mission = MissionItem.fromJson({'id': 'mymissionid', 'title': 'T', 'steps': []});
      expect(mission.ingressUrl, contains('mymissionid'));
      expect(mission.ingressUrl, startsWith('https://link.ingress.com/'));
    });
  });

  // ── BannerItem ────────────────────────────────────────────────────────────

  group('BannerItem — list response shape', () {
    late List<BannerItem> banners;

    setUpAll(() {
      banners = _fixtureList('banner_list.json')
          .cast<Map<String, dynamic>>()
          .map(BannerItem.fromJson)
          .toList();
    });

    test('parses correct number of banners', () {
      expect(banners, hasLength(3));
    });

    test('parses id and title', () {
      expect(banners[0].id, 'parque-santa-ana-6476');
      expect(banners[0].title, 'PARQUE SANTA ANA');
    });

    test('parses numeric fields', () {
      expect(banners[0].numberOfMissions, 18);
      expect(banners[0].numberOfDisabledMissions, 0);
      expect(banners[0].lengthMeters, 9501);
      expect(banners[0].width, 6);
    });

    test('parses coordinates', () {
      expect(banners[0].startLatitude, closeTo(-0.241489, 1e-6));
      expect(banners[0].startLongitude, closeTo(-78.519962, 1e-6));
    });

    test('parses formattedAddress', () {
      expect(banners[0].formattedAddress, 'Quito, Ecuador');
    });

    test('pictureUrl resolves relative picture path', () {
      expect(
        banners[0].pictureUrl,
        'https://api.bannergress.com/bnrs/pictures/db77f33065dbe755ea8c22b3ac739549',
      );
    });

    test('bannerUrl is correct', () {
      expect(banners[0].bannerUrl, 'https://bannergress.com/banner/parque-santa-ana-6476');
    });

    test('missions are empty for list response (no missions attribute)', () {
      expect(banners[0].missions, isEmpty);
    });

    test('author and authorAgent are null when missions are empty', () {
      expect(banners[0].author, isNull);
      expect(banners[0].authorAgent, isNull);
    });
  });

  group('BannerItem — detail response shape', () {
    late BannerItem banner;

    setUpAll(() {
      banner = BannerItem.fromJson(_fixture('banner_detail.json'));
    });

    test('parses top-level fields', () {
      expect(banner.id, 'parque-santa-ana-6476');
      expect(banner.title, 'PARQUE SANTA ANA');
      expect(banner.type, 'sequential');
      expect(banner.description, isNotNull);
      expect(banner.numberOfMissions, 18);
    });

    test('parses missions map and sorts by numeric key', () {
      // Fixture has keys "0", "9", "17" — must come out in that numeric order
      expect(banner.missions, hasLength(3));
      expect(banner.missions[0].title, 'PARQUE SANTA ANA 1/18');
      expect(banner.missions[1].title, 'PARQUE SANTA ANA 10/18');
      expect(banner.missions[2].title, 'PARQUE SANTA ANA 18/18');
    });

    test('parses steps within missions', () {
      expect(banner.missions[0].steps, hasLength(2));
      expect(banner.missions[0].steps[0].objective, 'hack');
    });

    test('detects enterPassphrase in last mission', () {
      final lastMission = banner.missions[2];
      expect(lastMission.steps.any((s) => s.objective == 'enterPassphrase'), isTrue);
    });

    test('handles unavailable POI in steps', () {
      final unavailableStep = banner.missions[1].steps
          .firstWhere((s) => s.poi?.type == 'unavailable');
      expect(unavailableStep.poi?.latitude, isNull);
    });

    test('author is from first mission (null when not provided)', () {
      expect(banner.missions[0].author, isNull);
      expect(banner.author, isNull);
      expect(banner.authorAgent, isNull);
    });

    test('authorAgent returns AgentItem from first mission with author', () {
      // The last mission (index 2) has author, but authorAgent uses missions.first
      // So we verify authorAgent on a banner whose first mission has an author
      final detail = BannerItem.fromJson({
        'id': 'x',
        'title': 'T',
        'missions': {
          '0': {
            'id': 'm1',
            'title': 'M1',
            'author': {'name': 'TestAgent', 'faction': 'resistance'},
            'steps': [],
          }
        },
      });

      expect(detail.author, 'TestAgent');
      expect(detail.authorAgent?.name, 'TestAgent');
      expect(detail.authorAgent?.faction, 'resistance');
    });

    test('pictureUrl resolves relative detail picture path', () {
      expect(
        banner.pictureUrl,
        'https://api.bannergress.com/bnrs/pictures/db77f33065dbe755ea8c22b3ac739549',
      );
    });

    test('absolute picture URLs are used as-is', () {
      final b = BannerItem.fromJson({
        'id': 'x',
        'title': 'T',
        'picture': 'https://example.com/img.png',
      });
      expect(b.pictureUrl, 'https://example.com/img.png');
    });

    test('pictureUrl falls back to /bnrs/{id}/picture when picture is null', () {
      final b = BannerItem.fromJson({'id': 'myid', 'title': 'T'});
      expect(b.pictureUrl, 'https://api.bannergress.com/bnrs/myid/picture');
    });
  });

  group('BannerItem — mission sort order', () {
    test('missions keyed 0,9,17 sort numerically, not lexicographically', () {
      // Lexicographic order would be "0","17","9" — numeric must be "0","9","17"
      final banner = BannerItem.fromJson({
        'id': 'x',
        'title': 'T',
        'missions': {
          '9':  {'id': 'm9',  'title': 'ninth',     'steps': []},
          '17': {'id': 'm17', 'title': 'seventeenth','steps': []},
          '0':  {'id': 'm0',  'title': 'first',     'steps': []},
        },
      });
      expect(banner.missions[0].title, 'first');
      expect(banner.missions[1].title, 'ninth');
      expect(banner.missions[2].title, 'seventeenth');
    });
  });
}
