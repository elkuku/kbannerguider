import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const KBannerGuiderApp());
}

class KBannerGuiderApp extends StatelessWidget {
  const KBannerGuiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBannerGuider',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const BannerListPage(),
    );
  }
}

class BannerListPage extends StatefulWidget {
  const BannerListPage({super.key});

  @override
  State<BannerListPage> createState() => _BannerListPageState();
}

class _BannerListPageState extends State<BannerListPage> {
  List<Map<String, dynamic>> _banners = [];
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
      final position = await _determinePosition();
      setState(() => _position = position);

      final uri = Uri.parse(
        'https://api.bannergress.com/bnrs'
        '?orderBy=proximityStartPoint'
        '&orderDirection=ASC'
        '&online=true'
        '&proximityLatitude=${position.latitude}'
        '&proximityLongitude=${position.longitude}',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

      setState(() {
        _banners = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it in settings.',
      );
    }

    return Geolocator.getCurrentPosition();
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
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final title = banner['title'] as String? ?? 'Untitled';
              final missions = banner['numberOfMissions'] as int?;
              final id = banner['id'] as String? ?? '';

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    'https://api.bannergress.com/bnrs/$id/picture',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.map, size: 48),
                  ),
                ),
                title: Text(title),
                subtitle: missions != null
                    ? Text('$missions mission${missions == 1 ? '' : 's'}')
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
