import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:kbannerguider/models/banner_item.dart';
import 'package:kbannerguider/models/mission_item.dart';
import 'package:kbannerguider/services/banner_service.dart';
import 'package:kbannerguider/widgets/banner_tile.dart';
import 'package:kbannerguider/widgets/filter_bar.dart';
import 'package:kbannerguider/widgets/guider_bar.dart';
import 'package:kbannerguider/widgets/list_type_selector.dart';
import 'package:kbannerguider/widgets/location_bar.dart';
import 'package:kbannerguider/widgets/mission_tile.dart';
import 'package:kbannerguider/widgets/sign_in_banner.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

Widget _wrapScrollable(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2024),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

BannerItem _banner({
  String id = 'test-banner',
  String title = 'Test Banner',
  int missions = 5,
  String? address,
  double? lat,
  double? lng,
  String? warning,
  String? listType,
  List<Map<String, dynamic>> missionsList = const [],
}) =>
    BannerItem.fromJson({
      'id': id,
      'title': title,
      'numberOfMissions': missions,
      'formattedAddress': ?address,
      'startLatitude': ?lat,
      'startLongitude': ?lng,
      'warning': ?warning,
      'listType': ?listType,
      if (missionsList.isNotEmpty)
        'missions': {
          for (var i = 0; i < missionsList.length; i++)
            '$i': missionsList[i],
        },
    });

MissionItem _mission({
  String id = 'mission-1',
  String title = 'Test Mission 1/5',
  String type = 'sequential',
  List<Map<String, dynamic>> steps = const [],
  Map<String, dynamic>? author,
}) =>
    MissionItem.fromJson({
      'id': id,
      'title': title,
      'type': type,
      'steps': steps,
      'author': ?author,
    });

Map<String, dynamic> _hackStep(String poiTitle) => {
      'objective': 'hack',
      'poi': {
        'id': 'poi-1',
        'title': poiTitle,
        'latitude': -0.2295,
        'longitude': -78.5243,
        'type': 'portal',
      },
    };

Map<String, dynamic> _passphraseStep() => {
      'objective': 'enterPassphrase',
      'poi': {
        'id': 'poi-2',
        'title': 'Secret Portal',
        'latitude': -0.2295,
        'longitude': -78.5243,
        'type': 'portal',
      },
    };

// ── GuiderBar ─────────────────────────────────────────────────────────────────

void main() {
  group('GuiderBar', () {
    testWidgets('shows Start label when currentIndex is 0', (tester) async {
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 0,
        total: 3,
        onDecrement: null,
        onIncrement: () {},
        onLaunch: () async {},
      )));
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('shows Next label in the middle', (tester) async {
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 1,
        total: 3,
        onDecrement: () {},
        onIncrement: () {},
        onLaunch: () async {},
      )));
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('shows Mark as done when at end', (tester) async {
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 3,
        total: 3,
        onDecrement: () {},
        onIncrement: null,
        onLaunch: null,
        onMarkDone: () async {},
      )));
      expect(find.text('Mark as done'), findsOneWidget);
    });

    testWidgets('counter shows currentIndex / total', (tester) async {
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 2,
        total: 5,
        onDecrement: () {},
        onIncrement: () {},
        onLaunch: () async {},
      )));
      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('increment button triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 1,
        total: 3,
        onDecrement: () {},
        onIncrement: () => tapped = true,
        onLaunch: () async {},
      )));
      await tester.tap(find.byIcon(Icons.add));
      expect(tapped, isTrue);
    });

    testWidgets('decrement button triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 1,
        total: 3,
        onDecrement: () => tapped = true,
        onIncrement: () {},
        onLaunch: () async {},
      )));
      await tester.tap(find.byIcon(Icons.remove));
      expect(tapped, isTrue);
    });

    testWidgets('launch button calls onLaunch', (tester) async {
      var launched = false;
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 1,
        total: 3,
        onDecrement: () {},
        onIncrement: () {},
        onLaunch: () async => launched = true,
      )));
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(launched, isTrue);
    });

    testWidgets('renders with dark theme background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: GuiderBar(
            currentIndex: 1,
            total: 3,
            onDecrement: () {},
            onIncrement: () {},
            onLaunch: () async {},
          ),
        ),
      ));
      expect(find.byType(GuiderBar), findsOneWidget);
    });

    testWidgets('mark done button calls onMarkDone at end', (tester) async {
      var done = false;
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 3,
        total: 3,
        onDecrement: () {},
        onIncrement: null,
        onLaunch: null,
        onMarkDone: () async => done = true,
      )));
      await tester.tap(find.text('Mark as done'));
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('shows spinner while launching and re-enables after',
        (tester) async {
      await tester.pumpWidget(_wrap(GuiderBar(
        currentIndex: 1,
        total: 3,
        onDecrement: () {},
        onIncrement: () {},
        onLaunch: () async {},
      )));
      await tester.tap(find.text('Next'));
      await tester.pump(); // spinner visible before microtask settles
      await tester.pump(); // microtask settles — back to normal
      expect(find.text('Next'), findsOneWidget);
    });
  });

  // ── ListTypeSelector ───────────────────────────────────────────────────────

  group('ListTypeSelector', () {
    testWidgets('shows all four options', (tester) async {
      await tester.pumpWidget(_wrap(ListTypeSelector(
        current: 'none',
        onChanged: (_) {},
      )));
      expect(find.text('None'), findsOneWidget);
      expect(find.text('To-do'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('calls onChanged with correct value when tapped',
        (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(ListTypeSelector(
        current: 'none',
        onChanged: (v) => selected = v,
      )));
      await tester.tap(find.text('To-do'));
      expect(selected, 'todo');
    });

    testWidgets('calls onChanged with done when Done tapped', (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(ListTypeSelector(
        current: 'none',
        onChanged: (v) => selected = v,
      )));
      await tester.tap(find.text('Done'));
      expect(selected, 'done');
    });

    testWidgets('calls onChanged with blacklist when Skip tapped',
        (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(ListTypeSelector(
        current: 'none',
        onChanged: (v) => selected = v,
      )));
      await tester.tap(find.text('Skip'));
      expect(selected, 'blacklist');
    });

    testWidgets('calls onChanged with none when None tapped', (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(ListTypeSelector(
        current: 'todo',
        onChanged: (v) => selected = v,
      )));
      await tester.tap(find.text('None'));
      expect(selected, 'none');
    });
  });

  // ── MissionTile ────────────────────────────────────────────────────────────

  group('MissionTile', () {
    testWidgets('shows mission title with 1-based index prefix',
        (tester) async {
      final m = _mission(title: 'Test Mission 1/5');
      await tester.pumpWidget(_wrap(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      expect(find.text('1. Test Mission 1/5'), findsOneWidget);
    });

    testWidgets('uses 1-based index (index=2 → "3.")', (tester) async {
      final m = _mission(title: 'Third Mission');
      await tester.pumpWidget(_wrap(MissionTile(
        index: 2,
        mission: m,
        color: Colors.red,
      )));
      expect(find.text('3. Third Mission'), findsOneWidget);
    });

    testWidgets('shows key icon when mission has passphrase step',
        (tester) async {
      final m = _mission(steps: [_passphraseStep()]);
      await tester.pumpWidget(_wrap(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      expect(find.byIcon(Icons.key_outlined), findsWidgets);
    });

    testWidgets('does not show key icon when no passphrase step',
        (tester) async {
      final m = _mission(steps: [_hackStep('Some Portal')]);
      await tester.pumpWidget(_wrap(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      // key icon is only shown for passphrase
      expect(find.byIcon(Icons.key_outlined), findsNothing);
    });

    testWidgets('shows open-in-ingress button', (tester) async {
      final m = _mission();
      await tester.pumpWidget(_wrap(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('expands to show waypoint titles', (tester) async {
      final m = _mission(steps: [_hackStep('Main Portal'), _hackStep('Side Portal')]);
      await tester.pumpWidget(_wrapScrollable(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Main Portal'), findsOneWidget);
      expect(find.text('Side Portal'), findsOneWidget);
    });

    testWidgets('shows no waypoint message when steps empty', (tester) async {
      final m = _mission(steps: []);
      await tester.pumpWidget(_wrapScrollable(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No waypoint data available.'), findsOneWidget);
    });

    testWidgets('step tiles show correct labels for every objective type',
        (tester) async {
      // One step per objective covers all switch cases in _StepTile.
      final m = _mission(steps: [
        {'objective': 'captureOrUpgrade', 'poi': {'id': 'p1', 'title': 'P1', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'createLink',       'poi': {'id': 'p2', 'title': 'P2', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'createField',      'poi': {'id': 'p3', 'title': 'P3', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'installMod',       'poi': {'id': 'p4', 'title': 'P4', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'takePhoto',        'poi': {'id': 'p5', 'title': 'P5', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'viewWaypoint',     'poi': {'id': 'p6', 'title': 'P6', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'enterPassphrase',  'poi': {'id': 'p7', 'title': 'P7', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
        {'objective': 'unknownObjective', 'poi': {'id': 'p8', 'title': 'P8', 'latitude': 0.0, 'longitude': 0.0, 'type': 'portal'}},
      ]);
      await tester.pumpWidget(_wrapScrollable(MissionTile(
        index: 0,
        mission: m,
        color: Colors.blue,
      )));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Capture/Upgrade'), findsOneWidget);
      expect(find.text('Create Link'),     findsOneWidget);
      expect(find.text('Create Field'),    findsOneWidget);
      expect(find.text('Install Mod'),     findsOneWidget);
      expect(find.text('Take Photo'),      findsOneWidget);
      expect(find.text('View Waypoint'),   findsOneWidget);
      expect(find.text('Enter Passphrase'),findsOneWidget);
      expect(find.text('unknownObjective'),findsOneWidget); // default case
    });
  });

  // ── InfoRow ────────────────────────────────────────────────────────────────

  group('InfoRow', () {
    testWidgets('shows label and value', (tester) async {
      await tester.pumpWidget(_wrap(const InfoRow(
        icon: Icons.flag,
        label: 'Missions',
        value: '18',
      )));
      expect(find.text('Missions: '), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('shows icon', (tester) async {
      await tester.pumpWidget(_wrap(const InfoRow(
        icon: Icons.straighten,
        label: 'Length',
        value: '9.5 km',
      )));
      expect(find.byIcon(Icons.straighten), findsOneWidget);
    });
  });

  // ── BannergressSignInBanner ────────────────────────────────────────────────

  group('BannergressSignInBanner', () {
    testWidgets('shows sign-in prompt when no error', (tester) async {
      await tester.pumpWidget(_wrap(BannergressSignInBanner(
        authError: null,
        onSignIn: () {},
      )));
      expect(
        find.text('Sign in to sync your To-do list from Bannergress'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('shows error text when authError is set', (tester) async {
      await tester.pumpWidget(_wrap(BannergressSignInBanner(
        authError: 'Login cancelled',
        onSignIn: () {},
      )));
      expect(find.text('Login cancelled'), findsOneWidget);
    });

    testWidgets('shows error icon when authError is set', (tester) async {
      await tester.pumpWidget(_wrap(BannergressSignInBanner(
        authError: 'Something went wrong',
        onSignIn: () {},
      )));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('calls onSignIn when button tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(BannergressSignInBanner(
        authError: null,
        onSignIn: () => tapped = true,
      )));
      await tester.tap(find.text('Sign in'));
      expect(tapped, isTrue);
    });

    testWidgets('shows account icon when no error', (tester) async {
      await tester.pumpWidget(_wrap(BannergressSignInBanner(
        authError: null,
        onSignIn: () {},
      )));
      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    });
  });

  // ── LocationBar ────────────────────────────────────────────────────────────

  group('LocationBar', () {
    testWidgets('shows Locating when no position and no custom center',
        (tester) async {
      await tester.pumpWidget(_wrap(LocationBar(
        position: null,
        customCenter: null,
        onPickLocation: () {},
        onClearCustom: () {},
      )));
      expect(find.textContaining('Locating'), findsOneWidget);
    });

    testWidgets('shows GPS coordinates when position is set', (tester) async {
      await tester.pumpWidget(_wrap(LocationBar(
        position: _pos(-0.22950, -78.52430),
        customCenter: null,
        onPickLocation: () {},
        onClearCustom: () {},
      )));
      expect(find.textContaining('-0.22950'), findsOneWidget);
      expect(find.textContaining('(GPS)'), findsOneWidget);
    });

    testWidgets('shows GPS icon when not custom', (tester) async {
      await tester.pumpWidget(_wrap(LocationBar(
        position: _pos(1.0, 2.0),
        customCenter: null,
        onPickLocation: () {},
        onClearCustom: () {},
      )));
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('shows custom pin icon when customCenter set', (tester) async {
      await tester.pumpWidget(_wrap(LocationBar(
        position: null,
        customCenter: const LatLng(-0.23, -78.52),
        onPickLocation: () {},
        onClearCustom: () {},
      )));
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
    });

    testWidgets('shows GPS-back icon when custom center is active',
        (tester) async {
      await tester.pumpWidget(_wrap(LocationBar(
        position: null,
        customCenter: const LatLng(-0.23, -78.52),
        onPickLocation: () {},
        onClearCustom: () {},
      )));
      expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    });

    testWidgets('calls onPickLocation when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(LocationBar(
        position: null,
        customCenter: null,
        onPickLocation: () => tapped = true,
        onClearCustom: () {},
      )));
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('calls onClearCustom when GPS button tapped', (tester) async {
      var cleared = false;
      await tester.pumpWidget(_wrap(LocationBar(
        position: null,
        customCenter: const LatLng(1.0, 2.0),
        onPickLocation: () {},
        onClearCustom: () => cleared = true,
      )));
      await tester.tap(find.byIcon(Icons.gps_fixed));
      expect(cleared, isTrue);
    });
  });

  // ── FilterBar ─────────────────────────────────────────────────────────────

  group('FilterBar', () {
    testWidgets('shows all four filter chips', (tester) async {
      await tester.pumpWidget(_wrap(FilterBar(
        hiddenFilters: {},
        listTypes: {},
        banners: [],
        onChanged: (_) {},
      )));
      expect(find.textContaining('To-do'), findsOneWidget);
      expect(find.textContaining('Done'), findsOneWidget);
      expect(find.textContaining('Skip'), findsOneWidget);
      expect(find.textContaining('Unsorted'), findsOneWidget);
    });

    testWidgets('shows correct unsorted count', (tester) async {
      final banners = [
        _banner(id: 'a'),
        _banner(id: 'b'),
        _banner(id: 'c'),
      ];
      // 'a' is todo, 'b' and 'c' are unsorted
      await tester.pumpWidget(_wrap(FilterBar(
        hiddenFilters: {},
        listTypes: {'a': 'todo'},
        banners: banners,
        onChanged: (_) {},
      )));
      expect(find.textContaining('Unsorted  2'), findsOneWidget);
      expect(find.textContaining('To-do  1'), findsOneWidget);
    });

    testWidgets('calls onChanged when chip tapped', (tester) async {
      Set<String>? result;
      await tester.pumpWidget(_wrap(FilterBar(
        hiddenFilters: {},
        listTypes: {},
        banners: [],
        onChanged: (h) => result = h,
      )));
      await tester.tap(find.textContaining('To-do'));
      expect(result, contains('todo'));
    });

    testWidgets('removes filter from hidden when deselected chip tapped',
        (tester) async {
      Set<String>? result;
      await tester.pumpWidget(_wrap(FilterBar(
        hiddenFilters: {'done'},
        listTypes: {},
        banners: [],
        onChanged: (h) => result = h,
      )));
      await tester.tap(find.textContaining('Done'));
      expect(result, isNot(contains('done')));
    });
  });

  // ── BannerTile ─────────────────────────────────────────────────────────────

  group('BannerTile', () {
    BannerService mockService() => BannerService(
          client: MockClient((_) async => http.Response('[]', 200)),
        );

    testWidgets('shows banner title', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(title: 'My Cool Banner'),
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.text('My Cool Banner'), findsOneWidget);
    });

    testWidgets('shows mission count', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(missions: 12),
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.textContaining('12 missions'), findsOneWidget);
    });

    testWidgets('shows singular "mission" for count of 1', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(missions: 1),
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.textContaining('1 mission'), findsOneWidget);
      expect(find.textContaining('missions'), findsNothing);
    });

    testWidgets('shows distance when provided', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(),
        bannerService: mockService(),
        listTypes: {},
        distance: '1.2 km',
      )));
      expect(find.textContaining('1.2 km'), findsOneWidget);
    });

    testWidgets('shows formatted address when banner has one', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(address: 'Quito, Ecuador'),
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.textContaining('Quito, Ecuador'), findsOneWidget);
    });

    testWidgets('shows todo badge icon when listType is todo', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(),
        bannerService: mockService(),
        listTypes: {},
        listType: 'todo',
      )));
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    });

    testWidgets('shows done badge icon when listType is done', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(),
        bannerService: mockService(),
        listTypes: {},
        listType: 'done',
      )));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('no badge shown when listType is null', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(),
        bannerService: mockService(),
        listTypes: {},
        listType: null,
      )));
      expect(find.byIcon(Icons.bookmark_outline), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('shows key icon when banner has passphrase mission',
        (tester) async {
      final b = _banner(missionsList: [
        {
          'id': 'm1',
          'title': 'M1',
          'steps': [_passphraseStep()],
        }
      ]);
      await tester.pumpWidget(_wrap(BannerTile(
        banner: b,
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.byIcon(Icons.key_outlined), findsOneWidget);
    });

    testWidgets('shows author name when signed in and author present',
        (tester) async {
      final b = _banner(missionsList: [
        {
          'id': 'm1',
          'title': 'M1',
          'steps': [],
          'author': {'name': 'TestAgent', 'faction': 'enlightened'},
        }
      ]);
      await tester.pumpWidget(_wrap(BannerTile(
        banner: b,
        bannerService: mockService(),
        listTypes: {},
        isSignedIn: true,
      )));
      expect(find.textContaining('TestAgent'), findsOneWidget);
    });

    testWidgets('hides author name when not signed in', (tester) async {
      final b = _banner(missionsList: [
        {
          'id': 'm1',
          'title': 'M1',
          'steps': [],
          'author': {'name': 'TestAgent', 'faction': 'enlightened'},
        }
      ]);
      await tester.pumpWidget(_wrap(BannerTile(
        banner: b,
        bannerService: mockService(),
        listTypes: {},
        isSignedIn: false,
      )));
      expect(find.textContaining('TestAgent'), findsNothing);
    });

    testWidgets('shows warning text when banner has warning', (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(warning: 'Mission unavailable'),
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.textContaining('Mission unavailable'), findsOneWidget);
    });

    testWidgets('shows blacklist badge icon when listType is blacklist',
        (tester) async {
      await tester.pumpWidget(_wrap(BannerTile(
        banner: _banner(),
        bannerService: mockService(),
        listTypes: {},
        listType: 'blacklist',
      )));
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    // These three tests use banners WITHOUT numberOfMissions so subtitleParts
    // is empty and the short-circuit || chain reaches lines 76-78.

    testWidgets('shows address when subtitleParts is empty', (tester) async {
      final b = BannerItem.fromJson({
        'id': 'b1',
        'title': 'X',
        'formattedAddress': 'Quito, Ecuador',
      });
      await tester.pumpWidget(_wrap(BannerTile(
        banner: b,
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.textContaining('Quito, Ecuador'), findsOneWidget);
    });

    testWidgets('shows author when subtitleParts is empty and signed in',
        (tester) async {
      final b = BannerItem.fromJson({
        'id': 'b1',
        'title': 'X',
        'missions': {
          '0': {
            'id': 'm1',
            'title': 'M1',
            'author': {'name': 'HeroAgent', 'faction': 'ENLIGHTENED'},
          },
        },
      });
      await tester.pumpWidget(_wrap(BannerTile(
        banner: b,
        bannerService: mockService(),
        listTypes: {},
        isSignedIn: true,
      )));
      expect(find.textContaining('HeroAgent'), findsOneWidget);
    });

    testWidgets('shows warning when subtitleParts is empty', (tester) async {
      final b = BannerItem.fromJson({
        'id': 'b1',
        'title': 'X',
        'warning': 'Danger!',
      });
      await tester.pumpWidget(_wrap(BannerTile(
        banner: b,
        bannerService: mockService(),
        listTypes: {},
      )));
      expect(find.textContaining('Danger!'), findsOneWidget);
    });
  });
}
