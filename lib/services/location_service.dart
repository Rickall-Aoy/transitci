import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Retourne la position GPS actuelle de l'utilisateur
  static Future<Position> getCurrentPosition() async {
    // 1. Vérifier si le service de localisation est activé
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('La localisation est désactivée sur cet appareil.');
    }

    // 2. Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission de localisation refusée.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permission refusée définitivement. Active la localisation dans les paramètres.',
      );
    }

    // 3. Retourner la position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Calcule la distance en mètres entre deux points GPS
  static double distanceEnMetres({
    required double lat1, required double lon1,
    required double lat2, required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}