import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationBar extends StatelessWidget {
  const LocationBar({
    super.key,
    required this.position,
    required this.customCenter,
    required this.onPickLocation,
    required this.onClearCustom,
  });

  final Position? position;
  final LatLng? customCenter;
  final VoidCallback onPickLocation;
  final VoidCallback onClearCustom;

  @override
  Widget build(BuildContext context) {
    final isCustom = customCenter != null;
    final lat = isCustom ? customCenter!.latitude : position?.latitude;
    final lng = isCustom ? customCenter!.longitude : position?.longitude;
    final coordText = lat != null && lng != null
        ? '${lat.toStringAsFixed(5)},  ${lng.toStringAsFixed(5)}'
        : 'Locating…';

    return InkWell(
      onTap: onPickLocation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(
              isCustom ? Icons.location_pin : Icons.my_location,
              size: 16,
              color: isCustom
                  ? Colors.orange
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isCustom ? coordText : '$coordText  (GPS)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            if (isCustom)
              GestureDetector(
                onTap: onClearCustom,
                child: Tooltip(
                  message: 'Switch back to GPS',
                  child: Icon(Icons.gps_fixed,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
              )
            else
              Icon(Icons.edit_location_alt_outlined,
                  size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
