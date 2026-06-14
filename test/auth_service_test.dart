import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/services/auth_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// In-memory TokenStorage for tests.
class FakeTokenStorage implements TokenStorage {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> deleteAll() async => _data.clear();
}

/// Builds a JWT with an exp claim `expiresInSeconds` from now.
/// The signature is fake — AuthService only decodes the payload.
String _makeJwt(int expiresInSeconds) {
  final exp =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresInSeconds;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': exp, 'sub': 'agent007'})))
      .replaceAll('=', '');
  return 'eyJhbGciOiJSUzI1NiJ9.$payload.fakesig';
}

/// Token response body returned by the Keycloak token endpoint.
String _tokenBody({
  String accessToken = 'new_access_token',
  String refreshToken = 'new_refresh_token',
}) =>
    jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': 'Bearer',
      'expires_in': 300,
    });

AuthService _makeService({
  FakeTokenStorage? storage,
  http.Client? httpClient,
}) =>
    AuthService(
      storage: storage ?? FakeTokenStorage(),
      httpClient: httpClient ?? MockClient((_) async => http.Response('', 500)),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── isLoggedIn ─────────────────────────────────────────────────────────────

  group('AuthService.isLoggedIn', () {
    test('returns false when no refresh token stored', () async {
      final svc = _makeService();
      expect(await svc.isLoggedIn(), isFalse);
    });

    test('returns true when refresh token is stored', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'some_refresh_token');
      final svc = _makeService(storage: storage);
      expect(await svc.isLoggedIn(), isTrue);
    });

    test('returns false when refresh token is empty string', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', '');
      final svc = _makeService(storage: storage);
      expect(await svc.isLoggedIn(), isFalse);
    });
  });

  // ── getAccessToken ─────────────────────────────────────────────────────────

  group('AuthService.getAccessToken', () {
    test('returns null when no access token stored', () async {
      final svc = _makeService();
      expect(await svc.getAccessToken(), isNull);
    });

    test('returns stored token when it is not expired', () async {
      final storage = FakeTokenStorage();
      final validToken = _makeJwt(600); // expires 10 min from now
      await storage.write('bg_access_token', validToken);
      final svc = _makeService(storage: storage);

      expect(await svc.getAccessToken(), validToken);
    });

    test('triggers refresh when access token expires within 60 s', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_access_token', _makeJwt(30)); // expires soon
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient(
          (_) async => http.Response(_tokenBody(accessToken: 'refreshed'), 200),
        ),
      );

      expect(await svc.getAccessToken(), 'refreshed');
    });

    test('triggers refresh for an already-expired token', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_access_token', _makeJwt(-120)); // expired 2 min ago
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient(
          (_) async => http.Response(_tokenBody(accessToken: 'refreshed'), 200),
        ),
      );

      expect(await svc.getAccessToken(), 'refreshed');
    });

    test('triggers refresh for a malformed JWT', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_access_token', 'not.a.valid.jwt.at.all');
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient(
          (_) async => http.Response(_tokenBody(accessToken: 'refreshed'), 200),
        ),
      );

      expect(await svc.getAccessToken(), 'refreshed');
    });

    test('returns null when token is expired and refresh also fails', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_access_token', _makeJwt(-60));
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 401)),
      );

      expect(await svc.getAccessToken(), isNull);
    });

    test('deduplicates concurrent refresh calls', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_access_token', _makeJwt(-60));
      await storage.write('bg_refresh_token', 'rt');

      var callCount = 0;
      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((_) async {
          callCount++;
          return http.Response(_tokenBody(accessToken: 'refreshed'), 200);
        }),
      );

      // Fire three concurrent calls — only one HTTP request should go out.
      final results = await Future.wait([
        svc.getAccessToken(),
        svc.getAccessToken(),
        svc.getAccessToken(),
      ]);

      expect(callCount, 1);
      expect(results, everyElement('refreshed'));
    });
  });

  // ── refreshIfNeeded ────────────────────────────────────────────────────────

  group('AuthService.refreshIfNeeded', () {
    test('returns null when no refresh token is stored', () async {
      final svc = _makeService();
      expect(await svc.refreshIfNeeded(), isNull);
    });

    test('sends correct grant_type, client_id, and refresh_token', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'my_refresh_token');

      Map<String, String>? sentBody;
      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((req) async {
          sentBody = Uri.splitQueryString(req.body);
          return http.Response(_tokenBody(), 200);
        }),
      );

      await svc.refreshIfNeeded();

      expect(sentBody?['grant_type'], 'refresh_token');
      expect(sentBody?['client_id'], 'bannergress-website');
      expect(sentBody?['refresh_token'], 'my_refresh_token');
    });

    test('returns new access token and saves both tokens on success', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'old_rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((_) async => http.Response(
              _tokenBody(
                  accessToken: 'fresh_at', refreshToken: 'fresh_rt'),
              200,
            )),
      );

      final token = await svc.refreshIfNeeded();

      expect(token, 'fresh_at');
      expect(await storage.read('bg_access_token'), 'fresh_at');
      expect(await storage.read('bg_refresh_token'), 'fresh_rt');
    });

    test('calls logout and returns null on 401', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'rt');
      await storage.write('bg_access_token', 'at');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('', 401)),
      );

      final result = await svc.refreshIfNeeded();

      expect(result, isNull);
      expect(await storage.read('bg_refresh_token'), isNull);
      expect(await storage.read('bg_access_token'), isNull);
    });

    test('calls logout and returns null on non-200 response', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((_) async => http.Response('error', 500)),
      );

      expect(await svc.refreshIfNeeded(), isNull);
      expect(await storage.read('bg_refresh_token'), isNull);
    });

    test('calls logout and returns null on network error', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((_) async => throw Exception('network error')),
      );

      expect(await svc.refreshIfNeeded(), isNull);
      expect(await storage.read('bg_refresh_token'), isNull);
    });

    test('posts to the Keycloak token endpoint', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'rt');

      Uri? captured;
      final svc = _makeService(
        storage: storage,
        httpClient: MockClient((req) async {
          captured = req.url;
          return http.Response(_tokenBody(), 200);
        }),
      );

      await svc.refreshIfNeeded();

      expect(
        captured?.toString(),
        contains('login.bannergress.com'),
      );
      expect(captured?.path, contains('/token'));
    });
  });

  // ── logout ─────────────────────────────────────────────────────────────────

  group('AuthService.logout', () {
    test('clears access token and refresh token', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_access_token', 'at');
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(storage: storage);
      await svc.logout();

      expect(await storage.read('bg_access_token'), isNull);
      expect(await storage.read('bg_refresh_token'), isNull);
    });

    test('isLoggedIn returns false after logout', () async {
      final storage = FakeTokenStorage();
      await storage.write('bg_refresh_token', 'rt');

      final svc = _makeService(storage: storage);
      expect(await svc.isLoggedIn(), isTrue);

      await svc.logout();
      expect(await svc.isLoggedIn(), isFalse);
    });
  });
}
