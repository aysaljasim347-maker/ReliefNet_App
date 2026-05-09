import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disasteraid_pk/core/api/api_client.dart';

class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({super.key});
  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  List<Map<String, dynamic>> campaigns = [];
  bool loading = true;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  double _radius = 50; // km

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enable location in settings')),
          );
        }
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() => _currentLocation = LatLng(position.latitude, position.longitude));
      _mapController.move(_currentLocation!, 12);
      _loadNearbyCampaigns();
      
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final api = ApiClient();
      final res = await api.dio.get('/campaigns/map');
      setState(() {
        campaigns = List<Map<String, dynamic>>.from(res.data['data']);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      print('Map load error: $e');
    }
  }

  Future<void> _loadNearbyCampaigns() async {
    if (_currentLocation == null) return;
    
    setState(() => loading = true);
    try {
      final api = ApiClient();
      final res = await api.dio.get('/campaigns/nearby', queryParameters: {
        'lat': _currentLocation!.latitude,
        'lng': _currentLocation!.longitude,
        'radius': _radius,
      });
      setState(() {
        campaigns = List<Map<String, dynamic>>.from(res.data['data']);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      print('Nearby load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns Near You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Find Near Me',
          ),
        ],
      ),
      body: loading
        ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(30.3753, 69.3451),
                    initialZoom: _currentLocation != null ? 12 : 6,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.disasteraid.pk',
                    ),
                    // Current location marker
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Campaign markers
                    MarkerLayer(
                      markers: campaigns.map((c) {
                        final lat = c['latitude'] as num?;
                        final lng = c['longitude'] as num?;
                        if (lat == null || lng == null) return null;
                        
                        return Marker(
                          point: LatLng(lat.toDouble(), lng.toDouble()),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showCampaignSheet(c),
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        );
                      }).whereType<Marker>().toList(),
                    ),
                  ],
                ),
                // Radius filter
                if (_currentLocation != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Text('Radius: '),
                            Expanded(
                              child: Slider(
                                value: _radius,
                                min: 1,
                                max: 100,
                                divisions: 20,
                                label: '${_radius.toInt()} km',
                                onChanged: (v) => setState(() => _radius = v),
                                onChangeEnd: (v) => _loadNearbyCampaigns(),
                              ),
                            ),
                            Text('${_radius.toInt()}km'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showCampaignSheet(Map<String, dynamic> c) {
    final distance = c['distance_km'] as num?;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('By ${c['org_name']}'),
            Text('Raised: PKR ${c['raised_amount']} / ${c['target_amount']}'),
            if (distance != null) 
              Text('${distance.toStringAsFixed(1)} km away', 
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to campaign detail
              },
              child: const Text('View Campaign'),
            ),
          ],
        ),
      ),
    );
  }
}