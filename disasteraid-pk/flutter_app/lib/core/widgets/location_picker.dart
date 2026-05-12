// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';

// class LocationPicker extends StatefulWidget {
//   final Function(LatLng latLng, String address) onLocationPicked;
//   const LocationPicker({super.key, required this.onLocationPicked});

//   @override
//   State<LocationPicker> createState() => _LocationPickerState();
// }

// class _LocationPickerState extends State<LocationPicker> {
//   LatLng? _selectedLocation;
//   String _address = '';
//   bool _loading = false;
//   final MapController _mapController = MapController();

//   Future<void> _getCurrentLocation() async {
//     setState(() => _loading = true);
//     try {
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) return;
//       }

//       final position = await Geolocator.getCurrentPosition();
//       final latLng = LatLng(position.latitude, position.longitude);

//       await _updateLocation(latLng);
//       _mapController.move(latLng, 15);
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _updateLocation(LatLng latLng) async {
//     setState(() => _selectedLocation = latLng);

//     // Reverse geocode to get address
//     try {
//       final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
//       if (placemarks.isNotEmpty) {
//         final p = placemarks.first;
//         _address = '${p.street}, ${p.locality}, ${p.administrativeArea}';
//       }
//     } catch (e) {
//       _address = 'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
//     }

//     widget.onLocationPicked(latLng, _address);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: Text(
//                 _address.isEmpty ? 'No location selected' : _address,
//                 style: TextStyle(color: _address.isEmpty ? Colors.grey : null),
//               ),
//             ),
//             FilledButton.icon(
//               onPressed: _loading ? null : _getCurrentLocation,
//               icon: _loading
//                   ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
//                   : const Icon(Icons.my_location),
//               label: const Text('Use Current'),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         SizedBox(
//           height: 200,
//           child: FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _selectedLocation ?? const LatLng(30.3753, 69.3451),
//               initialZoom: _selectedLocation != null ? 15 : 6,
//               onTap: (tapPos, latLng) => _updateLocation(latLng),
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                 userAgentPackageName: 'com.disasteraid.pk',
//               ),
//               if (_selectedLocation != null)
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       point: _selectedLocation!,
//                       width: 40,
//                       height: 40,
//                       child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
//                     ),
//                   ],
//                 ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text('Tap map to adjust pin', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPicker extends StatefulWidget {
  final Function(LatLng latLng, String address) onLocationPicked;
  const LocationPicker({super.key, required this.onLocationPicked});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  LatLng? _selectedLocation;
  String _address = '';
  bool _loading = false;
  final MapController _mapController = MapController();

  Future<void> _getCurrentLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      await _updateLocation(latLng);
      _mapController.move(latLng, 15);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateLocation(LatLng latLng) async {
    setState(() => _selectedLocation = latLng);

    try {
      final placemarks =
          await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _address = '${p.street}, ${p.locality}, ${p.administrativeArea}';
      }
    } catch (e) {
      _address =
          'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
    }

    widget.onLocationPicked(latLng, _address);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Address row ──────────────────────────────────────
        // FIX: Row children must be bounded. Expanded takes
        // remaining space; button is intrinsically sized via
        // a tight SizedBox so it never receives infinite width.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _address.isEmpty ? 'No location selected' : _address,
                style: TextStyle(
                  color: _address.isEmpty ? Colors.grey : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: _loading ? null : _getCurrentLocation,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('Use Current'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Map ───────────────────────────────────────────────
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _selectedLocation ?? const LatLng(30.3753, 69.3451),
                initialZoom: _selectedLocation != null ? 15 : 6,
                onTap: (tapPos, latLng) => _updateLocation(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.disasteraid.pk',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap map to adjust pin',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
