import '../models/gare.dart';
import '../models/ligne.dart';
import '../models/trajet.dart';
import 'location_service.dart';

class RoutingService {

  static List<Trajet> calculerTrajets({
    required double userLat,
    required double userLon,
    required double destLat,
    required double destLon,
    required List<Ligne> lignes,
    required int heure,
  }) {
    final List<Trajet> trajets = [];
    final lignesDepart = _lignesProches(
      lignes: lignes,
      lat: userLat,
      lon: userLon,
      limit: 24,
    );
    final lignesDestination = _lignesProches(
      lignes: lignes,
      lat: destLat,
      lon: destLon,
      limit: 24,
    );
    final lignesDirectes =
        _dedupeLignes([...lignesDepart, ...lignesDestination]);

    // ── 1. Trajets directs (1 seule ligne) ──
    for (final ligne in lignesDirectes) {
      final t = _trajetDirect(
        userLat: userLat, userLon: userLon,
        destLat: destLat, destLon: destLon,
        ligne: ligne, heure: heure,
      );
      if (t != null) trajets.add(t);
    }

    // ── 2. Trajets avec 1 correspondance ──
    for (final l1 in lignesDepart) {
      for (final l2 in lignesDestination) {
        if (l1.id == l2.id) continue;
        final t = _trajetCorrespondance(
          userLat: userLat, userLon: userLon,
          destLat: destLat, destLon: destLon,
          ligne1: l1, ligne2: l2, heure: heure,
        );
        if (t != null) trajets.add(t);
      }
    }

    // ── 3. Trajets avec 2 correspondances (> 8km) ──
    final distTotale = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: destLat, lon2: destLon,
    );

    if (distTotale > 8000) {
      final lignesIntermediaires = _dedupeLignes(lignes)
          .where((ligne) =>
              !lignesDepart.any((l) => l.id == ligne.id) &&
              !lignesDestination.any((l) => l.id == ligne.id))
          .take(32)
          .toList();

      for (final l1 in lignesDepart.take(12)) {
        for (final l2 in lignesIntermediaires) {
          for (final l3 in lignesDestination.take(12)) {
            if (l1.id == l2.id || l2.id == l3.id || l1.id == l3.id) continue;
            final t = _trajetDoubleCorrespondance(
              userLat: userLat, userLon: userLon,
              destLat: destLat, destLon: destLon,
              ligne1: l1, ligne2: l2, ligne3: l3, heure: heure,
            );
            if (t != null) trajets.add(t);
          }
        }
      }
    }

    // Trier et garder les 3 meilleurs
    trajets.sort((a, b) => a.score.compareTo(b.score));
    return trajets.take(3).toList();
  }

  static List<Ligne> _lignesProches({
    required List<Ligne> lignes,
    required double lat,
    required double lon,
    required int limit,
  }) {
    final scored = lignes.map((ligne) {
      final arret = ligne.arretLePlusProche(lat, lon);
      final distance = LocationService.distanceEnMetres(
        lat1: lat,
        lon1: lon,
        lat2: arret.latitude,
        lon2: arret.longitude,
      );
      return MapEntry(ligne, distance);
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return scored
        .where((entry) => entry.value <= 5000)
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  static List<Ligne> _dedupeLignes(List<Ligne> lignes) {
    final seen = <String>{};
    final result = <Ligne>[];
    for (final ligne in lignes) {
      if (seen.add(ligne.id)) result.add(ligne);
    }
    return result;
  }

  // ── Trajet direct ──
  static Trajet? _trajetDirect({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne, required int heure,
  }) {
    // La ligne doit desservir à la fois le départ et la destination
    if (!ligne.peutDesservir(userLat, userLon)) return null;
    if (!ligne.peutDesservir(destLat, destLon)) return null;

    // Trouver les arrêts les plus proches
    final arretDepart = ligne.arretLePlusProche(userLat, userLon);
    final arretArrivee = ligne.arretLePlusProche(destLat, destLon);

    // Éviter si même arrêt
    if (arretDepart.nom == arretArrivee.nom) return null;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );

    if (distUserArret > 5000) return null;

    final tempsAPied1 = _tempsAPied(distUserArret);
    final tempsTransport = _estimerTempsTransport(ligne.type, heure);
    final tempsAPied2 = _tempsAPied(distArretDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretDepart.latitude,
        versLongitude: arretDepart.longitude,
        dureeMinutes: tempsAPied1,
        prix: 0,
        description: 'Marche vers ${arretDepart.nom}',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: tempsTransport,
        prix: ligne.prix,
        description: '${_emoji(ligne.type)} ${ligne.nom}',
        conseil: ligne.conseil,
        arretMontee: arretDepart.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: tempsAPied2,
        prix: 0,
        description: 'Marche vers la destination',
      ),
    ];

    final duree = tempsAPied1 + tempsTransport + tempsAPied2;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: ligne.prix,
      score: _score(duree: duree, prix: ligne.prix, correspondances: 0),
      resume: '${_emoji(ligne.type)} ${_labelType(ligne.type)}',
    );
  }

  // ── Trajet avec 1 correspondance ──
  static Trajet? _trajetCorrespondance({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne1, required Ligne ligne2,
    required int heure,
  }) {
    // Ligne1 doit desservir le départ
    if (!ligne1.peutDesservir(userLat, userLon)) return null;
    // Ligne2 doit desservir la destination
    if (!ligne2.peutDesservir(destLat, destLon)) return null;

    // Trouver le point de correspondance (arrêt commun entre les 2 lignes)
    Arret? pointCorrespondance;
    double minDist = double.infinity;

    for (final a1 in ligne1.tousLesArrets) {
      for (final a2 in ligne2.tousLesArrets) {
        final dist = LocationService.distanceEnMetres(
          lat1: a1.latitude, lon1: a1.longitude,
          lat2: a2.latitude, lon2: a2.longitude,
        );
        // Arrêts proches = correspondance possible (< 400m)
        if (dist < 400 && dist < minDist) {
          minDist = dist;
          pointCorrespondance = a1;
        }
      }
    }

    if (pointCorrespondance == null) return null;

    final arretDepart = ligne1.arretLePlusProche(userLat, userLon);
    final arretArrivee = ligne2.arretLePlusProche(destLat, destLon);

    // La correspondance doit rapprocher de la destination
    final distCorrDest = LocationService.distanceEnMetres(
      lat1: pointCorrespondance.latitude,
      lon1: pointCorrespondance.longitude,
      lat2: destLat, lon2: destLon,
    );
    final distDepartDest = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: destLat, lon2: destLon,
    );
    if (distCorrDest >= distDepartDest) return null;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    if (distUserArret > 5000) return null;

    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );

    final tempsAPied1 = _tempsAPied(distUserArret);
    final tempsT1 = _estimerTempsTransport(ligne1.type, heure);
    const tempsCorr = 5;
    final tempsT2 = _estimerTempsTransport(ligne2.type, heure);
    final tempsAPied2 = _tempsAPied(distArretDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretDepart.latitude,
        versLongitude: arretDepart.longitude,
        dureeMinutes: tempsAPied1,
        prix: 0,
        description: 'Marche vers ${arretDepart.nom}',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: pointCorrespondance.latitude,
        versLongitude: pointCorrespondance.longitude,
        dureeMinutes: tempsT1,
        prix: ligne1.prix,
        description: '${_emoji(ligne1.type)} ${ligne1.nom}',
        conseil: ligne1.conseil,
        arretMontee: arretDepart.nom,
        arretDescente: pointCorrespondance.nom,
        couleurVehicule: ligne1.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: pointCorrespondance.latitude,
        deLongitude: pointCorrespondance.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: tempsCorr + tempsT2,
        prix: ligne2.prix,
        description: '${_emoji(ligne2.type)} ${ligne2.nom}',
        conseil: ligne2.conseil,
        arretMontee: pointCorrespondance.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne2.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: tempsAPied2,
        prix: 0,
        description: 'Marche vers la destination',
      ),
    ];

    final duree = tempsAPied1 + tempsT1 + tempsCorr + tempsT2 + tempsAPied2;
    final prix = ligne1.prix + ligne2.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 1),
      resume: '${_emoji(ligne1.type)} ${_labelType(ligne1.type)} '
          '→ ${_emoji(ligne2.type)} ${_labelType(ligne2.type)}',
    );
  }

  // ── Trajet avec 2 correspondances ──
  static Trajet? _trajetDoubleCorrespondance({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne1, required Ligne ligne2, required Ligne ligne3,
    required int heure,
  }) {
    if (!ligne1.peutDesservir(userLat, userLon)) return null;
    if (!ligne3.peutDesservir(destLat, destLon)) return null;

    // Correspondance 1 : entre ligne1 et ligne2
    Arret? corr1;
    double minD1 = double.infinity;
    for (final a1 in ligne1.tousLesArrets) {
      for (final a2 in ligne2.tousLesArrets) {
        final d = LocationService.distanceEnMetres(
          lat1: a1.latitude, lon1: a1.longitude,
          lat2: a2.latitude, lon2: a2.longitude,
        );
        if (d < 400 && d < minD1) { minD1 = d; corr1 = a1; }
      }
    }
    if (corr1 == null) return null;

    // Correspondance 2 : entre ligne2 et ligne3
    Arret? corr2;
    double minD2 = double.infinity;
    for (final a2 in ligne2.tousLesArrets) {
      for (final a3 in ligne3.tousLesArrets) {
        final d = LocationService.distanceEnMetres(
          lat1: a2.latitude, lon1: a2.longitude,
          lat2: a3.latitude, lon2: a3.longitude,
        );
        if (d < 400 && d < minD2) { minD2 = d; corr2 = a2; }
      }
    }
    if (corr2 == null) return null;

    final arretDepart = ligne1.arretLePlusProche(userLat, userLon);
    final arretArrivee = ligne3.arretLePlusProche(destLat, destLon);

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    if (distUserArret > 5000) return null;

    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );

    final t0 = _tempsAPied(distUserArret);
    final t1 = _estimerTempsTransport(ligne1.type, heure);
    final t2 = _estimerTempsTransport(ligne2.type, heure);
    final t3 = _estimerTempsTransport(ligne3.type, heure);
    final t4 = _tempsAPied(distArretDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretDepart.latitude,
        versLongitude: arretDepart.longitude,
        dureeMinutes: t0, prix: 0,
        description: 'Marche vers ${arretDepart.nom}',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: corr1.latitude, versLongitude: corr1.longitude,
        dureeMinutes: t1, prix: ligne1.prix,
        description: '${_emoji(ligne1.type)} ${ligne1.nom}',
        conseil: ligne1.conseil,
        arretMontee: arretDepart.nom,
        arretDescente: corr1.nom,
        couleurVehicule: ligne1.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: corr1.latitude, deLongitude: corr1.longitude,
        versLatitude: corr2.latitude, versLongitude: corr2.longitude,
        dureeMinutes: 5 + t2, prix: ligne2.prix,
        description: '${_emoji(ligne2.type)} ${ligne2.nom}',
        conseil: ligne2.conseil,
        arretMontee: corr1.nom,
        arretDescente: corr2.nom,
        couleurVehicule: ligne2.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: corr2.latitude, deLongitude: corr2.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: 5 + t3, prix: ligne3.prix,
        description: '${_emoji(ligne3.type)} ${ligne3.nom}',
        conseil: ligne3.conseil,
        arretMontee: corr2.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne3.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: t4, prix: 0,
        description: 'Marche vers la destination',
      ),
    ];

    final duree = t0 + t1 + 5 + t2 + 5 + t3 + t4;
    final prix = ligne1.prix + ligne2.prix + ligne3.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 2),
      resume: '${_emoji(ligne1.type)} → ${_emoji(ligne2.type)} '
          '→ ${_emoji(ligne3.type)}',
    );
  }

  // ── Helpers ──

  static int _tempsAPied(double metres) =>
      (metres / 4000 * 60).round().clamp(1, 60);

  static int _estimerTempsTransport(TransportType type, int heure) {
    final pointe = (heure >= 7 && heure <= 9) || (heure >= 17 && heure <= 20);
    final bonus = pointe ? 15 : 0;
    switch (type) {
      case TransportType.woroWoro: return 20 + bonus;
      case TransportType.gbaka:    return 25 + bonus;
      case TransportType.sotra:    return 30 + bonus;
      case TransportType.yango:    return 15 + (bonus ~/ 2);
    }
  }

  static double _score({
    required int duree, required int prix, required int correspondances}) {
    return (duree * 1.5) + (prix / 100) + (correspondances * 10.0);
  }

  static String _labelType(TransportType type) {
    switch (type) {
      case TransportType.woroWoro: return 'Woro-Woro';
      case TransportType.gbaka:    return 'Gbaka';
      case TransportType.sotra:    return 'SOTRA';
      case TransportType.yango:    return 'Yango';
    }
  }

  static String _emoji(TransportType type) {
    switch (type) {
      case TransportType.woroWoro: return '🚕';
      case TransportType.gbaka:    return '🚐';
      case TransportType.sotra:    return '🚌';
      case TransportType.yango:    return '🚗';
    }
  }
}
