import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kbannerguider/screens/banner_list_page.dart';
import 'package:kbannerguider/services/banner_service.dart';
import 'package:kbannerguider/services/location_service.dart';

class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<Position> getCurrentPosition() async => Position(
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
}

const _oneBanner =
    '[{"id":"parque-santa-ana-6476","title":"PARQUE SANTA ANA","numberOfMissions":18,"lengthMeters":9501}]';

void main() {
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

      expect(find.text('KBannerGuider'), findsOneWidget);
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

    testWidgets('shows banner title and mission count when data is returned',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BannerListPage(
            locationService: const _FakeLocationService(),
            bannerService: BannerService(
              client: MockClient((_) async => http.Response(_oneBanner, 200)),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PARQUE SANTA ANA'), findsOneWidget);
      expect(find.text('18 missions'), findsOneWidget);
    });

    testWidgets('shows error state and Retry button on HTTP failure',
        (tester) async {
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

    testWidgets('Nearby and To-do tabs are present', (tester) async {
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

      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('To-do'), findsOneWidget);
    });
  });
}
