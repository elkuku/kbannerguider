import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/models/banner_item.dart';
import 'package:kbannerguider/screens/banner_detail_page.dart';
import 'package:kbannerguider/services/banner_service.dart';
import 'package:kbannerguider/widgets/list_type_selector.dart';
import 'package:kbannerguider/widgets/mission_tile.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _hackStep(String title) => {
      'objective': 'hack',
      'poi': {
        'id': 'poi-$title',
        'title': title,
        'latitude': -0.2295,
        'longitude': -78.5243,
        'type': 'portal',
      },
    };

Map<String, dynamic> _passphraseStep() => {
      'objective': 'enterPassphrase',
      'poi': {
        'id': 'poi-pp',
        'title': 'Passphrase Portal',
        'latitude': -0.2295,
        'longitude': -78.5243,
        'type': 'portal',
      },
    };

Map<String, dynamic> _missionJson({
  String id = 'm1',
  String title = 'Mission 1/3',
  String type = 'sequential',
  List<Map<String, dynamic>> steps = const [],
  Map<String, dynamic>? author,
}) =>
    {
      'id': id,
      'title': title,
      'type': type,
      'steps': steps,
      'author': ?author,
    };

BannerItem _banner({
  String id = 'banner-1',
  String title = 'Test Banner',
  String? description,
  String? warning,
  String? type = 'sequential',
  int? numberOfMissions = 3,
  int? numberOfDisabledMissions,
  int? lengthMeters = 2500,
  String? formattedAddress = 'Quito, Ecuador',
  double? startLatitude,
  double? startLongitude,
  String? listType,
  List<Map<String, dynamic>> missions = const [],
}) =>
    BannerItem.fromJson({
      'id': id,
      'title': title,
      'numberOfMissions': numberOfMissions,
      'type': ?type,
      'description': ?description,
      'warning': ?warning,
      'numberOfDisabledMissions': ?numberOfDisabledMissions,
      'lengthMeters': ?lengthMeters,
      'formattedAddress': ?formattedAddress,
      'startLatitude': ?startLatitude,
      'startLongitude': ?startLongitude,
      'listType': ?listType,
      if (missions.isNotEmpty)
        'missions': {
          for (var i = 0; i < missions.length; i++) '$i': missions[i],
        },
    });

// ── Helpers ───────────────────────────────────────────────────────────────────

/// MockClient that returns 404 so _loadDetail fails silently, keeping
/// the banner that was passed in as the initial widget.banner.
BannerService _failingService() => BannerService(
      client: MockClient((_) async => http.Response('', 404)),
    );

/// MockClient that returns a full banner JSON so _loadDetail succeeds
/// and replaces _banner with the fetched version.
BannerService _serviceReturning(BannerItem banner) {
  final body = jsonEncode({
    'id': banner.id,
    'title': banner.title,
    'type': banner.type,
    'description': banner.description,
    'warning': banner.warning,
    'numberOfMissions': banner.numberOfMissions,
    'numberOfDisabledMissions': banner.numberOfDisabledMissions,
    'lengthMeters': banner.lengthMeters,
    'formattedAddress': banner.formattedAddress,
    'startLatitude': banner.startLatitude,
    'startLongitude': banner.startLongitude,
    'listType': banner.listType,
    if (banner.missions.isNotEmpty)
      'missions': {
        for (var i = 0; i < banner.missions.length; i++)
          '$i': {
            'id': banner.missions[i].id,
            'title': banner.missions[i].title,
            'type': banner.missions[i].type,
            'steps': banner.missions[i].steps
                .map((s) => {
                      'objective': s.objective,
                      if (s.poi != null)
                        'poi': {
                          'id': s.poi!.id,
                          'title': s.poi!.title,
                          'latitude': s.poi!.latitude,
                          'longitude': s.poi!.longitude,
                          'type': s.poi!.type,
                        },
                    })
                .toList(),
            if (banner.missions[i].author != null)
              'author': {
                'name': banner.missions[i].author!.name,
                'faction': banner.missions[i].author!.faction,
              },
          },
      },
  });
  return BannerService(
    client: MockClient((_) async => http.Response(body, 200)),
  );
}

/// Wraps BannerDetailPage in a minimal navigator so Navigator.pop works.
Widget _buildPage(
  BannerItem banner, {
  Map<String, String> listTypes = const {},
  Future<String?> Function()? getToken,
  BannerService? service,
}) =>
    MaterialApp(
      home: BannerDetailPage(
        banner: banner,
        bannerService: service ?? _failingService(),
        listTypes: listTypes,
        getToken: getToken,
      ),
    );

/// Pumps enough frames for the async _loadDetail to complete.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('BannerDetailPage', () {
    // ── AppBar ──────────────────────────────────────────────────────────────

    group('AppBar', () {
      testWidgets('shows banner title', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(title: 'Awesome Route')));
        await _settle(tester);
        expect(find.text('Awesome Route'), findsWidgets);
      });

      testWidgets('shows Missions and Map tabs', (tester) async {
        await tester.pumpWidget(_buildPage(_banner()));
        await _settle(tester);
        expect(find.text('Missions'), findsOneWidget);
        expect(find.text('Map'), findsOneWidget);
      });

      testWidgets('shows loading spinner during fetch', (tester) async {
        // Use a slow client so the spinner is visible on first pump.
        final completer = Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => http.Response('', 200),
        );
        final service = BannerService(
          client: MockClient((_) => completer),
        );
        await tester.pumpWidget(_buildPage(_banner(), service: service));
        await tester.pump(); // first frame — still loading
        // AppBar spinner + possible loading spinner below info (missions empty)
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        // Drain the pending 1-second timer so the test can finish cleanly.
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('hides spinner once detail fetch completes', (tester) async {
        await tester.pumpWidget(_buildPage(_banner()));
        await _settle(tester);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    // ── Info tab — layout ───────────────────────────────────────────────────

    group('Info tab layout', () {
      testWidgets('shows banner title as heading', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(title: 'Quito Art Walk')));
        await _settle(tester);
        // Title appears in both AppBar and the heading inside the info tab.
        expect(find.text('Quito Art Walk'), findsWidgets);
      });

      testWidgets('shows description when set', (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(description: 'A great banner route.')),
        );
        await _settle(tester);
        expect(find.text('A great banner route.'), findsOneWidget);
      });

      testWidgets('does not show description section when absent',
          (tester) async {
        await tester.pumpWidget(_buildPage(_banner(description: null)));
        await _settle(tester);
        expect(find.text('A great banner route.'), findsNothing);
      });

      testWidgets('shows warning card when banner has warning', (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(warning: 'Mission 3 is disabled')),
        );
        await _settle(tester);
        expect(find.text('Mission 3 is disabled'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      });

      testWidgets('shows passphrase warning when mission has passphrase step',
          (tester) async {
        final b = _banner(missions: [
          _missionJson(steps: [_passphraseStep()]),
        ]);
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        expect(
          find.text('One or more missions require a passphrase.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.key_outlined), findsWidgets);
      });

      testWidgets('no passphrase warning when no passphrase steps',
          (tester) async {
        final b = _banner(missions: [
          _missionJson(steps: [_hackStep('Portal A')]),
        ]);
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        expect(
          find.text('One or more missions require a passphrase.'),
          findsNothing,
        );
      });

      testWidgets('shows View on Bannergress link', (tester) async {
        await tester.pumpWidget(_buildPage(_banner()));
        await _settle(tester);
        expect(find.text('View on Bannergress'), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      });
    });

    // ── Info tab — InfoRows ─────────────────────────────────────────────────

    group('Info tab InfoRows', () {
      testWidgets('shows Sequential for sequential type', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(type: 'sequential')));
        await _settle(tester);
        expect(find.text('Sequential'), findsOneWidget);
      });

      testWidgets('shows Any order for non-sequential type', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(type: 'anyOrder')));
        await _settle(tester);
        expect(find.text('Any order'), findsOneWidget);
      });

      testWidgets('shows mission count', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(numberOfMissions: 7)));
        await _settle(tester);
        // InfoRow label + value
        expect(find.text('Missions: '), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
      });

      testWidgets('shows disabled missions in count when some disabled',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(
            numberOfMissions: 5,
            numberOfDisabledMissions: 1,
          )),
        );
        await _settle(tester);
        expect(find.text('4 active (1 disabled)'), findsOneWidget);
      });

      testWidgets('shows route length formatted', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(lengthMeters: 3500)));
        await _settle(tester);
        expect(find.text('3.5 km'), findsOneWidget);
      });

      testWidgets('shows formatted address', (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(formattedAddress: 'Guayaquil, Ecuador')),
        );
        await _settle(tester);
        expect(find.text('Guayaquil, Ecuador'), findsWidgets);
      });

      testWidgets('shows coordinates when no formatted address', (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(
            formattedAddress: null,
            startLatitude: -2.17403,
            startLongitude: -79.92202,
          )),
        );
        await _settle(tester);
        expect(find.textContaining('-2.17403'), findsOneWidget);
        expect(find.textContaining('-79.92202'), findsOneWidget);
      });

      testWidgets('shows author name from first mission', (tester) async {
        final b = _banner(missions: [
          _missionJson(author: {
            'name': 'GreenAgent42',
            'faction': 'enlightened',
          }),
        ]);
        await tester.pumpWidget(_buildPage(b, getToken: () async => null));
        await _settle(tester);
        expect(find.text('GreenAgent42'), findsOneWidget);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      });

      testWidgets('omits author row when no missions', (tester) async {
        await tester
            .pumpWidget(_buildPage(_banner(), getToken: () async => null));
        await _settle(tester);
        expect(find.byIcon(Icons.person_outline), findsNothing);
      });
    });

    // ── List-type selector ──────────────────────────────────────────────────

    group('ListTypeSelector', () {
      testWidgets('hidden when getToken is null', (tester) async {
        await tester.pumpWidget(_buildPage(_banner(), getToken: null));
        await _settle(tester);
        expect(find.byType(ListTypeSelector), findsNothing);
      });

      testWidgets('shown when getToken is provided', (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(), getToken: () async => null),
        );
        await _settle(tester);
        expect(find.byType(ListTypeSelector), findsOneWidget);
      });

      testWidgets('shows None selected when banner not in listTypes',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(_banner(), getToken: () async => null),
        );
        await _settle(tester);
        // ListTypeSelector renders all four options; "None" is current
        expect(find.text('None'), findsOneWidget);
        expect(find.text('To-do'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
      });

      testWidgets('shows todo as current when listTypes contains todo',
          (tester) async {
        await tester.pumpWidget(
          _buildPage(
            _banner(id: 'banner-1'),
            listTypes: {'banner-1': 'todo'},
            getToken: () async => null,
          ),
        );
        await _settle(tester);
        // The ListTypeSelector is built with current='todo'
        final selector = tester.widget<ListTypeSelector>(
          find.byType(ListTypeSelector),
        );
        expect(selector.current, 'todo');
      });
    });

    // ── Missions list ───────────────────────────────────────────────────────

    group('Missions list', () {
      testWidgets('shows mission count header when banner has missions',
          (tester) async {
        final b = _banner(missions: [
          _missionJson(id: 'm1', title: 'M1'),
          _missionJson(id: 'm2', title: 'M2'),
          _missionJson(id: 'm3', title: 'M3'),
        ]);
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        expect(find.text('Missions (3)'), findsOneWidget);
      });

      testWidgets('shows MissionTile widgets after scrolling to them',
          (tester) async {
        final b = _banner(missions: [
          _missionJson(id: 'm1', title: 'First Mission'),
          _missionJson(id: 'm2', title: 'Second Mission'),
        ]);
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        // Missions are rendered in a SliverList below the info section;
        // drag the scroll view down to bring them into the viewport.
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();
        expect(find.byType(MissionTile), findsWidgets);
      });

      testWidgets('mission tile shows 1-based title after scrolling',
          (tester) async {
        final b = _banner(missions: [
          _missionJson(id: 'm1', title: 'First Mission'),
        ]);
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();
        expect(find.textContaining('1. First Mission'), findsOneWidget);
      });

      testWidgets('shows loading spinner when loading and no missions yet',
          (tester) async {
        // Slow client + empty banner (no missions) → two spinners:
        // one in the AppBar and one below the info section.
        final completer = Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => http.Response('', 200),
        );
        final service = BannerService(
          client: MockClient((_) => completer),
        );
        await tester.pumpWidget(
          _buildPage(_banner(missions: []), service: service),
        );
        await tester.pump(); // first frame — still loading, no missions
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        await tester.pump(const Duration(seconds: 2)); // drain timer
      });
    });

    // ── Detail load from network ────────────────────────────────────────────

    group('Detail fetch', () {
      testWidgets('enriches banner from network response', (tester) async {
        // Start with a sparse banner; server returns the full version.
        final sparse = _banner(
          description: null,
          missions: [],
          lengthMeters: null,
        );
        final full = _banner(
          description: 'Fetched description',
          missions: [_missionJson(title: 'Fetched Mission')],
          lengthMeters: 5000,
        );
        await tester.pumpWidget(
          _buildPage(sparse, service: _serviceReturning(full)),
        );
        await _settle(tester);
        expect(find.text('Fetched description'), findsOneWidget);
        expect(find.text('5.0 km'), findsOneWidget);
      });
    });

    // ── _setListType ─────────────────────────────────────────────────────────

    group('_setListType', () {
      testWidgets('changing list type posts to the API', (tester) async {
        var postCalled = false;
        final svc = BannerService(
          client: MockClient((request) async {
            if (request.method == 'POST') postCalled = true;
            return http.Response('', 200);
          }),
        );
        await tester.pumpWidget(_buildPage(
          _banner(id: 'banner-1'),
          getToken: () async => 'fake-token',
          service: svc,
        ));
        await _settle(tester);

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(postCalled, isTrue);
      });

      testWidgets('selecting the same type again skips the API call',
          (tester) async {
        var postCount = 0;
        final svc = BannerService(
          client: MockClient((request) async {
            if (request.method == 'POST') postCount++;
            return http.Response('', 200);
          }),
        );
        await tester.pumpWidget(_buildPage(
          _banner(id: 'banner-1'),
          listTypes: {'banner-1': 'done'},
          getToken: () async => 'fake-token',
          service: svc,
        ));
        await _settle(tester);

        await tester.tap(find.text('Done')); // same as current
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(postCount, isZero);
      });

      testWidgets('selecting None removes banner from returned listTypes',
          (tester) async {
        Map<String, String>? returned;

        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) {
            return TextButton(
              onPressed: () async {
                returned = await Navigator.push<Map<String, String>>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => BannerDetailPage(
                      banner: _banner(id: 'banner-1'),
                      bannerService: _failingService(),
                      listTypes: {'banner-1': 'todo'},
                      getToken: () async => null, // no API call
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            );
          }),
        ));

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('None'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(returned, isNotNull);
        expect(returned!.containsKey('banner-1'), isFalse);
      });
    });

    // ── Event and offline dates ───────────────────────────────────────────────

    group('Event and offline dates', () {
      testWidgets('shows event date range when both dates are set',
          (tester) async {
        final b = BannerItem.fromJson({
          'id': 'ev1',
          'title': 'Event Banner',
          'eventStartDate': '2026-01-01',
          'eventEndDate': '2026-01-07',
        });
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        expect(find.textContaining('2026-01-01'), findsOneWidget);
        expect(find.textContaining('2026-01-07'), findsOneWidget);
      });

      testWidgets('shows only start date when no end date', (tester) async {
        final b = BannerItem.fromJson({
          'id': 'ev2',
          'title': 'Event Banner',
          'eventStartDate': '2026-06-15',
        });
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        expect(find.textContaining('2026-06-15'), findsOneWidget);
      });

      testWidgets('shows planned offline date', (tester) async {
        final b = BannerItem.fromJson({
          'id': 'off1',
          'title': 'Offline Banner',
          'plannedOfflineDate': '2026-12-31',
        });
        await tester.pumpWidget(_buildPage(b));
        await _settle(tester);
        expect(find.textContaining('2026-12-31'), findsOneWidget);
      });
    });

    // ── Navigation ──────────────────────────────────────────────────────────

    group('Navigation', () {
      testWidgets('back button pops and returns listTypes', (tester) async {
        Map<String, String>? returned;

        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) {
            return TextButton(
              onPressed: () async {
                returned = await Navigator.push<Map<String, String>>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => BannerDetailPage(
                      banner: _banner(id: 'banner-1'),
                      bannerService: _failingService(),
                      listTypes: {'banner-1': 'todo'},
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            );
          }),
        ));

        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byType(BackButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(returned, isNotNull);
        expect(returned, containsPair('banner-1', 'todo'));
      });

      testWidgets('system back gesture is intercepted (canPop is false)',
          (tester) async {
        // Navigate to the page via push so PopScope is active on the stack.
        Map<String, String>? returned;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              returned = await Navigator.push<Map<String, String>>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => BannerDetailPage(
                    banner: _banner(id: 'b1'),
                    bannerService: _failingService(),
                    listTypes: {'b1': 'done'},
                  ),
                ),
              );
            },
            child: const Text('Open'),
          )),
        ));
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Simulate system back: since canPop=false the onPopInvokedWithResult
        // handler calls Navigator.pop with _listTypes instead.
        final NavigatorState nav =
            tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(returned, containsPair('b1', 'done'));
      });
    });
  });
}
