enum TransportType { woroWoro, gbaka, sotra, yango }

class Gare {
  final String id;
  final String nom;
  final TransportType type;
  final double latitude;
  final double longitude;
  final List<String> lignes;
  final int prixMoyen; // en FCFA

  const Gare({
    required this.id,
    required this.nom,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.lignes,
    required this.prixMoyen,
  });

  /// Icône selon le type de transport
  String get emoji {
    switch (type) {
      case TransportType.woroWoro: return '🚕';
      case TransportType.gbaka:    return '🚐';
      case TransportType.sotra:    return '🚌';
      case TransportType.yango:    return '🚗';
    }
  }

  /// Couleur selon le type
  int get couleur {
    switch (type) {
      case TransportType.woroWoro: return 0xFFFF6B2B; // orange
      case TransportType.gbaka:    return 0xFF00C896; // vert
      case TransportType.sotra:    return 0xFF2196F3; // bleu
      case TransportType.yango:    return 0xFFFFCC00; // jaune
    }
  }

  double get distanceFictive => (latitude - 5.3196).abs() + (longitude + 4.0167).abs();
}