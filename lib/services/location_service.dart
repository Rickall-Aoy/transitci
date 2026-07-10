import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Demande la permission au runtime si nécessaire (checkPermission seul ne
  /// déclenche jamais la popup — requestPermission le fait), puis retourne la
  /// position. Lève une exception explicite si service désactivé / refusé /
  /// timeout, avec le mot-clé 'deniedForever' si la permission est définitive.
  static Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('La localisation est désactivée sur cet appareil.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('deniedForever');
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Permission de localisation refusée.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Pas de fix GPS frais (fréquent sur émulateur) : on utilise la dernière
      // position connue si elle existe, sinon on propage l'erreur.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  /// Ouvre les paramètres de l'app (indispensable si deniedForever : la popup
  /// de permission ne réapparaîtra jamais sinon).
  static Future<void> openAppSettings() => Geolocator.openAppSettings();

  static double distanceEnMetres({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
