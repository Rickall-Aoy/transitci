/// Arc (arête) du graphe de transport : liaison à pied entre deux arrêts.
///
/// Minimale et compatible avec le reste du projet : identifiants des arrêts
/// (via [Stop.id]), distance réelle en mètres et coût utilisé par le
/// pathfinding (Dijkstra). Créée pour le besoin des walking edges.
class Edge {
  final String fromId;
  final String toId;
  final double distanceMetres;
  final double cout;

  const Edge({
    required this.fromId,
    required this.toId,
    required this.distanceMetres,
    required this.cout,
  });

  String get mode => 'walking';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Edge && fromId == other.fromId && toId == other.toId;

  @override
  int get hashCode => fromId.hashCode ^ toId.hashCode;
}
