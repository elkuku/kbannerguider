import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/screens/banner_list_page.dart';
import 'package:kbannerguider/services/auth_service.dart';
import 'package:kbannerguider/services/banner_service.dart';
import 'package:kbannerguider/services/location_service.dart';
import 'package:kbannerguider/widgets/filter_bar.dart';
import 'package:kbannerguider/widgets/sign_in_banner.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeLocationService extends LocationService {
  _FakeLocationService({Position? position, bool fail = false})
      : _position = position ?? _defaultPos,
        _fail = fail;

  static final _defaultPos = Position(
    latitude: -0.2295,
    longitude: -78.5243,
    timestamp: DateTime(2024),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  final Position _position;
  final bool _fail;

  @override
  Future<Position> getCurrentPosition() async {
    if (_fail) throw Exception('Location services are disabled.');
    return _position;
  }
}

class _CountingLocationService extends _FakeLocationService {
  _CountingLocationService({super.fail}) : super();
  int calls = 0;

  @override
  Future<Position> getCurrentPosition() async {
    calls++;
    return super.getCurrentPosition();
  }
}

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage([Map<String, String>? initial])
      : _map = Map.of(initial ?? {});
  final Map<String, String> _map;

  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<void> deleteAll() async => _map.clear();
}

/// Builds a minimal non-expired JWT so AuthService.getAccessToken() returns
/// it without attempting a network refresh.
String _makeJwt() {
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'test-user', 'exp': exp})))
      .replaceAll('=', '');
  return 'eyJhbGciOiJSUzI1NiJ9.$payload.sig';
}

AuthService _signedInAuth() => AuthService(
      storage: _FakeTokenStorage({
        'bg_refresh_token': 'fake-refresh',
        'bg_access_token': _makeJwt(),
      }),
      httpClient: MockClient((_) async => http.Response('', 404)),
    );

AuthService _signedOutAuth() => AuthService(
      storage: _FakeTokenStorage(),
      httpClient: MockClient((_) async => http.Response('', 404)),
    );

// ── Service builder ───────────────────────────────────────────────────────────

/// A BannerService whose MockClient distinguishes nearby vs list-type calls.
BannerService _bannerService({
  String nearbyBody = '[]',
  String todoBody = '[]',
  int nearbyStatus = 200,
}) =>
    BannerService(
      client: MockClient((request) async {
        if (request.url.queryParameters.containsKey('listTypes')) {
          final type = request.url.queryParameters['listTypes'];
          if (type == 'todo') return http.Response(todoBody, 200);
          return http.Response('[]', 200);
        }
        return http.Response(nearbyBody, nearbyStatus);
      }),
    );

const _twoBanners = '''[
  {"id":"b1","title":"Banner Alpha","numberOfMissions":6,
   "startLatitude":-0.230,"startLongitude":-78.525},
  {"id":"b2","title":"Banner Beta","numberOfMissions":3,
   "startLatitude":-0.231,"startLongitude":-78.526}
]''';

const _oneTodo = '''[
  {"id":"t1","title":"Todo Banner","numberOfMissions":4,"listType":"todo"}
]''';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildPage({
  LocationService? location,
  BannerService? bannerSvc,
  AuthService? auth,
  VoidCallback? onToggleTheme,
  bool isDarkMode = true,
}) =>
    MaterialApp(
      home: BannerListPage(
        locationService: location ?? _FakeLocationService(),
        bannerService: bannerSvc ?? _bannerService(),
        authService: auth,
        onToggleTheme: onToggleTheme,
        isDarkMode: isDarkMode,
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('BannerListPage', () {
    // ── Theme toggle ──────────────────────────────────────────────────────────

    group('Theme toggle', () {
      testWidgets('shows light_mode icon when isDarkMode is true',
          (tester) async {
        await tester.pumpWidget(_buildPage());
        expect(find.byIcon(Icons.light_mode), findsOneWidget);
      });

      testWidgets('shows dark_mode icon when isDarkMode is false',
          (tester) async {
        await tester.pumpWidget(_buildPage(isDarkMode: false));
        expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      });

      testWidgets('calls onToggleTheme when icon button tapped', (tester) async {
        var toggled = false;
        await tester.pumpWidget(_buildPage(onToggleTheme: () => toggled = true));
        await tester.tap(find.byIcon(Icons.light_mode));
        expect(toggled, isTrue);
      });
    });

    // ── Nearby tab — location error ────────────────────────────────────────────

    group('Nearby tab — location error', () {
      testWidgets('shows error message when location service fails',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(location: _FakeLocationService(fail: true)),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button re-fetches banners', (tester) async {
        final loc = _CountingLocationService(fail: true);
        await tester.pumpWidget(_buildPage(location: loc));
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        final callsBeforeRetry = loc.calls;

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(loc.calls, greaterThan(callsBeforeRetry));
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    // ── Nearby tab — banner count in tab label ──────────────────────────────

    group('Nearby tab — tab label', () {
      testWidgets('shows banner count in Nearby tab label when loaded',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(bannerSvc: _bannerService(nearbyBody: _twoBanners)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Nearby (2)'), findsOneWidget);
      });

      testWidgets('Nearby tab label has no count when empty', (tester) async {
        await tester.pumpWidget(_buildPage());
        await tester.pumpAndSettle();
        expect(find.text('Nearby'), findsOneWidget);
        expect(find.textContaining('Nearby ('), findsNothing);
      });
    });

    // ── Nearby tab — filter bar ────────────────────────────────────────────────

    group('Nearby tab — filter bar', () {
      testWidgets('FilterBar not shown when no authService', (tester) async {
        await tester.pumpWidget(
          _buildPage(bannerSvc: _bannerService(nearbyBody: _twoBanners)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FilterBar), findsNothing);
      });

      testWidgets('FilterBar not shown when signed out', (tester) async {
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(nearbyBody: _twoBanners),
            auth: _signedOutAuth(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FilterBar), findsNothing);
      });

      testWidgets('FilterBar shown when signed in and banners loaded',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(nearbyBody: _twoBanners),
            auth: _signedInAuth(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FilterBar), findsOneWidget);
      });

      testWidgets('shows no-match message when all banners filtered out',
          (tester) async {
        // Pre-select all filters as hidden so nothing is shown.
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(nearbyBody: _twoBanners),
            auth: _signedInAuth(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Unsorted chip to hide unsorted banners (b1 and b2 have
        // no list type → unsorted).
        await tester.tap(find.textContaining('Unsorted'));
        await tester.pump();
        expect(
          find.text('No banners match the selected filter.'),
          findsOneWidget,
        );
      });
    });

    // ── Auth — account button ──────────────────────────────────────────────────

    group('Auth — account button', () {
      testWidgets('no account button when authService is null', (tester) async {
        await tester.pumpWidget(_buildPage(auth: null));
        await tester.pump();
        expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
      });

      testWidgets('shows sign-in icon when authService set and not signed in',
          (tester) async {
        await tester.pumpWidget(_buildPage(auth: _signedOutAuth()));
        await tester.pumpAndSettle();
        // Icon appears in AppBar button AND in BannergressSignInBanner.
        expect(find.byIcon(Icons.account_circle_outlined), findsWidgets);
      });

      testWidgets(
          'shows filled account icon and sign-out menu when signed in',
          (tester) async {
        await tester.pumpWidget(_buildPage(auth: _signedInAuth()));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.account_circle), findsOneWidget);

        await tester.tap(find.byIcon(Icons.account_circle));
        await tester.pumpAndSettle();
        expect(find.text('Sign out'), findsOneWidget);
      });

      testWidgets('sign out clears signed-in state', (tester) async {
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(nearbyBody: _twoBanners),
            auth: _signedInAuth(),
          ),
        );
        await tester.pumpAndSettle();
        // Confirm signed in: FilterBar visible.
        expect(find.byType(FilterBar), findsOneWidget);

        // Open account menu and sign out.
        await tester.tap(find.byIcon(Icons.account_circle));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        // FilterBar gone, sign-in icon shown (AppBar + BannergressSignInBanner).
        expect(find.byType(FilterBar), findsNothing);
        expect(find.byIcon(Icons.account_circle_outlined), findsWidgets);
      });
    });

    // ── Auth — sign-in banner in Nearby tab ────────────────────────────────────

    group('Auth — sign-in banner', () {
      testWidgets('shows sign-in banner when authService set, not signed in',
          (tester) async {
        await tester.pumpWidget(_buildPage(auth: _signedOutAuth()));
        await tester.pumpAndSettle();
        expect(find.byType(BannergressSignInBanner), findsOneWidget);
        expect(find.text('Sign in'), findsWidgets);
      });

      testWidgets('no sign-in banner when authService is null', (tester) async {
        await tester.pumpWidget(_buildPage(auth: null));
        await tester.pumpAndSettle();
        expect(find.byType(BannergressSignInBanner), findsNothing);
      });

      testWidgets('sign-in banner hidden when signed in', (tester) async {
        await tester.pumpWidget(_buildPage(auth: _signedInAuth()));
        await tester.pumpAndSettle();
        expect(find.byType(BannergressSignInBanner), findsNothing);
      });
    });

    // ── To-do tab — not signed in ──────────────────────────────────────────────

    group('To-do tab — not signed in', () {
      Future<void> switchToTodo(WidgetTester tester) async {
        await tester.tap(find.text('To-do'));
        await tester.pumpAndSettle();
      }

      testWidgets('shows sign-in prompt when no authService', (tester) async {
        await tester.pumpWidget(_buildPage(auth: null));
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        expect(
          find.text('Sign in to see your Bannergress to-do list.'),
          findsOneWidget,
        );
      });

      testWidgets('shows sign-in prompt when authService set but not signed in',
          (tester) async {
        await tester.pumpWidget(_buildPage(auth: _signedOutAuth()));
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        expect(
          find.text('Sign in to see your Bannergress to-do list.'),
          findsOneWidget,
        );
      });

      testWidgets('shows sign-in button when authService provided',
          (tester) async {
        await tester.pumpWidget(_buildPage(auth: _signedOutAuth()));
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        // TextButton.icon with 'Sign in' label inside the todo empty state.
        expect(find.text('Sign in'), findsWidgets);
      });

      testWidgets('no sign-in button when no authService', (tester) async {
        await tester.pumpWidget(_buildPage(auth: null));
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        // TextButton.icon with login icon is the auth-service sign-in button.
        expect(find.byIcon(Icons.login), findsNothing);
      });
    });

    // ── To-do tab — signed in ─────────────────────────────────────────────────

    group('To-do tab — signed in', () {
      Future<void> switchToTodo(WidgetTester tester) async {
        await tester.tap(find.text('To-do'));
        await tester.pumpAndSettle();
      }

      testWidgets('shows empty message when signed in but no todos',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(todoBody: '[]'),
            auth: _signedInAuth(),
          ),
        );
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        expect(
          find.text('No to-do banners on Bannergress.'),
          findsOneWidget,
        );
      });

      testWidgets('shows todo banner titles when signed in', (tester) async {
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(todoBody: _oneTodo),
            auth: _signedInAuth(),
          ),
        );
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        expect(find.text('Todo Banner'), findsOneWidget);
      });

      testWidgets('shows banner count in To-do tab label', (tester) async {
        await tester.pumpWidget(
          _buildPage(
            bannerSvc: _bannerService(todoBody: _oneTodo),
            auth: _signedInAuth(),
          ),
        );
        await tester.pumpAndSettle();
        await switchToTodo(tester);
        expect(find.text('To-do (1)'), findsOneWidget);
      });
    });

    // ── Refresh button ─────────────────────────────────────────────────────────

    group('Refresh button', () {
      testWidgets('refresh button triggers a new fetch', (tester) async {
        var calls = 0;
        final svc = BannerService(
          client: MockClient((_) async {
            calls++;
            return http.Response('[]', 200);
          }),
        );
        await tester.pumpWidget(
          _buildPage(bannerSvc: svc),
        );
        await tester.pumpAndSettle();
        final callsAfterLoad = calls;

        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        expect(calls, greaterThan(callsAfterLoad));
      });

      testWidgets('refresh button is disabled while loading', (tester) async {
        // Use a delayed client so the loading state persists during the test.
        final completer = Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => http.Response('[]', 200),
        );
        final svc = BannerService(
          client: MockClient((_) => completer),
        );
        await tester.pumpWidget(_buildPage(bannerSvc: svc));
        await tester.pump(); // first frame — loading

        final btn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.refresh),
        );
        expect(btn.onPressed, isNull); // disabled while loading
        await tester.pump(const Duration(seconds: 2)); // drain timer
      });
    });
  });
}
