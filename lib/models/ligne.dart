import 'gare.dart';

class Arret {
  final String nom;
  final double latitude;
  final double longitude;

  const Arret({
    required this.nom,
    required this.latitude,
    required this.longitude,
  });

  factory Arret.fromJson(Map<String, dynamic> json) {
    return Arret(
      nom: json['nom']?.toString() ?? '',
      latitude: (json['latitude'] is String)
          ? double.tryParse(json['latitude']) ?? 0.0
          : (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] is String)
          ? double.tryParse(json['longitude']) ?? 0.0
          : (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class Ligne {
  final String id;
  final String nom;
  final TransportType type;
  final Arret terminusDepart;
  final Arret terminusArrivee;
  final List<Arret> arretsPossibles;
  final int prix;
  final String couleurVehicule;
  final String conseil;

  const Ligne({
    required this.id,
    required this.nom,
    required this.type,
    required this.terminusDepart,
    required this.terminusArrivee,
    this.arretsPossibles = const [],
    required this.prix,
    required this.couleurVehicule,
    this.conseil = 'Demandez au chauffeur si il dessert votre arrêt.',
  });

  factory Ligne.fromJson(Map<String, dynamic> json) {
    final typeString = json['type']?.toString() ?? '';
    return Ligne(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      type: _typeFromString(typeString),
      terminusDepart: Arret.fromJson(json['depart'] as Map<String, dynamic>? ?? {}),
      terminusArrivee: Arret.fromJson(json['arrivee'] as Map<String, dynamic>? ?? {}),
      arretsPossibles: (json['arrets_possibles'] as List<dynamic>?)
              ?.map((entry) => Arret.fromJson(entry as Map<String, dynamic>))
              .toList() ??
          [],
      prix: json['prix'] is int
          ? json['prix'] as int
          : int.tryParse(json['prix']?.toString() ?? '') ?? 0,
      couleurVehicule: json['couleur_vehicule']?.toString() ?? '0xFFFF6B00',
      conseil: json['conseil']?.toString() ?? 'Demandez au chauffeur si il dessert votre arrêt.',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'type': _typeToString(type),
        'depart': terminusDepart.toJson(),
        'arrivee': terminusArrivee.toJson(),
        'arrets_possibles': arretsPossibles.map((a) => a.toJson()).toList(),
        'prix': prix,
        'couleur_vehicule': couleurVehicule,
        'conseil': conseil,
      };

  List<Arret> get tousLesArrets => [
        terminusDepart,
        ...arretsPossibles,
        terminusArrivee,
      ];

  bool peutDesservir(double lat, double lon, {double rayonMetres = 1000}) {
    return tousLesArrets.any((a) {
      final dist = _distance(lat, lon, a.latitude, a.longitude);
      return dist <= rayonMetres;
    });
  }

  Arret arretLePlusProche(double lat, double lon) {
    return tousLesArrets.reduce((a, b) {
      final dA = _distance(lat, lon, a.latitude, a.longitude);
      final dB = _distance(lat, lon, b.latitude, b.longitude);
      return dA < dB ? a : b;
    });
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a = dLat * dLat + dLon * dLon;
    return r * a;
  }

  static TransportType _typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'gbaka':
        return TransportType.gbaka;
      case 'sotra':
        return TransportType.sotra;
      case 'yango':
        return TransportType.yango;
      case 'woro_woro':
      case 'woro-woro':
      case 'woro':
        return TransportType.woroWoro;
      default:
        return TransportType.gbaka;
    }
  }

  static String _typeToString(TransportType type) {
    switch (type) {
      case TransportType.woroWoro:
        return 'woro_woro';
      case TransportType.gbaka:
        return 'gbaka';
      case TransportType.sotra:
        return 'sotra';
      case TransportType.yango:
        return 'yango';
    }
  }
}
