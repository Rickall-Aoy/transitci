import 'dart:convert';
import 'package:http/http.dart' as http;
import 'maps_service.dart';

class PlacesService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api';

  // ── Autocomplete Google Places ──
  static Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String sessionToken,
  }) async {
    if (input.trim().isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&key=${MapsService.apiKey}'
      '&sessiontoken=$sessionToken'
      '&language=fr'
      '&components=country:ci'
      // Biais géographique sur Abidjan
      '&location=5.3600,-4.0083'
      '&radius=30000',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return [];

      return (data['predictions'] as List)
          .map((p) => PlacePrediction.fromJson(p))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Détails d'un lieu (coordonnées GPS) ──
  static Future<PlaceDetail?> getPlaceDetail({
    required String placeId,
    required String sessionToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/place/details/json'
      '?place_id=$placeId'
      '&key=${MapsService.apiKey}'
      '&sessiontoken=$sessionToken'
      '&language=fr'
      '&fields=geometry,name,formatted_address',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;

      return PlaceDetail.fromJson(data['result']);
    } catch (e) {
      return null;
    }
  }
}

// ── Modèles ──

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

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structured['main_text'] ?? json['description'] ?? '',
      secondaryText: structured['secondary_text'] ?? '',
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

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final loc = json['geometry']['location'];
    return PlaceDetail(
      name: json['name'] ?? '',
      address: json['formatted_address'] ?? '',
      latitude: loc['lat'].toDouble(),
      longitude: loc['lng'].toDouble(),
    );
  }
}