import 'location_service.dart';

class YangoEstimate {
  final int prixMin;
  final int prixMax;
  final int dureeMinutes;

  const YangoEstimate({
    required this.prixMin,
    required this.prixMax,
    required this.dureeMinutes,
  });
}

class YangoEstimateService {
  static const double _prixParKm = 150;
  static const double _prixBase = 500;

  static YangoEstimate estimer({
    required double userLat,
    required double userLon,
    required double destLat,
    required double destLon,
    required int heure,
  }) {
    final distanceKm = LocationService.distanceEnMetres(
          lat1: userLat,
          lon1: userLon,
          lat2: destLat,
          lon2: destLon,
        ) /
        1000;

    final pointe = (heure >= 7 && heure <= 9) || (heure >= 17 && heure <= 20);
    final multiplicateur = pointe ? 1.3 : 1.0;

    final prixEstime = (_prixBase + distanceKm * _prixParKm) * multiplicateur;

    return YangoEstimate(
      prixMin: (prixEstime * 0.85).round(),
      prixMax: (prixEstime * 1.15).round(),
      dureeMinutes: (distanceKm / 25 * 60).round().clamp(5, 90),
    );
  }
}
