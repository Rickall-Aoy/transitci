import 'package:flutter/foundation.dart';

class Vehicule {
  final String id;
  final String chauffeurId;
  final String? ligneId;
  final double latitude;
  final double longitude;
  final double? vitesse;
  final DateTime? updatedAt;

  const Vehicule({
    required this.id,
    required this.chauffeurId,
    this.ligneId,
    required this.latitude,
    required this.longitude,
    this.vitesse,
    this.updatedAt,
  });

  factory Vehicule.fromJson(Map<String, dynamic> json) {
    return Vehicule(
      id: json['id']?.toString() ?? '',
      chauffeurId: json['chauffeur_id']?.toString() ?? '',
      ligneId: json['ligne_id']?.toString(),
      latitude: (json['latitude'] is String)
          ? double.tryParse(json['latitude']) ?? 0.0
          : (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] is String)
          ? double.tryParse(json['longitude']) ?? 0.0
          : (json['longitude'] as num?)?.toDouble() ?? 0.0,
      vitesse: (json['vitesse'] is String)
          ? double.tryParse(json['vitesse'])
          : (json['vitesse'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chauffeur_id': chauffeurId,
        'ligne_id': ligneId,
        'latitude': latitude,
        'longitude': longitude,
        'vitesse': vitesse,
        'updated_at': updatedAt?.toIso8601String(),
      };

  double distanceTo(double lat, double lon) {
    // Haversine approx
    const r = 6371000.0;
    final dLat = (lat - latitude) * (3.141592653589793 / 180);
    final dLon = (lon - longitude) * (3.141592653589793 / 180);
    final a = dLat * dLat + dLon * dLon;
    return r * a;
  }
}
