import 'gare.dart';

enum TypeSegment { piedVersGare, transport, piedVersDest }

class Segment {
  final TypeSegment type;
  final double deLatitude;
  final double deLongitude;
  final double versLatitude;
  final double versLongitude;
  final Gare? gare;
  final int dureeMinutes;
  final int prix;
  final String description;

  // ── Nouveaux champs ──
  final String? conseil;        // "Demandez au chauffeur..."
  final String? arretMontee;   // "Gare Cocody Mairie"
  final String? arretDescente; // "CHU Cocody"
  final String? couleurVehicule; // "Jaune", "Bleu"...

  const Segment({
    required this.type,
    required this.deLatitude,
    required this.deLongitude,
    required this.versLatitude,
    required this.versLongitude,
    this.gare,
    required this.dureeMinutes,
    required this.prix,
    required this.description,
    this.conseil,
    this.arretMontee,
    this.arretDescente,
    this.couleurVehicule,
  });
}

class Trajet {
  final List<Segment> segments;
  final int dureeTotal;       // minutes
  final int prixTotal;        // FCFA
  final double score;
  final String resume;        // ex: "Woro-Woro → Gbaka"

  const Trajet({
    required this.segments,
    required this.dureeTotal,
    required this.prixTotal,
    required this.score,
    required this.resume,
  });

  // Nombre de correspondances
  int get correspondances => segments
      .where((s) => s.type == TypeSegment.transport)
      .length - 1;
}