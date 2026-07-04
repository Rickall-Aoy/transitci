import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeMapView extends StatelessWidget {
  const HomeMapView({
    super.key,
    required this.initialCameraPosition,
    required this.mapStyle,
    required this.polylines,
    required this.markers,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  final CameraPosition initialCameraPosition;
  final String mapStyle;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      key: const ValueKey('home_google_map'),
      initialCameraPosition: initialCameraPosition,
      style: mapStyle,
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      polylines: polylines,
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
    );
  }
}
