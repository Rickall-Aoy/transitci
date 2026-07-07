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
    );
    final lignesDestination = _lignesProches(
      lignes: lignes,
      lat: destLat,
      lon: destLon,
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
    double maxDistance = 8000,
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
        .where((entry) => entry.value <= maxDistance)
        .take(48)
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

  /// Cherche un point de correspondance entre deux lignes ET retourne
  /// les index respectifs, pour permettre de valider le sens de chacune.
  static ({Arret arret, int indexLigne1, int indexLigne2})? _trouverCorrespondance(
      Ligne ligne1, Ligne ligne2) {
    final arrets1 = ligne1.tousLesArrets;
    final arrets2 = ligne2.tousLesArrets;

    Arret? meilleur;
    int meilleurIndex1 = -1;
    int meilleurIndex2 = -1;
    double minDist = double.infinity;

    for (int i = 0; i < arrets1.length; i++) {
      for (int j = 0; j < arrets2.length; j++) {
        final dist = LocationService.distanceEnMetres(
          lat1: arrets1[i].latitude, lon1: arrets1[i].longitude,
          lat2: arrets2[j].latitude, lon2: arrets2[j].longitude,
        );
        if (dist < 400 && dist < minDist) {
          minDist = dist;
          meilleur = arrets1[i];
          meilleurIndex1 = i;
          meilleurIndex2 = j;
        }
      }
    }

    if (meilleur == null) return null;
    return (arret: meilleur, indexLigne1: meilleurIndex1, indexLigne2: meilleurIndex2);
  }

  // ── Trajet direct ──
  static Trajet? _trajetDirect({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne, required int heure,
  }) {
    if (!ligne.peutDesservir(userLat, userLon)) return null;
    if (!ligne.peutDesservir(destLat, destLon)) return null;

    final departInfo = ligne.arretLePlusProcheAvecIndex(userLat, userLon);
    final arriveeInfo = ligne.arretLePlusProcheAvecIndex(destLat, destLon);

    if (departInfo.index >= arriveeInfo.index) {
      final distGare2Dest = LocationService.distanceEnMetres(
        lat1: arriveeInfo.arret.latitude,
        lon1: arriveeInfo.arret.longitude,
        lat2: destLat,
        lon2: destLon,
      );
      if (distGare2Dest > 2000) return null;
    }

    final arretDepart = departInfo.arret;
    final arretArrivee = arriveeInfo.arret;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );

    if (distUserArret > 8000) return null;

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
        description: 'Marche vers ${arretDepart.nom} (~${tempsAPied1} min)',
        conseil: 'Dirige-toi vers ${arretDepart.nom} à pied.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: tempsTransport,
        prix: ligne.prix,
        description: 'Prends ${_labelType(ligne.type)} direction ${ligne.terminusArrivee.nom}'
            ' — descends à ${arretArrivee.nom}',
        conseil: _conseilParType(ligne.type, arretArrivee.nom),
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
        description: 'Marche vers ta destination (~${tempsAPied2} min)',
      ),
    ];

    final duree = tempsAPied1 + tempsTransport + tempsAPied2;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: ligne.prix,
      score: _score(duree: duree, prix: ligne.prix, correspondances: 0),
      resume: _construireResumeDirect(
        tempsAPied1: tempsAPied1,
        ligne: ligne,
        tempsTransport: tempsTransport,
        tempsAPied2: tempsAPied2,
        arretArrivee: arretArrivee,
      ),
    );
  }

  // ── Trajet avec 1 correspondance ──
  static Trajet? _trajetCorrespondance({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne1, required Ligne ligne2,
    required int heure,
  }) {
    if (!ligne1.peutDesservir(userLat, userLon)) return null;
    if (!ligne2.peutDesservir(destLat, destLon)) return null;

    final corr = _trouverCorrespondance(ligne1, ligne2);
    if (corr == null) return null;

    final departInfo = ligne1.arretLePlusProcheAvecIndex(userLat, userLon);
    final arriveeInfo = ligne2.arretLePlusProcheAvecIndex(destLat, destLon);

    // Le point de correspondance doit être APRÈS le départ sur ligne1,
    // et AVANT l'arrivée sur ligne2 — sinon le trajet remonte le sens.
    if (departInfo.index >= corr.indexLigne1) return null;
    if (corr.indexLigne2 >= arriveeInfo.index) return null;

    final pointCorrespondance = corr.arret;
    final arretDepart = departInfo.arret;
    final arretArrivee = arriveeInfo.arret;

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
    if (distUserArret > 8000) return null;

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
        description: 'Marche vers ${arretDepart.nom} (~${tempsAPied1} min)',
        conseil: 'Dirige-toi vers ${arretDepart.nom} à pied.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: pointCorrespondance.latitude,
        versLongitude: pointCorrespondance.longitude,
        dureeMinutes: tempsT1,
        prix: ligne1.prix,
        description: 'Prends ${_labelType(ligne1.type)} direction ${ligne1.terminusArrivee.nom}'
            ' — descends à ${pointCorrespondance.nom}',
        conseil: _conseilParType(ligne1.type, pointCorrespondance.nom),
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
        description: 'Prends ${_labelType(ligne2.type)} direction ${ligne2.terminusArrivee.nom}'
            ' — descends à ${arretArrivee.nom}',
        conseil: _conseilParType(ligne2.type, arretArrivee.nom),
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
        description: 'Marche vers ta destination (~${tempsAPied2} min)',
      ),
    ];

    final duree = tempsAPied1 + tempsT1 + tempsCorr + tempsT2 + tempsAPied2;
    final prix = ligne1.prix + ligne2.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 1),
      resume: _construireResumeCorrespondance1(
        tempsAPied1: tempsAPied1,
        ligne1: ligne1,
        ligne2: ligne2,
        tempsAPied2: tempsAPied2,
        arretArrivee: arretArrivee,
      ),
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

    final corr1 = _trouverCorrespondance(ligne1, ligne2);
    if (corr1 == null) return null;

    final corr2 = _trouverCorrespondance(ligne2, ligne3);
    if (corr2 == null) return null;

    final departInfo = ligne1.arretLePlusProcheAvecIndex(userLat, userLon);
    final arriveeInfo = ligne3.arretLePlusProcheAvecIndex(destLat, destLon);

    // Validation du sens sur les 3 segments de la chaîne
    if (departInfo.index >= corr1.indexLigne1) return null;
    if (corr1.indexLigne2 >= corr2.indexLigne1) return null;
    if (corr2.indexLigne2 >= arriveeInfo.index) return null;

    final arretDepart = departInfo.arret;
    final arretArrivee = arriveeInfo.arret;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    if (distUserArret > 8000) return null;

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
        description: 'Marche vers ${arretDepart.nom} (~${t0} min)',
        conseil: 'Dirige-toi vers ${arretDepart.nom} à pied.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: corr1.arret.latitude, versLongitude: corr1.arret.longitude,
        dureeMinutes: t1, prix: ligne1.prix,
        description: 'Prends ${_labelType(ligne1.type)} direction ${ligne1.terminusArrivee.nom}'
            ' — descends à ${corr1.arret.nom}',
        conseil: _conseilParType(ligne1.type, corr1.arret.nom),
        arretMontee: arretDepart.nom,
        arretDescente: corr1.arret.nom,
        couleurVehicule: ligne1.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: corr1.arret.latitude, deLongitude: corr1.arret.longitude,
        versLatitude: corr2.arret.latitude, versLongitude: corr2.arret.longitude,
        dureeMinutes: 5 + t2, prix: ligne2.prix,
        description: 'Prends ${_labelType(ligne2.type)} direction ${ligne2.terminusArrivee.nom}'
            ' — descends à ${corr2.arret.nom}',
        conseil: _conseilParType(ligne2.type, corr2.arret.nom),
        arretMontee: corr1.arret.nom,
        arretDescente: corr2.arret.nom,
        couleurVehicule: ligne2.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: corr2.arret.latitude, deLongitude: corr2.arret.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: 5 + t3, prix: ligne3.prix,
        description: 'Prends ${_labelType(ligne3.type)} direction ${ligne3.terminusArrivee.nom}'
            ' — descends à ${arretArrivee.nom}',
        conseil: _conseilParType(ligne3.type, arretArrivee.nom),
        arretMontee: corr2.arret.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne3.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: t4, prix: 0,
        description: 'Marche vers ta destination (~${t4} min)',
      ),
    ];

    final duree = t0 + t1 + 5 + t2 + 5 + t3 + t4;
    final prix = ligne1.prix + ligne2.prix + ligne3.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 2),
      resume: _construireResumeCorrespondance2(
        tempsAPied1: t0,
        ligne1: ligne1,
        ligne2: ligne2,
        ligne3: ligne3,
        tempsAPied2: t4,
        arretArrivee: arretArrivee,
      ),
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

  static String _conseilParType(TransportType type, String arretDescente) {
    switch (type) {
      case TransportType.woroWoro:
        return 'Assieds-toi à l\'avant et dis "$arretDescente" '
            'au chauffeur avant d\'y arriver.';
      case TransportType.gbaka:
        return 'Crie "$arretDescente" quand tu approches. '
            'Le gbaka s\'arrête à la demande.';
      case TransportType.sotra:
        return 'Arrêt fixe à "$arretDescente". '
            'Surveille les panneaux d\'arrêt.';
      case TransportType.yango:
        return 'Le chauffeur connaît la destination. '
            'Confirme l\'adresse au démarrage.';
    }
  }

  static String _construireResumeDirect({
    required int tempsAPied1,
    required Ligne ligne,
    required int tempsTransport,
    required int tempsAPied2,
    required Arret arretArrivee,
  }) {
    final parties = <String>[];
    if (tempsAPied1 > 0) parties.add('🚶 $tempsAPied1 min');
    parties.add('${_emoji(ligne.type)} ${_labelType(ligne.type)} vers ${arretArrivee.nom}');
    if (tempsAPied2 > 0) parties.add('🚶 $tempsAPied2 min');
    return parties.join(' → ');
  }

  static String _construireResumeCorrespondance1({
    required int tempsAPied1,
    required Ligne ligne1,
    required Ligne ligne2,
    required int tempsAPied2,
    required Arret arretArrivee,
  }) {
    final parties = <String>[];
    if (tempsAPied1 > 0) parties.add('🚶 $tempsAPied1 min');
    parties.add('${_emoji(ligne1.type)} ${_labelType(ligne1.type)}');
    parties.add('${_emoji(ligne2.type)} ${_labelType(ligne2.type)} vers ${arretArrivee.nom}');
    if (tempsAPied2 > 0) parties.add('🚶 $tempsAPied2 min');
    return parties.join(' → ');
  }

  static String _construireResumeCorrespondance2({
    required int tempsAPied1,
    required Ligne ligne1,
    required Ligne ligne2,
    required Ligne ligne3,
    required int tempsAPied2,
    required Arret arretArrivee,
  }) {
    final parties = <String>[];
    if (tempsAPied1 > 0) parties.add('🚶 $tempsAPied1 min');
    parties.add('${_emoji(ligne1.type)} → ${_emoji(ligne2.type)}');
    parties.add('${_emoji(ligne3.type)} ${_labelType(ligne3.type)} vers ${arretArrivee.nom}');
    if (tempsAPied2 > 0) parties.add('🚶 $tempsAPied2 min');
    return parties.join(' → ');
  }
}