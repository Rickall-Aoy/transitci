import 'dart:convert';
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
      final stops1 = dir0['trip_id'] == dir1['trip_id']
          ? stops0
          : tripStops[dir1['trip_id']] ?? [];

      if (stops0.isEmpty && stops1.isEmpty) continue;

      final terminusDepart = stops0.isNotEmpty ? stops[stops0.first] : null;
      final terminusArrivee = stops1.isNotEmpty ? stops[stops1.last] : null;

      if (terminusDepart == null || terminusArrivee == null) continue;

      final arretsPossibles = <Arret>[];
      final seen = <String>{stops0.first, stops1.last};
      for (final sid in stops0) {
        if (!seen.contains(sid) && stops.containsKey(sid)) {
          seen.add(sid);
          arretsPossibles.add(stops[sid]!);
        }
      }
      for (final sid in stops1) {
        if (!seen.contains(sid) && stops.containsKey(sid)) {
          seen.add(sid);
          arretsPossibles.add(stops[sid]!);
        }
      }

      lignes.add(Ligne(
        id: routeId,
        nom: name,
        type: type,
        terminusDepart: terminusDepart,
        terminusArrivee: terminusArrivee,
        arretsPossibles: arretsPossibles,
        prix: type == TransportType.woroWoro ? 300 : 200,
        couleurVehicule: '#1779C2',
        conseil: type == TransportType.woroWoro
            ? 'Dites votre arrêt au chauffeur avant de monter.'
            : 'Demandez au chauffeur si il dessert votre arrêt.',
      ));
    }
    return lignes;
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
