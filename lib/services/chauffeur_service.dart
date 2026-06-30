import 'package:supabase_flutter/supabase_flutter.dart';

class ChauffeurService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _chauffeurId => _client.auth.currentUser!.id;

  // ---------- Lignes ----------
  Future<List<Map<String, dynamic>>> recupererLignes() async {
    final data = await _client.from('lignes').select();
    return List<Map<String, dynamic>>.from(data);
  }

  // ---------- Session de service ----------
  String? _sessionId;

  Future<void> demarrerSession(String ligneId) async {
    final result = await _client
        .from('sessions_service')
        .insert({
          'chauffeur_id': _chauffeurId,
          'ligne_id': ligneId,
        })
        .select()
        .single();
    _sessionId = result['id'] as String;

    await _client.from('activites_chauffeur').insert({
      'chauffeur_id': _chauffeurId,
      'type': 'connexion',
      'titre': 'Service démarré',
    });
  }

  Future<void> arreterSession() async {
    if (_sessionId != null) {
      await _client
          .from('sessions_service')
          .update({'fin': DateTime.now().toIso8601String()})
          .eq('id', _sessionId!);
    }

    await _client.from('activites_chauffeur').insert({
      'chauffeur_id': _chauffeurId,
      'type': 'deconnexion',
      'titre': 'Service arrêté',
    });

    _sessionId = null;
  }

  // ---------- Position GPS ----------
  Future<void> envoyerPosition({
    required String ligneId,
    required double latitude,
    required double longitude,
    double? vitesse,
  }) async {
    await _client.from('vehicules_live').upsert(
      {
        'chauffeur_id': _chauffeurId,
        'ligne_id': ligneId,
        'latitude': latitude,
        'longitude': longitude,
        'vitesse': vitesse,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'chauffeur_id',
    );
  }

  Future<void> supprimerPosition() async {
    await _client
        .from('vehicules_live')
        .delete()
        .eq('chauffeur_id', _chauffeurId);
  }

  // ---------- Statistiques (lecture ponctuelle) ----------
  Future<Map<String, dynamic>> recupererStatsJour() async {
    final data = await _client
        .from('stats_jour')
        .select()
        .eq('chauffeur_id', _chauffeurId)
        .maybeSingle();

    return {
      'nombre_trajets': (data?['nombre_trajets'] as int?) ?? 0,
      'gains_jour': (data?['gains_jour'] as num?) ?? 0,
    };
  }

  Future<Map<String, dynamic>> recupererNoteMoyenne() async {
    final data = await _client
        .from('note_moyenne')
        .select()
        .eq('chauffeur_id', _chauffeurId)
        .maybeSingle();

    return {
      'note_moyenne': (data?['note_moyenne'] as num?) ?? 0.0,
      'nombre_avis': (data?['nombre_avis'] as int?) ?? 0,
    };
  }

  Future<int> recupererTempsActifMinutes() async {
    final data = await _client
        .from('temps_actif_jour')
        .select()
        .eq('chauffeur_id', _chauffeurId)
        .maybeSingle();

    final minutes = data?['minutes_actives'];
    if (minutes == null) return 0;
    return (minutes as num).toInt();
  }

  Future<List<Map<String, dynamic>>> recupererActivitesRecentes({
    int limite = 5,
  }) async {
    final data = await _client
        .from('activites_chauffeur')
        .select()
        .eq('chauffeur_id', _chauffeurId)
        .order('created_at', ascending: false)
        .limit(limite);

    return List<Map<String, dynamic>>.from(data);
  }

  // ---------- Flux temps réel ----------

  /// Écoute les nouvelles activités du chauffeur en temps réel
  Stream<List<Map<String, dynamic>>> streamActivites() {
    return _client
        .from('activites_chauffeur')
        .stream(primaryKey: ['id'])
        .eq('chauffeur_id', _chauffeurId)
        .order('created_at', ascending: false)
        .limit(5);
  }

  /// Écoute les trajets terminés aujourd'hui en temps réel
  Stream<List<Map<String, dynamic>>> streamTrajetsAujourdhui() {
    final debutJour = DateTime.now().toUtc();
    final minuit = DateTime(debutJour.year, debutJour.month, debutJour.day);

    return _client
        .from('trajets_historique')
        .stream(primaryKey: ['id'])
        .eq('chauffeur_id', _chauffeurId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((r) =>
                DateTime.parse(r['created_at'] as String).isAfter(minuit))
            .toList());
  }

  // ---------- Simuler un trajet terminé (pour tester) ----------
  Future<void> enregistrerTrajetTermine({
    required String ligneId,
    double montant = 500,
    int dureeMinutes = 25,
  }) async {
    await _client.from('trajets_historique').insert({
      'chauffeur_id': _chauffeurId,
      'ligne_id': ligneId,
      'montant': montant,
      'duree_minutes': dureeMinutes,
      'statut': 'termine',
    });

    await _client.from('activites_chauffeur').insert({
      'chauffeur_id': _chauffeurId,
      'type': 'trajet',
      'titre': 'Trajet terminé',
      'montant': montant,
    });
  }
}