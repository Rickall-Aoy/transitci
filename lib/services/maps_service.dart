import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsService {
  static const String apiKey = 'AIzaSyDeDZOsuXaRTDaevhAEP_e4LA3K5X_OdJI';

  LatLng getInitialCameraPosition() {
    return const LatLng(6.5244, 3.3792);
  }
}
