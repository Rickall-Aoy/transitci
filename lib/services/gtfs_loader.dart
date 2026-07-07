import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/ligne.dart';
import '../models/gare.dart';

class GtfsLoader {
  GtfsLoader._();
  static final GtfsLoader instance = GtfsLoader._();

  List<Ligne> _lignes = [];
  List<Ligne> get lignes => _lignes;
  bool get isLoaded => _lignes.isNotEmpty;

  Future<void> initialize() async {
    if (_lignes.isNotEmpty) return;
    _lignes = await _loadAllLines();
    debugPrint('📊 GtfsLoader: ${_lignes.length} lignes construites');
  }

  Future<List<Ligne>> _loadAllLines() async {
    final stops = await _parseStops();
    final agencies = await _parseAgencies();
    final routes = await _parseRoutes();
    final trips = await _parseTrips();
    final stopTimes = await _parseStopTimes();

    final routeTrips = <String, List<Map<String, String>>>{};
    for (final t in trips) {
      routeTrips.putIfAbsent(t['route_id']!, () => []);
      if (routeTrips[t['route_id']]!.length < 2) {
        routeTrips[t['route_id']]!.add(t);
      }
    }

    final tripStops = <String, List<String>>{};
    for (final st in stopTimes) {
      tripStops.putIfAbsent(st['trip_id']!, () => []);
      tripStops[st['trip_id']]!.add(st['stop_id']!);
    }

    final lignes = <Ligne>[];
    int ignoreesCourtes = 0;

    for (final route in routes) {
      final routeId = route['route_id']!;
      final name = route['route_long_name'] ?? '';
      if (name.isEmpty) continue;

      final agencyId = route['agency_id'] ?? '';
      final type = _transportType(agencies[agencyId] ?? '');

      final routeTripsList = routeTrips[routeId] ?? [];
      if (routeTripsList.isEmpty) continue;

      final dir0 = routeTripsList.firstWhere(
        (t) => t['direction_id'] == '0',
        orElse: () => routeTripsList.first,
      );
      final dir1 = routeTripsList.firstWhere(
        (t) => t['direction_id'] == '1' && t['trip_id'] != dir0['trip_id'],
        orElse: () => dir0,
      );

      final stops0 = tripStops[dir0['trip_id']] ?? [];
      final memeDirection = dir0['trip_id'] == dir1['trip_id'];
      final stops1 =
          memeDirection ? const <String>[] : (tripStops[dir1['trip_id']] ?? []);

      // Direction "aller" — toujours construite si des arrêts existent
      final ligneAller = _construireLigneDirection(
        routeId: routeId,
        suffixe: 'A',
        name: name,
        type: type,
        sequenceStopIds: stops0,
        stops: stops,
      );
      if (ligneAller != null) {
        lignes.add(ligneAller);
      } else if (stops0.isNotEmpty) {
        ignoreesCourtes++;
      }

      // Direction "retour" — seulement si distincte de l'aller
      if (stops1.isNotEmpty) {
        final ligneRetour = _construireLigneDirection(
          routeId: routeId,
          suffixe: 'R',
          name: name,
          type: type,
          sequenceStopIds: stops1,
          stops: stops,
        );
        if (ligneRetour != null) {
          lignes.add(ligneRetour);
        } else {
          ignoreesCourtes++;
        }
      }
    }

    debugPrint(
      '📊 GtfsLoader: ${lignes.length} lignes construites '
      '(${ignoreesCourtes} directions ignorées car < 2 arrêts)',
    );

    return lignes;
  }

  /// Construit une Ligne pour UN SEUL sens de circulation, en conservant
  /// l'ordre réel de passage des arrêts (aucun mélange aller/retour).
  Ligne? _construireLigneDirection({
    required String routeId,
    required String suffixe,
    required String name,
    required TransportType type,
    required List<String> sequenceStopIds,
    required Map<String, Arret> stops,
  }) {
    final sequence = <Arret>[];
    String? dernierId;

    for (final sid in sequenceStopIds) {
      if (sid == dernierId) continue; // évite les doublons consécutifs (arrêt répété)
      final arret = stops[sid];
      if (arret != null) {
        sequence.add(arret);
        dernierId = sid;
      }
    }

    if (sequence.length < 2) return null;

    final arretsPossibles = sequence.sublist(1, sequence.length - 1);
    final nomDirection = suffixe == 'A' ? name : '$name (retour)';

    return Ligne(
      id: '${routeId}_$suffixe',
      nom: nomDirection,
      type: type,
      terminusDepart: sequence.first,
      terminusArrivee: sequence.last,
      arretsPossibles: arretsPossibles,
      prix: type == TransportType.woroWoro ? 300 : 200,
      couleurVehicule: '#1779C2',
      conseil: type == TransportType.woroWoro
          ? 'Dites votre arrêt au chauffeur avant de monter.'
          : 'Demandez au chauffeur si il dessert votre arrêt.',
    );
  }

  TransportType _transportType(String agencyName) {
    final lower = agencyName.toLowerCase();
    if (lower.contains('gbaka')) return TransportType.gbaka;
    if (lower.contains('woro')) return TransportType.woroWoro;
    return TransportType.gbaka;
  }

  Future<Map<String, Arret>> _parseStops() async {
    final lines = await _loadCsv('assets/gtfs/stops.txt');
    final map = <String, Arret>{};
    for (final row in lines) {
      final id = row['stop_id'] ?? '';
      final name = row['stop_name'] ?? '';
      final lat = double.tryParse(row['stop_lat'] ?? '') ?? 0.0;
      final lon = double.tryParse(row['stop_lon'] ?? '') ?? 0.0;
      if (id.isNotEmpty && name.isNotEmpty) {
        map[id] = Arret(nom: name, latitude: lat, longitude: lon);
      }
    }
    return map;
  }

  Future<Map<String, String>> _parseAgencies() async {
    final lines = await _loadCsv('assets/gtfs/agency.txt');
    final map = <String, String>{};
    for (final row in lines) {
      final id = row['agency_id'] ?? '';
      final name = row['agency_name'] ?? '';
      if (id.isNotEmpty) map[id] = name;
    }
    return map;
  }

  Future<List<Map<String, String>>> _parseRoutes() async {
    return _loadCsv('assets/gtfs/routes.txt');
  }

  Future<List<Map<String, String>>> _parseTrips() async {
    return _loadCsv('assets/gtfs/trips.txt');
  }

  Future<List<Map<String, String>>> _parseStopTimes() async {
    return _loadCsv('assets/gtfs/stop_times.txt');
  }

  Future<List<Map<String, String>>> _loadCsv(String path) async {
    final content = await rootBundle.loadString(path);
    final lines = const LineSplitter().convert(content.trim());
    if (lines.isEmpty) return [];

    final headers = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (int i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i]);
      if (values.length != headers.length) continue;
      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j];
      }
      rows.add(row);
    }
    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }
}