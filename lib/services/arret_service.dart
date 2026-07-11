import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ligne.dart';
import '../models/stop.dart';
import '../models/edge.dart';
import 'walking_edges_service.dart';

/// Charge et met en CACHE les arrêts (44 gares d'Abidjan) et la table de
/// jonction `ligne_arrets` depuis Supabase.
///
/// - Le chargement est fait UNE SEULE FOIS (au démarrage via [initialize]) ;
///   il n'est jamais relancé à chaque recherche.
/// - À partir des arrêts, une couche de walking edges (transferts à pied) est
///   construite une fois via [WalkingEdgesService] et conservée en cache.
/// - [enrichirLignes] complète les lignes Supabase (qui n'ont que leurs
///   terminus) avec leurs arrêts intermédiaires : ces arrêts deviennent des
///   points de correspondance supplémentaires pour le routing existant, SANS
///   modifier sa logique heuristique.
class ArretService {
  ArretService._();
  static final ArretService instance = ArretService._();

  /// Plafond de distance (m) entre deux gares pour créer un walking edge.
  static const double _rayonEdgeMetres = 1200;

  SupabaseClient get _client => Supabase.instance.client;

  // ── Caches ──
  final List<Arret> _arrets = <Arret>[];
  final Map<String, Arret> _arretsById = <String, Arret>{};
  final Map<String, List<Arret>> _arretsParLigne = <String, List<Arret>>{};
  List<Stop> _stops = const <Stop>[];
  List<Edge> _walkingEdges = const <Edge>[];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<Arret> get arrets => List.unmodifiable(_arrets);
  List<Stop> get stops => List.unmodifiable(_stops);
  List<Edge> get walkingEdges => List.unmodifiable(_walkingEdges);

  /// Charge `arrets` + `ligne_arrets` puis construit la couche de walking
  /// edges. Idempotent : ne recharge pas si déjà chargé.
  Future<void> initialize() async {
    if (_loaded) return;
    try {
      await _chargerArrets();
      await _chargerLigneArrets();
      _construireWalkingEdges();
      _loaded = true;
      debugPrint('✅ ArretService: ${_arrets.length} arrets, '
          '${_arretsParLigne.length} lignes mappées, '
          '${_walkingEdges.length} walking edges');
    } catch (e) {
      // Non fatal : le routing continue de fonctionner sans les arrets Supabase.
      debugPrint('❌ ArretService.initialize: $e');
    }
  }

  Future<void> _chargerArrets() async {
    final response = await _client
        .from('arrets')
        .select('id, nom, latitude, longitude, commune, type');
    final rows = List<Map<String, dynamic>>.from(response as List);

    _arrets.clear();
    _arretsById.clear();
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final arret = Arret(
        nom: row['nom']?.toString() ?? '',
        latitude: _toDouble(row['latitude']),
        longitude: _toDouble(row['longitude']),
      );
      if (arret.latitude == 0 && arret.longitude == 0) continue;
      _arrets.add(arret);
      _arretsById[id] = arret;
    }
  }

  Future<void> _chargerLigneArrets() async {
    final response = await _client
        .from('ligne_arrets')
        .select('ligne_id, arret_id, ordre')
        .order('ordre', ascending: true);
    final rows = List<Map<String, dynamic>>.from(response as List);

    _arretsParLigne.clear();
    for (final row in rows) {
      final ligneId = row['ligne_id']?.toString() ?? '';
      final arretId = row['arret_id']?.toString() ?? '';
      if (ligneId.isEmpty || arretId.isEmpty) continue;
      final arret = _arretsById[arretId];
      if (arret == null) continue;
      // `ordre` déjà trié par la requête : on préserve la séquence.
      _arretsParLigne.putIfAbsent(ligneId, () => <Arret>[]).add(arret);
    }
  }

  /// Construit un [Stop] par gare (id unique) puis la couche de walking edges
  /// (transferts à pied entre gares distantes de ≤ 1200 m).
  void _construireWalkingEdges() {
    _stops = <Stop>[
      for (final entry in _arretsById.entries)
        Stop(arret: entry.value, ligneId: 'arret:${entry.key}'),
    ];
    _walkingEdges = WalkingEdgesService.buildWalkingEdges(
      _stops,
      maxDistanceMetres: _rayonEdgeMetres,
    );
  }

  /// Retourne une copie des [lignes] enrichie : chaque ligne présente dans
  /// `ligne_arrets` reçoit sa séquence d'arrêts Supabase comme arrêts
  /// intermédiaires (points de correspondance supplémentaires pour le routing).
  ///
  /// Les lignes sans mapping (ex. lignes GTFS) sont renvoyées inchangées.
  /// Aucune logique de calcul d'itinéraire n'est touchée.
  List<Ligne> enrichirLignes(List<Ligne> lignes) {
    if (_arretsParLigne.isEmpty) return lignes;
    return lignes.map((ligne) {
      final arretsDb = _arretsParLigne[ligne.id];
      if (arretsDb == null || arretsDb.isEmpty) return ligne;
      return Ligne(
        id: ligne.id,
        nom: ligne.nom,
        type: ligne.type,
        terminusDepart: ligne.terminusDepart,
        terminusArrivee: ligne.terminusArrivee,
        arretsPossibles: <Arret>[
          ...ligne.arretsPossibles,
          ...arretsDb,
        ],
        prix: ligne.prix,
        couleurVehicule: ligne.couleurVehicule,
        conseil: ligne.conseil,
      );
    }).toList();
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
