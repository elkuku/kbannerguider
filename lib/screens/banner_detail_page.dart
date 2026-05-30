import 'package:flutter/material.dart';

import '../models/banner_item.dart';
import '../services/banner_service.dart';

class BannerDetailPage extends StatefulWidget {
  const BannerDetailPage({
    super.key,
    required this.banner,
    required this.bannerService,
  });

  final BannerItem banner;
  final BannerService bannerService;

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  late BannerItem _banner;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _banner = widget.banner;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final full = await widget.bannerService.fetchById(_banner.id);
      if (mounted) setState(() => _banner = full);
    } catch (_) {
      // keep the list data already shown
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_banner.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_loadingDetail)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'banner-${_banner.id}',
              child: Image.network(
                _banner.pictureUrl,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 240,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.map, size: 64, color: Colors.grey),
                ),
              ),
            ),
            if (_banner.warning != null)
              Container(
                color: Colors.amber.shade100,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_banner.warning!)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _banner.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_banner.description != null &&
                      _banner.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _banner.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (_banner.type != null)
                    _InfoRow(
                      icon: Icons.format_list_numbered,
                      label: 'Type',
                      value: _banner.type == 'sequential'
                          ? 'Sequential'
                          : 'Any order',
                    ),
                  if (_banner.numberOfMissions != null)
                    _InfoRow(
                      icon: Icons.flag,
                      label: 'Missions',
                      value: _missionsLabel(_banner),
                    ),
                  if (_banner.lengthMeters != null)
                    _InfoRow(
                      icon: Icons.straighten,
                      label: 'Route length',
                      value: _formatDistance(_banner.lengthMeters!),
                    ),
                  if (_banner.formattedAddress != null)
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Start location',
                      value: _banner.formattedAddress!,
                    )
                  else if (_banner.startLatitude != null &&
                      _banner.startLongitude != null)
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Start point',
                      value: '${_banner.startLatitude!.toStringAsFixed(5)}, '
                          '${_banner.startLongitude!.toStringAsFixed(5)}',
                    ),
                  if (_banner.eventStartDate != null)
                    _InfoRow(
                      icon: Icons.event,
                      label: 'Event',
                      value: _banner.eventEndDate != null
                          ? '${_banner.eventStartDate} – ${_banner.eventEndDate}'
                          : _banner.eventStartDate!,
                    ),
                  if (_banner.plannedOfflineDate != null)
                    _InfoRow(
                      icon: Icons.event_busy,
                      label: 'Planned offline',
                      value: _banner.plannedOfflineDate!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _missionsLabel(BannerItem b) {
    final total = b.numberOfMissions!;
    final disabled = b.numberOfDisabledMissions ?? 0;
    final active = total - disabled;
    if (disabled > 0) return '$active active ($disabled disabled)';
    return '$total';
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '$meters m';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
