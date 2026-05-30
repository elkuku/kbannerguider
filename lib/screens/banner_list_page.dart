import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/banner_item.dart';
import '../services/banner_service.dart';
import '../services/location_service.dart';
import 'banner_detail_page.dart';

class BannerListPage extends StatefulWidget {
  BannerListPage({
    super.key,
    LocationService? locationService,
    BannerService? bannerService,
  })  : _locationService = locationService ?? const LocationService(),
        _bannerService = bannerService ?? BannerService();

  final LocationService _locationService;
  final BannerService _bannerService;

  @override
  State<BannerListPage> createState() => _BannerListPageState();
}

class _BannerListPageState extends State<BannerListPage> {
  List<BannerItem> _banners = [];
  bool _loading = false;
  String? _error;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final position = await widget._locationService.getCurrentPosition();
      setState(() => _position = position);

      final banners = await widget._bannerService.fetchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _banners = banners;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Banners'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchBanners,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchBanners,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const Center(child: Text('No banners found nearby.'));
    }

    return Column(
      children: [
        if (_position != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'Location: ${_position!.latitude.toStringAsFixed(5)}, '
              '${_position!.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: _banners.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BannerDetailPage(
                      banner: banner,
                      bannerService: widget._bannerService,
                    ),
                  ),
                ),
                leading: Hero(
                  tag: 'banner-${banner.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      banner.pictureUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.map, size: 48),
                    ),
                  ),
                ),
                title: Text(banner.title),
                subtitle: banner.numberOfMissions != null
                    ? Text(
                        '${banner.numberOfMissions} mission'
                        '${banner.numberOfMissions == 1 ? '' : 's'}',
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
              );
            },
          ),
        ),
      ],
    );
  }
}
