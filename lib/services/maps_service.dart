// maps_service.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsService {
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  LatLng getInitialCameraPosition() {
    return const LatLng(5.3600, -4.0083); // Abidjan
  }
}
