import 'gare.dart';
import '../services/location_service.dart';

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

/// Résultat d'une recherche d'arrêt le plus proche, avec sa position
/// dans la séquence ordonnée de la ligne (utile pour valider le sens).
class ArretAvecIndex {
  final Arret arret;
  final int index;

  const ArretAvecIndex({required this.arret, required this.index});
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

  /// Séquence ORDONNÉE et dans le sens réel de circulation de la ligne.
  /// Ne jamais mélanger deux directions dans une même instance de Ligne —
  /// créer deux Ligne distinctes (aller / retour) à la source si besoin.
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

  /// Conservé pour compatibilité — préférer [arretLePlusProcheAvecIndex]
  /// partout où l'ordre de passage doit être vérifié (routing).
  Arret arretLePlusProche(double lat, double lon) {
    return arretLePlusProcheAvecIndex(lat, lon).arret;
  }

  /// Retourne l'arrêt le plus proche ET sa position dans la séquence,
  /// pour permettre de vérifier que deux arrêts sont dans le bon ordre
  /// (départ AVANT arrivée) dans le sens réel de circulation.
  ArretAvecIndex arretLePlusProcheAvecIndex(double lat, double lon) {
    final tous = tousLesArrets;
    var meilleurIndex = 0;
    var meilleureDistance =
        _distance(lat, lon, tous[0].latitude, tous[0].longitude);

    for (int i = 1; i < tous.length; i++) {
      final d = _distance(lat, lon, tous[i].latitude, tous[i].longitude);
      if (d < meilleureDistance) {
        meilleureDistance = d;
        meilleurIndex = i;
      }
    }
    return ArretAvecIndex(arret: tous[meilleurIndex], index: meilleurIndex);
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    return LocationService.distanceEnMetres(
      lat1: lat1,
      lon1: lon1,
      lat2: lat2,
      lon2: lon2,
    );
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