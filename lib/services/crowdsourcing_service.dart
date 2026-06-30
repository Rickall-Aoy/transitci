import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ligne.dart';
import '../models/gare.dart';

class ArretSignale {
  final String? id;
  final String nom;
  final double latitude;
  final double longitude;
  final TransportType typeTransport;
  final String? ligneId;
  final String statut;
  final int votesConfirmes;
  final int votesInfirmes;
  final DateTime? createdAt;

  const ArretSignale({
    this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.typeTransport,
    this.ligneId,
    this.statut = 'en_attente',
    this.votesConfirmes = 0,
    this.votesInfirmes = 0,
    this.createdAt,
  });

  factory ArretSignale.fromJson(Map<String, dynamic> json) {
    return ArretSignale(
      id: json['id'],
      nom: json['nom'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      typeTransport: _typeFromString(json['type_transport']),
      ligneId: json['ligne_id'],
      statut: json['statut'] ?? 'en_attente',
      votesConfirmes: json['votes_confirmes'] ?? 0,
      votesInfirmes: json['votes_infirmes'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'latitude': latitude,
    'longitude': longitude,
    'type_transport': _typeToString(typeTransport),
    'ligne_id': ligneId,
    'statut': statut,
  };

  static TransportType _typeFromString(String s) {
    switch (s) {
      case 'gbaka':   return TransportType.gbaka;
      case 'sotra':   return TransportType.sotra;
      case 'yango':   return TransportType.yango;
      default:        return TransportType.woroWoro;
    }
  }

  static String _typeToString(TransportType t) {
    switch (t) {
      case TransportType.woroWoro: return 'woroWoro';
      case TransportType.gbaka:    return 'gbaka';
      case TransportType.sotra:    return 'sotra';
      case TransportType.yango:    return 'yango';
    }
  }
}

class CrowdsourcingService {
  static final _supabase = Supabase.instance.client;

  // ── Signaler un nouvel arrêt ──
  static Future<bool> signalerArret({
    required String nom,
    required double latitude,
    required double longitude,
    required TransportType type,
    String? ligneId,
  }) async {
    try {
      await _supabase.from('arrets_signales').insert({
        'nom': nom,
        'latitude': latitude,
        'longitude': longitude,
        'type_transport': ArretSignale._typeToString(type),
        'ligne_id': ligneId,
        'statut': 'en_attente',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Récupérer tous les arrêts signalés autour d'un point ──
  static Future<List<ArretSignale>> getArretsProches({
    required double lat,
    required double lon,
    double rayonDegres = 0.05, // ~5km
  }) async {
    try {
      final response = await _supabase
          .from('arrets_signales')
          .select()
          .gte('latitude', lat - rayonDegres)
          .lte('latitude', lat + rayonDegres)
          .gte('longitude', lon - rayonDegres)
          .lte('longitude', lon + rayonDegres)
          .inFilter('statut', ['en_attente', 'valide']);

      return (response as List)
          .map((e) => ArretSignale.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Récupérer tous les arrêts validés ──
  static Future<List<ArretSignale>> getArretsValides() async {
    try {
      final response = await _supabase
          .from('arrets_signales')
          .select()
          .eq('statut', 'valide')
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => ArretSignale.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }
}