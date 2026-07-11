import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlacesService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  // Biais géographique sur Abidjan (viewbox), sans forcer une restriction stricte
  static const String _viewbox = '-4.35,5.55,-3.65,5.05'; // gauche,haut,droite,bas
  static const String _userAgent = 'TransitCI/1.0 (contact: nzuemichel01@gmail.com)';

  static Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String sessionToken, // conservé pour compatibilité d'appel, inutilisé ici
  }) async {
    if (input.trim().isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/search'
      '?q=${Uri.encodeComponent(input)}'
      '&format=jsonv2'
      '&addressdetails=1'
      '&limit=6'
      '&countrycodes=ci'
      '&viewbox=$_viewbox'
      '&bounded=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent}, // requis par la politique Nominatim
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Nominatim search HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as List;
      if (data.isEmpty) return [];

      return data.map((p) => PlacePrediction.fromNominatim(p)).toList();
    } catch (e) {
      debugPrint('❌ Nominatim search exception: $e');
      return [];
    }
  }

  // Nominatim renvoie déjà les coordonnées dans le résultat de recherche,
  // donc pas besoin d'un second appel "détails" comme avec Google Places —
  // on garde la signature pour éviter de toucher au widget appelant.
  static Future<PlaceDetail?> getPlaceDetail({
    required String placeId,
    required String sessionToken,
  }) async {
    // placeId encode ici directement lat/lon (voir PlacePrediction.fromNominatim)
    final parts = placeId.split(',');
    if (parts.length != 3) return null;

    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;

    return PlaceDetail(
      name: parts[2],
      address: parts[2],
      latitude: lat,
      longitude: lon,
    );
  }
}

// ── Modèles (signature identique à l'ancien PlacesService) ──

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromNominatim(Map<String, dynamic> json) {
    final displayName = json['display_name']?.toString() ?? '';
    final lat = json['lat']?.toString() ?? '0';
    final lon = json['lon']?.toString() ?? '0';

    // Sépare le premier segment (nom du lieu) du reste (adresse complète)
    final parts = displayName.split(',');
    final mainText = parts.isNotEmpty ? parts.first.trim() : displayName;
    final secondaryText =
        parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

    // On encode lat/lon/nom directement dans le "placeId" pour éviter
    // un second appel réseau lors de la sélection (Nominatim search
    // fournit déjà les coordonnées, contrairement à Google Places).
    return PlacePrediction(
      placeId: '$lat,$lon,$mainText',
      description: displayName,
      mainText: mainText,
      secondaryText: secondaryText,
    );
  }
}

class PlaceDetail {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const PlaceDetail({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
