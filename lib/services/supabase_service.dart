import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ligne.dart';
import '../models/gare.dart';
import 'arret_service.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // ── Lignes depuis Supabase (toutes) ──
  static Future<List<Ligne>> getLignes() async {
    try {
      final response = await _client
          .from('lignes')
          .select()
          .not('terminus_depart_lat', 'is', null)
          .not('terminus_arrivee_lat', 'is', null);

      final rows = response as List;

      // Diagnostic : combien de lignes par type arrivent depuis Supabase,
      // AVANT tout filtrage supplémentaire
      final countsParType = <String, int>{};
      for (final l in rows) {
        final t = l['type']?.toString() ?? 'null';
        countsParType[t] = (countsParType[t] ?? 0) + 1;
      }
      debugPrint('📊 Lignes Supabase reçues (avec coords non-null): $countsParType');

      final lignes = <Ligne>[];
      for (final l in rows) {
        try {
          final ligne = Ligne(
            id: l['id']?.toString() ?? '',
            nom: l['nom']?.toString() ?? '',
            type: _typeFromString(l['type']?.toString() ?? ''),
            couleurVehicule: l['reseau']?.toString() ?? 'standard',
            prix: _toInt(l['prix'], fallback: 200),
            conseil: _conseilParType(l['type']?.toString() ?? ''),
            terminusDepart: Arret(
              nom: l['depart']?.toString() ?? '',
              latitude: _toDouble(l['terminus_depart_lat']),
              longitude: _toDouble(l['terminus_depart_lng']),
            ),
            terminusArrivee: Arret(
              nom: l['arrivee']?.toString() ?? '',
              latitude: _toDouble(l['terminus_arrivee_lat']),
              longitude: _toDouble(l['terminus_arrivee_lng']),
            ),
            arretsPossibles: const [],
          );

          if (ligne.terminusDepart.latitude == 0 ||
              ligne.terminusArrivee.latitude == 0) {
            debugPrint('⚠️ Ligne ignorée (coords à 0) id=${l['id']} nom=${l['nom']}');
            continue;
          }

          lignes.add(ligne);
        } catch (e) {
          // Une ligne malformée ne doit pas faire échouer tout le batch
          debugPrint('⚠️ Ligne Supabase ignorée (id=${l['id']}): $e');
        }
      }

      debugPrint('✅ ${lignes.length}/${rows.length} lignes Supabase exploitables');
      // Injecte les arrêts Supabase (ligne_arrets) comme arrêts intermédiaires
      // → points de correspondance supplémentaires pour le routing existant.
      // No-op si ArretService n'est pas encore chargé.
      return ArretService.instance.enrichirLignes(lignes);
    } catch (e) {
      debugPrint('❌ Erreur getLignes (requête/connexion): $e');
      return [];
    }
  }

  // ── Lignes SOTRA brutes pour alimenter les marqueurs d'arrêts Supabase ──
  static Future<List<Map<String, dynamic>>> getLignesSotra() async {
    try {
      final response = await _client
          .from('lignes')
          .select(
            'id, nom, depart, arrivee, type, prix, terminus_depart_lat, terminus_depart_lng',
          )
          .eq('type', 'sotra')
          .not('terminus_depart_lat', 'is', null)
          .not('terminus_depart_lng', 'is', null);

      final rows = List<Map<String, dynamic>>.from(response);
      debugPrint('📊 Lignes SOTRA Supabase avec coords: ${rows.length}');

      return rows.map((ligne) {
        final depart = ligne['depart']?.toString() ?? '';
        return {
          ...ligne,
          'lat_depart': _toDouble(ligne['terminus_depart_lat']),
          'lon_depart': _toDouble(ligne['terminus_depart_lng']),
          'terminus_depart': depart,
          'prix': _toInt(ligne['prix'], fallback: 200),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur getLignesSotra: $e');
      return [];
    }
  }

  // ── Véhicules live ──
  static Future<List<Map<String, dynamic>>> getVehiculesLive() async {
    try {
      final response = await _client
          .from('vehicules_live')
          .select('*, chauffeurs(nom, type_vehicule), lignes(nom, type)')
          .gte(
              'updated_at',
              DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toIso8601String());
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur getVehiculesLive: $e');
      return [];
    }
  }

  // ── Signaler un arrêt ──
  static Future<bool> signalerArret({
    required String nom,
    required double latitude,
    required double longitude,
    required String typeTransport,
    String? ligneId,
  }) async {
    try {
      await _client.from('arrets_signales').insert({
        'nom': nom,
        'latitude': latitude,
        'longitude': longitude,
        'type_transport': typeTransport,
        'ligne_id': ligneId,
        'statut': 'en_attente',
      });
      return true;
    } catch (e) {
      debugPrint('❌ Erreur signalerArret: $e');
      return false;
    }
  }

  // ── Helpers ──
  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static TransportType _typeFromString(String type) {
    switch (type) {
      case 'woro_woro':
        return TransportType.woroWoro;
      case 'gbaka':
        return TransportType.gbaka;
      case 'warren':
        return TransportType.woroWoro; // warren = woro-woro
      case 'sotra':
        return TransportType.sotra;
      default:
        debugPrint('⚠️ Type de ligne inconnu en base: "$type" — fallback sotra');
        return TransportType.sotra;
    }
  }

  static String _conseilParType(String type) {
    switch (type) {
      case 'woro_woro':
      case 'warren':
        return 'Dites votre arrêt au chauffeur avant de monter.';
      case 'gbaka':
        return 'Criez votre arrêt quand vous approchez.';
      default:
        return 'Bus SOTRA — arrêts fixes aux panneaux.';
    }
  }
}