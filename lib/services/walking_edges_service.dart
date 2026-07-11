import 'dart:math';
import '../models/stop.dart';
import '../models/edge.dart';
import '../models/ligne.dart';

/// Construit la couche de « walking edges » (transferts à pied) du graphe de
/// transport, consommée par le pathfinding (Dijkstra).
class WalkingEdgesService {
  /// Distance Haversine en mètres entre deux points (lat/lon en degrés).
  static double haversineMetres(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // rayon moyen de la Terre (m)
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Aplatit le graphe existant ([Ligne] → [Arret]) en nœuds [Stop],
  /// un par (arrêt, ligne).
  static List<Stop> stopsFromLignes(List<Ligne> lignes) {
    final stops = <Stop>[];
    for (final ligne in lignes) {
      for (final arret in ligne.tousLesArrets) {
        stops.add(Stop(arret: arret, ligneId: ligne.id));
      }
    }
    return stops;
  }

  /// Construit les walking edges entre arrêts de *lignes différentes*,
  /// dans un rayon de [maxDistanceMetres] (400 m par défaut), de façon
  /// bidirectionnelle.
  ///
  /// Coût : (distanceMetres / 1.3889) * 2.5
  ///   - 1.3889 m/s ≈ 5 km/h (vitesse de marche)
  ///   - ×2.5 : pénalité (attente, traversée, confort) pour le pathfinding.
  static List<Edge> buildWalkingEdges(
    List<Stop> stops, {
    double maxDistanceMetres = 400,
  }) {
    final edges = <Edge>[];
    for (int i = 0; i < stops.length; i++) {
      for (int j = i + 1; j < stops.length; j++) {
        final a = stops[i];
        final b = stops[j];

        // Condition : lignes différentes (sinon aucun transfert utile).
        if (a.ligneId == b.ligneId) continue;

        final d = haversineMetres(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        );

        // Condition : distance <= plafond.
        if (d > maxDistanceMetres) continue;

        final cout = (d / 1.3889) * 2.5;

        // Bidirectionnel : A→B et B→A.
        edges.add(Edge(
          fromId: a.id,
          toId: b.id,
          distanceMetres: d,
          cout: cout,
        ));
        edges.add(Edge(
          fromId: b.id,
          toId: a.id,
          distanceMetres: d,
          cout: cout,
        ));
      }
    }
    return edges;
  }
}
