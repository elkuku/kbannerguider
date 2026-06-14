// Tests built from real authenticated Bannergress API responses (Quito/Guayaquil,
// Ecuador) captured June 2026. Fixtures in test/fixtures/banner_nearby_auth.json
// and test/fixtures/banner_todo.json.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/services/banner_service.dart';

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  // ── Authenticated fetchNearby ──────────────────────────────────────────────

  group('BannerService.fetchNearby (authenticated)', () {
    test('parses banner id, title, address from authenticated response', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_nearby_auth.json'), 200)),
      );

      final banners =
          await service.fetchNearby(latitude: -0.2295, longitude: -78.5243, accessToken: 'tok');

      expect(banners[0].id, 'parque-santa-ana-6476');
      expect(banners[0].title, 'PARQUE SANTA ANA');
      expect(banners[0].formattedAddress, 'Quito, Ecuador');
    });

    test('populates missions and author from authenticated response', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_nearby_auth.json'), 200)),
      );

      final banners =
          await service.fetchNearby(latitude: -0.2295, longitude: -78.5243, accessToken: 'tok');

      final banner = banners[0];
      expect(banner.missions, isNotEmpty);
      expect(banner.authorAgent, isNotNull);
      expect(banner.authorAgent!.name, 'GreenAgent42');
      expect(banner.authorAgent!.faction, 'enlightened');
    });

    test('author getter returns name string from first mission', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_nearby_auth.json'), 200)),
      );

      final banners =
          await service.fetchNearby(latitude: -0.2295, longitude: -78.5243, accessToken: 'tok');

      expect(banners[0].author, 'GreenAgent42');
    });

    test('missions are sorted numerically even in authenticated response', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_nearby_auth.json'), 200)),
      );

      final banners =
          await service.fetchNearby(latitude: -0.2295, longitude: -78.5243, accessToken: 'tok');

      final missions = banners[0].missions;
      expect(missions[0].title, 'PARQUE SANTA ANA 1/18');
      expect(missions[1].title, 'PARQUE SANTA ANA 2/18');
    });

    test('mission steps include POI title and coordinates', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_nearby_auth.json'), 200)),
      );

      final banners =
          await service.fetchNearby(latitude: -0.2295, longitude: -78.5243, accessToken: 'tok');

      final firstStep = banners[0].missions[0].steps[0];
      expect(firstStep.objective, 'hack');
      expect(firstStep.poi?.title, 'Entrada Principal Parque Santa Ana');
      expect(firstStep.poi?.latitude, closeTo(-0.241489, 1e-6));
      expect(firstStep.poi?.longitude, closeTo(-78.519962, 1e-6));
    });

    test('sends all required attributes in URL when authenticated', () async {
      Uri? captured;
      final service = BannerService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response('[]', 200);
        }),
      );

      await service.fetchNearby(latitude: 0, longitude: 0, accessToken: 'tok');

      final attrs = captured?.queryParametersAll['attributes'] ?? [];
      expect(attrs, containsAll(['id', 'title', 'missions', 'listType', 'warning']));
    });

    test('returns 2 banners from authenticated fixture', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_nearby_auth.json'), 200)),
      );

      final banners =
          await service.fetchNearby(latitude: -0.2295, longitude: -78.5243, accessToken: 'tok');

      expect(banners, hasLength(2));
    });
  });

  // ── fetchByListType (todo) ─────────────────────────────────────────────────

  group('BannerService.fetchByListType — real todo response', () {
    test('parses listType field as "todo"', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      expect(banners[0].listType, 'todo');
    });

    test('parses banner id and title from todo response', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      expect(banners[0].id, 'un-atardecer-con-la-perla-df54');
      expect(banners[0].title, 'Un atardecer con la Perla');
      expect(banners[0].formattedAddress, 'Guayaquil, Ecuador');
    });

    test('populates author from missions in todo response', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      expect(banners[0].authorAgent?.name, 'BlueAgent99');
      expect(banners[0].authorAgent?.faction, 'resistance');
    });

    test('resolves relative picture URL for todo banner', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      expect(
        banners[0].pictureUrl,
        'https://api.bannergress.com/bnrs/pictures/01e7182e17381def60c07f2eadf71f15',
      );
    });

    test('todo banner has correct mission count', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      expect(banners[0].numberOfMissions, 36);
    });

    test('mission step has correct objective and POI type', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      final step = banners[0].missions[0].steps[0];
      expect(step.objective, 'hack');
      expect(step.poi?.type, 'portal');
      expect(step.poi?.title, 'Tucan De Mi Tierra');
    });

    test('returns 2 banners from todo fixture', () async {
      final service = BannerService(
        client: MockClient(
            (_) async => http.Response(_fixture('banner_todo.json'), 200)),
      );

      final banners =
          await service.fetchByListType(listType: 'todo', accessToken: 'tok');

      expect(banners, hasLength(2));
    });
  });
}
