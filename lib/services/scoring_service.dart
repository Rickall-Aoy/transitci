import '../models/gare.dart';
import 'location_service.dart';

class TransportOption {
  final Gare gare;
  final double distanceAPied; // en mètres
  final int tempsAPied;       // en minutes
  final int tempsTotalEstime; // en minutes
  final int prix;             // en FCFA
  final double score;         // plus bas = meilleur

  const TransportOption({
    required this.gare,
    required this.distanceAPied,
    required this.tempsAPied,
    required this.tempsTotalEstime,
    required this.prix,
    required this.score,
  });
}

enum Priorite { economique, rapide, equilibre }

class ScoringService {
  /// Retourne les meilleures options triées par score
  static List<TransportOption> calculerOptions({
    required double userLat,
    required double userLon,
    required List<Gare> gares,
    required Priorite priorite,
    required int heure, // 0-23
  }) {
    final options = gares.map((gare) {
      // 1. Distance à pied vers la gare (en mètres)
      final distance = LocationService.distanceEnMetres(
        lat1: userLat, lon1: userLon,
        lat2: gare.latitude, lon2: gare.longitude,
      );

      // 2. Temps à pied (vitesse moyenne ~4km/h)
      final tempsAPied = (distance / 4000 * 60).round();

      // 3. Temps de trajet estimé selon type
      final tempsTrajet = _estimerTempsTrajet(gare.type, heure);

      // 4. Temps total
      final tempsTotal = tempsAPied + tempsTrajet;

      // 5. Prix
      final prix = _estimerPrix(gare);

      // 6. Score selon priorité
      final score = _calculerScore(
        distance: distance,
        tempsTotal: tempsTotal,
        prix: prix,
        priorite: priorite,
        heure: heure,
        type: gare.type,
      );

      return TransportOption(
        gare: gare,
        distanceAPied: distance,
        tempsAPied: tempsAPied,
        tempsTotalEstime: tempsTotal,
        prix: prix,
        score: score,
      );
    }).toList();

    // Trier par score (plus bas = meilleur) et garder les 3 meilleures
    options.sort((a, b) => a.score.compareTo(b.score));
    return options.take(3).toList();
  }

  static int _estimerTempsTrajet(TransportType type, int heure) {
    // Pénalité embouteillages : 7h-9h et 17h-20h
    final bool heurePointe = (heure >= 7 && heure <= 9) ||
                             (heure >= 17 && heure <= 20);
    final int bonus = heurePointe ? 15 : 0;

    switch (type) {
      case TransportType.woroWoro: return 20 + bonus;
      case TransportType.gbaka:    return 25 + bonus;
      case TransportType.sotra:    return 30 + bonus;
      case TransportType.yango:    return 15 + (bonus ~/ 2);
    }
  }

  static int _estimerPrix(Gare gare) {
    if (gare.type == TransportType.yango) {
      // Yango : prix dynamique simulé
      return 1500 + (gare.distanceFictive * 100).round();
    }
    return gare.prixMoyen;
  }

  static double _calculerScore({
    required double distance,
    required int tempsTotal,
    required int prix,
    required Priorite priorite,
    required int heure,
    required TransportType type,
  }) {
    // Normalisation
    final double scoreDistance = distance / 1000; // km
    final double scorePrix     = prix / 100;
    final double scoreTemps    = tempsTotal.toDouble();

    // Pénalité nuit (après 21h) pour woro-woro et gbaka
    final bool nuit = heure >= 21 || heure <= 5;
    double penaliteNuit = 0;
    if (nuit && (type == TransportType.woroWoro || type == TransportType.gbaka)) {
      penaliteNuit = 20; // moins disponibles la nuit
    }

    // Poids selon priorité
    switch (priorite) {
      case Priorite.economique:
        // Prix x3, temps x1, distance x1
        return (scorePrix * 3) + scoreTemps + scoreDistance + penaliteNuit;

      case Priorite.rapide:
        // Temps x3, distance x2, prix x1
        return (scoreTemps * 3) + (scoreDistance * 2) + scorePrix + penaliteNuit;

      case Priorite.equilibre:
        // Poids égaux
        return (scorePrix * 1.5) + (scoreTemps * 1.5) + scoreDistance + penaliteNuit;
    }
  }
}