import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/supabase_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LatLng _abidjan = const LatLng(5.3600, -4.0083);
  Timer? _timer;
  Set<Marker> _markers = <Marker>{};

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadMarkers());
  }

  Future<void> _loadMarkers() async {
    final vehicles = await SupabaseService.getVehiculesLive();
    if (!mounted) return;

    setState(() {
      _markers = vehicles.map((vehicle) {
        final latitude = double.tryParse(vehicle['latitude']?.toString() ?? '') ?? 5.3570;
        final longitude = double.tryParse(vehicle['longitude']?.toString() ?? '') ?? -4.0120;
        final title = vehicle['ligne_id']?.toString() ?? 'Véhicule';
        final markerId = vehicle['id']?.toString() ?? vehicle['chauffeur_id']?.toString() ?? '$latitude:$longitude';

        return Marker(
          markerId: MarkerId(markerId),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: title,
            snippet: 'Dernière mise à jour: ${vehicle['updated_at'] ?? 'inconnue'}',
          ),
        );
      }).toSet();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des bus'),
        backgroundColor: const Color(0xFFFF6B00),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _abidjan,
          zoom: 13,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) {
          if (!_controller.isCompleted) {
            _controller.complete(controller);
          }
        },
      ),
    );
  }
}