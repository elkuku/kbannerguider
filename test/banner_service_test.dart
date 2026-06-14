import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/services/banner_service.dart';

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  group('BannerService.fetchNearby', () {
    test('parses real list response shape', () async {
      final body = _fixture('banner_list.json');
      final service = BannerService(
        client: MockClient((_) async => http.Response(body, 200)),
      );

      final banners = await service.fetchNearby(latitude: -0.2295, longitude: -78.5243);

      expect(banners, hasLength(3));
      expect(banners[0].id, 'parque-santa-ana-6476');
      expect(banners[0].title, 'PARQUE SANTA ANA');
      expect(banners[0].numberOfMissions, 18);
      expect(banners[0].startLatitude, closeTo(-0.241489, 1e-6));
    });

    test('sends proximity parameters in URL', () async {
      Uri? captured;
      final service = BannerService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response('[]', 200);
        }),
      );

      await service.fetchNearby(latitude: 1.23, longitude: 4.56);

      expect(captured?.queryParameters['proximityLatitude'], '1.23');
      expect(captured?.queryParameters['proximityLongitude'], '4.56');
      expect(captured?.queryParameters['orderBy'], 'proximityStartPoint');
    });

    test('sends Bearer header when token provided', () async {
      String? authHeader;
      final service = BannerService(
        client: MockClient((req) async {
          authHeader = req.headers['Authorization'];
          return http.Response('[]', 200);
        }),
      );

      await service.fetchNearby(
        latitude: 0,
        longitude: 0,
        accessToken: 'mytoken',
      );

      expect(authHeader, 'Bearer mytoken');
    });

    test('does not send Authorization header without token', () async {
      String? authHeader;
      final service = BannerService(
        client: MockClient((req) async {
          authHeader = req.headers['Authorization'];
          return http.Response('[]', 200);
        }),
      );

      await service.fetchNearby(latitude: 0, longitude: 0);

      expect(authHeader, isNull);
    });

    test('sends attributes parameters only when authenticated', () async {
      final withAuth = <String>[];
      final withoutAuth = <String>[];

      final svcAuth = BannerService(
        client: MockClient((req) async {
          withAuth.addAll(req.url.queryParametersAll['attributes'] ?? []);
          return http.Response('[]', 200);
        }),
      );
      final svcAnon = BannerService(
        client: MockClient((req) async {
          withoutAuth.addAll(req.url.queryParametersAll['attributes'] ?? []);
          return http.Response('[]', 200);
        }),
      );

      await svcAuth.fetchNearby(latitude: 0, longitude: 0, accessToken: 'tok');
      await svcAnon.fetchNearby(latitude: 0, longitude: 0);

      expect(withAuth, contains('missions'));
      expect(withoutAuth, isEmpty);
    });

    test('throws on non-200 response', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('error', 500)),
      );

      expect(
        () => service.fetchNearby(latitude: 0, longitude: 0),
        throwsA(isA<Exception>()),
      );
    });

    test('sends offset parameter for pagination', () async {
      Uri? captured;
      final service = BannerService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response('[]', 200);
        }),
      );

      await service.fetchNearby(latitude: 0, longitude: 0, offset: 25);

      expect(captured?.queryParameters['offset'], '25');
    });
  });

  group('BannerService.fetchById', () {
    test('parses real detail response shape', () async {
      final body = _fixture('banner_detail.json');
      final service = BannerService(
        client: MockClient((_) async => http.Response(body, 200)),
      );

      final banner = await service.fetchById('parque-santa-ana-6476');

      expect(banner.id, 'parque-santa-ana-6476');
      expect(banner.title, 'PARQUE SANTA ANA');
      expect(banner.missions, hasLength(3));
      expect(banner.type, 'sequential');
    });

    test('missions are sorted numerically from detail response', () async {
      final body = _fixture('banner_detail.json');
      final service = BannerService(
        client: MockClient((_) async => http.Response(body, 200)),
      );

      final banner = await service.fetchById('any');

      expect(banner.missions[0].title, 'PARQUE SANTA ANA 1/18');
      expect(banner.missions[1].title, 'PARQUE SANTA ANA 10/18');
      expect(banner.missions[2].title, 'PARQUE SANTA ANA 18/18');
    });

    test('sends Bearer header when access token provided', () async {
      String? authHeader;
      final service = BannerService(
        client: MockClient((req) async {
          authHeader = req.headers['Authorization'];
          return http.Response(jsonEncode({'id': 'x', 'title': 'T'}), 200);
        }),
      );

      await service.fetchById('x', accessToken: 'tok123');

      expect(authHeader, 'Bearer tok123');
    });

    test('does not send Authorization header without token', () async {
      String? authHeader;
      final service = BannerService(
        client: MockClient((req) async {
          authHeader = req.headers['Authorization'];
          return http.Response(jsonEncode({'id': 'x', 'title': 'T'}), 200);
        }),
      );

      await service.fetchById('x');

      expect(authHeader, isNull);
    });

    test('URL-encodes the banner id', () async {
      Uri? captured;
      final service = BannerService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(jsonEncode({'id': 'a/b', 'title': 'T'}), 200);
        }),
      );

      await service.fetchById('a/b');

      expect(captured?.path, contains('a%2Fb'));
    });

    test('throws on non-200 response', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('not found', 404)),
      );

      expect(() => service.fetchById('x'), throwsA(isA<Exception>()));
    });
  });

  group('BannerService.setListType', () {
    test('sends POST with correct body and auth header', () async {
      http.Request? captured;
      final service = BannerService(
        client: MockClient((req) async {
          captured = req;
          return http.Response('', 200);
        }),
      );

      await service.setListType('banner-id', 'todo', 'mytoken');

      expect(captured?.method, 'POST');
      expect(captured?.headers['Authorization'], 'Bearer mytoken');
      expect(captured?.body, '{"listType":"todo"}');
    });

    test('throws SessionExpiredException on 401', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('', 401)),
      );

      expect(
        () => service.setListType('x', 'todo', 'tok'),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('accepts 204 as success', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('', 204)),
      );

      await expectLater(service.setListType('x', 'done', 'tok'), completes);
    });
  });

  group('BannerService.fetchByListType', () {
    test('parses list-type response as array', () async {
      final body = _fixture('banner_list.json');
      final service = BannerService(
        client: MockClient((_) async => http.Response(body, 200)),
      );

      final banners = await service.fetchByListType(
        listType: 'todo',
        accessToken: 'tok',
      );

      expect(banners, hasLength(3));
    });

    test('throws SessionExpiredException on 401', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('', 401)),
      );

      expect(
        () => service.fetchByListType(listType: 'todo', accessToken: 'tok'),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('sends listTypes and attributes in query', () async {
      Uri? captured;
      final service = BannerService(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response('[]', 200);
        }),
      );

      await service.fetchByListType(listType: 'done', accessToken: 'tok');

      expect(captured?.queryParameters['listTypes'], 'done');
      expect(captured?.queryParametersAll['attributes'], contains('missions'));
    });

    test('throws generic exception on non-200 non-401 status', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('', 500)),
      );

      await expectLater(
        () => service.fetchByListType(listType: 'todo', accessToken: 'tok'),
        throwsException,
      );
    });
  });

  group('BannerService.setListType — error paths', () {
    test('throws generic exception on non-200/204 non-401 status', () async {
      final service = BannerService(
        client: MockClient((_) async => http.Response('', 500)),
      );

      await expectLater(
        () => service.setListType('b1', 'todo', 'tok'),
        throwsException,
      );
    });
  });

  group('SessionExpiredException', () {
    test('toString returns readable message', () {
      expect(
        SessionExpiredException().toString(),
        'Session expired — please sign in again.',
      );
    });
  });
}
