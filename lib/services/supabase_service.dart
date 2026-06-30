import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper utilitaire pour quelques appels Supabase récurrents.
class SupabaseService {
  static final _client = Supabase.instance.client;
  static final List<Map<String, dynamic>> _demoLignes = [
    {
      'id': 'ligne-demo-1',
      'nom': 'Ligne 1 – Centre / Plateau',
      'type': 'urbain',
      'depart': 'Centre',
      'arrivee': 'Plateau',
    },
    {
      'id': 'ligne-demo-2',
      'nom': 'Ligne 2 – Cocody / Yopougon',
      'type': 'urbain',
      'depart': 'Cocody',
      'arrivee': 'Yopougon',
    },
  ];

  static final List<Map<String, dynamic>> _demoVehicles = [
    {
      'id': 'vehicle-demo-1',
      'chauffeur_id': 'demo-chauffeur',
      'ligne_id': 'ligne-demo-1',
      'latitude': 5.3570,
      'longitude': -4.0120,
      'vitesse': 28,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    },
  ];

  /// Récupère la liste des lignes.
  /// Retourne une liste de maps contenant `id`, `nom`, `type`, `depart`, `arrivee`.
  static Future<List<Map<String, dynamic>>> getLignes() async {
    try {
      final res = await _client.from('lignes').select('id,nom,type,depart,arrivee');
      final List data = res as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseService.getLignes error: $e');
      return List<Map<String, dynamic>>.from(_demoLignes);
    }
  }

  /// Upsert (insert ou update) une ligne de `vehicules_live`.
  /// Le `data` doit contenir au minimum `chauffeur_id`, `latitude`, `longitude`.
  static Future<bool> upsertVehiculeLive(Map<String, dynamic> data) async {
    try {
      await _client.from('vehicules_live').upsert(data);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseService.upsertVehiculeLive error: $e');
      final updated = Map<String, dynamic>.from(data);
      final existingIndex = _demoVehicles.indexWhere(
        (vehicle) => vehicle['chauffeur_id'] == updated['chauffeur_id'],
      );
      if (existingIndex >= 0) {
        _demoVehicles[existingIndex] = updated;
      } else {
        _demoVehicles.add(updated);
      }
      return true;
    }
  }

  /// Supprime l'enregistrement `vehicules_live` pour un `chauffeur_id` donné.
  static Future<bool> deleteVehiculeByChauffeur(String chauffeurId) async {
    try {
      await _client.from('vehicules_live').delete().eq('chauffeur_id', chauffeurId);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseService.deleteVehiculeByChauffeur error: $e');
      _demoVehicles.removeWhere((vehicle) => vehicle['chauffeur_id'] == chauffeurId);
      return true;
    }
  }

  /// Récupère toutes les positions de `vehicules_live`.
  static Future<List<Map<String, dynamic>>> getVehiculesLive() async {
    try {
      final res = await _client.from('vehicules_live').select('id,chauffeur_id,ligne_id,latitude,longitude,vitesse,updated_at');
      final List data = res as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseService.getVehiculesLive error: $e');
      return List<Map<String, dynamic>>.from(_demoVehicles);
    }
  }
}
