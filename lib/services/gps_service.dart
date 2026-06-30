import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Service GPS centralisé : gestion des permissions et d'un flux de positions.
class GpsService {
  static StreamSubscription<Position>? _positionSub;

  /// Demande la permission de localisation et active le service si nécessaire.
  static Future<LocationPermission> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // L'utilisateur doit activer le service GPS
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Retourne la position courante ou lève une exception si indisponible.
  static Future<Position> getCurrentPosition({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    return await Geolocator.getCurrentPosition(desiredAccuracy: accuracy);
  }

  /// Démarre un flux de positions et retourne un [StreamSubscription].
  /// Appelle [onData] à chaque nouvelle position.
  static Future<StreamSubscription<Position>> startPositionStream(
    void Function(Position) onData, {
    LocationSettings? locationSettings,
  }) async {
    // Par défaut, paramètres adaptés aux mobiles
    final settings = locationSettings ?? const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    // Si un stream existait, on le remplace
    await stopPositionStream();

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(onData, onError: (e) {
      // ignore: avoid_print
      print('GpsService stream error: $e');
    });

    return _positionSub!;
  }

  /// Arrête le flux de positions s'il existe.
  static Future<void> stopPositionStream() async {
    try {
      await _positionSub?.cancel();
    } catch (_) {}
    _positionSub = null;
  }

  /// Vérifie rapidement si la permission est accordée.
  static Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }
}
