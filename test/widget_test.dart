import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/models/banner_item.dart';
import 'package:kbannerguider/screens/banner_list_page.dart';
import 'package:kbannerguider/services/banner_service.dart';
import 'package:kbannerguider/services/location_service.dart';

class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<Position> getCurrentPosition() async => Position(
        latitude: 1.0,
        longitude: 2.0,
        timestamp: DateTime(2024),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

void main() {
  group('BannerItem', () {
    test('fromJson parses all fields', () {
      final item = BannerItem.fromJson({
        'id': 'abc',
        'title': 'Test Banner',
        'numberOfMissions': 5,
      });

      expect(item.id, 'abc');
      expect(item.title, 'Test Banner');
      expect(item.numberOfMissions, 5);
      expect(item.pictureUrl, 'https://api.bannergress.com/bnrs/abc/picture');
    });

    test('fromJson uses defaults for missing fields', () {
      final item = BannerItem.fromJson({});

      expect(item.id, '');
      expect(item.title, 'Untitled');
      expect(item.numberOfMissions, isNull);
    });
  });

  group('BannerListPage', () {
    testWidgets('shows app bar title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BannerListPage(
            locationService: const _FakeLocationService(),
            bannerService: BannerService(
              client: MockClient((_) async => http.Response('[]', 200)),
            ),
          ),
        ),
      );

      expect(find.text('Nearby Banners'), findsOneWidget);
    });

    testWidgets('shows loading indicator on start', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BannerListPage(
            locationService: const _FakeLocationService(),
            bannerService: BannerService(
              client: MockClient((_) async => http.Response('[]', 200)),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no banners returned', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BannerListPage(
            locationService: const _FakeLocationService(),
            bannerService: BannerService(
              client: MockClient((_) async => http.Response('[]', 200)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No banners found nearby.'), findsOneWidget);
    });

    testWidgets('shows banner list when data is returned', (tester) async {
      const body =
          '[{"id":"x1","title":"My Banner","numberOfMissions":3}]';

      await tester.pumpWidget(
        MaterialApp(
          home: BannerListPage(
            locationService: const _FakeLocationService(),
            bannerService: BannerService(
              client: MockClient((_) async => http.Response(body, 200)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Banner'), findsOneWidget);
      expect(find.text('3 missions'), findsOneWidget);
    });

    testWidgets('shows error state on failure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BannerListPage(
            locationService: const _FakeLocationService(),
            bannerService: BannerService(
              client: MockClient((_) async => http.Response('', 500)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
